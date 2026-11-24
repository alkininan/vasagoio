"""Build a deterministic install ZIP using an explicit distribution allowlist."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]

def package(out):
    toc = (ROOT / "vasagoio.toc").read_text()
    version = re.search(r"^## Version: (.+)$", toc, re.M).group(1)
    entries = ["vasagoio.toc", "README.md", "LICENSE", "CHANGELOG.md", "THIRD_PARTY.md"]
    entries += [line.strip().replace("\\", "/") for line in toc.splitlines() if line.strip() and not line.startswith("#")]
    entries += [str(p.relative_to(ROOT)) for p in sorted((ROOT / "media").glob("*.tga"))]
    entries += [str(p.relative_to(ROOT)) for p in sorted((ROOT / "docs").glob("*")) if p.suffix in (".md", ".json") and p.name != "DEVELOPMENT_CONTRACT.md"]
    assert len(entries) == len(set(entries)), "Duplicate archive member"
    manifest = {}
    for name in entries:
        path = (ROOT / name).resolve()
        assert path.is_relative_to(ROOT) and path.is_file() and not path.is_symlink(), name
        manifest[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    out.mkdir(parents=True, exist_ok=True)
    archive = out / f"vasagoio-{version}.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name in sorted(entries):
            info = zipfile.ZipInfo("vasagoio/" + name, date_time=(2026, 1, 1, 0, 0, 0))
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, (ROOT / name).read_bytes())
        info = zipfile.ZipInfo("vasagoio/manifest.json", date_time=(2026, 1, 1, 0, 0, 0))
        info.external_attr = 0o100644 << 16
        z.writestr(info, json.dumps({"version": version, "files": manifest}, indent=2) + "\n")
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    (out / (archive.name + ".sha256")).write_text(f"{checksum}  {archive.name}\n")
    print(f"{archive.name}: {len(entries)} files; SHA256 {checksum}")
    return archive

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=ROOT / "dist")
    package(parser.parse_args().out)
