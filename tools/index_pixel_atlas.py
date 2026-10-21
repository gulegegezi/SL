"""Index alpha bounds only; does not modify the generated PNGs. Run from project root."""
import json
from pathlib import Path
from PIL import Image

root = Path('assets/portraits_v2')
result = {}
specs = [
    ('lead', 'lead-atlas.png', ['child','teen','youth','adult','middle','elder'], [0,262,512,765,1034,1282,1536]),
    ('npc', 'npc-atlas.png', ['parent','friend','teacher','boss','partner','mate'], [0,265,523,790,1048,1300,1536]),
    ('infant', 'infant-atlas.png', ['infant'], [0,724]),
]
for kind, filename, names, rows in specs:
    image = Image.open(root / filename).convert('RGBA')
    alpha = image.getchannel('A').point(lambda p: 255 if p >= 128 else 0)
    width, height = image.size
    for row, name in enumerate(names):
        frames = []
        for col in range(4):
            left, right = col * width // 4, (col + 1) * width // 4
            top, bottom = rows[row], min(rows[row+1], height)
            bounds = alpha.crop((left, top, right, bottom)).getbbox()
            assert bounds, (kind, name, col)
            x0,y0,x1,y1 = bounds
            frames.append([left+x0, top+y0, x1-x0, y1-y0])
        result[f'{kind}:{name}'] = {'file': filename, 'frames': frames}
(root / 'regions.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print('Indexed', len(result), 'characters /', sum(len(v['frames']) for v in result.values()), 'frames')
