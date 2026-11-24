"""Portable offline checks. Does not access the game installation or accounts."""
import argparse
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import zipfile
from package import package

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--lua", default="lua5.1")
parser.add_argument("--luac", default="luac5.1")
args = parser.parse_args()
subprocess.run([sys.executable, str(ROOT / "tools/window_catalog.py"), "--check"], check=True)
for source in sorted(ROOT.rglob("*.lua")):
    subprocess.run([args.luac, "-p", str(source)], check=True)
for spec in sorted((ROOT / "tests").glob("*_spec.lua")):
    subprocess.run([args.lua, str(spec), str(ROOT)], cwd=ROOT, check=True)
toc = (ROOT / "vasagoio.toc").read_text()
for line in toc.splitlines():
    if line and not line.startswith("#"):
        assert (ROOT / line).is_file(), f"Missing TOC file: {line}"
for path in ROOT.rglob("*"):
    if not path.is_file() or ".git" in path.parts or "dist" in path.parts or "__pycache__" in path.parts:
        continue
    if path.suffix in {".md", ".json", ".lua", ".toc", ".yml"}:
        text = path.read_text()
        assert not re.search(r"/Users/|/home/[a-z]|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_", text), f"Private path/token in {path.name}"
        if path.suffix == ".md":
            for target in re.findall(r"\]\(([^)]+)\)", text):
                if "://" not in target and not target.startswith("#"):
                    assert (path.parent / target.split("#")[0]).exists(), f"Broken local documentation link in {path.name}: {target}"
for path in (ROOT / "media").glob("*.tga"):
    content = path.read_bytes()
    assert len(content) == 18 + 128*128*4 and content[16] == 32, f"Invalid original media: {path}"
with tempfile.TemporaryDirectory() as temp:
    archive = package(Path(temp))
    original = archive.read_bytes()
    assert package(Path(temp)).read_bytes() == original, "Package is not reproducible"
    with zipfile.ZipFile(archive) as z:
        names = z.namelist()
        assert "vasagoio/vasagoio.toc" in names
        assert all(n.startswith("vasagoio/") and ".." not in n for n in names)
        assert not any(n.lower().endswith((".ttf", ".otf")) or "/WTF/" in n for n in names)
print("Offline checks passed. Native WoW behavior and visual parity remain untested.")
