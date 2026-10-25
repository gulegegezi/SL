"""续写三个前 30 岁的事件：LC26（幼儿园毕业照）/ LC27（我的理想）/ LC28（志愿表）。

用学到的旁白口吻：旁白有立场、元叙述具体、梗落在具体物件上。
生成完整的 event 结构（lenses / choices / outcomes / panels）并补 dialogue book。
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EVENT_PATH = ROOT / "data" / "story_life_comic.json"
DIALOGUE_PATH = ROOT / "data" / "story_life_dialogue.json"

# ---------------------------------------------------------------- LC26
LC26 = {
    "id": "LC26",
    "title": "幼儿园毕业照，笑得像知道未来",
    "age_range": [5, 7],
    "stage": "childhood",
    "scene": "classroom",
    "actors": ["lead", "teacher", "friend"],
    "prop": "",
    "facts": "毕业照排队时，老师要求每个人笑得像知道未来。你不太确定未来长什么样，但旁边的同学已经笑僵了。",
    "npc_dialogue": "老师：不用露牙，想象一件好事就行。",
    "lenses": [
        {"narrator": "你第一次被要求表演“知道未来”。", "inner": "可我只知道今天的点心是豆沙包。", "dialogue": "豆沙包。", "result_tail": "快门响了，你笑得很像你自己。"},
        {"narrator": "毕业照项目进入表情招标阶段，标书要求：像知道未来。", "inner": "我未来的全部信息：今天有豆沙包。", "dialogue": "可以笑给豆沙包吗？", "result_tail": "照片洗出来，老师说你笑得太具体了。"},
        {"narrator": "脑内未来是一间很大的教室，你先在里面找豆沙包。", "inner": "如果未来没有豆沙包，那也算一种答案。", "dialogue": "我准备好了。", "result_tail": "未来的教室里，豆沙包暂时还没出现。"},
        {"narrator": "想象中的时间管理局要求你提交一份“未来知情同意书”。", "inner": "本人对未来一无所知，但愿意配合拍照。", "dialogue": "先拍，再知道。", "result_tail": "时间管理局没有批复，照片先归档了。"},
    ],
    "choices": [
        {"label": "按老师说的笑", "intent": "perform", "effects": {"mental": 2, "abstract": 1},
         "lines": ["豆沙包。", "我在想豆沙包。", "未来会有豆沙包吗？", "先笑，再想。"],
         "memory": "_毕业照_标准笑",
         "outcome": {"facts": "你笑得很标准。照片挂上墙，家长群里一片“真乖”。", "visual": "settle"},
         "responses": "标准笑通过验收。旁白：这张以后会出现在家庭群，配文“我们家的乖崽”。"},
        {"label": "做鬼脸", "intent": "rebel", "effects": {"charm": 1, "abstract": 2},
         "lines": ["略。", "我要留证据。", "这张以后能卖钱吗？", "本照片最终解释权归我。"],
         "memory": "_毕业照_鬼脸",
         "outcome": {"facts": "你做了个鬼脸。照片洗出来，老师犹豫了三秒，还是发了。", "visual": "wave"},
         "responses": "老师犹豫了三秒。旁白：那三秒，是这张照片最值钱的部分。"},
        {"label": "问“未来是什么味道”", "intent": "curious", "effects": {"mental": 1, "abstract": 3},
         "lines": ["什么味？", "是豆沙包味吗？", "能尝一口吗？", "请给未来加一点糖。"],
         "memory": "_毕业照_未来味",
         "outcome": {"facts": "你问了。老师愣住，旁边的同学替他回答：“甜的。”", "visual": "raise"},
         "responses": "同学替你答了。旁白：本作第一个替旁白解围的 NPC。"},
    ],
    "narrator_asides": [
        "旁白提醒：毕业照不按颜值收费，按配合度。",
        "家长群即将出现本条照片。旁白建议先检查牙缝。",
        "摄影师喊三二一。旁白喊：这可能是你最后一次毫无理由地笑。",
        "宇宙时间局暂无回应。旁白代签：已知晓，先拍。",
    ],
}

# ---------------------------------------------------------------- LC27
LC27 = {
    "id": "LC27",
    "title": "我的理想，不在评分标准里",
    "age_range": [9, 12],
    "stage": "school",
    "scene": "classroom",
    "actors": ["lead", "teacher"],
    "prop": "notebook",
    "facts": "作文题是《我的理想》。你写：想当一名玩家。老师把你叫到办公室，说这个理想不在评分标准里。",
    "npc_dialogue": "老师：换个能写的。科学家、老师、医生，都行。",
    "lenses": [
        {"narrator": "你认真写了一个理想，老师说它“不够具体”。", "inner": "我明明写得很具体：每天上线。", "dialogue": "玩家也要上班吗？", "result_tail": "作文本发下来，评语是“想象丰富，注意审题”。"},
        {"narrator": "作文评分标准里没有“玩家”这一项。旁白查了一下，也没有“旁白”。", "inner": "那旁白的理想算什么？", "dialogue": "能加个选项吗？", "result_tail": "分数不高，但你把“玩家”两个字写得很好看。"},
        {"narrator": "脑内理想是一张巨大的地图，你在地图边缘找到一块没标注的区域。", "inner": "也许理想就是还没被命名的地方。", "dialogue": "我先去那边看看。", "result_tail": "那块没标注的区域，被你记住了。"},
        {"narrator": "想象中的职业介绍所只收录了三百六十行，你站在第三百六十一行前面。", "inner": "系统没收录，不代表不存在。", "dialogue": "申请新增一行。", "result_tail": "介绍所没有回复，你把自己的名字写在了那一行。"},
    ],
    "choices": [
        {"label": "坚持不改，就写玩家", "intent": "rebel", "effects": {"mental": 2, "abstract": 2},
         "lines": ["我想当玩家。", "玩家也是职业。", "至少我是认真的。", "请保留原文。"],
         "memory": "_理想_玩家",
         "outcome": {"facts": "你没有改。作文得了中等分，老师在旁边写：“希望你找到自己的玩法。”", "visual": "read"},
         "responses": "你没有改。旁白：中等分，但这是本页唯一一句你亲手写的。"},
        {"label": "改成科学家，研究游戏", "intent": "comply", "effects": {"mental": 2},
         "lines": ["好，我改。", "科学家具体一点。", "那我研究游戏行吗？", "科学地玩游戏。"],
         "memory": "_理想_科学家",
         "outcome": {"facts": "你改成了科学家。老师满意，你在结尾偷偷加了一句“研究游戏也算”。", "visual": "draw"},
         "responses": "老师满意。旁白：你在结尾埋的那句，二十年后会有人翻出来。"},
        {"label": "加一句“以上内容由玩家本人负责”", "intent": "meta", "effects": {"abstract": 3, "charm": 1},
         "lines": ["加一句免责声明。", "以上内容由玩家本人负责。", "出了问题找我。", "旁白可以作证。"],
         "memory": "_理想_免责声明",
         "outcome": {"facts": "你在结尾加了一行小字。老师看了很久，最后说：“这句写得比正文好。”", "visual": "draw"},
         "responses": "老师看了很久。旁白：她可能第一次见到有作者给自己的作文写免责声明。"},
    ],
    "narrator_asides": [
        "旁白提醒：本题按“符合考纲”评分，不按“符合本人”评分。",
        "旁白查了评分标准，第 7 条写着“理想应积极向上”。玩家不在列表里。",
        "地图边缘那块空白，旁白也没去过。",
        "第三百六十一行暂时没有工资，也没有社保。",
    ],
}

# ---------------------------------------------------------------- LC28
LC28 = {
    "id": "LC28",
    "title": "志愿表上没有“以后再说”",
    "age_range": [17, 19],
    "stage": "adolescence",
    "scene": "classroom",
    "actors": ["lead", "teacher"],
    "prop": "report",
    "facts": "填志愿那天，系统里有一百多个专业，没有一个是“以后再说”。你盯着屏幕，倒计时开始。",
    "npc_dialogue": "班主任：先选一个能上的，剩下的以后再说。",
    "lenses": [
        {"narrator": "你第一次发现，选择是要计时的。", "inner": "以后再说，算不算一个专业？", "dialogue": "有“以后再说”吗？", "result_tail": "你按下确认，倒计时停了。"},
        {"narrator": "志愿系统共 128 个专业，没有“再想想”选项。旁白建议先别刷新页面。", "inner": "刷新能刷出人生吗？", "dialogue": "能保存吗？", "result_tail": "系统提示：提交后不可修改。你确认了两次。"},
        {"narrator": "脑内志愿表是一张车票，目的地一栏空着。", "inner": "空着也许不是错误。", "dialogue": "我先不填。", "result_tail": "车票没有目的地，但你上了车。"},
        {"narrator": "想象中的未来规划局要求你提交一份确定的人生，窗口写着：不确定请排队。", "inner": "排队也算一种前进。", "dialogue": "拿个号。", "result_tail": "规划局下班了，你还在排队。"},
    ],
    "choices": [
        {"label": "选一个最像的", "intent": "comply", "effects": {"mental": 2, "money": 1},
         "lines": ["就这个吧。", "像就够了。", "以后可以换吗？", "先上车。"],
         "memory": "_志愿_最像",
         "outcome": {"facts": "你选了一个最像的。班主任松了口气，你在备注里写了“待定”。", "visual": "read"},
         "responses": "提交成功。旁白：你在备注里写的“待定”，比专业名更像你。"},
        {"label": "填“其他”，写理由", "intent": "rebel", "effects": {"abstract": 2, "mental": 1},
         "lines": ["我选其他。", "理由：还没想好。", "这不是偷懒。", "这是留白。"],
         "memory": "_志愿_留白",
         "outcome": {"facts": "你在“其他”里写了一行理由。系统卡了三秒，居然通过了。", "visual": "draw"},
         "responses": "系统卡了三秒。旁白：那三秒它在读你的理由，还是在读你的胆子？"},
        {"label": "问能不能自己开一个", "intent": "curious", "effects": {"abstract": 3, "charm": 2},
         "lines": ["能开一个吗？", "就叫“以后再说”。", "我当第一个学生。", "学费怎么算？"],
         "memory": "_志愿_开一个",
         "outcome": {"facts": "班主任笑了半天，说：“你先毕业，再开。”", "visual": "wave"},
         "responses": "班主任笑了半天。旁白：这个专业暂时只有你一个学生，和一个不肯下班的旁白。"},
    ],
    "narrator_asides": [
        "旁白提醒：倒计时不会因为你在思考人生而暂停。",
        "128 个专业里没有“再想想”。旁白申请新增，被系统驳回。",
        "车票没有目的地。旁白给你留了个靠窗位。",
        "规划局窗口：不确定请排队。队伍很长，大家都差不多。",
    ],
}


def build_event(src: dict) -> dict:
    actors = src["actors"]
    bindings = {a: ("lead" if a == "lead" else a) for a in actors}
    lenses = src["lenses"]
    event_panels = [
        {"shot": "wide", "actors": actors, "action": "establish", "caption": src["facts"]},
        {"shot": "detail", "actors": actors, "action": "look_at_prop", "prop": src["prop"], "caption": src["npc_dialogue"]},
        {"shot": "medium", "actors": ["lead"], "action": "react", "voice_ref": "lenses[tier]"},
        {"shot": "wide", "actors": actors, "action": "choice_pause", "prop": src["prop"]},
    ]
    choices = []
    for ci, c in enumerate(src["choices"]):
        lines = c["lines"]
        outcome = c["outcome"]
        voices = []
        for t in range(4):
            voices.append({
                "tier": t,
                "narrator": outcome["facts"] + " " + lenses[t]["result_tail"],
                "inner": lenses[t]["inner"],
                "dialogue": lines[t],
            })
        outcome_panels = [
            {"shot": "medium", "actors": actors, "action": "hold", "prop": src["prop"], "caption": c["label"]},
            {"shot": "wide", "actors": actors, "action": outcome["visual"], "prop": src["prop"], "caption": outcome["facts"]},
            {"shot": "detail", "actors": ["lead"], "action": "settle", "prop": src["prop"],
             "voice_ref": "selected_outcome.voices[tier]"},
        ]
        choices.append({
            "label": c["label"],
            "intent": c["intent"],
            "effects": c["effects"],
            "lines": lines,
            "memory": c["memory"],
            "id": "%s.C%d" % (src["id"], ci + 1),
            "outcomes": [{
                "weight": 1,
                "facts": outcome["facts"],
                "visual": outcome["visual"],
                "effects": c["effects"],
                "memory": c["memory"],
                "id": "%s.C%d.O1" % (src["id"], ci + 1),
                "voices": voices,
                "panels": outcome_panels,
            }],
        })
    return {
        "id": src["id"], "title": src["title"], "age_range": src["age_range"],
        "stage": src["stage"], "scene": src["scene"], "actors": actors, "prop": src["prop"],
        "facts": src["facts"], "npc_dialogue": src["npc_dialogue"], "lenses": lenses,
        "choices": choices, "requirements": {}, "callback": None,
        "recurrence": {"once": True, "cooldown_years": 0},
        "panels": event_panels, "cast_bindings": bindings,
        "narrator_asides": src["narrator_asides"],
    }


def main() -> None:
    data = json.loads(EVENT_PATH.read_text(encoding="utf-8"))
    existing = {e["id"] for e in data["events"]}
    for src in (LC26, LC27, LC28):
        assert src["id"] not in existing, src["id"] + " 已存在"
        data["events"].append(build_event(src))
    data["events"].sort(key=lambda e: (e["age_range"][0], e["id"]))
    EVENT_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    book = json.loads(DIALOGUE_PATH.read_text(encoding="utf-8"))
    guides = {
        "LC26": ["老师喊看镜头。你先确认点心还在不在。",
                 "我准备拍一张“知道未来”的脸。主演的表情包里没有这一项。",
                 "未来很大，你先在里面找豆沙包。",
                 "时间管理局没有回复。旁白代签：先拍，后果自负。"],
        "LC27": ["笔在你手里，评分标准在老师手里。",
                 "这篇作文的评分标准里没有“玩家”。旁白查过了。",
                 "地图边缘有一块没标注的地方。",
                 "第三百六十一行还没有工资，但可以先写名字。"],
        "LC28": ["倒计时开始了。你可以选，也可以先想。",
                 "128 个专业，没有“再想想”。旁白建议先别刷新。",
                 "车票空着目的地，也能上车。",
                 "规划局快下班了。队伍里的人都还没想好。"],
    }
    for src in (LC26, LC27, LC28):
        eid = src["id"]
        existing_guides = guides[eid]
        book["events"][eid] = {
            "guide": existing_guides,
            "responses": [c["responses"] for c in src["choices"]],
            "roast": [g + "（旁白备注）" for g in existing_guides],
            "npc": [src["npc_dialogue"]] * 3,
        }
    DIALOGUE_PATH.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("added LC26/LC27/LC28; events:", len(data["events"]))


if __name__ == "__main__":
    main()
