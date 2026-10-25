"""Index original generated full-body atlases without modifying their pixels."""
import json
from pathlib import Path
from collections import deque
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]/"assets/comic_ensemble"

def bounds(mask):
    w,h=mask.size
    pixels=bytearray(mask.tobytes())
    largest=(0,None)
    for start in range(len(pixels)):
        if not pixels[start]: continue
        queue=deque([start]);pixels[start]=0
        area=0;x0=w;y0=h;x1=y1=0
        while queue:
            pos=queue.popleft();x,y=pos%w,pos//w;area+=1
            x0=min(x0,x);y0=min(y0,y);x1=max(x1,x+1);y1=max(y1,y+1)
            for ny in range(max(0,y-1),min(h,y+2)):
                for nx in range(max(0,x-1),min(w,x+2)):
                    i=ny*w+nx
                    if pixels[i]: pixels[i]=0;queue.append(i)
        if area>largest[0]: largest=area,(x0,y0,x1,y1)
    return largest[1]

output={}
for file,keys,rows in [
    ("npc-v1.png",["npc_parent","npc_friend","npc_teacher","npc_boss","npc_partner","npc_mate"],[0,260,526,805,1080,1341,1536]),
    ("lead-v2.png" if (ROOT/"lead-v2.png").exists() else "lead-v1.png",["lead_child","lead_teen","lead_youth","lead_adult","lead_middle","lead_elder"],[0,239,511,791,1079,1330,1536])]:
    im=Image.open(ROOT/file).convert("RGBA")
    alpha=im.getchannel("A").point(lambda v:255 if v>=128 else 0)
    w,h=im.size
    for row,key in enumerate(keys):
        frames=[]
        for col in range(4):
            left,right=col*w//4,(col+1)*w//4;top,bottom=rows[row],rows[row+1]
            box=bounds(alpha.crop((left,top,right,bottom)))
            assert box,(key,col)
            x,y,x1,y1=box
            assert y1-y>x1-x,(key,col,"full body required")
            frames.append([left+x,top+y,x1-x,y1-y])
        output[key]={"file":file,"frames":frames,"facing":"right","render_height":64}
im=Image.open(ROOT/"middle-v1.png").convert("RGBA")
alpha=im.getchannel("A").point(lambda v:255 if v>=128 else 0)
w,h=im.size
frames=[]
for col in range(4):
    left,right=col*w//4,(col+1)*w//4
    x,y,x1,y1=bounds(alpha.crop((left,0,right,h)))
    frames.append([left+x,y,x1-x,y1-y])
output["lead_middle"]={"file":"middle-v1.png","frames":frames,"facing":"right","render_height":64}
(ROOT/"regions.json").write_text(json.dumps(output,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("PASS: indexed 12 identities x 4 full-body keyposes without modifying source images")
