"""Authoring source for the short-life route. No generated art or copied game text."""
import json
from pathlib import Path

events = []
nodes = {}

def choice(label, result, effects, tags=(), expr='normal', action='idle', prop='', **extra):
    sentences = [part + '。' for part in result.rstrip('。').split('。') if part]
    panels = []
    for i,line in enumerate(sentences):
        panel = dict(caption=line, shot='medium' if i == 0 else 'close', shot_locked=True)
        if i == 0:
            panel.update(expr=expr, action=action, prop=prop, actor='lead')
        if '醒来' in line: panel.update(expr='normal', action='idle', prop='', actor='lead')
        panels.append(panel)
    return dict(label=label, result=result, effects=effects, tags=list(tags),comic=panels, **extra)

def event(eid, age, title, scene, role, setup, action_text, question, kind, prop, reveal, choices, **extra):
    value = dict(id=eid, age=age, title=title, text=setup+action_text+question, once=True, important=True,
                 scene=scene, choices=choices, short=True, comic=[
                     dict(caption=setup, shot='wide', shot_locked=True, support='npc_'+role),
                     dict(caption=action_text, shot='medium', shot_locked=True,
                          interaction=dict(kind=kind, prop=prop, hint={'tap':'点击画中物件','drag':'把物件拖到右侧虚线框','hold':'按住画中物件片刻','reveal':'点击翻开纸页'}[kind],
                                           reveal=reveal, completed=False)),
                     dict(caption=question, shot='close', shot_locked=True, action='idle', expr='normal', intensity=0)], **extra)
    events.append(value)
    return value

event('SL01',1,'抓周：预算只有一张桌子','home','parent',
      '大人把书、玩具和一只旧算盘摆在桌上。你还不懂职业，只知道玩具离自己最远。',
      '妈妈把玩具推到桌沿。你伸手去够，围观的人比你还紧张。',
      '这次伸手，要抓住什么？','drag','toy','玩具底下压着一张小纸条：喜欢的东西，也值得认真。',[
          choice('抱走玩具，先开心再说','你抓住玩具笑了。大人讨论了半天，最终得出结论：这孩子会玩。',{'health':1,'charm':1},['爱玩'],'happy','raise','toy'),
          choice('翻开书，看看有没有吃的','你翻开书认真看了三秒。然后咬住书角，完成了人生第一次知识摄入。',{'int':2},['好奇'],'happy','read','book'),
          choice('伸手抓住妈妈的手指','你抓住妈妈的手指不肯松开。她笑着说，这份工作暂时不需要简历。',{'health':1},['恋家'],'happy','raise',relations={'parent':2})])
event('SL04',4,'墙上的第一届画展','home','parent',
      '墙刚刷白，你的蜡笔就开始营业。太阳有八条腿，小人比房子还高。',
      '你举起画笔。门外响起钥匙声，妈妈要回来了。',
      '画展即将迎来唯一的赞助人。','tap','pencil','门口贴着保洁提醒。墙纸后面，也许还有别的办法。',[
          choice('承认是我画的，请她评个奖','你举起画笔坦白。妈妈没有颁奖，却搬来一叠旧报纸给你继续画。',{'charm':2},['坦率'],'shy','raise','pencil',relations={'parent':1}),
          choice('把画描到纸上，保留作品','你翻开本子，把八条腿的太阳重新画好。很多年后，第一张画还夹在里面。',{'int':1,'charm':1},['画画'],'happy','read','book',next='SL04B'),
          choice('把拖把摆成策展人的姿势','你把拖把递给妈妈，说这叫合作创作。她笑了，然后邀请你参与展后清洁。',{'health':1,'abstract':3},['幽默'],'happy','raise')])
