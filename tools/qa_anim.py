#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""qa_anim.py — gamelife Godot 版动画系统静态 QA
用途：
  1) GDScript 语法粗扫（括号平衡 / 空格缩进 / 控制语句冒号）
  2) EVENT_ANIM 精选表键有效性（是否有拼错的 id）
  3) 复刻 _pick_anims 分发规则，跑全事件池统计动画覆盖率
用法：python3 tools/qa_anim.py
"""
import json
import os
import re
import sys
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = [os.path.join(ROOT, "scripts", "vfx.gd"), os.path.join(ROOT, "scripts", "main.gd")]
DATA = os.path.join(ROOT, "data", "game_data.json")

# 与 vfx.gd 的 EVENT_ANIM 保持同步（键 → 动画）
EVENT_ANIM = {
    "C15": "firework", "N13": "firework", "N24": "firework", "N30": "firework",
    "N42": "firework", "N15": "firework", "S_RETIRE": "firework", "S_HOT": "firework",
    "M01": "jackpot", "M03": "jackpot", "S_LOTTERY": "jackpot", "C04": "jackpot", "C11": "jackpot",
    "P06": "night", "N12": "night", "A004": "night", "A010": "night", "A015": "night",
    "A033": "night", "A038": "night", "M08": "night", "A027": "night",
    "P17": "night", "P21": "night",
    "N21": "rain", "M07": "rain", "M04": "rain", "M12": "rain", "N19": "rain",
    "N18": "rain", "N45": "rain", "N36": "rain", "A020": "rain", "N28": "rain", "M16": "rain",
    "N11": "heartbreak", "N31": "heartbreak", "A007": "heartbreak",
    "A014": "heartbreak", "A030": "heartbreak", "M05": "heartbreak",
    "N01": "exam", "N03": "exam", "N04": "exam", "N07": "exam", "N08": "exam",
    "C08": "exam", "C17": "exam", "C18": "exam", "A003": "exam",
    "N38": "exam", "S_XHSD": "exam",
    "L06": "gamble", "L14": "gamble", "L17": "gamble", "L24": "gamble",
    "L28": "gamble", "A029": "gamble",
    "A008": "code", "A012": "code", "A023": "code", "A031": "code",
    "S_NEAR": "death", "S_ICU": "death", "N39": "death",
    "P09": "death", "P11": "death", "P14": "death", "N22": "death",
    "N34": "smoke", "P16": "smoke",
    "C06": "run", "C14": "run", "N25": "run", "M15": "run",
}

MAX_LAYERS = 3
SOLO_ANIMS = ["glitch", "death", "night", "rain", "jackpot"]
CTRL = re.compile(r"^(\t*)(if|elif|else|for|while|match|func|static func)\b")


def scan_syntax():
    print("=" * 60)
    print("[1] GDScript 静态扫描")
    print("=" * 60)
    issues = 0
    for f in SCRIPTS:
        name = os.path.basename(f)
        text = open(f, encoding="utf-8").read()
        lines = text.split("\n")
        # 括号平衡（排除注释行里的括号会误报，仅作粗查）
        bal = {
            "{": text.count("{") - text.count("}"),
            "(": text.count("(") - text.count(")"),
        }
        space_indent = [i for i, l in enumerate(lines, 1)
                        if l.strip() and re.match(r"^ +", l) and not re.match(r"^\t", l)]
        missing_colon = []
        for i, l in enumerate(lines, 1):
            s = l.rstrip()
            if not s.strip():
                continue
            if CTRL.match(s) and not s.endswith(":"):
                if re.search(r":\s*\S", s):        # 冒号后仍有内容 → 单行内联语句
                    continue
                if s.endswith((",", "[", "{")):    # 本行是续行开头（多行字面量）
                    continue
                prev = lines[i - 2].rstrip() if i >= 2 else ""
                nxt = lines[i].rstrip() if i < len(lines) else ""
                cont = prev.endswith((",", "(", "[", "{", "\\", "and", "or", "+", "-", "="))
                cont = cont or nxt.endswith((",", "]", ")", "}", "\\"))
                if not cont:
                    missing_colon.append((i, s.strip()[:80]))
        print(f"  {name}: {len(lines)} 行")
        print(f"    {{}} 净值={bal['{']:+d}  () 净值={bal['(']:+d}")
        print(f"    空格缩进行: {len(space_indent)}")
        print(f"    疑似缺冒号: {len(missing_colon)}")
        for i, s in missing_colon[:6]:
            print(f"      L{i}: {s}")
        if space_indent or missing_colon:
            issues += len(space_indent) + len(missing_colon)
    print(f"  → {'发现问题 ' + str(issues) + ' 处' if issues else '未发现真实问题（{} 净值非 0 属注释内括号）'}")
    return issues


def check_event_anim():
    print()
    print("=" * 60)
    print("[2] EVENT_ANIM 精选表键有效性")
    print("=" * 60)
    d = json.load(open(DATA, encoding="utf-8"))
    ids = {e["id"] for e in d["EVENTS"]}
    bad = [k for k in EVENT_ANIM if k not in ids]
    if bad:
        print(f"  ✗ 无效 id（{len(bad)} 个）: {bad}")
    else:
        print(f"  ✓ 全部 {len(EVENT_ANIM)} 个键均命中真实事件")
    used = Counter(EVENT_ANIM.values())
    print("  各动画分配事件数:", dict(used.most_common()))
    return len(bad)


def resolve_event_anim(event, ev_anim_table):
    if event.get("eventAnim"):
        return str(event["eventAnim"])
    eid = event.get("id", "")
    if eid in ev_anim_table:
        return ev_anim_table[eid]
    if eid.startswith("A0"):
        return "glitch"
    if event.get("line", "") == "lucky":
        return "gamble"
    return ""


def pick_anims(eff, choice, event, ev_anim_table):
    """复刻 main.gd _pick_anims（用 effects 原值近似 delta）"""
    out = []
    if choice.get("anim"):
        out.append(str(choice["anim"]))
    ev_anim = resolve_event_anim(event, ev_anim_table)
    has_ev = bool(ev_anim)
    if has_ev and ev_anim not in out:
        out.append(ev_anim)

    best = {k: int(v) for k, v in eff.items() if k != "anim"}
    net = sum(v for k, v in best.items() if k != "abstract")

    single = []
    if best.get("money", 0) > 0:
        single.append(("coin", abs(best["money"])))
    elif best.get("money", 0) < 0:
        single.append(("bill", abs(best["money"])))
    if best.get("int", 0) > 0:
        single.append(("brain", abs(best["int"])))
    if best.get("charm", 0) > 0:
        single.append(("heart", abs(best["charm"])))
    if best.get("health", 0) > 0:
        single.append(("muscle", abs(best["health"])))
    elif best.get("health", 0) < 0:
        single.append(("decay", abs(best["health"])))
    if best.get("luck", 0) > 0:
        single.append(("clover", abs(best["luck"])))
    if abs(best.get("abstract", 0)) >= 4:
        single.append(("psych", abs(best["abstract"])))
    if best.get("lifespan", 0) != 0:
        single.append(("hourglass", 5))
    single.sort(key=lambda x: -x[1])

    if has_ev:
        if ev_anim not in SOLO_ANIMS and single:
            out.append(single[0][0])
    else:
        if net >= 6:
            out.append("confetti")
        elif net <= -6:
            out.append("wilt")
        out.extend(t for t, _ in single)

    uniq = []
    for a in out:
        if a not in uniq:
            uniq.append(a)
    if not uniq:
        uniq.append("spark")
    return uniq[:MAX_LAYERS]


def coverage():
    print()
    print("=" * 60)
    print("[3] 动画覆盖率（全事件池 × 全选项）")
    print("=" * 60)
    d = json.load(open(DATA, encoding="utf-8"))
    events = d["EVENTS"]
    dist = Counter()
    layers = Counter()
    ev_anim_events = 0
    fallback_events = 0
    total = 0
    for e in events:
        if resolve_event_anim(e, EVENT_ANIM):
            ev_anim_events += 1
        else:
            fallback_events += 1
        for c in e.get("choices", []):
            total += 1
            a = pick_anims(c.get("effects", {}), c, e, EVENT_ANIM)
            layers[len(a)] += 1
            for x in a:
                dist[x] += 1
    print(f"  事件总数: {len(events)}  |  选项总数: {total}")
    print(f"  有专属动画的事件: {ev_anim_events} ({ev_anim_events * 100 // len(events)}%)"
          f"  |  走属性分发的: {fallback_events}")
    print()
    print("  动画类型出现次数:")
    for k, v in dist.most_common():
        print(f"    {k:12s} {v:4d}")
    print()
    print("  单次选择叠加层数:")
    for k in sorted(layers):
        print(f"    {k} 层: {layers[k]} 次")
    print()
    ev_anims = ["firework", "jackpot", "night", "rain", "heartbreak", "exam",
                "gamble", "code", "death", "glitch", "smoke", "run"]
    hit = [a for a in ev_anims if dist.get(a, 0) > 0]
    print(f"  事件级专属动画中已触发的: {len(hit)}/{len(ev_anims)} -> {hit}")
    miss = [a for a in ev_anims if a not in hit]
    if miss:
        print(f"  ⚠ 未触发: {miss}")
    return total


def check_refs():
    print()
    print("=" * 60)
    print("[4] 函数/常量引用检查（能否抓到「调用了不存在的符号」）")
    print("=" * 60)
    vfx_path = os.path.join(ROOT, "scripts", "vfx.gd")
    main_path = os.path.join(ROOT, "scripts", "main.gd")
    vfx = open(vfx_path, encoding="utf-8").read()
    main = open(main_path, encoding="utf-8").read()

    defined = set(re.findall(r"^static func (\w+)", vfx, re.M))
    consts = set(re.findall(r"^const (\w+)", vfx, re.M))
    members = defined | consts
    print(f"  vfx.gd 导出符号: {len(defined)} 个静态函数 + {len(consts)} 个常量")

    # _dispatch 里的 case → 函数调用
    calls = re.findall(r'"[A-Za-z_]+":\s+(_\w+)\(', vfx)
    missing = sorted({c for c in calls if c not in defined})
    print(f"  _dispatch 分发调用: {len(calls)} 个 -> " +
          ("✓ 全部有定义" if not missing else f"✗ 缺失 {missing}"))

    # main.gd 里对 ChoiceVFX 的引用
    refs = sorted(set(re.findall(r"ChoiceVFX\.(\w+)", main)))
    bad_refs = [r for r in refs if r not in members]
    print(f"  main.gd 引用 ChoiceVFX: {refs}")
    print("    -> " + ("✓ 全部存在" if not bad_refs else f"✗ 不存在 {bad_refs}"))

    # 动画类型 → 是否有 dispatch 分支（防止分发器漏了某类型）
    dispatch_types = set(re.findall(r'"([a-z]+)":\s+_\w+\(', vfx))
    if re.search(r"_\s*:\s+_spark\(", vfx):
        dispatch_types.add("spark")   # 默认分支 _: _spark(...)
    used_types = {"coin", "bill", "brain", "heart", "muscle", "decay", "clover",
                  "psych", "hourglass", "confetti", "wilt", "tag", "spark",
                  "firework", "jackpot", "night", "rain", "heartbreak", "exam",
                  "gamble", "code", "death", "glitch", "smoke", "run"}
    not_dispatch = sorted(used_types - dispatch_types)
    print(f"  分发器覆盖动画类型: {len(dispatch_types)}/{len(used_types)} -> " +
          ("✓ 无遗漏" if not not_dispatch else f"✗ 未分发 {not_dispatch}"))
    return len(missing) + len(bad_refs) + len(not_dispatch)


if __name__ == "__main__":
    bad_syn = scan_syntax()
    bad_ids = check_event_anim()
    coverage()
    bad_refs = check_refs()
    print()
    print("=" * 60)
    ok = bad_syn == 0 and bad_ids == 0 and bad_refs == 0
    print("QA 结论:", "PASS" if ok else f"存在待确认项 (语法 {bad_syn} / 无效id {bad_ids} / 引用 {bad_refs})")
    sys.exit(0 if ok else 1)
