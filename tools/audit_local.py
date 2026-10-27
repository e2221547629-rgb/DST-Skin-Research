"""Read an owned local DST installation; publish only hashes and line references."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

FILES = ["networking.lua", "components/skinner.lua", "prefabs/player_common.lua",
         "playerprofile.lua", "skinsutils.lua", "mainfunctions.lua", "components/wardrobe.lua"]
TERMS = ["ValidateSpawnPrefabRequest", "CheckClientOwnership", "CheckOwnership",
         "SetPlayerSkin", "AssignItemSkins", "SetSkin(", "SetSkinMode", "SetSkinName",
         "ValidateItemsLocal", "SendSpawnRequestToServer", 'AddComponent("skinner")',
         "function Skinner:OnLoad", "function Skinner:GetClothing", "SetPristine"]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("game_root", type=Path)
    parser.add_argument("--output", type=Path, default=Path("evidence/source_manifest.json"))
    parser.add_argument("--extract", type=Path, default=Path(".local-source"))
    args = parser.parse_args()
    bundle = args.game_root / "data/databundles/scripts.zip"
    result = {"game_version": (args.game_root / "version.txt").read_text().strip(),
              "bundle_sha256": hashlib.file_digest(bundle.open("rb"), "sha256").hexdigest(),
              "scope": "Local installed scripts; does not establish latest Steam version or native engine behavior",
              "files": {}, "references": {}}
    with zipfile.ZipFile(bundle) as archive:
        for relative in FILES:
            name = "scripts/" + relative
            data = archive.read(name)
            lines = data.decode("utf-8-sig").splitlines()
            result["files"][name] = {"sha256": hashlib.sha256(data).hexdigest(), "lines": len(lines)}
            dest = args.extract / relative
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
            result["references"][name] = {term: [i for i, line in enumerate(lines, 1) if term in line]
                                            for term in TERMS if any(term in line for line in lines)}
        # Inventory of call sites, not a native engine implementation audit.
        result["native_call_sites"] = []
        for name in archive.namelist():
            if not name.endswith(".lua"): continue
            lines = archive.read(name).decode("utf-8-sig", errors="replace").splitlines()
            for i, line in enumerate(lines, 1):
                for term in ("SetPlayerSkin", "AssignItemSkins", "ValidateSpawnPrefabRequest", "SendSpawnRequestToServer"):
                    if term in line:
                        result["native_call_sites"].append({"file": name, "line": i, "symbol": term})
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PASS local source manifest: version {result['game_version']}, {len(FILES)} files")
    print("Extracted game scripts are local only. Do not commit or redistribute them.")

if __name__ == "__main__": main()
