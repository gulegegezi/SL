"""续写两个「纯文本叙事」事件：LC29 搬家 / LC30 父亲的手机。

文字量大、旁白口吻，页面走 presentation=text（大字号、宽行距、无 3D）。
"""
import json
from pathlib import Path

import add_story_events as base

ROOT = Path(__file__).resolve().parent.parent
EVENT_PATH = ROOT / "data" / "story_life_comic.json"
DIALOGUE_PATH = ROOT / "data" / "story_life_dialogue.json"

LC29 = {
    "id": "LC29",
    "title": "搬家那天，纸箱比人先认识新家",
    "age_range": [9, 13],
    "stage": "school",
    "scene": "home",
    "actors": ["lead", "parent", "mate"],
    "prop": "",
    "facts": "搬家那天，纸箱比人先认识新家。你在第七个箱子上写“我的”，笔没水了。新家的墙很白，白到能照出你旧东西的缺点。爸爸说先睡一晚就习惯了，妈妈在找烧水的锅，你坐在还没拆的箱子上，觉得房间比原来小，又比原来空。",
    "npc_dialogue": "爸爸：先睡一晚，明天就习惯了。",
    "lenses": [
        {"narrator": "你第一次发现，家可以被装进箱子。", "inner": "箱子上写“我的”，算不算一种占地方？", "dialogue": "这个放哪儿？", "result_tail": "第一晚，你在新房间听见旧家具的声音。"},
        {"narrator": "搬家项目进入拆箱阶段，进度条停在第七个箱子。", "inner": "我的东西不多，但每一样都占一个位置。", "dialogue": "先拆哪个？", "result_tail": "箱子拆到一半，你决定先吃晚饭。"},
        {"narrator": "脑内新家是一张还没画完的地图，旧家具在上面找位置。", "inner": "地图空着的地方，可以留给以后。", "dialogue": "先把床放好。", "result_tail": "地图完成了四分之一，够睡了。"},
        {"narrator": "想象中的居住管理局要求你为新房间重新登记所有物。", "inner": "有些东西没有编号，只有记忆。", "dialogue": "先登记那盏灯。", "result_tail": "管理局下班了，灯还亮着。"},
    ],
    "choices": [
        {"label": "把箱子按记忆顺序拆", "intent": "order", "effects": {"mental": 2, "abstract": 1},
         "lines": ["先拆书架。", "再拆台灯。", "箱子会记得顺序吗？", "按老房间的来。"],
         "memory": "_搬家_记忆顺序",
         "outcome": {"facts": "你按老房间的顺序拆箱，新家慢慢有了旧家的形状。", "visual": "hold"},
         "responses": "你按记忆拆箱。旁白：新家没有记忆，只好借你的。"},
        {"label": "先在墙上贴一张旧照片", "intent": "anchor", "effects": {"mental": 1, "charm": 1},
         "lines": ["先贴照片。", "墙就不空了。", "这是哪儿？", "我们家。"],
         "memory": "_搬家_先贴照片",
         "outcome": {"facts": "你把旧照片贴在墙上，房间先有了一小块熟悉。", "visual": "raise"},
         "responses": "照片先上了墙。旁白：家具还没到，家先到了。"},
        {"label": "坐在箱子上发呆", "intent": "rest", "effects": {"mental": 2, "abstract": 2},
         "lines": ["先坐会儿。", "不急。", "箱子挺结实。", "明天再拆。"],
         "memory": "_搬家_发呆",
         "outcome": {"facts": "你坐在箱子上发呆，妈妈没催你，只把灯打开了。", "visual": "sit"},
         "responses": "你没有拆箱。旁白：搬家第一天，允许只负责坐着。"},
    ],
    "narrator_asides": [
        "旁白提醒：纸箱上的字，以后会成为拆箱的说明书。",
        "进度条停在第七个箱子。旁白建议先吃饭，进度条不会跑。",
        "地图空着的地方，可能是留给新朋友的。",
        "居住管理局下班了。灯还亮着，就算登记过了。",
    ],
    "text_only": True,
}

