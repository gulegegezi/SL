extends RefCounted
## Optional observations and camera direction. These never resolve a story choice.
## The viewport owns movement, replay, skip, and restoration of the normal camera.

const CG_PATH := "res://data/pixel_cg.json"
const INTERACTIONS := {
	"LC25": {"id":"naiwa_smile","label":"走近看看新同学","action":"nod","target":"npc","prop":"","reveal":"黄色的新同学仍坐在最后一排，笑容没有收起来。你先点点头，把下一句话留给自己决定。"},
	"LC01": {"id": "blanket_corner", "label": "碰碰毯角", "action": "receive", "target": "prop", "prop": "blanket", "reveal": "小手碰到柔软的布边。大人的手停下来，等你先松一点；这场谈判连语言都还没发明。"},
	"LC02": {"id": "photo_countdown", "label": "听听倒计时", "action": "talk", "target": "npc", "prop": "photo", "reveal": "爸爸低声跟着相机数：三、二……妈妈还在整理座位。原来大人也不总能在规定时间内准备好。"},
	"LC03": {"id": "shadow_test", "label": "试试墙上的影子", "action": "offer", "target": "prop", "prop": "flashlight", "reveal": "手指靠近光源，墙上的影子就长大；退远一点，又缩回小小一团。你刚发现一只不用喂饭的巨兽。"},
	"LC04": {"id": "biscuit_inspect", "label": "看看饼干", "action": "read", "target": "prop", "prop": "biscuit", "reveal": "饼干中间原本就有一道裂缝。两个人争的是同一块饼干，却分别指着不同的一半。"},
	"LC05": {"id": "mirror_gap", "label": "照照缺牙的笑", "action": "read", "target": "prop", "prop": "tooth", "reveal": "你把嘴张圆，再抿起来。镜子里那扇漏风的小窗没有消失，倒让每个表情都多了一点口哨声。"},
	"LC06": {"id": "eraser_detail", "label": "看看半块橡皮", "action": "read", "target": "prop", "prop": "eraser", "reveal": "橡皮的切口歪歪扭扭，包装纸倒被叠得很整齐。同桌一直盯着你的笔尖，还没注意到你的笔盒。"},
	"LC07": {"id": "ledger_check", "label": "核对账本上的日期", "action": "read", "target": "prop", "prop": "ledger", "reveal": "账本上有两行同一天的日期，钱盒旁还压着一张折起的收据。你只记下了位置，尚未替任何人下结论。"},
	"LC08": {"id": "bread_wait", "label": "走近门口听听", "action": "talk", "target": "npc", "prop": "exam", "reveal": "妈妈先问面包凉了没有，没问你排第几。纸袋的声音很轻，却让你攥着考卷的手更不知道往哪放。"},
	"LC09": {"id": "drum_soundcheck", "label": "轻敲一下试音", "action": "drum", "target": "prop", "prop": "drum", "reveal": "一记很轻的鼓点在空教室里滚了一圈。同学抬头示意：听得见。试音到此为止，演不演还由你决定。"},
	"LC10": {"id": "album_margin", "label": "翻看留言页", "action": "read", "target": "prop", "prop": "notebook", "reveal": "前几页写着同一种祝福，角落却留着不同的涂鸦：坏掉的风扇、迟到的早餐，还有画歪的班主任。"},
	"LC11": {"id": "bag_weight", "label": "掂掂行李", "action": "receive", "target": "prop", "prop": "eggs", "reveal": "行李提起来比刚才沉了一点。鸡蛋袋口又被打了一道结，门边的路线纸也折好了，像一张过分认真的护身符。"},
	"LC12": {"id": "plant_label", "label": "翻看盆边的便签", "action": "read", "target": "prop", "prop": "plant", "reveal": "盆边便签写着别浇太勤，下面又有人补了也别完全忘记。这个工位连一盆植物都交接得很有分歧。"},
	"LC13": {"id": "fridge_labels", "label": "看看冰箱标签", "action": "read", "target": "prop", "prop": "fridge", "reveal": "白菜上贴了名字，酸奶上没有。室友看了看手里的杯子，像突然发现一条从未正式公布的边界。"},
	"LC14": {"id": "message_pause", "label": "读完那条消息", "action": "read", "target": "prop", "prop": "phone", "reveal": "输入框上方的正在输入出现又消失。最后只剩一个问号；借多少、何时还、你能不能承受，都还没有说清。"},
	"LC15": {"id": "old_voice", "label": "认一认电话里的笑声", "action": "talk", "target": "npc", "prop": "eraser", "reveal": "那个外号念到最后一个字时，对方先笑了。声音变了，抢在你反驳前笑出来的习惯没有变。"},
	"LC16": {"id": "bill_detail", "label": "对一对账单", "action": "read", "target": "prop", "prop": "bill", "reveal": "电费单的一角沾着外卖袋上的油印。两个人的手机屏幕都停在优惠券页，还没有谁先说今天算了。"},
	"LC17": {"id": "draft_screen", "label": "看看没发出的草稿", "action": "read", "target": "prop", "prop": "noodles", "reveal": "离职信末尾的谢谢删过又打上。楼下面馆的招牌已经亮了，电脑右上角的发送键仍然安静。"},
	"LC18": {"id": "report_question", "label": "问清圈出的那一项", "action": "talk", "target": "npc", "prop": "report", "reveal": "医生指向复查栏：先补齐检查，才能判断。红圈提醒你下一步要做什么，并不是已经写好的结局。"},
	"LC19": {"id": "video_listen", "label": "多听一会儿电话", "action": "talk", "target": "npc", "prop": "bill", "reveal": "镜头移开后，两个人都把语速提快了。你听见纸张摩擦桌面的声音，也听见他们努力把一切说成平常。"},
	"LC20": {"id": "key_turn", "label": "看一看旧钥匙", "action": "read", "target": "prop", "prop": "key", "reveal": "钥匙齿磨得发亮。管理员把新钥匙圈晃了晃：旧锁换了，房间还在。门能不能再开，并不只问这把钥匙。"},
	"LC21": {"id": "badge_compare", "label": "核对工牌", "action": "read", "target": "prop", "prop": "badge", "reveal": "工牌上的错字只差一笔，新系统的按钮却几乎没有一个眼熟。年轻同事把鼠标放慢，等你看清再点。"},
	"LC22": {"id": "phone_demonstration", "label": "请老师慢演示一次", "action": "talk", "target": "npc", "prop": "phone", "reveal": "老师把手指悬在发送按钮上，没有替你按下。旁边那位拍到脚的同学小声说，至少这次鞋擦得挺干净。"},
	"LC23": {"id": "photo_edge", "label": "轻轻揭开相册一角", "action": "read", "target": "prop", "prop": "photo", "reveal": "塑料膜发出很小的一声响。照片背后透出半个日期，空白边还留得下今天的一行字；你暂时没有落笔。"},
	"LC24": {"id": "bench_breeze", "label": "走近长椅", "action": "walk", "target": "prop", "prop": "bench", "reveal": "你在长椅边停下。风从空着的半边吹过，熟面孔把袋子往自己那侧挪了挪，留出一块可以慢慢决定的位置。"},
	"RX01": {"id": "workup_order", "label": "核对检查顺序", "action": "talk", "target": "npc", "prop": "report", "reveal": "医生把先后顺序写在纸上。检查是为了把未知缩小；纸上尚没有确诊结果。"},
	"RX02": {"id": "diagnosis_pause", "label": "请医生再说慢一点", "action": "talk", "target": "npc", "prop": "report", "reveal": "医生放下笔，重新解释已经确认的诊断和接下来可讨论的治疗。你可以先把问题记下，不必马上表现得镇定。"},
	"RX03": {"id": "treatment_calendar", "label": "看看治疗日历", "action": "read", "target": "prop", "prop": "report", "reveal": "日历上除了复诊，也还有吃饭、洗衣和想见的人。你在看下一页，身体的变化仍需要继续观察。"},
	"RX04": {"id": "accident_orient", "label": "确认身边的声音", "action": "talk", "target": "npc", "prop": "phone", "reveal": "有人告诉你自己是谁、现在在哪里。你先辨认那道声音，事情的后续由已经发生的事故决定。"},
	"RX05": {"id": "new_routine", "label": "试一试新的节奏", "action": "walk", "target": "prop", "prop": "bench", "reveal": "你先试很短的一段，在需要的时候停下。旁边的人跟着你的速度走，没有替你规定今天该走多远。"},
	"RX06": {"id": "memory_silence", "label": "停下来看看旧物", "action": "read", "target": "prop", "prop": "photo", "reveal": "旧物没有回答。你可以安静地看一会儿，也可以先把它放好；思念没有必须完成的动作。"}
}

static var _cg_data: Dictionary = {}
static var _cg_loaded := false

static func interaction(event_id: String) -> Dictionary:
	return Dictionary(INTERACTIONS.get(event_id, {})).duplicate(true)

static func cg(event_id: String, result: bool = false) -> Dictionary:
	if not _cg_loaded:
		_cg_loaded = true
		if FileAccess.file_exists(CG_PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CG_PATH))
			if parsed is Dictionary:
				_cg_data = parsed.get("events", {})
	var event_data: Dictionary = _cg_data.get(event_id, {})
	var direction: Dictionary = event_data.get("result" if result else "intro", {})
	return direction.duplicate(true)
