set -e
cd /home/claude/nightcity
rm -rf build/web && mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html 2>&1 | grep -iE "error" || true
cd build/web
python3 - <<'PY'
import re
p='index.service.worker.js'; s=open(p).read()
s=s.replace('"index.worker.js",','')
s=re.sub(r'const CACHED_FILES = \[(.*?)\];', lambda m: 'const CACHED_FILES = [%s,"index.wasm","index.pck","index.manifest.json","index.144x144.png","index.180x180.png","index.512x512.png"];' % m.group(1), s, count=1)
open(p,'w').write(s)
PY
touch .nojekyll
echo built
