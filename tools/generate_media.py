"""Generate original antialiased rounded masks; no third-party assets needed."""
from pathlib import Path
import math
import struct

ROOT = Path(__file__).resolve().parents[1] / "media"
ROOT.mkdir(exist_ok=True)

def tga(name, coverage, size=128):
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 0x28)
    pixels = bytearray()
    for y in range(size):
        for x in range(size):
            alpha = round(255 * sum(coverage((x + (sx+.5)/4)/size, (y + (sy+.5)/4)/size)
                                    for sy in range(4) for sx in range(4)) / 16)
            pixels.extend((255, 255, 255, alpha))
    (ROOT / name).write_bytes(header + pixels)

tga("corner.tga", lambda x, y: (x-1)**2 + (y-1)**2 <= 1)
for dimension in (28, 32, 36, 42):
    radius = 10 / dimension
    def rounded(x, y, r=radius):
        dx, dy = max(r-x, 0, x-(1-r)), max(r-y, 0, y-(1-r))
        return dx*dx + dy*dy <= r*r
    tga(f"mask{dimension}.tga", rounded)
print("Generated 5 original TGA masks.")
