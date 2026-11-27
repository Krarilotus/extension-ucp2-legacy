"""Build the installable UCP2-Legacy preview and its SHA-256 checksum."""

import hashlib
import re
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


def main():
    root = Path(__file__).resolve().parents[1]
    definition = (root / "definition.yml").read_text(encoding="utf-8")
    version = re.search(r"^version: (\d+\.\d+\.\d+)\s*$", definition, re.MULTILINE)
    if version is None:
        raise ValueError("Missing module version in definition.yml")

    # The ZIP opens at the module root, with patches in port/ and texts in locale/.
    module_extensions = {".lua", ".yml", ".md"}
    files = [path for path in root.iterdir() if path.is_file() and path.suffix in module_extensions]
    for folder in ("port", "locale"):
        files.extend(
            path for path in (root / folder).rglob("*")
            if path.is_file() and path.suffix in module_extensions
        )

    dist = root / "dist"
    dist.mkdir(exist_ok=True)
    archive = dist / f"ucp2-legacy-{version[1]}.zip"
    with ZipFile(archive, "w", ZIP_DEFLATED) as output:
        for path in sorted(files):
            if path.is_symlink() or not path.resolve().is_relative_to(root):
                raise ValueError(f"Module file must be inside the checkout: {path}")
            output.write(path, path.relative_to(root).as_posix())

    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix(".zip.sha256").write_text(f"{checksum}  {archive.name}\n", encoding="ascii")
    print(archive)


if __name__ == "__main__":
    main()