event('SL07',7,'同桌的半块橡皮','classroom','friend',
      '开学第一天，老师让你写名字。你的铅笔刚落纸就断了，同桌把橡皮切成两半。',
      '同桌把半块橡皮推过来，又悄悄指了指窗外的操场。',
      '认识一个人，有时比写完一行字更难。','drag','eraser','橡皮背面歪歪扭扭地写着：放学一起走？',[
          choice('把铅笔也掰成两份——算了，借他削笔刀','你递过削笔刀，两人都笑了。放学时，他果然在校门口等你。',{'charm':2},['老友'],'happy','raise','eraser',relations={'friend':2}),
          choice('先道谢，约他一起写作业','你翻开作业本，给同桌留了一半桌面。第一支学习小组只有两个人，效率暂时未知。',{'int':2},['认真'],'happy','read','book',relations={'friend':1}),
          choice('独自把名字写完，放学再打招呼','你握紧铅笔把名字写好。没说出口的那句谢谢，被你写在了小纸条上。',{'int':1,'charm':1},['观察者'],'shy','sign','letter')])
event('SL12',12,'成绩单会不会烫手','classroom','teacher',
      '期末成绩单折了三折，还是塞不进你假装轻松的口袋。老师把你叫到窗边。',
      '你翻开成绩单。老师先问：最近睡得好吗？',
      '红色分数之外，你愿意说点什么？','reveal','letter','评语栏写着：会问问题，比永远答对更重要。',[
          choice('承认不会的题，请她再讲一次','你翻开错题本。老师画了三个小圈，原来最难的地方只差一步。',{'int':2},['会求助'],'determined','read','book',relations={'teacher':1}),
          choice('保证下次第一，今晚开始熬夜','你打开电脑，把计划排到凌晨。第一晚只完成了计划的标题。',{'int':2,'health':-1},['要强'],'determined','type','computer'),
          choice('先睡够，再慢慢补回来','你收起成绩单，认真睡了一觉。第二天的题没有变简单，但眼睛终于看得清了。',{'health':2,'int':1},['有分寸'],'sleep','sleep','bed')])
event('SL12X',12,'班费失踪案，嫌疑人是风','classroom','friend',
      '班费信封少了十元。所有人沉默，只有窗户在哐当作响，同桌举手要求先审问风。',
      '你翻开账本，末页夹着一张没找零的小卖部收据。',
      '侦探事务所今天只有一张课桌。','reveal','letter','收据背面写着：班长垫付十元，尚未归还。',[
          choice('先核对账本，不给任何人贴标签','你翻开账本逐项核对。钱没丢，只是班长把借条夹进了语文书。',{'int':2,'charm':1},['细心'],'determined','read','book'),
          choice('把风叫作证人，顺便缓和气氛','你抬起账本，宣布风暂时无罪。大家笑出来以后，班长终于想起了借条。',{'charm':2,'abstract':2},['幽默'],'happy','raise','letter',relations={'friend':1}),
          choice('陪被怀疑的同学一起找证据','你走到同桌身边，替他留了座位。账终于对上时，他只说了一句谢谢。',{'charm':1},['仗义'],'determined','walk',relations={'friend':2})], need_tags=['幽默'])
event('SL16',16,'社团招新：世界缺一个鼓手','classroom','friend',
      '社团海报说零基础可报，面试却问你会什么。你说会按时吃饭，学长说乐队很需要稳定的人。',
      '你敲了敲桌上的练习鼓。隔壁读书社一起抬起了头。',
      '放学后的时间，要留给谁？','tap','drum','海报背面还有一行小字：别把爱好也过成排名。',[
          choice('加入乐队，先把节拍练稳','你举起鼓槌，从四拍练起。首演只有三位观众，其中一位是来借教室的。',{'charm':2,'health':1},['乐队'],'happy','raise','drum',next='SL16B'),
          choice('带着画本去做海报','你翻开画本，把太阳改成四条腿。大家一致认为，这已经是成熟的设计。',{'int':1,'charm':1},['画画'],'happy','sign','pencil'),
          choice('不加社团，给自己留一段空白','你合上报名表，慢慢走回家。黄昏没有记入履历，却让你很放松。',{'health':2},['有分寸'],'happy','walk')])
