import json, os, sys
here = os.path.dirname(os.path.abspath(__file__))
data_dir = os.path.join(here, '..', 'GroundControl', 'data')
data = {n[:-5]: json.load(open(os.path.join(data_dir, n))) for n in sorted(os.listdir(data_dir)) if n.endswith('.json')}
blob = json.dumps(data, ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/')
src = open(os.path.join(here, 'template.html')).read()
open(os.path.join(here, 'index.html'), 'w').write(src.replace('__DATA__', blob))
print('built', len(blob), 'bytes of data')
