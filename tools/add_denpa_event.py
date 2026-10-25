"""加一个「电波系误会」事件 LC34，给 20 代补一种日常误会喜剧。

参考《GAMERS 电玩咖》的写法：每个人都只掌握一半信息，于是各自动作、
互相加码，最后由旁白把「此刻的误会」摆出来。不抄原文，只学结构。
"""
import json
from pathlib import Path

import add_story_events as base

ROOT = Path(__file__).resolve().parent.parent
EVENT_PATH = ROOT / "data" / "story_life_comic.json"
DIALOGUE_PATH = ROOT / "data" / "story_life_dialogue.json"

LC34 = {
    "id": "LC34",
    "title": "联机到十点，被邻居误会在相亲",
    "age_range": [23, 32],
    "stage": "adult",
    "scene": "home",
    "actors": ["lead", "boss"],
    "prop": "phone",
    "facts": "周五晚上，你和同事联机打游戏，语音里喊“打他打他”。十点，邻居敲门送水果，往屋里看了一眼：一台电视、两个人、满地零食。她笑着说：年轻人，慢慢聊。门关上了，语音里同事问：刚才谁啊？",
    "npc_dialogue": "同事：刚才谁啊？\n你：邻居，送水果。\n同事：她为什么笑得那么懂？\n你：可能误会了。\n同事：误会什么？\n你：误会我们在约会。",
    "misread": "邻居认定你在约会；同事以为你被邻居催婚；你以为自己只是打了个排位。",
    "lenses": [
        {"narrator": "你第一次发现，解释也会被当成剧情推进。", "inner": "我说的是游戏，她听到的是好事将近。", "dialogue": "阿姨，我们在打游戏。", "result_tail": "门关上以后，语音里同事笑到破音。"},
        {"narrator": "邻里关系进入信息不对称阶段，水果是开场白。", "inner": "她送的是苹果，收走的是我的清白。", "dialogue": "这真是同事。", "result_tail": "第二天，楼道里多了一个版本。"},
        {"narrator": "脑内邻里群正在直播一档叫《年轻人》的节目。", "inner": "我在自己家，成了别人剧里的角色。", "dialogue": "不是你们想的那样。", "result_tail": "群里的剧情比游戏精彩。"},
        {"narrator": "想象中的社区广播站播报：本单元新增一段佳话。", "inner": "我只是想安静地输一把。", "dialogue": "请把音量调小。", "result_tail": "广播没有停，游戏也输了。"},
    ],
    "choices": [
        {"label": "追出去解释清楚", "intent": "explain", "effects": {"mental": 1, "charm": 1},
         "lines": ["阿姨，我们在打游戏。", "真的是同事。", "您别多想。", "我解释十分钟了。"],
         "memory": "_误会_解释",
         "outcome": {"facts": "你追到楼道解释了十分钟。邻居点头：“我懂，我懂。”第二天，传闻从“约会”升级成“同居”。", "visual": "talk"},
         "responses": "你解释得很清楚。旁白：清楚到邻居开始替你规划婚礼。",
         "roast": "旁白：你解释了十分钟，误会从“约会”升级成“同居”。"},
        {"label": "不解释，继续打", "intent": "avoid", "effects": {"mental": 2},
         "lines": ["算了。", "继续。", "先打排位。", "解释打不赢。"],
         "memory": "_误会_不解释",
         "outcome": {"facts": "你没解释。第二天，楼下大爷见你就问：“对象呢？今天没来？”", "visual": "phone"},
         "responses": "你选择沉默。旁白：沉默被解读成了默认，默认又被解读成了进度条。"},
        {"label": "干脆请同事来家吃顿饭", "intent": "lean_in", "effects": {"charm": 2, "mental": 1, "abstract": 1},
         "lines": ["一起吃个饭吧。", "把误会做实。", "省得解释。", "就当团建。"],
         "memory": "_误会_做实",
         "outcome": {"facts": "周末你们真吃了顿饭。邻居在楼道里点头：“进展不错。”你说：只是团建。她说：懂。", "visual": "offer"},
         "responses": "你们吃了饭。旁白：邻居的误会得到了实体支持，从此再没怀疑过。",
         "roast": "旁白：你用一个更大的误会，覆盖了上一个误会。"},
    ],
    "narrator_asides": [
        "旁白提醒：水果不是证据，但在这里算。",
        "楼道是本地最大的信息交易所。",
        "脑内直播间标题：他到底有没有对象。",
        "社区广播站不接受撤稿。",
    ],
}


def main() -> None:
    data = json.loads(EVENT_PATH.read_text(encoding="utf-8"))
    ids = {e["id"] for e in data["events"]}
    assert "LC34" not in ids, "LC34 已存在"
    ev = base.build_event(LC34)
    ev["misread"] = LC34["misread"]
    for c in LC34["choices"]:
        if c.get("roast"):
            for built in ev["choices"]:
                if built["label"] == c["label"]:
                    built["roast"] = c["roast"]
    data["events"].append(ev)
    data["events"].sort(key=lambda e: (e["age_range"][0], e["id"]))
    EVENT_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    book = json.loads(DIALOGUE_PATH.read_text(encoding="utf-8"))
    book["events"]["LC34"] = {
        "guide": ["邻居敲门了。你可以解释，也可以继续打。",
                  "信息不对称开始累积。水果只是开场白。",
                  "脑内邻里群正在直播你的生活。",
                  "社区广播站已经拟好标题。"],
        "responses": [c["responses"] for c in LC34["choices"]],
        "roast": ["旁白备注：解释也是一种加戏。",
                  "旁白备注：沉默会被当作默认。",
                  "旁白备注：更大的误会盖住上一个。",
                  "旁白备注：广播站不撤稿。"],
        "npc": [LC34["npc_dialogue"]] * 3,
    }
    DIALOGUE_PATH.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("added LC34; events:", len(data["events"]))


if __name__ == "__main__":
    main()
