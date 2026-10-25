"""30 岁前后再加三个事件：同学会 / 健身年卡 / 相册回忆。

沿用旁白三句法（设定 → 元吐槽 → 具体物件），每个选项都有回应，离谱选项带吐槽。
"""
import json
from pathlib import Path

import add_story_events as base

ROOT = Path(__file__).resolve().parent.parent
EVENT_PATH = ROOT / "data" / "story_life_comic.json"
DIALOGUE_PATH = ROOT / "data" / "story_life_dialogue.json"

LC31 = {
    "id": "LC31",
    "title": "同学群里有人 @全体，说要办十周年聚会",
    "age_range": [28, 34],
    "stage": "adult",
    "scene": "park",
    "actors": ["lead", "friend"],
    "prop": "",
    "facts": "同学群突然跳出 @全体：十周年聚会，AA，地点定在当年校门口那家店。群里瞬间刷出三十条“必须到”，然后安静了。你翻了翻日历，那天刚好没事，也刚好不太想去。",
    "npc_dialogue": "班长：不来也行，先把钱交了，群里好统计。",
    "lenses": [
        {"narrator": "你盯着“必须到”三个字，想起当年也这么喊过。", "inner": "我到底是想见人，还是怕被写进“没来名单”？", "dialogue": "那天我有空吗？", "result_tail": "你最后看了一眼群公告，没点接龙。"},
        {"narrator": "十周年聚会项目进入报名阶段，热情与 AA 制同步在线。", "inner": "群里的“必须到”一般活不过三天。", "dialogue": "先交钱还是先交人？", "result_tail": "接龙停在第十七位，像当年值日表。"},
        {"narrator": "脑内同学会是一间巨大的教室，所有人的座位都还在原来的位置。", "inner": "我怕的不是变老，是被问现在做什么。", "dialogue": "先坐后排。", "result_tail": "教室没变，座位牌换成了职位。"},
        {"narrator": "想象中的时间管理局要求你提交十年总结，格式不限。", "inner": "我的十年总结只有一行：还在。", "dialogue": "能交白卷吗？", "result_tail": "管理局收下了白卷，盖了个章。"},
    ],
    "choices": [
        {"label": "去，但只待一小时", "intent": "boundary", "effects": {"mental": 2, "charm": 1},
         "lines": ["我去，但只待一小时。", "先说好，不聊工资。", "我坐角落。", "一小时够认脸了。"],
         "memory": "_同学会_一小时",
         "outcome": {"facts": "你去了，待了一小时。有人问你近况，你说“还行”，居然是真的。", "visual": "wave"},
         "responses": "一小时到点，你起身。旁白：本场聚会你完成了主要剧情，支线留给别人。"},
        {"label": "交钱不去", "intent": "avoid", "effects": {"mental": 1, "money": -2},
         "lines": ["钱我交，人不到。", "群里替我留个名。", "下次一定。", "这算不算云参加？"],
         "memory": "_同学会_云参加",
         "outcome": {"facts": "你交了钱没去。群里发了合照，你在照片外，也在名单里。", "visual": "phone"},
         "responses": "你交了钱。旁白：这可能是本作最省力的一次社交。"},
        {"label": "提议改期，改成小范围", "intent": "rebel", "effects": {"abstract": 2, "mental": 1, "charm": -1},
         "lines": ["三十个人太多。", "改成四个人吧。", "我请客。", "别 @全体。"],
         "memory": "_同学会_改小",
         "outcome": {"facts": "你提议改成四个人。班长沉默了很久，回了句：“也行，你先拉群。”", "visual": "phone"},
         "responses": "班长让你拉群。旁白：你把三十人的局裁成四个，还顺手接了班长的活。",
         "roast": "旁白：全班三十人，你裁到四个，还抢了班长的活。"},
    ],
    "narrator_asides": [
        "旁白提醒：@全体 是本群唯一有效的召集令。",
        "接龙第十七位，和当年值日表上的名字差不多。",
        "教室没变，只是座位牌换成了职位。",
        "时间管理局收下了白卷。它也没写总结。",
    ],
}

