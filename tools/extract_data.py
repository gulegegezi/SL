"""
从 gamelife.html 中提取 window.GL_DATA 的全部游戏数据，
输出为 Godot 可用的 JSON 文件。
结局的 cond 箭头函数提取为字符串，供 GDScript 端评估。
"""
import json
import re
import sys
import os

HTML_PATH = "D:/gamelife/gamelife.html"
OUT_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "game_data.json")

def extract_gl_data_block(html_text: str) -> str:
    """提取 window.GL_DATA = (function(){ ... })(); 中的函数体"""
    start = html_text.index("window.GL_DATA = (function ()")
    # 找到匹配的 })(); 
    depth = 0
    i = html_text.index("{", start)
    depth = 1
    while depth > 0:
        i += 1
        c = html_text[i]
        if c == '{': depth += 1
        elif c == '}': depth -= 1
    # i 现在指向最后一个 }
    return html_text[start:i+4]  # 包含 })()

def extract_const(name: str, text: str):
    """提取 const NAME = [ ... ]; 的内容并 eval"""
    # 找到 const NAME =
    pattern = rf'const\s+{re.escape(name)}\s*=\s*'
    m = re.search(pattern, text)
    if not m:
        raise ValueError(f"Cannot find const {name}")
    start = m.end()
    # 判断是 [ 还是 {
    if text[start] == '[':
        # 找到匹配的 ]
        depth = 1
        i = start + 1
        while depth > 0:
            if text[i] == '[': depth += 1
            elif text[i] == ']': depth -= 1
            i += 1
        raw = text[start:i]
    elif text[start] == '{':
        depth = 1
        i = start + 1
        while depth > 0:
            if text[i] == '{': depth += 1
            elif text[i] == '}': depth -= 1
            i += 1
        raw = text[start:i]
    else:
        raise ValueError(f"Unexpected char after const {name}: {text[start]}")
    return raw

def safe_eval_js_array(raw: str):
    """将 JS 数组/对象转为 Python 对象（利用 JS->JSON 近似法）"""
    # JS 对象的 key 不带引号，需要补上
    # 先把单引号字符串内的内容保护起来
    # 逐步处理
    
    # Step 1: 替换单引号为双引号（小心不要破坏内容）
    # 这个太复杂了，改用 node.js 来执行
    return None

def extract_via_node(html_text: str) -> dict:
    """使用 Node.js 执行 GL_DATA 的 IIFE 并输出 JSON"""
    gl_block = extract_gl_data_block(html_text)
    
    node_script = """// 提供 window 桩，让 HTML 中的 JS 在 Node 里跑
var window = globalThis;
var localStorage = { getItem: ()=>null, setItem: ()=>{} };
""" + gl_block + """

// window.GL_DATA 已被 IIFE 赋值，从里面取数据
const D = window.GL_DATA;

// 对每个 ending，把 cond 函数体提取出来
const endOut = D.ENDINGS.map(e => {
    const out = Object.assign({}, e);
    if (typeof e.cond === 'function') {
        out.condStr = e.cond.toString();
        delete out.cond;
    }
    return out;
});

const result = {
    REGIONS: D.REGIONS,
    BODY_TYPES: D.BODY_TYPES,
    HEALTH_TYPES: D.HEALTH_TYPES,
    TIERS: D.TIERS,
    FAMILIES: D.FAMILIES,
    TALENTS: D.TALENTS,
    PARENT_JOBS: D.PARENT_JOBS,
    BIRTH_HOURS: D.BIRTH_HOURS,
    BIRTH_DREAMS: D.BIRTH_DREAMS,
    ENDINGS: endOut,
    ACHIEVEMENTS: D.ACHIEVEMENTS,
    EVENTS: D.EVENTS.map(e => Object.assign({}, e)),
    XHSD_PROVINCES: D.XHSD_PROVINCES
};

process.stdout.write(JSON.stringify(result, null, 2));
"""
    
    import subprocess
    import tempfile
    
    node_path = r"C:\Users\goze\.workbuddy\binaries\node\versions\22.22.2-6\node.exe"
    # 写入临时 JS 文件避免命令行长度限制
    script_dir = os.path.dirname(os.path.abspath(__file__))
    tmp_js = os.path.join(script_dir, "_extract_tmp.js")
    with open(tmp_js, "w", encoding="utf-8") as f:
        f.write(node_script)
    
    result = subprocess.run(
        [node_path, tmp_js],
        capture_output=True, text=True, timeout=30,
        cwd=script_dir
    )
    
    # 清理临时文件
    try:
        os.remove(tmp_js)
    except:
        pass
    
    if result.returncode != 0:
        print("STDERR:", result.stderr[:2000])
        raise RuntimeError("Node execution failed")
    return json.loads(result.stdout)

def main():
    with open(HTML_PATH, "r", encoding="utf-8") as f:
        html_text = f.read()
    
    print("Extracting game data via Node.js...")
    data = extract_via_node(html_text)
    
    # 统计
    print(f"  Regions: {len(data['REGIONS'])}")
    print(f"  Body types: {len(data['BODY_TYPES'])}")
    print(f"  Health types: {len(data['HEALTH_TYPES'])}")
    print(f"  Tiers: {len(data['TIERS'])}")
    print(f"  Families: {len(data['FAMILIES'])}")
    print(f"  Talents: {len(data['TALENTS'])}")
    print(f"  Parent jobs: {len(data['PARENT_JOBS'])}")
    print(f"  Birth hours: {len(data['BIRTH_HOURS'])}")
    print(f"  Birth dreams: {len(data['BIRTH_DREAMS'])}")
    print(f"  Endings: {len(data['ENDINGS'])}")
    print(f"  Achievements: {len(data['ACHIEVEMENTS'])}")
    print(f"  Events: {len(data['EVENTS'])}")
    
    # 输出
    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"\nWritten to {OUT_PATH}")
    print(f"File size: {os.path.getsize(OUT_PATH)} bytes")

if __name__ == "__main__":
    main()