event('SL18',18,'志愿表与不会回头的列车','home','parent',
      '录取线出来的晚上，饭菜热了两次。父母把地图摊开，筷子指向他们没有去过的城市。',
      '你翻开志愿表，把想去的地方圈起来。妈妈把水杯推近。',
      '这次决定可以听建议，但签名是你的。','hold','letter','地图边缘写着车次，也写着家里的电话号码。',[
          choice('去外地读书，学着自己照顾自己','你签下志愿表，拖着箱子走向车站。妈妈挥手到看不见你，才想起忘了叮嘱天气。',{'int':2,'money':-2},['远行'],'determined','sign','letter',relations={'parent':1}),
          choice('留在本地，学一门想学的专业','你签下志愿表，圈好通勤路线。新生活开始了，家里的拖鞋还在原来的地方。',{'int':1,'health':1},['恋家'],'happy','sign','letter'),
          choice('先工作，学费和方向都慢慢攒','你收起志愿表，走进第一家愿意收学徒的店。别人问梦想时，你说先学会修好眼前的东西。',{'money':3,'health':1},['手艺人'],'determined','walk',nextAge=27)])
event('SL22',22,'招聘启事：欢迎拥有三年经验的应届生','office','boss',
      '面试官问你最大的缺点。你盯着空调遥控器，突然觉得不会撒谎也是一种缺点。',
      '你翻开作品集。老板终于从简历上抬起头来。',
      '要怎样开始你的第一份工作？','reveal','book','作品集最后一页，是你真正花时间解决过的问题。',[
          choice('讲一个做过的项目，不背标准答案','你翻开作品集，把失败的步骤也讲清楚。老板点头，说下周来试试。',{'money':3,'int':1},['务实'],'determined','read','book'),
          choice('挑一份能准时下班的工作','你签下合同，先问清楚休息时间。你的第一项职业技能是按时关机。',{'money':1,'health':2},['有分寸'],'happy','poweroff','computer'),
          choice('和朋友试着开一间小工作室','你给朋友打电话，约在便宜的咖啡店。创业计划先从两人平摊一杯咖啡开始。',{'money':-2,'charm':2},['合伙人'],'happy','phone','phone',relations={'friend':1},next='SL22B')])
event('SL22X',22,'你的作品，比你的简历先到了','office','friend',
      '以前画的海报被人转发，客户问画手能不能明天交稿。你看了一眼钟，今天只剩十分钟。',
      '你拿起画笔，又翻开写满修改意见的合同。',
      '被看见之后，也要学会报价。','hold','pencil','合同边角写着：修改次数需要提前约定。',[
          choice('说清范围，认真报一个价','你签下合同，约定三轮修改。客户第一次回复好的，你反而有点不习惯。',{'money':4,'charm':1},['务实'],'determined','sign','letter'),
          choice('先做样稿，看看是否真的合适','你翻开画本，画出一个小样。被拒绝的方案后来成了自己的头像。',{'int':2,'money':1},['画画'],'happy','sign','pencil'),
          choice('暂时拒绝，先把身体养好','你放下画笔，关掉电脑。第二天醒来，喜欢画画这件事还在。',{'health':3},['有分寸'],'sleep','sleep','bed')], need_tags=['画画'])
