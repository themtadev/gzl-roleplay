local isCustomSoundsEnabled = true
local previousWeapon = 0

addEventHandler("onClientResourceStart", resourceRoot, function()
    setWorldSoundEnabled(5, false, true)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    setWorldSoundEnabled(5, true)
end)

local function handleWeaponFire(weaponId, hitX, hitY, hitZ, hitElement)
    if not isCustomSoundsEnabled then
        return
    end

    local cfg = WeaponConfig[weaponId]
    if not cfg then
        return
    end

    local mx, my, mz
    if getPedWeaponMuzzlePosition then
        mx, my, mz = getPedWeaponMuzzlePosition(source)
    end
    if not mx then
        mx, my, mz = getElementPosition(source)
        mz = mz + 0.5
    end

    local px, py, pz = getElementPosition(localPlayer)
    local dist = getDistanceBetweenPoints3D(px, py, pz, mx, my, mz)

    if cfg.shoots and #cfg.shoots > 0 and dist <= (cfg.maxDist or 150) then
        local soundPath = cfg.shoots[math.random(1, #cfg.shoots)]
        local sound = playSound3D(soundPath, mx, my, mz, false)
        if sound then
            setSoundMaxDistance(sound, cfg.maxDist or 150)
            setSoundMinDistance(sound, 5)
            setSoundVolume(sound, cfg.volume or 1.0)
        end
    end

    if cfg.afters and #cfg.afters > 0 and dist >= (cfg.echoMinDist or 20) and dist <= (cfg.echoMaxDist or 350) then
        local echoPath = cfg.afters[math.random(1, #cfg.afters)]
        local echoSound = playSound3D(echoPath, mx, my, mz, false)
        if echoSound then
            setSoundMaxDistance(echoSound, cfg.echoMaxDist or 350)
            setSoundMinDistance(echoSound, 25)
            setSoundVolume(echoSound, 0.85)
        end
    end

    if hitX and hitY and hitZ and RicochetSounds and #RicochetSounds > 0 then
        local hitDist = getDistanceBetweenPoints3D(px, py, pz, hitX, hitY, hitZ)
        if hitDist <= 28 and dist >= 8 then
            local ricPath = RicochetSounds[math.random(1, #RicochetSounds)]
            local ricSound = playSound3D(ricPath, hitX, hitY, hitZ, false)
            if ricSound then
                setSoundMaxDistance(ricSound, 35)
                setSoundMinDistance(ricSound, 2)
                setSoundVolume(ricSound, 0.75)
            end
        end
    end
end

addEventHandler("onClientPlayerWeaponFire", root, handleWeaponFire)
addEventHandler("onClientPedWeaponFire", root, handleWeaponFire)

addEventHandler("onClientPlayerWeaponSwitch", localPlayer, function(prevSlot, newSlot)
    if not isCustomSoundsEnabled then
        return
    end

    local newWeapon = getPedWeapon(localPlayer, newSlot)
    local cfg = WeaponConfig[newWeapon]
    local px, py, pz = getElementPosition(localPlayer)

    if cfg and cfg.drawSound then
        local snd = playSound3D(cfg.drawSound, px, py, pz, false)
        if snd then
            setSoundMaxDistance(snd, 15)
            setSoundVolume(snd, 0.6)
        end
    elseif newWeapon == 0 and previousWeapon ~= 0 then
        local prevCfg = WeaponConfig[previousWeapon]
        if prevCfg and prevCfg.holsterSound then
            local snd = playSound3D(prevCfg.holsterSound, px, py, pz, false)
            if snd then
                setSoundMaxDistance(snd, 15)
                setSoundVolume(snd, 0.5)
            end
        end
    end

    previousWeapon = newWeapon
end)

addCommandHandler("weaponsounds", function()
    isCustomSoundsEnabled = not isCustomSoundsEnabled
    if isCustomSoundsEnabled then
        setWorldSoundEnabled(5, false, true)
        if exports.gzl_ui and exports.gzl_ui.showNotification then
            exports.gzl_ui:showNotification("NextGen Silah Sesleri: Aktif", "success")
        else
            outputChatBox("[GZL-SOUNDS] Ozel silah sesleri aktif edildi.", 0, 255, 120)
        end
    else
        setWorldSoundEnabled(5, true)
        if exports.gzl_ui and exports.gzl_ui.showNotification then
            exports.gzl_ui:showNotification("NextGen Silah Sesleri: Devre Disi", "info")
        else
            outputChatBox("[GZL-SOUNDS] Ozel silah sesleri devre disi birakildi.", 255, 180, 0)
        end
    end
end)

addCommandHandler("silahsesi", function()
    executeCommandHandler("weaponsounds")
end)

function isWeaponSoundsEnabled()
    return isCustomSoundsEnabled
end

function setWeaponSoundsEnabled(state)
    if state == isCustomSoundsEnabled then
        return
    end
    isCustomSoundsEnabled = state
    if isCustomSoundsEnabled then
        setWorldSoundEnabled(5, false, true)
    else
        setWorldSoundEnabled(5, true)
    end
end