LC32 = {
    "id": "LC32",
    "title": "健身房年卡，第一次去是办卡那天",
    "age_range": [26, 33],
    "stage": "adult",
    "scene": "home",
    "actors": ["lead", "boss"],
    "prop": "contract",
    "facts": "健身房年卡打折，销售说“你这种体型练三个月就能变”。你办了卡，第一次去是办卡那天。第二次，卡已经过期。手机里还留着教练的语音：哥，今天来吗？",
    "npc_dialogue": "销售：办卡就是改变的开始。",
    "lenses": [
        {"narrator": "你买下的不是课程，是一个更理想的自己。", "inner": "我到底想练，还是想拥有“正在练”的身份？", "dialogue": "明天一定去。", "result_tail": "明天来了，卡没来。"},
        {"narrator": "年卡进入冷静期，钱包比肌肉先有反应。", "inner": "办卡那天，我的运动量是签字。", "dialogue": "能退吗？", "result_tail": "合同写着：概不退款，但可转让给未来的你。"},
        {"narrator": "脑内健身房灯火通明，只有跑步机在等你。", "inner": "跑步机不需要我，它本来就会转。", "dialogue": "再办一张？", "result_tail": "跑步机转了三年，你没上过。"},
        {"narrator": "想象中的自律之神收到一份年卡供奉，回赠一张收据。", "inner": "神明说：心诚则灵，卡不灵。", "dialogue": "能开发票吗？", "result_tail": "神把收据折好，塞进了你的抽屉。"},
    ],
    "choices": [
        {"label": "转卡给朋友", "intent": "transfer", "effects": {"charm": 1, "money": 1},
         "lines": ["转你吧。", "我出过一次汗了。", "办卡那天。", "别浪费。"],
         "memory": "_年卡_转给朋友",
         "outcome": {"facts": "你把卡转给了朋友。他去了三次，比你多两次。", "visual": "offer"},
         "responses": "卡转出去了。旁白：你完成了本作最高效的一次健身。"},
        {"label": "硬着头皮去一次", "intent": "try", "effects": {"physical": 1, "mental": 1},
         "lines": ["去一次。", "就一次。", "拍照算吗？", "发个朋友圈。"],
         "memory": "_年卡_去一次",
         "outcome": {"facts": "你去了一次，练了二十分钟，拍照十分钟。教练说：不错，下次见。", "visual": "raise"},
         "responses": "你去了一次。旁白：二十分钟里有十分钟在找角度，也算运动。"},
        {"label": "把卡裱起来，当自律纪念", "intent": "meta", "effects": {"abstract": 3, "mental": 1},
         "lines": ["裱起来。", "挂在墙上。", "这是我的行为艺术。", "标题：《计划》。"],
         "memory": "_年卡_裱起来",
         "outcome": {"facts": "你把卡裱进相框，挂在玄关。来的人都问：这是奖状？", "visual": "draw"},
         "responses": "你把卡裱了。旁白：本作第一个给年卡办葬礼的人，仪式感满分。",
         "roast": "旁白：别人裱奖状，你裱年卡，还是没过期的那种。"},
    ],
    "narrator_asides": [
        "旁白提醒：办卡不等于健身，但等于消费。",
        "钱包的反应比肌肉快，这是生理常识。",
        "跑步机不需要你，它自己会转。",
        "自律之神收下供奉，回赠一张收据。",
    ],
}