event('SL27',27,'深夜的手机，没写完的消息','bedroom','partner',
      '聊天框亮了又暗。对方问周末能不能见面，你删掉三次精心编写的轻松回复。',
      '你拿起手机，看着那句简单的邀请。窗外下雨了。',
      '靠近一个人，或者诚实地保留距离？','tap','phone','对方又补了一句：没空也没关系，下次再约。',[
          choice('直说想见面，约一个舒服的地方','你给对方打电话，说自己有点紧张。电话另一头笑了，说那就一起紧张。',{'charm':2,'health':1},['有伴'],'shy','phone','phone',relations={'partner':2}),
          choice('告诉对方最近太累，认真另约时间','你拿起手机，发出一个具体的日期。等待不再像敷衍，因为约定有了落点。',{'health':2},['坦率'],'normal','phone','phone',relations={'partner':1}),
          choice('暂时不恋爱，给自己做一顿好饭','你放下手机，走进厨房。煎蛋有点焦，你仍然把它端得像一道大菜。',{'health':2,'money':1},['独行'],'happy','raise','meal')])
event('SL33',33,'房东说，这次真的只是聊聊','home','mate',
      '续租合同上的数字长大了，房间却没有。你和房东隔着一张晃动的餐桌坐下。',
      '你翻开账本，把收入和开支摆到桌面。',
      '想要的生活，必须住进同一套房里吗？','reveal','letter','账本里圈出了一笔长期被忽略的通勤费用。',[
          choice('搬小一点，换回更短的通勤','你签下新合同，搬家箱只装了真正想留的东西。每天省出的时间，够你慢慢吃完早餐。',{'money':-1,'health':2},['轻装'],'happy','sign','letter'),
          choice('留下谈条件，先修好漏水的窗','你举起维修照片，把要求一条条说清楚。房租只涨了一点，窗户终于不再陪你听雨。',{'charm':1,'money':1},['务实'],'determined','raise','letter'),
          choice('找朋友合住，把边界提前说好','你给朋友打电话，先谈洗碗和安静时间。搬来第一晚，两人都认真洗了自己的杯子。',{'money':2,'charm':1},['会协商'],'happy','phone','phone',relations={'friend':1})])
event('SL40',40,'体检报告不接受已读不回','hospital','teacher',
      '排队时你还在回工作消息。医生把报告翻过来，问你一天究竟有几个夜晚。',
      '你放下手机，翻开那张折过的报告。',
      '身体的意见，这次要不要算一票？','reveal','letter','需要复查的项目被圈了出来。它是提醒，不是宣判。',[
          choice('安排复查，把休息写进日程','你给医院打电话，预约好时间。忙碌终于第一次为身体让出了一格。',{'health':3,'money':-1},['照顾自己'],'determined','phone','phone',next='SL40B'),
          choice('先减少加班，和同事重新分工','你关掉电脑，把工作交接写清楚。办公室的灯少亮了一盏，项目并没有因此塌下来。',{'health':2,'charm':1},['有分寸'],'normal','poweroff','computer'),
          choice('暂时硬撑，先把这笔奖金拿到','你打开电脑，报告被压在键盘下面。奖金到账那天，你在会议中途睡着了。',{'money':4,'health':-3,'lifespan':-4},['硬撑'],'hurt','type','computer')])
event('SL40X',40,'工作群里的深夜鼓点','office','friend',
      '老乐队群突然复活，有人发来第一次演出的录音。鼓点错了两拍，笑声倒是整齐。',
      '你轻轻敲桌子，发现手指还记得节拍。',
      '四十岁的返场，要不要给自己留一张票？','tap','drum','群公告写着：不收费，不排名，音量不要吵到邻居。',[
          choice('周末合奏，先练最简单的一首','你举起鼓槌，和朋友从第一拍重新开始。大家都慢了一点，居然更容易合上。',{'health':2,'charm':1},['乐队'],'happy','raise','drum',relations={'friend':1}),
          choice('录一小段发过去，不追求完美','你给朋友打电话，把录音放给他们听。最先收到的不是点评，是一串笑声。',{'charm':2},['坦率'],'happy','phone','phone'),
          choice('只去听，给老朋友买瓶水','你走进排练室，坐到观众的位置。这次终于不必一边演奏一边担心有没有人听。',{'health':1,'charm':1},['有分寸'],'happy','sit')], need_tags=['乐队'])
