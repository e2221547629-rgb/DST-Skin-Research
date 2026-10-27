"""Optional cross-platform runner: pip install lupa==2.6; uses Lua 5.1 explicitly."""
import argparse
from pathlib import Path
import subprocess
import sys
from lupa.lua51 import LuaRuntime

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--local-source", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    import os
    os.chdir(root)
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('io.stdout:setvbuf("no")')
    assert lua.eval("_VERSION") == "Lua 5.1"
    print("Runtime:", lua.eval("_VERSION"), flush=True)
    compile_lua = lua.eval("function(s, n) local f, e = loadstring(s, n); assert(f, e); return true end")
    files = sorted(root.glob("mod/**/*.lua")) + sorted(root.glob("tests/*.lua"))
    for path in files:
        compile_lua(path.read_text(encoding="utf-8"), "@" + path.relative_to(root).as_posix())
    print(f"PASS syntax: {len(files)} Lua files", flush=True)
    lua.execute(Path("tests/mock_runtime.lua").read_text(encoding="utf-8"))
    subprocess.run([sys.executable, "tools/check_guardrails.py"], check=True)
    if args.local_source:
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute('io.stdout:setvbuf("no")')
        lua.execute(Path("tests/source_boundary.lua").read_text(encoding="utf-8"))
    else:
        print("SKIP local source branches: proprietary source not supplied")
    print("No DST engine, network transport or rendering test was performed.")

if __name__ == "__main__": main()
