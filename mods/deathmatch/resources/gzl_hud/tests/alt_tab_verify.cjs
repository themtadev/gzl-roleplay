const fs = require('fs');
const path = require('path');
const runtime = path.join(__dirname, '../../gzl_inventory/tests/runtime/node_modules/');
const parse = require(path.join(runtime, 'luaparse'));
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(path.join(runtime, 'fengari'));

console.log('--- RUNNING DEEP VERIFICATION SUITE ---');

// 1. Verify Syntax for all 4 modified files
const files = [
  '../../gzl_creator/client/shaders.lua',
  '../../gzl_hud/client/gui.lua',
  '../../gzl_inventory/client/main.lua',
  '../../gzl_hud/client/bottom_hud.lua'
];

for (const f of files) {
  const content = fs.readFileSync(path.join(__dirname, f), 'utf8');
  parse.parse(content, { luaVersion: '5.1' });
  console.log(`[SYNTAX PASS] ${f}`);
}

// 2. Test gzl_creator shaders.lua queue behavior in Fengari
{
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);

  const testScript = `
    events = {}
    timers = {}
    customApplied = {}
    timerIdCounter = 0

    root = "root"
    resourceRoot = "resourceRoot"
    localPlayer = "localPlayer"

    function addEventHandler(event, target, fn)
      if not events[event] then events[event] = {} end
      table.insert(events[event], fn)
    end

    function getElementType(elem)
      if elem == "player" or elem == "localPlayer" or elem == "player2" or elem == "player3" or elem == "player4" then
        return "player"
      end
      return "ped"
    end

    local streamedIn = {
      [localPlayer] = true,
      ["player2"] = true,
      ["player3"] = true,
      ["player4"] = true,
      ["ped1"] = true
    }

    function isElement(elem)
      return elem ~= nil and elem ~= false
    end

    function isElementStreamedIn(elem)
      return streamedIn[elem] == true
    end

    local elementData = {
      [localPlayer] = { ["char:customization"] = { gender = "male", skinTone = 1 } },
      ["player2"] = { ["char:customization"] = { gender = "female", skinTone = 2 } },
      ["player3"] = { ["char:customization"] = { gender = "male", skinTone = 1 } },
      ["player4"] = { ["char:customization"] = { gender = "male", skinTone = 3 } },
      ["ped1"] = { ["char:customization"] = { gender = "female", skinTone = 1 } }
    }

    function getElementData(elem, key)
      if elementData[elem] then
        return elementData[elem][key]
      end
      return nil
    end

    function getElementsByType(elemType)
      if elemType == "player" then
        return { localPlayer, "player2", "player3", "player4" }
      elseif elemType == "ped" then
        return { "ped1" }
      end
      return {}
    end

    function isTimer(t)
      return t ~= nil and timers[t] ~= nil
    end

    function setTimer(fn, interval, count)
      timerIdCounter = timerIdCounter + 1
      local id = "timer_" .. timerIdCounter
      timers[id] = { fn = fn, interval = interval, count = count }
      return id
    end

    function killTimer(id)
      timers[id] = nil
    end

    function destroyElement() end
    function dxCreateShader() return "shader" end
    function dxCreateRenderTarget() return "rt" end
    function dxSetRenderTarget() end
    function dxSetBlendMode() end
    function dxDrawImage() end
    function dxSetShaderValue() end
    function engineApplyShaderToWorldTexture() return true end
    function engineRemoveShaderFromWorldTexture() end
    function engineGetModelTextureNames() return {} end
    function getElementModel() return 0 end
    function fileExists() return false end
    function outputConsole() end

    CreatorConfig = { HairColors = {} }
    function resolveCreatorConfig() return { torso = {}, legs = {}, shoes = {}, hairs = {}, accessories = {} } end
    function applyCreatorOutfitModel() return true end
    function getCreatorOutfit() return nil end
  `;

  if (lauxlib.luaL_dostring(L, to_luastring(testScript)) !== lua.LUA_OK) {
    throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  }

  // Load actual shaders.lua
  const shadersSource = fs.readFileSync(path.join(__dirname, '../../gzl_creator/client/shaders.lua'), 'utf8');
  if (lauxlib.luaL_dostring(L, to_luastring(shadersSource)) !== lua.LUA_OK) {
    throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  }

  // Run simulation assertions
  const simulation = `
    -- Intercept applyCharacterCustomization
    local originalApply = applyCharacterCustomization
    local appliedLog = {}
    applyCharacterCustomization = function(ped, data)
      table.insert(appliedLog, ped)
      return originalApply(ped, data)
    end

    -- Trigger onClientRestore
    for _, fn in ipairs(events["onClientRestore"]) do
      fn()
    end

    -- ASSERT 1: localPlayer MUST be restored IMMEDIATELY on frame 0
    assert(#appliedLog == 1, "localPlayer must be restored immediately, got count: " .. #appliedLog)
    assert(appliedLog[1] == localPlayer, "First restored must be localPlayer")

    -- ASSERT 2: Queue timer must be active
    local timerCount = 0
    local activeTimer = nil
    for id, t in pairs(timers) do
      timerCount = timerCount + 1
      activeTimer = t
    end
    assert(timerCount == 1, "Expected 1 active queue timer, found: " .. timerCount)

    -- Advance tick 1 (50ms) -> player2 processed
    activeTimer.fn()
    assert(#appliedLog == 2, "Expected 2 players restored after tick 1")
    assert(appliedLog[2] == "player2", "Expected player2 restored")

    -- Test player3 quits while in queue
    source = "player3"
    for _, fn in ipairs(events["onClientPlayerQuit"]) do fn() end

    -- Advance tick 2 (50ms) -> player4 processed (player3 was evicted!)
    activeTimer.fn()
    assert(#appliedLog == 3, "Expected 3 players restored after tick 2")
    assert(appliedLog[3] == "player4", "Expected player4 restored, player3 was skipped")

    -- Test ped1 streams out while in queue
    source = "ped1"
    for _, fn in ipairs(events["onClientElementStreamOut"]) do fn() end

    -- Advance tick 3 -> queue should be empty, timer killed
    activeTimer.fn()
    assert(#appliedLog == 3, "No more players should be restored")
    local remainingTimers = 0
    for _ in pairs(timers) do remainingTimers = remainingTimers + 1 end
    assert(remainingTimers == 0, "Timer must be killed when queue becomes empty")

    -- Test second Alt-Tab while queue is running
    appliedLog = {}
    for _, fn in ipairs(events["onClientRestore"]) do fn() end
    assert(#appliedLog == 1 and appliedLog[1] == localPlayer, "localPlayer restored immediately on 2nd Alt-Tab")

    -- Second Alt-Tab immediately before queue finishes
    for _, fn in ipairs(events["onClientRestore"]) do fn() end
    assert(#appliedLog == 2 and appliedLog[2] == localPlayer, "localPlayer restored immediately on 3rd Alt-Tab")
    remainingTimers = 0
    for _ in pairs(timers) do remainingTimers = remainingTimers + 1 end
    assert(remainingTimers == 1, "Should have exactly 1 active timer after rapid Alt-Tab, no leaks")

    print("[PASS] gzl_creator shaders.lua staggering queue simulation");
  `;

  if (lauxlib.luaL_dostring(L, to_luastring(simulation)) !== lua.LUA_OK) {
    throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  }
  lua.lua_close(L);
}

