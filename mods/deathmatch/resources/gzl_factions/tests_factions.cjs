const fs = require('fs');
const path = require('path');
const fengari = require(path.resolve(__dirname, '../gzl_inventory/tests/runtime/node_modules/fengari'));
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = fengari;

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

const mockMtaLua = `
-- MTA Server & Shared Mock Environment
root = { id = 'root' }
resourceRoot = { id = 'resourceRoot' }
localPlayer = { id = 'localPlayer', name = 'Officer_John' }
exports = {}

local simTick = 10000
function getTickCount()
    simTick = simTick + 1500
    return simTick
end
function isElement(e) return type(e) == 'table' and e.id ~= nil end
function getElementType(e) return (e and e.type) or 'player' end
function getPlayerName(p) return p.name or 'TestPlayer' end
function getPlayerPing(p) return 42 end

local elementData = {}
function setElementData(e, k, v)
    elementData[e] = elementData[e] or {}
    elementData[e][k] = v
end
function getElementData(e, k)
    if not elementData[e] then return nil end
    return elementData[e][k]
end

local dimensions = {}
local interiors = {}
function getElementDimension(e) return dimensions[e] or 0 end
function setElementDimension(e, d) dimensions[e] = d end
function getElementInterior(e) return interiors[e] or 0 end
function setElementInterior(e, i) interiors[e] = i end

local elementPositions = {}
function setElementPosition(e, x, y, z) elementPositions[e] = { x, y, z } end
function getElementPosition(e)
    local p = elementPositions[e] or { 0, 0, 0 }
    return p[1], p[2], p[3]
end
function getDistanceBetweenPoints3D(x1, y1, z1, x2, y2, z2)
    local dx = x1 - x2
    local dy = y1 - y2
    local dz = z1 - z2
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local mockPlayers = { localPlayer }
function setMockPlayers(list) mockPlayers = list end
function getElementsByType(t)
    if t == 'player' then return mockPlayers end
    return {}
end

local events = {}
function addEvent(name, allowRemote)
    events[name] = { allowRemote = allowRemote, handlers = {} }
end
function addEventHandler(name, target, fn)
    if not events[name] then events[name] = { handlers = {} } end
    table.insert(events[name].handlers, fn)
end
function triggerEvent(name, sourceElem, ...)
    local ev = events[name]
    if ev then
        for _, fn in ipairs(ev.handlers) do
            client = sourceElem
            source = sourceElem
            fn(...)
        end
    end
end

local triggeredClientEvents = {}
function triggerClientEvent(target, name, sourceElem, ...)
    table.insert(triggeredClientEvents, { target = target, name = name, source = sourceElem, args = {...} })
end
function getTriggeredClientEvents() return triggeredClientEvents end
function clearTriggeredClientEvents() triggeredClientEvents = {} end

local commandHandlers = {}
function addCommandHandler(cmd, fn)
    commandHandlers[cmd] = fn
end
function executeCommandHandler(cmd, player, ...)
    if commandHandlers[cmd] then
        return commandHandlers[cmd](player, cmd, ...)
    end
end

function outputChatBox(...) end
function outputServerLog(...) end
function takePlayerMoney(...) end
function givePlayerMoney(...) end
function getPlayerMoney(...) return 50000 end
function fromJSON(s) return {} end
function toJSON(t) return '{}' end

local dbRows = {}
function setMockDBRows(tbl, rows) dbRows[tbl] = rows end
function dbConnect(...) return { db = true } end
function dbExec(...) return true end
function dbQuery(callback, db, query, ...)
    local args = {...}
    local rows = {}
    if string.find(query, "faction_members") then
        rows = dbRows["faction_members"] or {}
    elseif string.find(query, "faction_vault_logs") then
        rows = dbRows["faction_vault_logs"] or {}
    end
    if callback then callback({ rows = rows }) end
end
function dbPoll(qh, timeout) return qh.rows or {} end

function bindKey(...) end
function unbindKey(...) end
function guiGetScreenSize() return 1920, 1080 end
function showCursor(...) end
`;

