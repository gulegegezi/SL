"""Render the authored JSON into a readable script book, not a second story source."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
pack=json.loads((ROOT/'data/story_life_comic.json').read_text(encoding='utf-8'))
names=[tier['name'] for tier in pack['rules']['tiers']]
lines=['# 人生条漫完整分镜稿：折痕与歪楼','',
 '> 从 `data/story_life_comic.json` 生成；事实层始终不变，四档文字为主角视角。普通事件选择后各随机进入两种后续之一，不会替换玩家已经选定的动作。','',
 '## 事件与年龄索引','', '| ID | 事件 | 可触发年龄 | 场景 |','| --- | --- | --- | --- |']
for event in pack['events']:
    lines.append(f"| {event['id']} | {event['title']} | {event['age_range'][0]}–{event['age_range'][1]} | {event['scene']} |")
for event in pack['events']:
    lines += ['',f"## {event['id']} · {event['title']}",'',
      f"年龄：{event['age_range'][0]}–{event['age_range'][1]} 岁。场景：{event['scene']}。物件：{event['prop']}。",'',
      '**第一格：发生了什么。** '+event['facts'],'', '**第二格：对方真实说的话。** '+event['npc_dialogue'],'',
      '**第三格：主角的四种视角。** 未满三岁的成人式表达只作为内心字幕，不是孩子真的说出口。','']
    for voice in event['lenses']:
        lines += [f"**{names[voice['tier']]}**",'',f"旁白：{voice['narrator']}",f"\n内心：{voice['inner']}",f"\n主角：{voice['dialogue']}",'']
    lines += ['**第四格：停在可以选择的动作前。**','']
    for choice in event['choices']:
        lines += [f"### {choice['id']} · {choice['label']}",'',
          '四档表达：'+' / '.join(choice['lines']),'',
          '确定发生：'+choice['intent']+'；已知数值变化：'+json.dumps(choice['effects'],ensure_ascii=False)+'。','']
        for index,outcome in enumerate(choice['outcomes']):
            lines += [f"**随机后续 {index+1}（{outcome['id']}）。** {outcome['facts']}",'',
                      f"画面：先演出选择动作，再演出 `{outcome['visual']}`，最后停在物件或收势。",'',
                      f"留下的记忆：{outcome['memory']}。",'']
    lines += ['**结果的最后一格：四档旁白的尾音。** 先保留已经发生的结果事实，再接对应档的这一句。','']
    for voice in event['lenses']:
        lines += [f"- {names[voice['tier']]}：{voice['result_tail']}"]
    lines += ['', '前置条件：'+json.dumps(event['requirements'],ensure_ascii=False)+'。','']
    if event['callback']:lines += ['回响约束：'+event['callback'],'']
lines += ['## 突发事件分镜','', '> 下列选择是信息、支持和生活安排；不以积极、乐观或某句正确台词保证生存。所有概率和权重仅用于游戏原型，不对应现实医学概率。','']
for arc in pack['rare_arcs']:
    lines += [f"### {arc['id']} · {arc['title']}",'',arc['facts'],'']
    lines += [f"{i+1}. {panel}" for i,panel in enumerate(arc['panels'])]
    lines += ['', '选择：'+'；'.join(arc['options'])+'。','']
    for index,voice in enumerate(arc['lenses']):
        lines += [f"**{names[index]}**",'', '旁白：'+voice[0], '\n内心：'+voice[1], '\n主角：'+voice[2],'']
    lines += ['后续契约：'+json.dumps(arc['next'],ensure_ascii=False)+'。','']
lines += ['## 终章与覆盖层','']
for ending in pack['endings']:
    lines += [f"### {ending['id']}",'',ending['facts'],'']
    lines += [f"- {names[i]}：{text}" for i,text in enumerate(ending['voices'])]
    lines += ['']
(ROOT/'docs/story-life-events.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('Wrote complete readable script book')
