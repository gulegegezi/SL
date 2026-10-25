"""Index untouched source atlases; this script never redraws or edits images."""
import json
from pathlib import Path
from PIL import Image
from collections import deque

def figure_bounds(mask):
    """Find the main connected figure, excluding tiny bleed from adjacent rows."""
    width,height = mask.size
    pixels = bytearray(mask.tobytes())
    largest = (0,None)
    for start in range(len(pixels)):
        if not pixels[start]: continue
        pixels[start] = 0
        queue = deque([start])
        area = 0
        x0,y0,x1,y1 = width,height,0,0
        while queue:
            pos = queue.popleft()
            x,y = pos%width,pos//width
            area += 1
            x0,y0,x1,y1 = min(x0,x),min(y0,y),max(x1,x+1),max(y1,y+1)
            for ny in range(max(0,y-1),min(height,y+2)):
                for nx in range(max(0,x-1),min(width,x+2)):
                    nxt = ny*width+nx
                    if pixels[nxt]: pixels[nxt]=0; queue.append(nxt)
        if area > largest[0]: largest = (area,(x0,y0,x1,y1))
    return largest[1]
root = Path(__file__).resolve().parents[1] / 'assets/comic_actions'
specs = [
    ('lead.png',['infant_infant','lead_child','lead_teen','lead_youth','lead_adult','lead_elder'],[0,168,313,468,627,792,1024],[0,510,800,1110,1536]),
    ('npc.png',['npc_parent','npc_friend','npc_teacher','npc_boss','npc_partner','npc_mate'],[0,274,532,779,1020,1267,1536],[0,286,536,769,1024]),
    ('middle.png',['lead_middle'],None,None),
]
output = {}
for filename, keys, rows, columns in specs:
    image = Image.open(root / filename).convert('RGBA')
    alpha = image.getchannel('A').point(lambda value: 255 if value >= 128 else 0)
    width,height = image.size
    rows = rows or [0,height]
    columns = columns or [col*width//4 for col in range(5)]
    for row,key in enumerate(keys):
        frames = []
        for col in range(4):
            left,right = columns[col],columns[col+1]
            top,bottom = rows[row],rows[row+1]
            bounds = figure_bounds(alpha.crop((left,top,right,bottom)))
            assert bounds, (key,col)
            x,y,x1,y1 = bounds
            frames.append([left+x,top+y,x1-x,y1-y])
        output[key] = {'file':filename,'frames':frames}
(root/'regions.json').write_text(json.dumps(output,indent=2)+'\n',encoding='utf-8')
print('Indexed 13 identities x 4 actual body poses = 52 regions')

image = Image.open(root/'walk.png').convert('RGBA')
alpha = image.getchannel('A').point(lambda value: 255 if value >= 128 else 0)
width,height = image.size
walk = {}
rows = [0,239,496,775,1065,1320,height]
for row,key in enumerate(['lead_child','lead_teen','lead_youth','lead_adult','lead_middle','lead_elder']):
    frames = []
    for col in range(4):
        left,right = col*width//4,(col+1)*width//4
        top,bottom = rows[row],rows[row+1]
        x,y,x1,y1 = figure_bounds(alpha.crop((left,top,right,bottom)))
        frames.append([left+x,top+y,x1-x,y1-y])
    walk[key] = {'file':'walk.png','frames':frames}
(root/'walk-regions.json').write_text(json.dumps(walk,indent=2)+'\n',encoding='utf-8')
print('Indexed 6 walking ages x 4 whole-body frames = 24 regions')
