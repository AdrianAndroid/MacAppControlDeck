#!/bin/zsh
set -e
O=/Applications/Orca.app/Contents/Resources/bin/orca
name=$1
wid=${2:-3550}
cd "$HOME/Desktop/Tencent Lemon 调研"
$O computer get-app-state --app com.tencent.Lemon --window-id "$wid" --screenshot-scale 1 --json > "state-$name.json"
python3 - "$name" <<'PY'
import json, sys, shutil
name = sys.argv[1]
d = json.load(open(f'state-{name}.json'))
r = d.get('result') or {}
shot = r.get('screenshot') or {}
p = shot.get('path')
if p:
    shutil.copy2(p, f'screenshots/{name}.png')
print('SHOT', 'OK' if d.get('ok') else 'FAIL', name, shot.get('width'), shot.get('height'))
snap = r.get('snapshot') or {}
print(snap.get('treeText', '')[:2500])
PY