LC33 = {
    "id": "LC33",
    "title": "相册自动生成《去年今日》，那天你在加班",
    "age_range": [27, 35],
    "stage": "adult",
    "scene": "office",
    "actors": ["lead", "boss"],
    "prop": "phone",
    "facts": "手机弹出《去年今日》：照片里是你、蛋糕和一群笑着的人。你放大看了三秒，才想起那天你在公司，蛋糕是同事的离职蛋糕，笑容是加班到十点的那种。系统问：要生成回忆视频吗？",
    "npc_dialogue": "系统：已为你选好 12 张照片，配乐《最好的时光》。",
    "lenses": [
        {"narrator": "算法比你更记得你过过什么日子。", "inner": "它挑的十二张，有八张不是我拍的。", "dialogue": "生成吧。", "result_tail": "视频做完，你看了两遍。"},
        {"narrator": "回忆自动打包，配乐不用你选，情绪也已预备。", "inner": "它把我加班那天，剪成了黄金时代。", "dialogue": "能换首歌吗？", "result_tail": "系统说：此模板已获百万用户好评。"},
        {"narrator": "脑内相册是一间仓库，货架上摆着被算法挑过的自己。", "inner": "我记得的那几张，它一张都没选。", "dialogue": "我自己挑。", "result_tail": "你挑了半天，只挑出一张。"},
        {"narrator": "想象中的记忆管理局给每年发一份年度报告，配图由它决定。", "inner": "报告里没有加班，只有蛋糕。", "dialogue": "能申诉吗？", "result_tail": "申诉窗口排队的人，都拿着蛋糕照片。"},
    ],
    "choices": [
        {"label": "生成，但不发", "intent": "keep", "effects": {"mental": 1, "abstract": 1},
         "lines": ["生成。", "不发。", "自己看。", "存起来。"],
         "memory": "_相册_自己看",
         "outcome": {"facts": "你生成了视频，没发。偶尔翻到，会看完。", "visual": "phone"},
         "responses": "你生成了。旁白：有些回忆不需要观众，只需要不被删掉。"},
        {"label": "重新挑十二张", "intent": "curate", "effects": {"mental": 2, "abstract": 1},
         "lines": ["我自己挑。", "不加配乐。", "用真实的那几张。", "难看也没关系。"],
         "memory": "_相册_自己挑",
         "outcome": {"facts": "你重新挑了十二张，一半是糊的。系统提示：效果可能不佳。你说：就这样。", "visual": "draw"},
         "responses": "你挑了十二张糊的。旁白：系统建议重选，你建议它闭嘴。"},
        {"label": "关掉提醒，卸载相册", "intent": "rebel", "effects": {"abstract": 2, "mental": 2},
         "lines": ["关掉。", "不看回忆。", "我记性好。", "卸载。"],
         "memory": "_相册_卸载",
         "outcome": {"facts": "你关了提醒。三天后，系统换了个入口继续问：要看看去年吗？", "visual": "phone"},
         "responses": "你卸载了。旁白：算法在云端给你留了个备份，还起了个名字叫“珍贵的你”。",
         "roast": "旁白：你卸载了相册，它把你的回忆备份到了更远的地方。"},
    ],
    "narrator_asides": [
        "旁白提醒：算法挑照片，不看你的心情，看点赞。",
        "配乐已选好，情绪请自备。",
        "仓库里的自己，比相册里的旧一点。",
        "记忆管理局的申诉窗口，永远排着拿蛋糕照片的人。",
    ],
}


def main() -> None:
    data = json.loads(EVENT_PATH.read_text(encoding="utf-8"))
    ids = {e["id"] for e in data["events"]}
    for src in (LC31, LC32, LC33):
        assert src["id"] not in ids, src["id"] + " 已存在"
        ev = base.build_event(src)
        # 选项级吐槽：把 responses 里自带的 roast 落成 choice.roast
        for c in src["choices"]:
            if c.get("roast"):
                for built in ev["choices"]:
                    if built["label"] == c["label"]:
                        built["roast"] = c["roast"]
        data["events"].append(ev)
    data["events"].sort(key=lambda e: (e["age_range"][0], e["id"]))
    EVENT_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    book = json.loads(DIALOGUE_PATH.read_text(encoding="utf-8"))
    guides = {
        "LC31": ["群里喊得最响的人，通常到得最晚。",
                 "十周年项目启动，热情在线，AA 制也在线。",
                 "脑内教室座位没变，人变了。",
                 "时间管理局收白卷，格式不限。"],
        "LC32": ["销售说三个月就能变。你信了三分钟。",
                 "年卡冷静期开始，钱包先有反应。",
                 "跑步机在等你，它一直很有耐心。",
                 "自律之神收供奉，回赠一张收据。"],
        "LC33": ["系统比你更记得去年今日。",
                 "回忆自动打包，配乐已选好。",
                 "相册仓库里，摆着算法挑过的你。",
                 "记忆管理局发年度报告，配图它定。"],
    }
    for src in (LC31, LC32, LC33):
        eid = src["id"]
        book["events"][eid] = {
            "guide": guides[eid],
            "responses": [c["responses"] for c in src["choices"]],
            "roast": [g + "（旁白备注）" for g in guides[eid]],
            "npc": [src["npc_dialogue"]] * 3,
        }
    DIALOGUE_PATH.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("added LC31/32/33; events:", len(data["events"]))


if __name__ == "__main__":
    main()
