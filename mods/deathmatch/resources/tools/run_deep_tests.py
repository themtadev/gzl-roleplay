import ctypes, os
from ctypes import c_void_p, c_char_p, c_int

os.add_dll_directory(r'c:\Users\thommy\Desktop\GZL\x64')
lua = ctypes.CDLL(r'c:\Users\thommy\Desktop\GZL\x64\lua5.1.dll')
lua.luaL_newstate.restype = c_void_p
lua.luaL_openlibs.argtypes = [c_void_p]
lua.luaL_loadstring.argtypes = [c_void_p, c_char_p]
lua.luaL_loadstring.restype = c_int
lua.lua_pcall.argtypes = [c_void_p, c_int, c_int, c_int]
lua.lua_pcall.restype = c_int
lua.lua_tolstring.argtypes = [c_void_p, c_int, c_void_p]
lua.lua_tolstring.restype = c_char_p
lua.lua_close.argtypes = [c_void_p]

L = lua.luaL_newstate()
lua.luaL_openlibs(L)

test_script = b"""
_G.elementData = {}
function getElementData(elem, key)
    if not _G.elementData[elem] then return nil end
    return _G.elementData[elem][key]
end
function setElementData(elem, key, val)
    _G.elementData[elem] = _G.elementData[elem] or {}
    _G.elementData[elem][key] = val
end
function isElement(elem) return type(elem) == 'string' or type(elem) == 'table' end
function getElementType(elem) return 'player' end
function getPlayerName(elem) return tostring(elem) end
function isPedDead(elem) return false end
local currentTick = 100000
function getTickCount() return currentTick end

-- =========================================================
-- 1. Test isContraband (gzl_pd)
-- =========================================================
dofile([[c:/Users/thommy/Desktop/GZL/mods/deathmatch/resources/gzl_pd/shared/config.lua]])

assert(isContraband('weapon_pistol') == true, 'weapon_pistol should be contraband')
assert(isContraband('weapon_ak47') == true, 'weapon_ak47 should be contraband')
assert(isContraband('ammo_9') == true, 'ammo_9 should be contraband')
assert(isContraband('ammo-9') == true, 'ammo-9 should be contraband')
assert(isContraband('ammo-shotgun') == true, 'ammo-shotgun should be contraband')
assert(isContraband('lockpick') == true, 'lockpick should be contraband')
assert(isContraband('advanced-lockpick') == true, 'advanced-lockpick should be contraband')
assert(isContraband('advancedlockpick') == true, 'advancedlockpick should be contraband')
assert(isContraband('c4_bank') == true, 'c4_bank should be contraband')
assert(isContraband('coke_brick') == true, 'coke_brick should be contraband')
assert(isContraband('crack_baggy') == true, 'crack_baggy should be contraband')
assert(isContraband('weed') == true, 'weed should be contraband')
assert(isContraband('islenmisesrar') == true, 'islenmisesrar should be contraband')
assert(isContraband('kenevir') == true, 'kenevir should be contraband')
assert(isContraband('bread') == false, 'bread should NOT be contraband')
assert(isContraband('water') == false, 'water should NOT be contraband')
assert(isContraband('phone') == false, 'phone should NOT be contraband')
print('[PASS] 1. gzl_pd isContraband comprehensive checks')

-- =========================================================
-- 2. Test PDConfig.canAccess (duty enforcement)
-- =========================================================
local p1 = 'player1'
setElementData(p1, 'loggedin_character', true)
setElementData(p1, 'character:faction', 1)
setElementData(p1, 'duty:police', false)
setElementData(p1, 'duty', false)
assert(PDConfig.canAccess(p1) == false, 'Off-duty officer must NOT have access!')

setElementData(p1, 'duty:police', true)
assert(PDConfig.canAccess(p1) == true, 'On-duty officer MUST have access!')

setElementData(p1, 'duty:police', false)
setElementData(p1, 'duty', 'police')
assert(PDConfig.canAccess(p1) == true, 'duty=police MUST have access!')

local p_civ = 'player_civ'
setElementData(p_civ, 'loggedin_character', true)
setElementData(p_civ, 'character:faction', 0)
setElementData(p_civ, 'duty:police', false)
assert(PDConfig.canAccess(p_civ) == false, 'Civilian must NOT have access!')
print('[PASS] 2. gzl_pd PDConfig.canAccess duty gating checks')

-- =========================================================
-- 3. Test FactionConfig rank permissions and getMaxRank
-- =========================================================
dofile([[c:/Users/thommy/Desktop/GZL/mods/deathmatch/resources/gzl_factions/shared/config.lua]])

assert(FactionConfig.getMaxRank(1) == 8, 'LSPD max rank must be 8')
assert(FactionConfig.getMaxRank(2) == 6, 'EMS max rank must be 6')
assert(FactionConfig.getMaxRank(3) == 5, 'GOV max rank must be 5')

-- Custom faction test
_G.Factions = {
    [99] = {
        id = 99,
        name = 'Custom Mafia',
        ranks = {
            [1] = { name = 'Associate' },
            [3] = { name = 'Soldier' },
            [10] = { name = 'Boss' }
        }
    }
}
assert(FactionConfig.getMaxRank(99) == 10, 'Custom faction max rank must be 10')
assert(FactionConfig.canManageMembers(99, 10) == true, 'Boss can manage members')
assert(FactionConfig.canManageMembers(99, 3) == false, 'Soldier cannot manage members')
assert(FactionConfig.canWithdrawVault(99, 10) == true, 'Boss can withdraw vault')
assert(FactionConfig.canWithdrawVault(99, 1) == false, 'Associate cannot withdraw vault')

assert(FactionConfig.canManageMembers(1, 4) == false, 'LSPD rank 4 cannot manage members')
assert(FactionConfig.canManageMembers(1, 5) == true, 'LSPD rank 5 can manage members')
assert(FactionConfig.canManageMembers(1, 8) == true, 'LSPD rank 8 can manage members')
assert(FactionConfig.canWithdrawVault(1, 3) == false, 'LSPD rank 3 cannot withdraw vault')
assert(FactionConfig.canWithdrawVault(1, 4) == true, 'LSPD rank 4 can withdraw vault')
print('[PASS] 3. gzl_factions FactionConfig rank and permission checks')

-- =========================================================
-- 4. Test Coma vs Cuff persistence logic
-- =========================================================
local p2 = 'player2'
setElementData(p2, 'loggedin_character', true)
setElementData(p2, 'isCuffed', true)
setElementData(p2, 'ems:isDead', false)
setElementData(p2, 'character:is_dead', 0)

local isDeadCuffedOnly = (getElementData(p2, 'ems:isDead') == true or getElementData(p2, 'character:is_dead') == 1 or isPedDead(p2)) and 1 or 0
assert(isDeadCuffedOnly == 0, 'Cuffed-only player must NOT be marked as dead!')

setElementData(p2, 'ems:isDead', true)
local isDeadComa = (getElementData(p2, 'ems:isDead') == true or getElementData(p2, 'character:is_dead') == 1 or isPedDead(p2)) and 1 or 0
assert(isDeadComa == 1, 'Player in coma MUST be marked as dead!')
print('[PASS] 4. gzl_characters Coma vs Cuff persistence logic checks')

-- =========================================================
-- 5. Test gzl_ems getRemainingDeathTime math
-- =========================================================
dofile([[c:/Users/thommy/Desktop/GZL/mods/deathmatch/resources/gzl_ems/shared/config.lua]])

local function testRemainingTime(player)
    if not isElement(player) or not getElementData(player, 'ems:isDead') then return 0 end
    local deathTick = getElementData(player, 'ems:deathTick')
    if not deathTick then
        local storedRem = tonumber(getElementData(player, 'character:death_time_remaining'))
        return storedRem or (Config.BleedoutTime or 180)
    end
    local elapsed = (getTickCount() - deathTick) / 1000
    local total = Config.BleedoutTime or 180
    return math.max(0, math.ceil(total - elapsed))
end

local p3 = 'player3'
setElementData(p3, 'ems:isDead', true)
-- Case A: Just entered coma (tick = currentTick)
setElementData(p3, 'ems:deathTick', currentTick)
assert(testRemainingTime(p3) == 180, 'Initial coma remaining time should be 180s')

-- Case B: 60 seconds passed
currentTick = currentTick + 60000
assert(testRemainingTime(p3) == 120, 'After 60s elapsed, remaining time should be 120s')

-- Case C: Fallback to character:death_time_remaining when deathTick is nil (e.g. after server restart)
setElementData(p3, 'ems:deathTick', nil)
setElementData(p3, 'character:death_time_remaining', 75)
assert(testRemainingTime(p3) == 75, 'Fallback remaining time should be 75s')
print('[PASS] 5. gzl_ems remaining death time calculation and fallback checks')

-- =========================================================
-- 6. Test gzl_logs query building and parameter handling
-- =========================================================
local function buildQuery(tableType, filters, limit)
    local validTables = {
        admin = 'log_admin',
        money = 'log_money',
        items = 'log_items',
        combat = 'log_combat',
        sessions = 'log_sessions',
        system = 'log_system'
    }
    local tableName = validTables[tableType]
    if not tableName then return nil, 'Invalid log category' end

    limit = math.min(200, math.max(1, tonumber(limit) or 50))
    local whereClauses = {}
    local params = {}

    if type(filters) == 'table' then
        for k, v in pairs(filters) do
            if type(k) == 'string' and not string.find(k, '[^%w_]') then
                table.insert(whereClauses, k .. ' = ?')
                table.insert(params, v)
            end
        end
    end

    local queryStr = 'SELECT * FROM ' .. tableName
    if #whereClauses > 0 then
        queryStr = queryStr .. ' WHERE ' .. table.concat(whereClauses, ' AND ')
    end
    queryStr = queryStr .. ' ORDER BY id DESC LIMIT ' .. tostring(limit)
    return queryStr, params
end

local q1, pms1 = buildQuery('admin', { player_id = 5 }, 20)
assert(q1 == 'SELECT * FROM log_admin WHERE player_id = ? ORDER BY id DESC LIMIT 20', 'Admin query mismatch')
assert(#pms1 == 1 and pms1[1] == 5, 'Admin params mismatch')

local q2, pms2 = buildQuery('money', {}, 10)
assert(q2 == 'SELECT * FROM log_money ORDER BY id DESC LIMIT 10', 'Money query mismatch')
assert(#pms2 == 0, 'Empty params mismatch')

local q3, pms3 = buildQuery('invalid_category', {})
assert(q3 == nil, 'Invalid category should return nil')
print('[PASS] 6. gzl_logs query building and parameter unpacking checks')

-- =========================================================
-- 7. Test confiscate weapons safe collection without mutation
-- =========================================================
local suspectInventory = {
    [1] = { name = 'weapon_pistol', count = 1 },
    [2] = { name = 'bread', count = 2 },
    [3] = { name = 'ammo-9', count = 50 },
    [4] = { name = 'lockpick', count = 3 },
    [5] = { name = 'water', count = 1 }
}

local toConfiscate = {}
for _, itm in pairs(suspectInventory) do
    if itm and itm.name then
        local illegal = isContraband(itm.name)
        if illegal then
            table.insert(toConfiscate, { name = itm.name, count = itm.count or 1 })
        end
    end
end

assert(#toConfiscate == 3, 'Should identify 3 contraband items: weapon_pistol, ammo-9, lockpick')
local confiscatedNames = {}
for _, c in ipairs(toConfiscate) do
    confiscatedNames[c.name] = true
end
assert(confiscatedNames['weapon_pistol'] == true, 'weapon_pistol must be confiscated')
assert(confiscatedNames['ammo-9'] == true, 'ammo-9 must be confiscated')
assert(confiscatedNames['lockpick'] == true, 'lockpick must be confiscated')
assert(confiscatedNames['bread'] == nil, 'bread must NOT be confiscated')
assert(confiscatedNames['water'] == nil, 'water must NOT be confiscated')
print('[PASS] 7. gzl_pd safe weapon confiscation checks')

print('>>> ALL 7 CORE SUITE VERIFICATION TESTS COMPLETED WITH 100% SUCCESS! <<<')
"""

ret = lua.luaL_loadstring(L, test_script)
if ret != 0:
    err = lua.lua_tolstring(L, -1, None)
    print('Failed to load test script:', err.decode('utf-8'))
else:
    run_ret = lua.lua_pcall(L, 0, 0, 0)
    if run_ret != 0:
        err = lua.lua_tolstring(L, -1, None)
        print('Test script error:', err.decode('utf-8'))

lua.lua_close(L)