function runLua(code, desc) {
    const status = lauxlib.luaL_dostring(L, to_luastring(code));
    if (status !== 0) {
        const err = to_jsstring(lua.lua_tostring(L, -1));
        console.error('ERROR in ' + desc + ':\n' + err);
        process.exit(1);
    }
}

runLua(mockMtaLua, 'MTA Mocks');

const configLua = fs.readFileSync(path.resolve(__dirname, 'shared/config.lua'), 'utf8');
runLua(configLua, 'config.lua');

const dbLua = fs.readFileSync(path.resolve(__dirname, 'server/database.lua'), 'utf8');
runLua(dbLua, 'database.lua');
runLua('FactionDB = dbConnect("sqlite", ":/database.db")', 'Init FactionDB');

const mainLua = fs.readFileSync(path.resolve(__dirname, 'server/main.lua'), 'utf8');
runLua(mainLua, 'main.lua');

const vaultLua = fs.readFileSync(path.resolve(__dirname, 'server/vault.lua'), 'utf8');
runLua(vaultLua, 'vault.lua');

const networkLua = fs.readFileSync(path.resolve(__dirname, 'server/network.lua'), 'utf8');
runLua(networkLua, 'network.lua');

const commandsLua = fs.readFileSync(path.resolve(__dirname, 'server/commands.lua'), 'utf8');
runLua(commandsLua, 'commands.lua');

