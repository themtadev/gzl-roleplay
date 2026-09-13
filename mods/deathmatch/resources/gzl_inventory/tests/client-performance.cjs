const fs = require('fs');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('./runtime/node_modules/fengari');
const prelude = `
root, resourceRoot, localPlayer = {}, {}, {}
local events, timers, messages, pauseCalls, requests, keys = {}, {}, {}, {}, {}, {}
local characterId = 1
function addEvent() end
function addEventHandler(name, element, fn) events[name] = fn end
function removeEventHandler(name) events[name] = nil end
function guiGetScreenSize() return 1920, 1080 end
function bindKey(key, _, fn) keys[key] = fn end
function getResourceFromName() return nil end
function isElement(e) return e ~= nil end
function guiCreateBrowser() return {} end
function guiGetBrowser() return {} end
function guiSetVisible() end
function guiSetInputMode() end
function guiBringToFront() end
function focusBrowser() end
function showCursor() end
function setElementData() end
function getElementData() return characterId end
function isMainMenuActive() return false end
function triggerServerEvent(name, ...) requests[#requests+1] = name end
function getTickCount() return 1000 end
function setBrowserRenderingPaused(_, paused) pauseCalls[#pauseCalls+1] = paused end
function isTimer(t) return t ~= nil and timers[t] ~= nil end
function setTimer(fn) local t = {}; timers[t] = fn; return t end
function killTimer(t) timers[t] = nil end
function toJSON(payload) messages[#messages+1] = payload; return '{}' end
function executeBrowserJavascript() end
exports = {gzl_ui = {isProgressBarActive = function() return false end}}
`;
const checks = `
local inv = {id='p',type='player',slots=40,maxWeight=30000,items={[1]={slot=1,name='water',count=1,metadata={label='A'}}}}
local updated = {id='p',type='player',slots=40,maxWeight=30000,items={['1']={slot=1,name='water',count=1,metadata={label='B'}}}}
local deltas, count = getInventorySlotDeltas(inv, updated, 'player')
assert(count == 1 and deltas[1].item.metadata.label == 'B', 'metadata and string slots')
updated.maxWeight = 40000
assert(getInventorySlotDeltas(inv, updated, 'player') == nil, 'header change needs full sync')
events.onClientResourceStart()
events['ox_inventory:onNuiCallback']('uiLoaded', '{}')
assert(isRenderingPaused, 'hidden browser pauses')
local before = #messages
events['ox_inventory:syncInventory'](inv, {id='drop',type='drop',slots=40,items={}})
assert(#messages == before, 'hidden full sync sends no browser message')
toggleInventory(true)
assert(not isRenderingPaused, 'open browser runs continuously')
assert(events.onClientCursorMove == nil, 'no mouse wake handler')
assert(next(timers) == nil, 'no repeating idle pause timer')
toggleInventory(false)
assert(isRenderingPaused, 'close pauses browser')
events['ox_inventory:onNuiCallback']('uiLoaded', '{}')
assert(isRenderingPaused, 'late callback cannot wake hidden browser')
toggleHotbarDisplay()
assert(isTimer(hotbarTimer) and not isRenderingPaused, 'TAB opens hotbar')
assert(messages[#messages].action == 'toggleHotbar' and messages[#messages].data == true)
toggleHotbarDisplay()
assert(hotbarTimer == nil and isRenderingPaused, 'second TAB closes hotbar')
assert(messages[#messages].action == 'toggleHotbar' and messages[#messages].data == false)
toggleHotbarDisplay()
assert(isTimer(hotbarTimer) and not isRenderingPaused, 'third TAB reopens hotbar')
toggleInventory(true)
assert(hotbarTimer == nil and not isRenderingPaused, 'inventory opening clears hotbar')
print('PASS: metadata deltas, header fallback, hidden sync, open/close rendering, no mouse wake handler or idle timer, late callback stays paused.')
`;
const client = fs.readFileSync('client/main.lua','utf8');
require('./runtime/node_modules/luaparse').parse(client, {luaVersion:'5.1'});
function run(checks) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  const status = lauxlib.luaL_dostring(L, to_luastring(prelude + '\n' + client + '\n' + checks));
  if (status !== lua.LUA_OK) throw new Error(to_jsstring(lua.lua_tostring(L,-1)));
  lua.lua_close(L);
}
run(checks);
const setup = `
local inv = {id='p',type='player',slots=40,maxWeight=30000,items={[1]={slot=1,name='water',count=2,metadata={}}}}
local drop = {id='drop',type='drop',slots=40,items={}}
events.onClientResourceStart()
assert(requests[1] == 'ox_inventory:requestInventory', 'restart requests data without F2')
assert(not isRenderingPaused and not isBrowserReady, 'React can finish loading while hidden')
`;
const steps = {
  ready: `events['ox_inventory:onNuiCallback']('uiLoaded', '{}')`,
  data: `events['ox_inventory:syncInventory'](inv, drop)`,
  tab: `keys.tab()`
};
for(const order of [['ready','data','tab'],['ready','tab','data'],['data','ready','tab'],['data','tab','ready'],['tab','ready','data'],['tab','data','ready']]){
  run(setup + order.map(step=>steps[step]).join('\n') + `
assert(hotbarRequested and isTimer(hotbarTimer) and not isRenderingPaused, 'cold TAB visible in every readiness order')
assert(not isInventoryOpen, 'no F2 needed')
local oldTimer = hotbarTimer
events['ox_inventory:syncInventory'](inv, drop)
assert(hotbarTimer == oldTimer, 'sync does not restart hotbar timeout')
timers[hotbarTimer]()
assert(not hotbarRequested and hotbarTimer == nil and isRenderingPaused, 'auto-close clears native state')
keys.tab()
assert(hotbarRequested and isTimer(hotbarTimer), 'first TAB after timeout opens')
keys.tab()
assert(not hotbarRequested and hotbarTimer == nil, 'second TAB closes')
`);
  console.log('PASS: restart order ' + order.join(' -> '));
}
run(setup + `
keys.tab()
assert(hotbarRequested and hotbarTimer == nil, 'no timeout before data/UI readiness')
keys.tab()
${steps.ready}
${steps.data}
assert(not hotbarRequested and hotbarTimer == nil and isRenderingPaused, 'cancelled pending TAB never reopens')
events['ox_inventory:refreshSlots']({items={{inventory='player',item={slot=1,name='water',count=7,metadata={}}}}})
assert(getInventoryItemInSlot(1).count == 7, 'hidden refresh updates hotkeys cache')
keys.tab()
events['auth:showLoginScreen']()
assert(not hotbarRequested and not isInventoryOpen and leftInventory == nil, 'login closes hotbar and clears cache')
characterId = false
events['ox_inventory:syncInventory'](inv, drop)
assert(leftInventory == nil, 'logged-out response ignored')
characterId = 2
events.onClientElementDataChange('character:id')
assert(requests[#requests] == 'ox_inventory:requestInventory', 'character switch requests fresh snapshot')
`);
console.log('PASS: pending cancellation, hidden delta cache, login cleanup, character switch, Lua 5.1 syntax');
run(setup + `
toggleInventory(true)
characterId = false
toggleInventory(false)
assert(not isRenderingPaused, 'closing on logout before readiness cannot freeze bootstrap')
${steps.ready}
assert(isRenderingPaused and not isInventoryOpen, 'ready after cancelled F2 stays hidden')
characterId = 1
${steps.data}
local beforeUse = #requests
performUseItem(1, 1)
assert(pendingUseItem == nil and activeItemUseTimer == nil and #requests == beforeUse, 'failed progress start cannot consume an item')
keys.tab()
events.onClientPlayerWasted()
assert(not hotbarRequested and not isInventoryOpen and isRenderingPaused, 'death closes both surfaces')
`);
console.log('PASS: cancelled first F2, failed progress start, death cleanup');
