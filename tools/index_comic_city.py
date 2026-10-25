"""Index generated PNG alpha bounds without modifying artwork. Requires Pillow."""
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1] / 'assets' / 'comic_city'
output = {}
specs = [
    ('lead.png', ['infant_infant','lead_child','lead_teen','lead_youth','lead_adult','lead_middle','lead_elder'], [0,213,415,637,850,1076,1280,1485]),
    ('npc.png', ['npc_parent','npc_friend','npc_teacher','npc_boss','npc_partner','npc_mate'], [0,256,512,768,1024,1280,1536]),
]
for filename, keys, rows in specs:
    image = Image.open(root / filename).convert('RGBA')
    alpha = image.getchannel('A').point(lambda value: 255 if value >= 128 else 0)
    width, _ = image.size
    for row, key in enumerate(keys):
        frames = []
        for col in range(2):
            left, right = col * width // 2, (col + 1) * width // 2
            top, bottom = rows[row], rows[row + 1]
            bounds = alpha.crop((left, top, right, bottom)).getbbox()
            assert bounds, (key, col)
            x,y,x1,y1 = bounds
            frames.append([left+x, top+y, x1-x, y1-y])
        output[key] = {'file': filename, 'frames': frames}
(root / 'regions.json').write_text(json.dumps(output, indent=2), encoding='utf-8')
print('Indexed', len(output), 'characters, 26 bust portraits')
