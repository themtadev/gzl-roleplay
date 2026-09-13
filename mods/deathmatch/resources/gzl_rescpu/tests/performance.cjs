const fs=require('fs'),path=require('path');
const runtime='../../gzl_inventory/tests/runtime/node_modules/';
const f=require(runtime+'fengari'),parse=require(runtime+'luaparse');
const root=path.resolve(__dirname,'../..');
function read(p){return fs.readFileSync(path.join(root,p),'utf8');}
function run(code){const L=f.lauxlib.luaL_newstate();f.lualib.luaL_openlibs(L);if(f.lauxlib.luaL_dostring(L,f.to_luastring(code))!==f.lua.LUA_OK)throw Error(f.to_jsstring(f.lua.lua_tostring(L,-1)));}
for(const name of ['gzl_rescpu/ram.lua','gzl_rescpu/probe.lua','gzl_rescpu/server.lua','gzl_atm/client/interaction.lua','gzl_core/client/main.lua','gzl_hud/client/bottom_hud.lua','gzl_radar/client/main.lua'])parse.parse(read(name),{luaVersion:'5.1'});
run(`root={};resourceRoot={};tick=0;handlers={};commands={};stages={};target=nil;blend='blend';frame=0;sampleFrames={};buildFrames={};allocations=0
PerfProbe={record=function(n,t) stages[n]=true end}
function getTickCount() return tick end
function isMTAWindowFocused() return true end
function getResourceFromName(n) return n=='test' end
function getPerformanceStats(kind) sampleFrames[frame]=true;if kind=='Lua memory' then return {'name','change','current','max'},{{'test','','1 MB','1 MB'}} else return {'name','5s.cpu','5s.time'},{{'test','1%','0.05'}} end end
function dxGetStatus() return {} end
function guiGetScreenSize() return 1920,1080 end
function dxCreateFont() return {} end
function dxCreateRenderTarget() allocations=allocations+1;return {} end
function isElement(e) return type(e)=='table' and not e.dead end
function destroyElement(e) e.dead=true end
function dxSetRenderTarget(t) target=t;return true end
function dxGetBlendMode() return blend end
function dxSetBlendMode(b) blend=b end
function dxDrawText() if target then buildFrames[frame]=true end end
function dxDrawRectangle() end
function dxDrawImage() end
function tocolor() return 1 end
function addEventHandler(e,_,fn) handlers[e]=fn end
function removeEventHandler(e) handlers[e]=nil end
function addCommandHandler(n,fn) commands[n]=fn end
function isTimer() return false end
function outputDebugString(s) error(s) end
${read('gzl_rescpu/ram.lua')}
commands.ram('ram')
for i=1,1000 do frame=i;tick=i*5;handlers.onClientRender() end
for k in pairs(buildFrames) do assert(not sampleFrames[k],'sampling and drawing share frame') end
assert(stages['Lua memory'] and stages['Lua timing'] and stages['RAM sort'] and stages['fonts'] and stages['panel rebuild'])
assert(rows[1].name=='test' and cpuRows[1].current=='1.00 %' and allocations==1)
commands.ram('ram');assert(not handlers.onClientRender and panelTarget==nil)
print('PASS live sampling, separated work, cached panel, cleanup')`);
// Exhaustively compare walking outputs against the backed-up implementation.
function fn(src,name){const ast=parse.parse(src,{ranges:true});const node=ast.body.find(n=>n.type==='FunctionDeclaration'&&n.identifier?.name===name);return src.slice(...node.range);}
const old=fn(read('.optimization-backup/performance-pass/gzl_core/client/main.lua'),'handleWalkByDefault');const now=fn(read('gzl_core/client/main.lua'),'handleWalkByDefault');
run(`localPlayer={};isWalkByDefaultEnabled=true
function isPedInVehicle() return false end
function isPedDead() return false end
function isElementInWater() return false end
function isTyping() return typing end
function getPedControlState(_,k) return states[k] or false end
function setPedControlState(_,k,v) states[k]=v end
function getKeyState(k) return (k=='lshift' and shift) or (k=='space' and space) or false end
${old}
local before=handleWalkByDefault
${now}
for mask=0,127 do
 local function bit(n) return math.floor(mask/2^n)%2==1 end
 local function initial() return {forwards=bit(0),walk=bit(1),sprint=bit(2),jump=bit(3)} end
 typing=bit(4);shift=bit(5);space=bit(6);states=initial();before();local expected=states
 states=initial();handleWalkByDefault();for k,v in pairs(expected) do assert(states[k]==v,'control changed '..k) end
end
print('PASS 128 walking state combinations match previous behavior')`);
console.log('PASS all modified Lua syntax');

run(`root={};resourceRoot={};localPlayer={};ATMConfig={};exports={};events={};tick=0;near=false;scans=0;opened=0;vehicle=false
function guiGetScreenSize() return 1920,1080 end
function getTickCount() return tick end
function addEventHandler(n,_,fn) events[n]=fn end
function bindKey(_,_,fn) key=fn end
function getElementType() return 'object' end
function isElementStreamedIn() return true end
function isElement(e) return type(e)=='table' end
function getElementsByType() scans=scans+1;return {} end
function getElementPosition(e) return e==localPlayer and 0 or (near and 1 or 100),0,0 end
function getElementDimension() return 0 end
function getElementInterior() return 0 end
function getElementModel() return 2942 end
function getDistanceBetweenPoints3D(x,y,z,a,b,c) return math.abs(x-a) end
function getElementRotation() return 0,0,0 end
function processLineOfSight() return false end
function isATMOpen() return false end
function isPedInVehicle() return vehicle end
function isCursorShowing() return false end
function getScreenFromWorldPosition() return false end
function openATM() opened=opened+1 end
function playSoundFrontEnd() end
`+read('gzl_atm/client/interaction.lua')+`
events.onClientResourceStart();source={};events.onClientElementStreamIn();near=true;key();assert(opened==1)
near=false;key();assert(opened==1);near=true;events.onClientElementDestroy();key();assert(opened==1)
source={};events.onClientElementStreamIn();events.onClientElementStreamOut();key();assert(opened==1)
for i=1,1000 do tick=i*5;events.onClientRender() end
assert(scans==1,'object enumeration repeated')
print('PASS ATM startup/stream/destroy tracking and fresh proximity validation')`);