event('SL48',48,'妈妈学会了撤回语音','home','parent',
      '妈妈发来一条语音，撤回，又发来三条。内容都是问你周末有没有空，没有一条提她自己。',
      '你拿起手机，先把那条最长的语音听完。',
      '这一次，别只回一个收到。','hold','phone','语音的最后，她小声说：没事，只是想让你尝尝新学的菜。',[
          choice('约好回家，听她把同一件事讲完','你给妈妈打电话，问她想吃什么。她笑了，说菜都准备好了。',{'health':1,'money':-1},['恋家'],'happy','phone','phone',relations={'parent':2}),
          choice('把她常用的手机功能写成小卡片','你翻开本子，把每一步画得很大。卡片最后多了一行：不会就打给我。',{'int':1,'charm':1},['细心'],'happy','sign','letter',relations={'parent':1}),
          choice('坦白这周走不开，约固定通话','你给妈妈打电话，说清自己的日程。星期日的半小时，从临时抽空变成了约定。',{'health':1},['会协商'],'normal','phone','phone',relations={'parent':1})])
event('SL56',56,'衣柜里那只不肯退休的纸箱','home','friend',
      '整理房间时，你发现一只写着以后再看看的纸箱。当年「{choice:SL04}」的记忆，藏在最底下。',
      '你翻开旧本子，纸页边缘留下了很多年前的笔迹。',
      '把过去留下，还是把位置腾给以后？','reveal','book','本子里夹着一句话：等有空了，再做一次。',[
          choice('联系老友，约一次不谈工作的见面','你给老朋友打电话，开头还是那句在忙吗。这次你们真的约好了地点。',{'charm':2,'health':1},['老友'],'happy','phone','phone',relations={'friend':2}),
          choice('把旧爱好捡回来，不要求成果','你翻开本子，从第一页重新开始。没有人打分，反而让你坐了很久。',{'health':2,'int':1},['重拾爱好'],'happy','read','book'),
          choice('只留一件，其余送给需要的人','你举起纸箱，认真挑出一件留下。房间空了一点，记忆并没有变少。',{'health':1,'charm':1},['轻装'],'normal','raise','toy')])
event('SL65',65,'退休第一天，闹钟拒绝交接','bedroom','partner',
      '闹钟照常在六点响。你盯着天花板，第一次发现今天没有迟到这回事。',
      '你伸手关掉闹钟，又慢慢坐起来。',
      '空出来的时间，要怎样安排？','tap','clock','日历上没有红色截止日期，只有你自己写下的散步。',[
          choice('出门散步，认一认街角新开的店','你走出家门，没有抄近路。老板记住了你的口味，你记住了街上的树。',{'health':3},['散步'],'happy','walk'),
          choice('给社区孩子讲自己擅长的事','你翻开本子，发现最有用的是那些犯过的错。孩子们认真听了五分钟，然后开始提问。',{'int':1,'charm':2},['分享者'],'happy','read','book'),
          choice('先睡个回笼觉，再考虑伟大计划','你睡着了，阳光慢慢挪过枕头。醒来以后，伟大计划缩成了一顿热饭。',{'health':2},['有分寸'],'sleep','sleep','bed')])
event('SL65X',65,'社区音乐节：平均年龄六十八','park','friend',
      '朋友叫你参加社区音乐节。报名表让填监护人电话，你们一致决定填对方的号码。',
      '你敲响练习鼓，旁边下棋的大爷开始用脚打拍子。',
      '台下会有多少人，还是最重要的事吗？','tap','drum','节目单上印着：欢迎失误，禁止互相嫌弃。',[
          choice('上台演一首，当作送给老朋友','你举起鼓槌，笑着数了四拍。这次台下终于超过了三个人。',{'health':2,'charm':2},['乐队'],'happy','raise','drum',relations={'friend':1}),
          choice('帮忙布场，让别人站到灯下','你走到舞台旁，帮朋友摆好椅子。掌声响起时，你也在里面。',{'health':1,'charm':2},['分享者'],'happy','walk'),
          choice('身体累了，带着录音回家听','你给朋友打电话，说今天只负责鼓掌。录音里有人数错了拍，你笑了很久。',{'health':3},['有分寸'],'happy','phone','phone')], need_tags=['乐队'])
