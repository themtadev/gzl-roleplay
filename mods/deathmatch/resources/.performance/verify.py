from pathlib import Path
import sys, re, json, xml.etree.ElementTree as ET
sys.path.insert(0, str(Path(__file__).parent / 'vendor'))
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parent.parent
lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval('function(s,n) local f,e=loadstring(s,n); return f~=nil,e end')
rows, failures = [], []
for meta in sorted(root.glob('*/meta.xml')):
    row = {'resource': meta.parent.name, 'scripts': 0, 'render_mentions': 0, 'timers': 0, 'element_scans': 0}
    for script in ET.parse(meta).getroot().findall('script'):
        path = meta.parent / script.get('src', '')
        if not path.is_file():
            failures.append(str(path.relative_to(root)) + ': missing')
            continue
        raw = path.read_bytes()
        if raw.startswith(b'\x1bLua'):
            continue
        text = raw.decode('utf-8-sig')
        ok, error = compile_lua(text, str(path.relative_to(root)))
        if not ok: failures.append(error)
        row['scripts'] += 1
        row['render_mentions'] += len(re.findall(r'onClient(?:Pre)?Render', text))
        row['timers'] += len(re.findall(r'\bsetTimer\s*\(', text))
        row['element_scans'] += len(re.findall(r'\bgetElementsByType\s*\(', text))
    rows.append(row)

# Exercise the real radar cache function with engine stubs.
text = (root / 'gzl_radar/client/main.lua').read_text(encoding='utf-8-sig')
chunk = text[text.index('local blipCache,'):text.index('local function loadTablerIcon')]
lua.execute('''
now=0; scans=0; root={}; mtaIconMap={}
blip={alive=true,dim=0,int=0,x=1,y=2,z=3}
function getTickCount() return now end
function getElementsByType() scans=scans+1; return {blip} end
function isElement(e) return e.alive end
function getElementDimension(e) return e.dim end
function getElementInterior(e) return e.int end
function getElementPosition(e) return e.x,e.y,e.z end
function getElementData() return nil end
function getBlipIcon() return 1 end
function getBlipColor() return 255,255,255,255 end
function tocolor() return 1 end
''')
lua.execute(chunk + '\ngetBlips=getActiveMtaBlips')
lua.execute('''
assert(#getBlips(0,0)==1 and scans==1)
now=5; blip.x=20; assert(getBlips(0,0)[1].x==20 and scans==1)
blip.dim=1; assert(#getBlips(0,0)==0)
assert(#getBlips(1,0)==1 and scans==2)
blip.alive=false; now=10; assert(#getBlips(1,0)==0)
blip.alive=true; now=110; assert(#getBlips(1,0)==1 and scans==3)
now=0; assert(#getBlips(1,0)==1 and scans==4)
''')
report = {'resources':len(rows), 'scripts':sum(r['scripts'] for r in rows), 'syntax_failures':failures, 'radar_cache_tests':'passed', 'inventory':rows}
(root / '.performance/audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='inventory'}, indent=2))
sys.exit(bool(failures))