LC30 = {
    "id": "LC30",
    "title": "父亲的第一部手机，只会接不会打",
    "age_range": [14, 17],
    "stage": "adolescence",
    "scene": "home",
    "actors": ["lead", "mate"],
    "prop": "phone",
    "facts": "爸爸买了第一部手机，只会接不会打。他让你把常用号码存进去，你发现通讯录第一行写着“家”。他练习了三次拨号，每次都拨到一半就放下。你说我教你，他摆手：我会。然后继续按错。",
    "npc_dialogue": "爸爸：我会，就是按得慢。",
    "lenses": [
        {"narrator": "你第一次教爸爸用一样他承认不会的东西。", "inner": "他按错的时候，假装是手机的问题。", "dialogue": "按这个绿的。", "result_tail": "电话通了，他先说的是一句“没事”。"},
        {"narrator": "家庭技术支持工单：一部手机，一位不肯看说明书的用户。", "inner": "教三遍不算多，他等我长大用了十几年。", "dialogue": "再看一遍。", "result_tail": "他最后学会了，但只打给你。"},
        {"narrator": "脑内通讯录第一行永远是“家”，后面才是世界。", "inner": "有些号码不用背，按下去就是。", "dialogue": "先存你的。", "result_tail": "通讯录越存越长，第一行没变。"},
        {"narrator": "想象中的电信局记录了一通只响一声的电话。", "inner": "他打来不是有事，是想确认你还在。", "dialogue": "我接。", "result_tail": "记录里那通电话，响了一声就挂断。"},
    ],
    "choices": [
        {"label": "一步一步教他拨号", "intent": "teach", "effects": {"mental": 2, "charm": 1},
         "lines": ["按绿的。", "先拨号，再按这个。", "错了也没关系。", "再来一次。"],
         "memory": "_手机_教拨号",
         "outcome": {"facts": "你教了他三次，第四次他自己拨通了，第一句话是“我就试试”。", "visual": "phone"},
         "responses": "第四次他自己拨通了。旁白：他说的“我就试试”，其实准备了很久。"},
        {"label": "把自己的号码设成快捷 1", "intent": "shortcut", "effects": {"mental": 1, "abstract": 1},
         "lines": ["设成 1 吧。", "按一下就行。", "别告诉妈。", "这样最快。"],
         "memory": "_手机_快捷1",
         "outcome": {"facts": "你把号码设成快捷 1。后来他按错过很多次，唯独没按错过 1。", "visual": "phone"},
         "responses": "快捷 1 设好了。旁白：这是本作最短的一条回家路线。"},
        {"label": "假装没看见，让他自己练", "intent": "space", "effects": {"mental": 2, "abstract": 1},
         "lines": ["我先走开。", "他自己能行。", "别盯着他。", "练习需要观众缺席。"],
         "memory": "_手机_自己练",
         "outcome": {"facts": "你假装去倒水。回来时他正对着手机说“通了通了”，像在跟谁报喜。", "visual": "phone"},
         "responses": "你假装路过。旁白：你把“耐心的艺术”演成了“假装路过的艺术”。"},
    ],
    "narrator_asides": [
        "旁白提醒：说明书在盒子最底下，和他想的一样难找。",
        "工单状态：用户拒绝阅读说明书，但愿意按错十次。",
        "通讯录第一行是“家”。旁白：这个号码不用备注也知道是谁。",
        "电信局记录：响一声，挂断。疑似“确认你在”专线。",
    ],
    "text_only": True,
}


def main() -> None:
    data = json.loads(EVENT_PATH.read_text(encoding="utf-8"))
    ids = {e["id"] for e in data["events"]}
    for src in (LC29, LC30):
        assert src["id"] not in ids, src["id"] + " 已存在"
        ev = base.build_event(src)
        ev["text_only"] = True
        data["events"].append(ev)
    data["events"].sort(key=lambda e: (e["age_range"][0], e["id"]))
    EVENT_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    book = json.loads(DIALOGUE_PATH.read_text(encoding="utf-8"))
    for src in (LC29, LC30):
        eid = src["id"]
        book["events"][eid] = {
            "guide": [
                "箱子还没拆完，你先决定把什么放哪儿。",
                "搬家进度条停在第七个箱子。旁白建议先安顿一件小的。",
                "新家的地图还没画完，先从最占地方的那件家具开始。",
                "居住管理局没有回音。灯先亮着，就算住进来了。",
            ],
            "responses": [c["responses"] for c in src["choices"]],
            "roast": [g + "（旁白备注）" for g in [
                "箱子还没拆完，你先决定把什么放哪儿。",
                "搬家进度条停在第七个箱子。",
                "新家的地图还没画完。",
                "居住管理局没有回音。",
            ]],
            "npc": [src["npc_dialogue"]] * 3,
        }
    # 父亲的手机：一句话吐槽
    book["events"]["LC30"]["roast"] = [
        "旁白：说明书在盒子最底下，你先找到了耐心。",
        "旁白：本作最短的回家路线，一键。",
        "旁白：你把“耐心”演成了“假装路过”。",
        "旁白：他确认的不是号码，是你还在。",
    ]
    DIALOGUE_PATH.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("added text-only LC29/LC30; events:", len(data["events"]))


if __name__ == "__main__":
    main()