event('SL74',74,'药盒不是糖盒，今天也不是周五','home','mate',
      '你把药盒分成七格，认真写了星期。邻居来串门，先夸你的新糖盒看起来很高级。',
      '你翻开用药记录，把今天这一格推到面前。',
      '承认需要帮助，会不会也是一种熟练？','reveal','medicine','记录上还留着医生的复诊日期。按约定服用，不靠猜。',[
          choice('按医嘱整理，给复诊设个提醒','你拿起手机，把复诊时间写进日历。药盒各就各位，心里也不再那么乱。',{'health':3},['细心'],'normal','phone','phone'),
          choice('请信任的人一起核对一次','你给朋友打电话，请他帮忙看一眼记录。两个人对了三遍，顺便约了明早散步。',{'health':2,'charm':1},['会求助'],'happy','phone','phone',relations={'friend':1}),
          choice('把邻居的玩笑写进日记','你翻开日记，写下今天不是周五。写完发现，今天确实是周五。',{'health':1,'charm':1,'abstract':2},['幽默'],'happy','sign','pencil')])
event('SL84',84,'一封寄给未来的信','home','partner',
      '有人想让你讲一件最重要的事。你想了半天，先问他们茶凉了没有。',
      '你拿起笔，把信纸拉到面前。',
      '不必交代整个人生，只写想留下的话。','hold','letter','信封空着收件人。写给谁，都可以。',[
          choice('写给年轻的自己：不必每次都赢','你签下名字，把信折好。那些曾经难以启齿的失败，如今能平静地说给人听。',{'health':1,'charm':1},['释然'],'normal','sign','letter'),
          choice('写给重要的人：谢谢你来过','你翻开通讯录，把熟悉的名字慢慢念出声。有人接起电话，有人留在纸上。',{'charm':2},['念旧'],'sad','phone','phone'),
          choice('画一幅画，给太阳再添几条腿','你拿起画笔，画了八条腿的太阳。它跑得很快，像小时候一样。',{'health':1,'abstract':2},['画画'],'happy','sign','pencil')])
event('SL94',94,'今天的云，长得像一顿午饭','park','mate',
      '午后的长椅有点暖。你看着云，邻居说像一只猫，你说更像一碗还没拌开的面。',
      '你慢慢坐下，打开带来的旧相册。',
      '今天还想做点什么？','reveal','book','相册最后留着一张空白页。并不是所有空白都要填满。',[
          choice('再和朋友坐一会儿','你放下相册，认真听朋友讲一件小事。太阳落下以前，你们谁也没有着急。',{'health':1},['释然'],'happy','sit',relations={'friend':1}),
          choice('给晚辈讲一个不太可靠的笑话','你举起相册，讲起那个八条腿的太阳。孩子笑了，未必因为听懂。',{'charm':1},['幽默'],'happy','raise','book'),
          choice('回家，慢慢吃一碗面','你走回家，给自己盛好一碗热面。今天不需要变成大事，也值得认真过。',{'health':1},['有分寸'],'happy','raise','meal')])

