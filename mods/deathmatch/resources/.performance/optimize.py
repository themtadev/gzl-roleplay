from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parent.parent
BACKUP = ROOT / '.performance' / 'before'

def edit(name, transform):
    path = ROOT / name
    raw = path.read_bytes()
    text = raw.decode('utf-8-sig').replace('\r\n', '\n')
    result = transform(text)
    assert result != text, name
    backup = BACKUP / name
    backup.parent.mkdir(parents=True, exist_ok=True)
    if not backup.exists():
        backup.write_bytes(raw)
    newline = '\r\n' if b'\r\n' in raw else '\n'
    path.write_bytes((b'\xef\xbb\xbf' if raw.startswith(b'\xef\xbb\xbf') else b'') + result.replace('\n', newline).encode('utf-8'))

def replace(text, old, new):
    assert text.count(old) == 1, old[:100]
    return text.replace(old, new, 1)

def radar(text):
    text = replace(text, 'local function getActiveMtaBlips(pDim, pInt)\n    local list = {}', '''-- Refresh metadata at 10 Hz; moving blip positions remain frame accurate.
local blipCache, blipCacheTick, blipCacheDim, blipCacheInt = {}, nil, nil, nil
local function getActiveMtaBlips(pDim, pInt)
    local now = getTickCount()
    if blipCacheTick and now >= blipCacheTick and now - blipCacheTick < 100
        and pDim == blipCacheDim and pInt == blipCacheInt then
        for i = #blipCache, 1, -1 do
            local entry = blipCache[i]
            if isElement(entry.element) and getElementDimension(entry.element) == pDim
                and getElementInterior(entry.element) == pInt then
                entry.x, entry.y, entry.z = getElementPosition(entry.element)
            else
                table.remove(blipCache, i)
            end
        end
        return blipCache
    end
    local list = {}''')
    return replace(text, '    return list\nend\n\nlocal function loadTablerIcon', '    blipCache, blipCacheTick, blipCacheDim, blipCacheInt = list, now, pDim, pInt\n    return list\nend\n\nlocal function loadTablerIcon')

edit('gzl_radar/client/main.lua', radar)

for name in ['gzl_radar/client/main.lua', 'gzl_map/client/gui.lua']:
    def counts(text):
        text = replace(text, 'local screenW, screenH = guiGetScreenSize()', '''local screenW, screenH = guiGetScreenSize()
local playerCountTick, playerCount = nil, 0
local function getCachedPlayerCount()
    local now = getTickCount()
    if not playerCountTick or now < playerCountTick or now - playerCountTick >= 1000 then
        playerCount = #getElementsByType("player")
        playerCountTick = now
    end
    return playerCount
end''')
        return replace(text, 'tostring(#getElementsByType("player"))', 'tostring(getCachedPlayerCount())')
    edit(name, counts)

def idle(text):
    text = replace(text, 'addEventHandler("onClientPreRender", root, function()\n    local isMoving', 'setTimer(function()\n    local isMoving')
    return replace(text, 'end)\n\naddEventHandler("onClientKey", root, function()', 'end, 100, 0)\n\naddEventHandler("onClientKey", root, function()')
edit('gzl_animations/client/main.lua', idle)

def neon(text):
    text = replace(text, '    end\nend\n\nlocal function removeVehicleNeon', '''    else
        if isElement(m1) then destroyElement(m1) end
        if isElement(m2) then destroyElement(m2) end
    end
end

local function removeVehicleNeon''')
    return replace(text, '    local neonData = getElementData(veh, "veh:neon")', '''    if not isElementStreamedIn(veh) then
        removeVehicleNeon(veh)
        return
    end
    local neonData = getElementData(veh, "veh:neon")''')
edit('gzl_mechanic/client/neon.lua', neon)

def materials(text):
    for key, value in [('gSunDir', '0.0, 0.0, 1.0'), ('gSunColor', '0.95, 0.96, 1.0'), ('gAmbientColor', '0.45, 0.46, 0.50')]:
        text = replace(text, f'        dxSetShaderValue(interiorFixtureShader, "{key}", {value})\n', '')
        marker = '            dxSetShaderValue(interiorFixtureShader, "gClearcoatStrength", 0.12)'
        text = replace(text, marker, marker + f'\n            dxSetShaderValue(interiorFixtureShader, "{key}", {value})')
    return text
edit('gzl_atmosphere/client/materials.lua', materials)
print('Optimized 6 Lua files; originals in', BACKUP)
