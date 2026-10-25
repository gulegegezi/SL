"""剧情体检：结构、回响（串）、重复度、长度。

用法：
    python tools/check_story.py [data/story_life_comic.json]

退出码 0 = 全部通过；1 = 有错误（错误会逐条打印）。
"""
import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT = ROOT / "data" / "story_life_comic.json"
STAGES = {"infancy", "early_childhood", "childhood", "school", "adolescence",
           "young_adult", "adult", "midlife", "later_life"}
ROOMS = {"home", "classroom", "office", "park", "hospital", "grave"}
LIMITS = {"narrator": 90, "inner": 70, "dialogue": 50, "result_tail": 70}

errors: list[str] = []
warnings: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def main() -> int:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT
    data = json.loads(path.read_text(encoding="utf-8"))
    events = data.get("events", [])
    if not events:
        err("没有 events")
        return report(data)

    ids: dict[str, dict] = {}
    for e in events:
        eid = e.get("id", "")
        if not eid:
            err("事件缺 id")
            continue
        if eid in ids:
            err(f"{eid}: id 重复")
        ids[eid] = e
        if not e.get("title"):
            err(f"{eid}: 缺 title")
        rng = e.get("age_range", [])
        if len(rng) != 2 or rng[0] > rng[1]:
            err(f"{eid}: age_range 非法 {rng}")
        if e.get("stage") not in STAGES:
            warn(f"{eid}: 未知 stage {e.get('stage')}")
        if e.get("scene") not in ROOMS:
            warn(f"{eid}: 未知 scene {e.get('scene')}")
        choices = e.get("choices", [])
        if len(choices) != 3:
            err(f"{eid}: 选项应为 3 个，实际 {len(choices)}")
        lenses = e.get("lenses", [])
        if len(lenses) != 4:
            err(f"{eid}: lenses 应为 4 档，实际 {len(lenses)}")
        for i, lens in enumerate(lenses):
            for field in ("narrator", "inner", "dialogue", "result_tail"):
                text = str(lens.get(field, ""))
                if not text:
                    err(f"{eid}: T{i} 缺 {field}")
                elif len(text) > LIMITS[field]:
                    warn(f"{eid}: T{i} {field} 过长 {len(text)} 字（上限 {LIMITS[field]}）")

    # 回响：echo.from 必须是更早的事件
    echo_count = 0
    for e in events:
        echo = e.get("echo")
        if not echo:
            continue
        echo_count += 1
        src = echo.get("from", "")
        if src not in ids:
            err(f"{e.get('id')}: echo.from 不存在 {src}")
            continue
        if ids[src].get("age_range", [99])[0] >= e.get("age_range", [0])[0]:
            err(f"{e.get('id')}: echo.from {src} 不比它更早")

    motifs = data.get("motifs", {})
    for name, m in motifs.items():
        for eid in m.get("events", []):
            if eid not in ids:
                err(f"motif {name}: 引用了不存在的事件 {eid}")

    # 重复度：旁白开头 8 字
    heads = Counter()
    for e in events:
        for lens in e.get("lenses", []):
            t = str(lens.get("narrator", ""))[:8]
            if t:
                heads[t] += 1
    repeats = [(h, n) for h, n in heads.items() if n >= 4]

    total_chars = sum(len(str(l.get("narrator", ""))) + len(str(l.get("inner", "")))
                      for e in events for l in e.get("lenses", []))
    report(data, ids, echo_count, repeats, total_chars)
    return 0 if not errors else 1


def report(data, ids=None, echo_count=0, repeats=(), total_chars=0) -> int:
    events = data.get("events", [])
    print(f"事件 {len(events)} 条；回响 {echo_count} 处；motif {len(data.get('motifs', {}))} 个")
    print(f"旁白/内心总字数 {total_chars}")
    ages = sorted(e.get("age_range", [0])[0] for e in events)
    if ages:
        print(f"年龄段 {ages[0]}–{max(e.get('age_range', [0])[1] for e in events)}")
    for e in events:
        tc = len(e.get("choices", []))
        if tc != 3:
            print(f"  选项数异常 {e.get('id')}: {tc}")
    if repeats:
        print("重复开头（>=4 次）：")
        for h, n in repeats:
            print(f"  {h}… ×{n}")
    for w in warnings:
        print("WARN", w)
    for e in errors:
        print("ERROR", e)
    print("结论：", "通过" if not errors else f"{len(errors)} 个错误")
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