// 3. Test gzl_inventory toggleInventory + minimize/restore race conditions
{
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);

  const prelude = `
    root, resourceRoot, localPlayer = "root", "resourceRoot", "localPlayer"
    events, timers, pauseCalls = {}, {}, {}
    timerCounter = 0
    function addEvent() end
    function addEventHandler(name, element, fn)
      if not events[name] then events[name] = {} end
      table.insert(events[name], fn)
    end
    function removeEventHandler() end
    function guiGetScreenSize() return 1920, 1080 end
    function bindKey() end
    function getResourceFromName() return nil end
    function isElement(e) return e ~= nil end
    function guiCreateBrowser() return "browserElem" end
    function guiGetBrowser() return "browser" end
    function guiSetVisible() end
    function guiSetInputMode() end
    function guiBringToFront() end
    function focusBrowser() end
    function showCursor() end
    function setElementData() end
    function getElementData() return 1 end
    function isMainMenuActive() return false end
    function triggerServerEvent() end
    function getTickCount() return 1000 end
    function setBrowserRenderingPaused(b, paused) table.insert(pauseCalls, paused) end
    function isTimer(t) return t ~= nil and timers[t] ~= nil end
    function setTimer(fn, interval, count)
      timerCounter = timerCounter + 1
      local id = "timer_" .. timerCounter
      timers[id] = fn
      return id
    end
    function killTimer(t) timers[t] = nil end
    function toJSON() return "{}" end
    function executeBrowserJavascript() end
    exports = { gzl_ui = { isProgressBarActive = function() return false end } }
  `;

  const invSource = fs.readFileSync(path.join(__dirname, '../../gzl_inventory/client/main.lua'), 'utf8');

  if (lauxlib.luaL_dostring(L, to_luastring(prelude + '\n' + invSource)) !== lua.LUA_OK) {
    throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  }

  const testInv = `
    -- Start resource
    for _, fn in ipairs(events["onClientResourceStart"]) do fn() end
    -- Browser ready callback
    for _, fn in ipairs(events["ox_inventory:onNuiCallback"]) do fn("uiLoaded", "{}") end

    -- Open inventory
    pauseCalls = {}
    toggleInventory(true)
    assert(pauseCalls[#pauseCalls] == false, "Opening inventory unpauses browser")

    -- Minimize game
    for _, fn in ipairs(events["onClientMinimize"]) do fn() end
    assert(pauseCalls[#pauseCalls] == true, "Minimizing pauses browser rendering")

    -- User restores (Alt-Tab return)
    for _, fn in ipairs(events["onClientRestore"]) do fn() end
    assert(pauseCalls[#pauseCalls] == true, "Restoring does NOT unpause immediately")

    -- CRITICAL TEST: Player presses F2 / calls toggleInventory(true) during 500ms restore delay!
    -- This MUST NOT unpause browser prematurely!
    toggleInventory(true)
    assert(pauseCalls[#pauseCalls] == true, "toggleInventory during restore delay MUST NOT unpause browser!")

    -- Timer expires at 500ms
    local restoreTimer = nil
    for id, fn in pairs(timers) do restoreTimer = fn end
    assert(restoreTimer ~= nil, "Expected pending restore timer")
    restoreTimer()
    assert(pauseCalls[#pauseCalls] == false, "Browser safely unpauses after 500ms delay")

    print("[PASS] gzl_inventory CEF pause/restore and toggleInventory protection");
  `;

  if (lauxlib.luaL_dostring(L, to_luastring(testInv)) !== lua.LUA_OK) {
    throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  }
  lua.lua_close(L);
}

