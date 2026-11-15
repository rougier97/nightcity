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
# self-heal: if another app on the same origin wipes our offline cache, refill it next time we're online
python3 - <<'PY'
p='index.html'; s=open(p).read()
js = r"""<script>
(function(){
  if (!('caches' in window) || !('serviceWorker' in navigator)) return;
  window.addEventListener('load', function(){ setTimeout(async function(){
    try {
      if (!navigator.onLine) return;
      const t = await (await fetch('index.service.worker.js', {cache: 'no-store'})).text();
      const ver = /const CACHE_VERSION = '([^']*)'/.exec(t), pre = /const CACHE_PREFIX = '([^']*)'/.exec(t), files = /const CACHED_FILES = (\[[^\]]*\])/.exec(t);
      if (!ver || !pre || !files) return;
      const c = await caches.open(pre[1] + ver[1]);
      for (const f of JSON.parse(files[1])) { if (!(await c.match(f))) { try { await c.add(f); } catch (e) {} } }
    } catch (e) {}
  }, 6000); });
})();
</script>"""
s = s.replace('</body>', js + '\n</body>', 1)
open(p,'w').write(s)
PY
echo healed
