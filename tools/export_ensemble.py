"""Encode native Godot render frames as an animation preview; requires Pillow."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
frames = [Image.open(path).convert("RGB") for path in sorted((root / ".godot/ensemble-frames").glob("*.png"))]
assert len(frames) == 25, "Run tools/capture_ensemble.gd in Godot first"
frames[0].save(root / "docs/world-scenes/ensemble-motion.gif", save_all=True,
               append_images=frames[1:], duration=[100]*24+[700], loop=0, optimize=False)
print("PASS: exported native ensemble animation")
