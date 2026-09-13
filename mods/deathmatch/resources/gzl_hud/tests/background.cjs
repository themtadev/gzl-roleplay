// Run from resources: node gzl_hud/tests/background.cjs
const fs = require('fs');
const path = require('path');
const runtime = '../../gzl_inventory/tests/runtime/node_modules/';
const parse = require(runtime + 'luaparse');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(runtime + 'fengari');
const source = fs.readFileSync(path.join(__dirname, '../client/gui.lua'), 'utf8');
const ast = parse.parse(source, { luaVersion: '5.1', ranges: true });
function declaration(name) {
  const node = ast.body.find(n => n.type === 'FunctionDeclaration' && n.identifier?.name === name);
  if (!node) throw new Error('Missing function: ' + name);
  return source.slice(...node.range);
}
const restore = ast.body.find(n => n.type === 'CallStatement'
  && n.expression.arguments?.[0]?.raw === '"onClientPreRender"');
if (!restore) throw new Error('Missing foreground refresh');
const program = `
local backgroundRefreshPending = false
local minimized = true
local isBrowserReady, isVisible = true, true
local hudBrowser = {}
local lastVoice = {}
function isMTAWindowFocused() return not minimized end
function isElement(e) return e == hudBrowser end
function isAnyMapActive() return false end
${declaration('deferBackgroundUpdate')}
${declaration('pushPlayerStatus')}
${declaration('pushSessionData')}
${declaration('pushVoiceState')}
${declaration('updateBrowserPauseState')}
-- Real function bodies must return before touching any MTA/CEF dependency.
for i=1,7500 do
  pushPlayerStatus(true); pushSessionData(true); pushVoiceState(true)
  updateBrowserPauseState()
end
assert(backgroundRefreshPending)
local calls = 0
pushPlayerStatus = function(force) assert(force); calls=calls+1 end
pushSessionData = function(force) assert(force); calls=calls+1 end
pushVoiceState = function() calls=calls+1 end
local callback
function addEventHandler(_, _, fn) callback=fn end
${source.slice(...restore.range)}
callback(); assert(calls==0)
minimized=false; isBrowserReady=false; callback(); assert(calls==0)
isBrowserReady=true; callback(); assert(calls==3)
for i=1,100 do callback() end
assert(calls==3 and not backgroundRefreshPending)
print('PASS: Lua 5.1 syntax; 7,500 background update cycles blocked; one foreground refresh; browser-not-ready deferral')
`;
const state = lauxlib.luaL_newstate();
lualib.luaL_openlibs(state);
if (lauxlib.luaL_dostring(state, to_luastring(program)) !== lua.LUA_OK) {
  throw new Error(to_jsstring(lua.lua_tostring(state, -1)));
}
