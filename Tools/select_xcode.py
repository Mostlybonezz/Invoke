"""Use the runner's default supported Xcode, falling back to installed copies."""
import os
from pathlib import Path
import re
import subprocess


def version_at(path):
    env = os.environ | {"DEVELOPER_DIR": str(path)}
    try:
        output = subprocess.check_output(["xcodebuild", "-version"], env=env, text=True)
        match = re.search(r"Xcode (\d+)(?:\.(\d+))?", output)
        if match:
            return (int(match[1]), int(match[2] or 0)), output.strip()
    except subprocess.CalledProcessError:
        pass
    return (0, 0), ""


default = Path(subprocess.check_output(["xcode-select", "-p"], text=True).strip())
version, description = version_at(default)
selected = default
if version[0] < 16:
    candidates = []
    for path in Path("/Applications").glob("Xcode*.app/Contents/Developer"):
        candidate_version, candidate_description = version_at(path)
        if candidate_version[0] >= 16 and "beta" not in str(path).lower():
            candidates.append((candidate_version, str(path), candidate_description))
    if not candidates:
        raise SystemExit("No installed stable Xcode 16 or later was found.")
    version, selected, description = max(candidates)

print(f"Using {description}\nDEVELOPER_DIR={selected}")
if os.environ.get("GITHUB_ENV"):
    with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as output:
        output.write(f"DEVELOPER_DIR={selected}\n")
