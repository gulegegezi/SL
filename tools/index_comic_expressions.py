"""Generate alpha-bounded regions; source PNGs remain unmodified. Requires Pillow."""
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1] / 'assets/comic_expressions'
specs = [
    ('lead.png', ['infant_infant','lead_child','lead_teen','lead_youth','lead_adult','lead_elder'], [0,156,303,456,614,768,940]),
    ('npc.png', ['npc_parent','npc_friend','npc_teacher','npc_boss','npc_partner','npc_mate'], [0,216,424,645,849,1058,1283]),
    ('middle.png', ['lead_middle'], None),
]
output = {}
for filename, keys, rows in specs:
    image = Image.open(root / filename).convert('RGBA')
    alpha = image.getchannel('A').point(lambda value: 255 if value >= 128 else 0)
    width,height = image.size
    if rows is None: rows = [0,height]
    for row,key in enumerate(keys):
        frames = []
        for col in range(6):
            left,right = col*width//6, (col+1)*width//6
            top,bottom = rows[row],rows[row+1]
            box = alpha.crop((left,top,right,bottom)).getbbox()
            assert box is not None, (key,col)
            x,y,x1,y1 = box
            frames.append([left+x,top+y,x1-x,y1-y])
        output[key] = {'file': filename, 'frames': frames}
(root / 'regions.json').write_text(json.dumps(output,indent=2),encoding='utf-8')
print('Indexed 13 characters x 6 expressions = 78 portraits')