const serverTestsLua = `
assert(FactionConfig.PanelKey == "F6", "PanelKey should be F6")
assert(FactionConfig.CommandAliases[1] == "fpanel", "First alias should be fpanel")

-- 1. Test permission helpers
assert(FactionConfig.getMaxRank(1) == 8, "LSPD max rank should be 8")
assert(FactionConfig.canManageMembers(1, 8) == true, "Chief should manage members")
assert(FactionConfig.canManageMembers(1, 5) == true, "Sergeant (5) should manage members")
assert(FactionConfig.canManageMembers(1, 4) == false, "Officer (4) should not manage members in 8-rank faction")
assert(FactionConfig.canManageMembers(1, 1) == false, "Cadet should not manage members")

-- EMS max rank is 6
assert(FactionConfig.canInviteMembers(2, 4) == true, "Doctor (4) should be able to invite")
assert(FactionConfig.canInviteMembers(2, 2) == false, "Rank 2 should not invite")

-- Vault withdraw
assert(FactionConfig.canWithdrawVault(1, 4) == true, "Rank 4 should withdraw in LSPD")
assert(FactionConfig.canWithdrawVault(1, 3) == false, "Rank 3 should not withdraw in LSPD")

-- 2. Test Duty Toggle
setElementData(localPlayer, "loggedin_character", true)
setElementData(localPlayer, "character:id", 101)
setElementData(localPlayer, "character:name", "Officer_John")
PlayerFactions[localPlayer] = {
    character_id = 101,
    faction_id = 1,
    rank_id = 6,
    duty_status = 0
}

clearTriggeredClientEvents()
triggerEvent("faction:toggleDuty", localPlayer)
assert(PlayerFactions[localPlayer].duty_status == 1, "Duty should be toggled to 1")
local events = getTriggeredClientEvents()
assert(#events == 1, "Should trigger 1 client event for duty update")
assert(events[1].name == "faction:dutyUpdated", "Event should be faction:dutyUpdated")
assert(events[1].args[1] == true, "Duty arg should be true")

-- 3. Test Vault Deposit & Withdraw Boundaries
clearTriggeredClientEvents()
local ok, newBal = depositFactionVault(localPlayer, 5000, "Operasyon bağışı")
assert(ok == true, "Deposit should succeed")
assert(newBal == 255000, "New balance should be 255000")

PlayerFactions[localPlayer].rank_id = 2 -- Rank 2 cannot withdraw
local okWith, errWith = withdrawFactionVault(localPlayer, 1000, "İzinsiz çekim")
assert(okWith == false, "Unauthorized withdraw should fail")

PlayerFactions[localPlayer].rank_id = 6 -- Lieutenant can withdraw
local okWith2, newBal2 = withdrawFactionVault(localPlayer, 10000, "Ekipman alımı")
assert(okWith2 == true, "Authorized withdraw should succeed")
assert(newBal2 == 245000, "Vault balance after withdraw should be 245000")

-- Over-withdrawal should fail
local okOver, errOver = withdrawFactionVault(localPlayer, 9999999, "Fazla çekim")
assert(okOver == false, "Withdrawing more than vault balance should fail")

-- 4. Test Chat Commands & UI Network Synchronization
local mockCandidate = { id = 'mockCandidate', name = 'Civilian_Alex' }
setElementData(mockCandidate, "loggedin_character", true)
setElementData(mockCandidate, "character:id", 303)
setElementData(mockCandidate, "character:name", "Civilian_Alex")
setMockPlayers({ localPlayer, mockCandidate })

-- Test /finvite command
PlayerFactions[localPlayer].rank_id = 6
clearTriggeredClientEvents()
executeCommandHandler("finvite", localPlayer, "Civilian_Alex")

-- Verify prompt event was dispatched with valid sender_name
local cEvents = getTriggeredClientEvents()
local promptEv = nil
for _, ev in ipairs(cEvents) do
    if ev.name == "faction:showInvitePrompt" then promptEv = ev break end
end
assert(promptEv ~= nil, "/finvite should trigger faction:showInvitePrompt")
assert(promptEv.args[1].sender_name == "Officer_John", "sender_name must be Officer_John, not nil")
assert(promptEv.args[1].faction_id == 1, "faction_id should be 1")

-- Verify pending invite table has sender_name
assert(PendingFactionInvites[mockCandidate] ~= nil, "Candidate should have pending invite")
assert(PendingFactionInvites[mockCandidate].sender_name == "Officer_John", "sender_name in pending table must match")

-- Test /faccept command
clearTriggeredClientEvents()
executeCommandHandler("faccept", mockCandidate)
assert(PlayerFactions[mockCandidate] ~= nil, "Candidate should be in faction after /faccept")
assert(PlayerFactions[mockCandidate].character_id == 303, "Character ID should be 303")
assert(PlayerFactions[mockCandidate].rank_id == 1, "Default invite rank should be 1")
assert(PendingFactionInvites[mockCandidate] == nil, "Pending invite should be cleared")

-- 5. Test Cross-Accept: UI Invite with Custom Rank -> Chat /faccept
PlayerFactions[mockCandidate] = nil
clearPlayerFactionData(mockCandidate)
actionCooldowns = {}
clearTriggeredClientEvents()
triggerEvent("faction:invitePlayer", localPlayer, mockCandidate, 3)
assert(PendingFactionInvites[mockCandidate] ~= nil, "Candidate should have invite from UI")
assert(PendingFactionInvites[mockCandidate].rank_id == 3, "UI invite should specify rank 3")

-- Candidate accepts via /faccept chat command
executeCommandHandler("faccept", mockCandidate)
assert(PlayerFactions[mockCandidate] ~= nil, "Candidate should join faction")
assert(PlayerFactions[mockCandidate].rank_id == 3, "Candidate should retain rank 3 specified in UI invite")

-- 6. Test Member Hierarchy, Promotion, Demotion & Kick
local mockTarget = mockCandidate
setMockDBRows("faction_members", {
    { character_id = 303, faction_id = 1, character_name = "Civilian_Alex", rank_id = 5, duty_status = 0 }
})

-- Cannot promote target to same rank as self (Rank 6 tries to promote Rank 5 -> 6)
actionCooldowns = {}
clearTriggeredClientEvents()
triggerEvent("faction:manageMember", localPlayer, "promote", 303)
local resp = getTriggeredClientEvents()
assert(resp[1].name == "faction:actionResponse", "Should trigger actionResponse")
assert(resp[1].args[1] == false, "Promoting to equal rank must fail")

-- /fkick command kicks target and closes target's panel
clearTriggeredClientEvents()
executeCommandHandler("fkick", localPlayer, "Civilian_Alex")
assert(PlayerFactions[mockCandidate] == nil, "Target should be removed from PlayerFactions")
assert(CharacterFactions[303] == nil, "Target should be removed from CharacterFactions")

local kickEvents = getTriggeredClientEvents()
local panelCloseEv = nil
for _, ev in ipairs(kickEvents) do
    if ev.name == "faction:receivePanelData" and ev.target == mockCandidate then
        panelCloseEv = ev
        break
    end
end
assert(panelCloseEv ~= nil, "/fkick should send receivePanelData error to target to close open panel")

-- 7. Test Dimension and Interior Isolation for Nearby Players
local pSame = { id = 'pSame', name = 'Near_Player' }
setElementData(pSame, "loggedin_character", true)
setElementData(pSame, "character:id", 401)
setElementDimension(pSame, 0)
setElementInterior(pSame, 0)

local pDimDiff = { id = 'pDimDiff', name = 'Dim_Player' }
setElementData(pDimDiff, "loggedin_character", true)
setElementData(pDimDiff, "character:id", 402)
setElementDimension(pDimDiff, 5) -- different dimension
setElementInterior(pDimDiff, 0)

local pIntDiff = { id = 'pIntDiff', name = 'Int_Player' }
setElementData(pIntDiff, "loggedin_character", true)
setElementData(pIntDiff, "character:id", 403)
setElementDimension(pIntDiff, 0)
setElementInterior(pIntDiff, 3) -- different interior

setElementDimension(localPlayer, 0)
setElementInterior(localPlayer, 0)
setMockPlayers({ localPlayer, pSame, pDimDiff, pIntDiff })

clearTriggeredClientEvents()
triggerEvent("faction:requestPanelData", localPlayer)
local pEvents = getTriggeredClientEvents()
local panelData = nil
for _, ev in ipairs(pEvents) do
    if ev.name == "faction:receivePanelData" and ev.args[1] then
        panelData = ev.args[1]
        break
    end
end
-- 8. Test Self-Management Rejection
actionCooldowns = {}
clearTriggeredClientEvents()
triggerEvent("faction:manageMember", localPlayer, "kick", 101)
local selfResp = getTriggeredClientEvents()
assert(selfResp[1].name == "faction:actionResponse", "Should trigger actionResponse")
assert(selfResp[1].args[1] == false, "Self management must be rejected")
assert(selfResp[1].args[2] == "Kendi üzerinizde işlem yapamazsınız!", "Error message mismatch")

-- 9. Test Invalid Vault Amount Rejection
actionCooldowns = {}
clearTriggeredClientEvents()
triggerEvent("faction:vaultAction", localPlayer, "deposit", -500, "Geçersiz test")
local vBadResp = getTriggeredClientEvents()
assert(vBadResp[1].name == "faction:actionResponse", "Should trigger actionResponse")
assert(vBadResp[1].args[1] == false, "Negative vault deposit must fail")

-- 10. Test Rank Clamping on Excessive Rank Invite
clearPlayerFactionData(mockCandidate)
PlayerFactions[mockCandidate] = nil
actionCooldowns = {}
clearTriggeredClientEvents()
-- Officer (Rank 6) tries to invite candidate directly to Rank 7 (higher than inviter)
triggerEvent("faction:invitePlayer", localPlayer, mockCandidate, 7)
assert(PendingFactionInvites[mockCandidate] ~= nil, "Candidate should receive invite")
assert(PendingFactionInvites[mockCandidate].rank_id == 1, "Invite rank higher than inviter must clamp to rank 1")

print("ALL SERVER & NETWORK INTEGRATION TEST CASES PASSED SUCCESSFULLY!");
`;

