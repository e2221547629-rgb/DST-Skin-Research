"""A narrow regression tripwire, not a security proof or a Lua parser."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
for path in (root / "mod").rglob("*.lua"):
    text = path.read_text(encoding="utf-8")
    # The observer may query ownership, but cannot replace it or invoke setters.
    forbidden = [r"[:.]SetSkin(?:Name|Mode)?\s*\(", r"[:.]SetPlayerSkin\s*\(",
                 r"[:.]AssignItemSkins\s*\(", r"CheckClientOwnership\s*=",
                 r"CheckOwnership\s*=", r"ValidateSpawnPrefabRequest\s*=",
                 r"AddModRPCHandler\s*\(", r"SendModRPCToServer\s*\("]
    for pattern in forbidden:
        assert not re.search(pattern, text), f"{path}: forbidden mutation pattern {pattern}"
print("PASS observer mutation tripwires (heuristic)")