// 4. Test gzl_hud bottom_hud SVG cache, rounding, and signal icon update
{
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);

  const prelude = `
    events, timers = {}, {}
    root = "root"
    resourceRoot = "resourceRoot"
    localPlayer = "localPlayer"
    function guiGetScreenSize() return 1920, 1080 end
    function getTickCount() return 1000 end
    function fileExists() return false end
    function getPlayerPing() return 40 end
    function getElementData() return 1 end
    function getNetworkStats() return { packetlossLastSecond = 0 } end
    function dxGetTextWidth() return 30 end
    function isElement(e) return e ~= nil and e ~= false end

    createdSvgs = 0
    destroyedSvgs = 0
    function svgCreate(w, h, data)
      createdSvgs = createdSvgs + 1
      return { id = createdSvgs, w = w, h = h }
    end
    function destroyElement(e)
      destroyedSvgs = destroyedSvgs + 1
    end
    function addEventHandler(name, _, fn)
      events[name] = fn
    end
    function setTimer(fn, interval, count)
      timers[fn] = true
    end
    function addCommandHandler() end
    exports = {}
  `;

  const bottomHudSource = fs.readFileSync(path.join(__dirname, '../../gzl_hud/client/bottom_hud.lua'), 'utf8');

  const testSvg = `
    -- Start resource
    events["onClientResourceStart"]()
    local initialCreated = createdSvgs

    -- Test width fluctuation step-rounding
    -- Widths 181, 182, 183, 184 all round to 184 -> 0 new SVG allocations
    local pill1 = getGlassPillSVG(181, 26, 7)
    local pill2 = getGlassPillSVG(182, 26, 7)
    local pill3 = getGlassPillSVG(184, 26, 7)
    assert(pill1 == pill2 and pill2 == pill3, "Step rounding must reuse same SVG for 181-184px")
    assert(createdSvgs == initialCreated + 1, "Zero new allocations for 1-3px width fluctuations")

    -- Width jumps to 192 (new multiple of 4)
    local pill4 = getGlassPillSVG(192, 26, 7)
    assert(pill4 ~= pill1, "New width allocates new SVG")
    assert(destroyedSvgs >= 1, "Old SVG must be destroyed via destroyElement")

    -- Test signal icon dynamic update when ping changes
    getPlayerPing = function() return 150 end -- High ping -> poor state
    -- Trigger updatePingAndNetwork
    for fn in pairs(timers) do fn() end
    assert(lastPingState == "poor", "lastPingState must update to poor, got: " .. tostring(lastPingState))

    getPlayerPing = function() return 75 end -- Medium ping -> medium state
    for fn in pairs(timers) do fn() end
    assert(lastPingState == "medium", "lastPingState must update to medium, got: " .. tostring(lastPingState))

    getPlayerPing = function() return 25 end -- Low ping -> good state
    for fn in pairs(timers) do fn() end
    assert(lastPingState == "good", "lastPingState must update to good, got: " .. tostring(lastPingState))

    print("[PASS] gzl_hud bottom_hud SVG rounding and signal icon updates");
  `;

  if (lauxlib.luaL_dostring(L, to_luastring(prelude + '\n' + bottomHudSource + '\n' + testSvg)) !== lua.LUA_OK) {
    throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
  }
  lua.lua_close(L);
}

console.log('--- ALL VERIFICATION TESTS PASSED SUCCESSFULLY ---');