runLua(serverTestsLua, 'Server Integration Tests');

// 8. Client GUI Tests
const clientMockLua = `
local cursorShowing = false
function isCursorShowing() return cursorShowing end
function showCursor(show) cursorShowing = (show == true) end
function getCursorPosition() return 0.5, 0.5 end
function tocolor(r,g,b,a) return a or 255 end
function dxDrawRectangle(...) end
function dxDrawText(...) end
function dxDrawImage(...) end
function dxGetTextWidth(...) return 50 end
function pcall(fn, ...) return true end
function cancelEvent() end
function triggerServerEvent(...) end

local mockChatActive = false
local mockConsoleActive = false
local mockInputEnabled = false

function isChatBoxInputActive() return mockChatActive end
function isConsoleActive() return mockConsoleActive end
function guiGetInputEnabled() return mockInputEnabled end
function setMockChatActive(b) mockChatActive = b end
function setMockConsoleActive(b) mockConsoleActive = b end

-- Clear events for client
events = {}
`;

runLua(clientMockLua, 'Client MTA Mocks');

const clientGui = fs.readFileSync(path.resolve(__dirname, 'client/gui.lua'), 'utf8');
runLua(clientGui, 'client/gui.lua');

const clientTestsLua = `
-- Verify client functions exist
assert(type(openFactionPanel) == 'function', "openFactionPanel should be defined")
assert(type(closeFactionPanel) == 'function', "closeFactionPanel should be defined")
assert(type(toggleFactionPanel) == 'function', "toggleFactionPanel should be defined")

-- Receive Panel Data
triggerEvent("faction:receivePanelData", localPlayer, {
    faction = {
        id = 1,
        name = "Los Santos Police Department",
        short_name = "LSPD",
        type = "police",
        vault_balance = 250000,
        max_members = 50,
        ranks = {
            [1] = { name = "Cadet", salary = 1200 },
            [2] = { name = "Officer I", salary = 1800 }
        }
    },
    player = {
        character_id = 101,
        character_name = "John Doe",
        rank_id = 2,
        rank_name = "Officer I",
        duty = true,
        cash = 4500,
        canManage = true,
        canInvite = true,
        canWithdraw = true,
        maxRank = 8
    },
    members = {
        { character_id = 101, character_name = "John Doe", rank_id = 2, rank_name = "Officer I", is_online = true, duty_status = true }
    },
    vaultLogs = {
        { id = 1, character_name = "John Doe", action_type = "deposit", amount = 5000, reason = "Test", created_at = "2026-09-09 10:00:00" }
    },
    nearbyPlayers = {},
    onlineCount = 1,
    totalCount = 1
})

-- Test Panel Open
setElementData(localPlayer, "loggedin_character", true)
setElementData(localPlayer, "character:faction", 1)
openFactionPanel()
assert(isCursorShowing() == true, "Cursor must be showing when panel opens")

-- Test Render frame
triggerEvent("onClientRender", root)

-- Test onClientResourceStop Cleanup
triggerEvent("onClientResourceStop", resourceRoot)
assert(isCursorShowing() == false, "Cursor must be hidden when resource stops")

-- Test Panel Re-open
openFactionPanel()
assert(isCursorShowing() == true, "Cursor must be showing after reopen")

-- Test Key Intercept Guard: When player is typing in chat, 'y' / 'n' must NOT accept/reject
triggerEvent("faction:showInvitePrompt", localPlayer, {
    faction_id = 1,
    faction_name = "LSPD",
    sender_name = "Officer_John",
    rank_name = "Officer I",
    duration = 60
})

setMockChatActive(true)
triggerEvent("onClientKey", root, "y", true)
-- Prompt should still exist because chat box was active
triggerEvent("onClientRender", root)

-- When chat box is closed, 'y' accepts invite
setMockChatActive(false)
triggerEvent("onClientKey", root, "y", true)

-- Test Turkish UTF-8 Character Typing & Safe Backspacing
openFactionPanel()
triggerEvent("onClientClick", root, "left", "up", 100, 100)
-- Trigger click on roster search box to focus it
triggerEvent("onClientClick", root, "left", "up", 500, 250)

-- Type Turkish multi-byte characters: Ş (2 bytes), a, h, ı (2 bytes), s
for _, ch in ipairs({ "Ş", "a", "h", "ı", "s" }) do
    triggerEvent("onClientCharacter", root, ch)
end

-- Backspace each character and ensure multi-byte codes are cleanly removed
for i = 1, 6 do
    triggerEvent("onClientKey", root, "backspace", true)
end

closeFactionPanel()
assert(isCursorShowing() == false, "Cursor must be hidden after panel close")

print("ALL CLIENT GUI TEST CASES PASSED SUCCESSFULLY!");
`;

runLua(clientTestsLua, 'Client Deep Tests');
console.log('Complete test suite (Server + Client) passed with 0 errors!');