# 同龄的选择后续，不占用新的年龄节点，也不被时间跳跃吞掉。
for eid, title, scene, role, setup, motion, question, prop, choices in [
    ('SL04B','画展第二天：纸上的太阳','home','parent','妈妈把你的画夹到冰箱上。旁边的购物单突然显得很没有艺术追求。','你翻开画本，发现太阳旁边多了一个小小的笑脸。','要给这张画取个名字吗？','book',[
        choice('叫太阳放假，给妈妈也放半天','你抬起画本宣布放假。妈妈笑着同意了，家务明天再说。',{'charm':1},['共情'],'happy','raise','book'),
        choice('写上日期，以后回来看看','你签下日期，认真画了一条线。未来第一次有了能回看的坐标。',{'int':1},['细心'],'determined','sign','pencil'),
        choice('不取名字，让它自由发挥','你放下画笔，给太阳留了一点空白。艺术家的工作暂时结束，零食时间开始。',{'health':1},['爱玩'],'happy','put_down')]),
    ('SL16B','首演：灯光师还在写作业','classroom','friend','演出前三分钟，音箱突然没声。朋友蹲下来检查插头，发现插座里只有卷笔刀。','你伸手接过鼓槌，大家等你数拍。','首演也可以从不完美开始。','drum',[
        choice('改成不插电，一起把歌唱完','你举起鼓槌，轻轻数出四拍。没有音箱，反而听清了每个人的声音。',{'charm':2},['会应变'],'happy','raise','drum'),
        choice('告诉观众故障，请大家等一下','你抬起手解释状况。台下有人把自己的小音箱递了过来。',{'charm':1},['坦率'],'shy','wave'),
        choice('先邀请全场拍手，等设备修好','你举起双手带大家拍节奏。后来录音最响的部分，是没有歌词的那半分钟。',{'health':1,'charm':1},['幽默'],'happy','wave')]),
    ('SL22B','合伙协议不能只写相信你','office','friend','咖啡喝完了，账本还是空的。朋友把纸推过来，说先写钱怎么分，吵架时就少一个理由。','你拿起笔，看着第一张合伙协议。','朋友和生意，都值得说清楚。','letter',[
        choice('把投入、分工和退出办法写清楚','你签下协议，把难听的话提前说完。朋友松了口气，说这比拍胸脯可靠。',{'int':1,'money':2},['会协商'],'determined','sign','letter',relations={'friend':1}),
        choice('先做一个月的小项目，控制成本','你翻开账本，把第一个目标改小。第一笔收入不多，够你们各买一杯咖啡。',{'money':2,'health':1},['务实'],'happy','read','book'),
        choice('发现并不合适，保留朋友关系','你放下笔，说自己暂时不想合伙。朋友点头，两人继续聊没看完的电影。',{'health':2},['有分寸'],'normal','put_down',relations={'friend':1})]),
    ('SL40B','复查那天，你真的来了','hospital','friend','叫号屏亮起，你没有再借口临时开会。朋友在候诊椅边给你留了个位子。','你拿起报告，慢慢坐下。','等待的时候，也可以不刷工作群。','letter',[
        choice('向医生问清楚下一步','你翻开报告，把不明白的地方逐项问清。未来不是一句没事，而是一张能照着做的安排。',{'health':2},['会求助'],'determined','read','letter'),
        choice('请朋友陪着听一遍注意事项','你给朋友打电话，请他一起记重点。回家路上，两个人终于聊起检查以外的事。',{'health':1,'charm':1},['老友'],'normal','phone','phone',relations={'friend':1}),
        choice('把工作消息设为免打扰','你放下手机，抬头看了一会儿窗外。世界没有因为你晚回半小时而停止运转。',{'health':2},['有分寸'],'normal','put_down')])]:
    node = event(eid,0,title,scene,role,setup,motion,question,'reveal',prop,'这一幕会随你刚才的决定发生，不会被跳年略过。',choices)
    events.pop()
    nodes[eid] = node

output = {'version':1, 'ages':[1,4,7,12,16,18,22,27,33,40,48,56,65,74,84,94], 'events':events, 'nodes':nodes}
path = Path(__file__).resolve().parents[1] / 'data/short_life.json'
path.write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'Wrote {len(events)} milestone variants, {len(nodes)} follow-ups, {sum(len(e["choices"]) for e in events+list(nodes.values()))} authored choices')
