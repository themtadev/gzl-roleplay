local draggedSuspects = {} -- officer -> suspect
local officerDragging = {}  -- suspect -> officer

local function findTargetPlayer(player, query)
    if not query or query == "" then
        local px, py, pz = getElementPosition(player)
        local pInt = getElementInterior(player)
        local pDim = getElementDimension(player)
        local closest = nil
        local minDist = 3.2

        for _, p in ipairs(getElementsByType("player")) do
            if p ~= player and getElementInterior(p) == pInt and getElementDimension(p) == pDim then
                local tx, ty, tz = getElementPosition(p)
                local dist = getDistanceBetweenPoints3D(px, py, pz, tx, ty, tz)
                if dist < minDist then
                    minDist = dist
                    closest = p
                end
            end
        end
        return closest
    end

    local num = tonumber(query)
    if num then
        for _, p in ipairs(getElementsByType("player")) do
            local cid = tonumber(getElementData(p, "character:id") or getElementData(p, "char:id"))
            if cid == num then return p end
        end
    end

    local qLower = string.lower(query)
    for _, p in ipairs(getElementsByType("player")) do
        local pName = string.lower(getPlayerName(p))
        local cName = string.lower(tostring(getElementData(p, "character:name") or ""))
        if string.find(pName, qLower, 1, true) or string.find(cName, qLower, 1, true) then
            return p
        end
    end
    return nil
end

local function broadcastLocalAction(player, message)
    if not isElement(player) or not message then return end
    local px, py, pz = getElementPosition(player)
    local pInt = getElementInterior(player)
    local pDim = getElementDimension(player)

    for _, p in ipairs(getElementsByType("player")) do
        if getElementInterior(p) == pInt and getElementDimension(p) == pDim then
            local tx, ty, tz = getElementPosition(p)
            if getDistanceBetweenPoints3D(px, py, pz, tx, ty, tz) <= 20.0 then
                outputChatBox(message, p, 192, 57, 43, true)
            end
        end
    end
end


function isPlayerCuffed(player)
    if not isElement(player) then return false end
    return (getElementData(player, "isCuffed") == true or getElementData(player, "cuffed") == true)
end

function isPlayerDragged(player)
    if not isElement(player) then return false end
    return (getElementData(player, "isDragged") == true)
end

addCommandHandler("cuff", function(player, cmd, targetArg)
    if not isElement(player) or not PDConfig.canAccess(player) then
        outputChatBox("#ef4444[LSPD]#ffffff Bu yetkiyi kullanmak için görevde bir polis memuru olmalısınız!", player, 255, 255, 255, true)
        return
    end

    local target = findTargetPlayer(player, targetArg)
    if not target or not isElement(target) then
        outputChatBox("#38bdf8[KULLANIM]#ffffff /" .. cmd .. " [oyuncu_id / isim] (veya şüphelinin yanına yaklaşın)", player, 255, 255, 255, true)
        return
    end

    if target == player then
        outputChatBox("#ef4444[LSPD]#ffffff Kendinizi kelepçeleyemezsiniz!", player, 255, 255, 255, true)
        return
    end

    local px, py, pz = getElementPosition(player)
    local tx, ty, tz = getElementPosition(target)
    if getDistanceBetweenPoints3D(px, py, pz, tx, ty, tz) > 3.5 or getElementDimension(player) ~= getElementDimension(target) or getElementInterior(player) ~= getElementInterior(target) then
        outputChatBox("#ef4444[LSPD]#ffffff Şüpheliye yeterince yakın değilsiniz!", player, 255, 255, 255, true)
        return
    end

    if isPedInVehicle(target) then
        outputChatBox("#ef4444[LSPD]#ffffff Araç içerisindeki bir şahsı kelepçeleyemezsiniz!", player, 255, 255, 255, true)
        return
    end

    local offName = getElementData(player, "character:name") or getPlayerName(player)
    local tarName = getElementData(target, "character:name") or getPlayerName(target)
    local isCuffed = (getElementData(target, "isCuffed") == true)

    if isCuffed then
        if officerDragging[target] then
            local dragger = officerDragging[target]
            detachElements(target)
            setElementCollidableWith(target, dragger, true)
            setElementCollidableWith(dragger, target, true)
            draggedSuspects[dragger] = nil
            officerDragging[target] = nil
            setElementData(target, "isDragged", false, true)
        end

        setElementData(target, "isCuffed", false, true)
        setElementData(target, "cuffed", false, true)
        setPedAnimation(target, false)

        toggleControl(target, "fire", true)
        toggleControl(target, "aim_weapon", true)
        toggleControl(target, "next_weapon", true)
        toggleControl(target, "previous_weapon", true)
        toggleControl(target, "jump", true)
        toggleControl(target, "sprint", true)
        toggleControl(target, "enter_exit", true)

        triggerClientEvent(target, "pd:onCuffStateChanged", target, false)
        broadcastLocalAction(player, string.format("* %s kelepçenin anahtarını çevirerek %s adlı şahsın kelepçesini açtı.", offName, tarName))

        outputChatBox(string.format("#34d399[LSPD]#ffffff %s adlı şahsın kelepçesini açtınız.", tarName), player, 255, 255, 255, true)
        outputChatBox(string.format("#34d399[LSPD]#ffffff Memur %s kelepçelerinizi çözdü.", offName), target, 255, 255, 255, true)

        if exports.gzl_logs and exports.gzl_logs.logSystem then
            pcall(function() exports.gzl_logs:logSystem("PD", "UNCUFF", string.format("%s uncuffed %s", offName, tarName)) end)
        end
    else
        setElementData(target, "isCuffed", true, true)
        setElementData(target, "cuffed", true, true)
        setPedWeaponSlot(target, 0)
        setPedAnimation(target, "GRAVEYARD", "mrnM_loop", -1, true, false, false, false)

        toggleControl(target, "fire", false)
        toggleControl(target, "aim_weapon", false)
        toggleControl(target, "next_weapon", false)
        toggleControl(target, "previous_weapon", false)
        toggleControl(target, "jump", false)
        toggleControl(target, "sprint", false)
        toggleControl(target, "enter_exit", false)

        triggerClientEvent(target, "pd:onCuffStateChanged", target, true)
        broadcastLocalAction(player, string.format("* %s arkadan yaklaşarak %s adlı şahsın kollarını arkaya büküp kelepçeledi.", offName, tarName))

        outputChatBox(string.format("#ef4444[LSPD]#ffffff %s adlı şahsı kelepçelediniz.", tarName), player, 255, 255, 255, true)
        outputChatBox(string.format("#ef4444[LSPD]#ffffff Memur %s tarafından kelepçelendiniz!", offName), target, 255, 255, 255, true)

        if exports.gzl_logs and exports.gzl_logs.logSystem then
            pcall(function() exports.gzl_logs:logSystem("PD", "CUFF", string.format("%s cuffed %s", offName, tarName)) end)
        end
    end
end)
addCommandHandler("kelepcele", function(player, cmd, targetArg)
    executeCommandHandler("cuff", player, targetArg)
end)

addCommandHandler("drag", function(player, cmd, targetArg)
    if not isElement(player) or not PDConfig.canAccess(player) then
        outputChatBox("#ef4444[LSPD]#ffffff Bu yetkiyi kullanmak için görevde bir polis memuru olmalısınız!", player, 255, 255, 255, true)
        return
    end

    local offName = getElementData(player, "character:name") or getPlayerName(player)

    if draggedSuspects[player] then
        local suspect = draggedSuspects[player]
        draggedSuspects[player] = nil
        if isElement(suspect) then
            officerDragging[suspect] = nil
            detachElements(suspect)
            setElementCollidableWith(suspect, player, true)
            setElementCollidableWith(player, suspect, true)
            setElementData(suspect, "isDragged", false, true)
            local sName = getElementData(suspect, "character:name") or getPlayerName(suspect)
            broadcastLocalAction(player, string.format("* %s, %s adlı şahsın kolunu bıraktı.", offName, sName))
            outputChatBox(string.format("#38bdf8[LSPD]#ffffff %s adlı şahsı bıraktınız.", sName), player, 255, 255, 255, true)
            outputChatBox(string.format("#38bdf8[LSPD]#ffffff Memur %s kolunuzu bıraktı.", offName), suspect, 255, 255, 255, true)
        end
        return
    end

    local target = findTargetPlayer(player, targetArg)
    if not target or not isElement(target) then
        outputChatBox("#38bdf8[KULLANIM]#ffffff /" .. cmd .. " [oyuncu_id / isim] (veya şüphelinin yanına yaklaşın)", player, 255, 255, 255, true)
        return
    end

    if target == player then return end

    local px, py, pz = getElementPosition(player)
    local tx, ty, tz = getElementPosition(target)
    if getDistanceBetweenPoints3D(px, py, pz, tx, ty, tz) > 3.5 then
        outputChatBox("#ef4444[LSPD]#ffffff Şüpheliye yeterince yakın değilsiniz!", player, 255, 255, 255, true)
        return
    end

    local isCuffed = (getElementData(target, "isCuffed") == true)
    local isDown = (getElementData(target, "ems:isDead") == true)
    if not isCuffed and not isDown then
        outputChatBox("#ef4444[LSPD]#ffffff Bir şahsı sürüklemek için önce kelepçelemeli veya şahıs baygın olmalıdır!", player, 255, 255, 255, true)
        return
    end

    if officerDragging[target] then
        outputChatBox("#ef4444[LSPD]#ffffff Bu şahıs zaten başka bir memur tarafından sürükleniyor!", player, 255, 255, 255, true)
        return
    end

    local wasInVeh = false
    if isPedInVehicle(target) then
        removePedFromVehicle(target)
        wasInVeh = true
    end

    setElementCollidableWith(target, player, false)
    setElementCollidableWith(player, target, false)
    attachElements(target, player, 0, 0.9, 0)
    draggedSuspects[player] = target
    officerDragging[target] = player
    setElementData(target, "isDragged", true, true)

    local tarName = getElementData(target, "character:name") or getPlayerName(target)
    if wasInVeh then
        broadcastLocalAction(player, string.format("* %s, %s adlı şahsı araçtan indirdi ve koluna girdi.", offName, tarName))
    else
        broadcastLocalAction(player, string.format("* %s, %s adlı şahsın koluna girerek sürüklemeye başladı.", offName, tarName))
    end

    outputChatBox(string.format("#34d399[LSPD]#ffffff %s adlı şahsı sürüklemeye başladınız. (Bırakmak için tekrar /drag yazın)", tarName), player, 255, 255, 255, true)
    outputChatBox(string.format("#38bdf8[LSPD]#ffffff Memur %s kolunuza girerek sizi yönlendiriyor.", offName), target, 255, 255, 255, true)
end)
addCommandHandler("kolunagir", function(player, cmd, targetArg)
    executeCommandHandler("drag", player, targetArg)
end)
addCommandHandler("escort", function(player, cmd, targetArg)
    executeCommandHandler("drag", player, targetArg)
end)

addEventHandler("onPlayerVehicleEnter", root, function(veh, seat, door)
    local officer = source
    if draggedSuspects[officer] then
        local suspect = draggedSuspects[officer]
        draggedSuspects[officer] = nil
        officerDragging[suspect] = nil
        detachElements(suspect)
        setElementCollidableWith(suspect, officer, true)
        setElementCollidableWith(officer, suspect, true)
        setElementData(suspect, "isDragged", false, true)

        if isElement(suspect) and isElement(veh) then
            local maxSeats = getVehicleMaxPassengers(veh)
            local targetSeat = 2 -- rear left
            if maxSeats >= 3 and isVehicleSeatFree(veh, 3) then
                targetSeat = 3
            elseif maxSeats >= 2 and isVehicleSeatFree(veh, 2) then
                targetSeat = 2
            elseif maxSeats >= 1 and isVehicleSeatFree(veh, 1) then
                targetSeat = 1
            else
                targetSeat = nil
            end

            if targetSeat then
                warpPedIntoVehicle(suspect, veh, targetSeat)
                local offName = getElementData(officer, "character:name") or getPlayerName(officer)
                local tarName = getElementData(suspect, "character:name") or getPlayerName(suspect)
                broadcastLocalAction(officer, string.format("* %s, %s adlı şahsı polis aracının arka koltuğuna bindirdi.", offName, tarName))
            else
                outputChatBox("#ef4444[LSPD]#ffffff Polis aracında şüpheli için boş koltuk bulunmuyor!", officer, 255, 255, 255, true)
            end
        end
    end
end)

local function cleanupDragging(player)
    if draggedSuspects[player] then
        local suspect = draggedSuspects[player]
        draggedSuspects[player] = nil
        if isElement(suspect) then
            officerDragging[suspect] = nil
            detachElements(suspect)
            setElementCollidableWith(suspect, player, true)
            setElementCollidableWith(player, suspect, true)
            setElementData(suspect, "isDragged", false, true)
        end
    end
    if officerDragging[player] then
        local officer = officerDragging[player]
        officerDragging[player] = nil
        if isElement(officer) then
            draggedSuspects[officer] = nil
            setElementCollidableWith(player, officer, true)
            setElementCollidableWith(officer, player, true)
        end
        detachElements(player)
        setElementData(player, "isDragged", false, true)
    end
end

addEventHandler("onPlayerQuit", root, function()
    cleanupDragging(source)
end)
addEventHandler("onPlayerWasted", root, function()
    cleanupDragging(source)
end)

addCommandHandler("frisk", function(player, cmd, targetArg)
    if not isElement(player) or not PDConfig.canAccess(player) then
        outputChatBox("#ef4444[LSPD]#ffffff Bu yetkiyi kullanmak için görevde bir polis memuru olmalısınız!", player, 255, 255, 255, true)
        return
    end

    local target = findTargetPlayer(player, targetArg)
    if not target or not isElement(target) then
        outputChatBox("#38bdf8[KULLANIM]#ffffff /" .. cmd .. " [oyuncu_id / isim] (veya şüphelinin yanına yaklaşın)", player, 255, 255, 255, true)
        return
    end

    if target == player then
        outputChatBox("#ef4444[LSPD]#ffffff Kendi üzerinizi arayamazsınız!", player, 255, 255, 255, true)
        return
    end

    local px, py, pz = getElementPosition(player)
    local tx, ty, tz = getElementPosition(target)
    if getDistanceBetweenPoints3D(px, py, pz, tx, ty, tz) > 3.5 then
        outputChatBox("#ef4444[LSPD]#ffffff Şüpheliye yeterince yakın değilsiniz!", player, 255, 255, 255, true)
        return
    end

    local isCuffed = (getElementData(target, "isCuffed") == true)
    local isDown = (getElementData(target, "ems:isDead") == true)
    if not isCuffed and not isDown then
        outputChatBox("#f59e0b[LSPD]#ffffff Şahsın üzerini güvenli aramak için önce kelepçelemeli veya ellerini kaldırmış olmalıdır!", player, 255, 255, 255, true)
    end

    local offName = getElementData(player, "character:name") or getPlayerName(player)
    local tarName = getElementData(target, "character:name") or getPlayerName(target)

    broadcastLocalAction(player, string.format("* %s iki eliyle %s adlı şahsın üzerini ve ceplerini dikkatlice arar.", offName, tarName))
    outputChatBox(string.format("#f59e0b[ÜST ARAMA]#ffffff Memur %s üzerinizi ve ceplerinizi arıyor...", offName), target, 255, 255, 255, true)

    local targetCash = 0
    if exports.gzl_characters and exports.gzl_characters.getPlayerCash then
        targetCash = exports.gzl_characters:getPlayerCash(target)
    else
        targetCash = tonumber(getElementData(target, "character:money") or getPlayerMoney(target)) or 0
    end

    local targetItems = {}
    if exports.gzl_inventory and exports.gzl_inventory.getPlayerItems then
        local raw = exports.gzl_inventory:getPlayerItems(target)
        if raw then
            for _, itm in pairs(raw) do
                if itm and itm.name then
                    table.insert(targetItems, itm)
                end
            end
        end
    end

    outputChatBox(string.format("#38bdf8============== [ÜST ARAMA RAPORU: %s] ==============", tarName), player, 255, 255, 255, true)
    outputChatBox(string.format("#e2e8f0Nakit Para:#ffffff #34d399$%d", targetCash), player, 255, 255, 255, true)

    if #targetItems == 0 then
        outputChatBox("  #94a3b8(Üzerinde hiçbir eşya bulunmuyor)", player, 255, 255, 255, true)
    else
        outputChatBox("#e2e8f0Bulunan Eşyalar:", player, 255, 255, 255, true)
        local allItemsDef = (exports.gzl_inventory and exports.gzl_inventory.getItemsList and exports.gzl_inventory:getItemsList()) or {}

        for _, itm in ipairs(targetItems) do
            local def = allItemsDef[itm.name] or {}
            local label = itm.label or def.label or itm.name
            local count = itm.count or 1
            local illegal, tag = isContraband(itm.name)

            if illegal then
                outputChatBox(string.format("  #ffffff- %s #ef4444(x%d) [YASADIŞI: %s] #94a3b8(/elkol %s %s %d)", label, count, tag, tostring(getElementData(target, "character:id") or getPlayerName(target)), itm.name, count), player, 255, 255, 255, true)
            else
                outputChatBox(string.format("  #ffffff- %s #34d399(x%d) [YASAL]", label, count), player, 255, 255, 255, true)
            end
        end
    end
    outputChatBox("#38bdf8=======================================================", player, 255, 255, 255, true)
end)
addCommandHandler("ustara", function(player, cmd, targetArg)
    executeCommandHandler("frisk", player, targetArg)
end)
addCommandHandler("arama", function(player, cmd, targetArg)
    executeCommandHandler("frisk", player, targetArg)
end)

addCommandHandler("confiscate", function(player, cmd, targetArg, itemName, amountArg)
    if not isElement(player) or not PDConfig.canAccess(player) then
        outputChatBox("#ef4444[LSPD]#ffffff Bu yetkiyi kullanmak için görevde bir polis memuru olmalısınız!", player, 255, 255, 255, true)
        return
    end

    local target = findTargetPlayer(player, targetArg)
    if not target or not isElement(target) or not itemName then
        outputChatBox("#38bdf8[KULLANIM]#ffffff /" .. cmd .. " [oyuncu_id / isim] [eşya_adı] [miktar]", player, 255, 255, 255, true)
        return
    end

    local px, py, pz = getElementPosition(player)
    local tx, ty, tz = getElementPosition(target)
    if getDistanceBetweenPoints3D(px, py, pz, tx, ty, tz) > 3.5 then
        outputChatBox("#ef4444[LSPD]#ffffff Şüpheliye yeterince yakın değilsiniz!", player, 255, 255, 255, true)
        return
    end

    local amount = math.max(1, math.floor(tonumber(amountArg) or 1))

    if not exports.gzl_inventory or not exports.gzl_inventory.hasItem or not exports.gzl_inventory.removeItem then
        outputChatBox("#ef4444[LSPD]#ffffff Envanter sistemi yanıt vermiyor!", player, 255, 255, 255, true)
        return
    end

    if not exports.gzl_inventory:hasItem(target, itemName, amount) then
        outputChatBox(string.format("#ef4444[LSPD]#ffffff Şüphelinin üzerinde belirtilen miktarda '%s' bulunmuyor!", itemName), player, 255, 255, 255, true)
        return
    end

    local removed = exports.gzl_inventory:removeItem(target, itemName, amount)
    if removed then
        local offName = getElementData(player, "character:name") or getPlayerName(player)
        local tarName = getElementData(target, "character:name") or getPlayerName(target)

        broadcastLocalAction(player, string.format("* Memur %s, %s adlı şahsın üzerindeki '%s' (x%d) eşyasına el koydu.", offName, tarName, itemName, amount))

        outputChatBox(string.format("#34d399[LSPD]#ffffff %s adlı şahsın üzerindeki #ef4444%s (x%d)#ffffff eşyasına el koydunuz.", tarName, itemName, amount), player, 255, 255, 255, true)
        outputChatBox(string.format("#ef4444[LSPD]#ffffff Memur %s üzerinizdeki '%s' (x%d) eşyanıza el koydu!", offName, itemName, amount), target, 255, 255, 255, true)

        if exports.gzl_logs and exports.gzl_logs.logItem then
            pcall(function() exports.gzl_logs:logItem(target, "confiscate", itemName, amount, player, "Officer Confiscation") end)
        end
    else
        outputChatBox("#ef4444[LSPD]#ffffff Eşyaya el konulurken bir hata oluştu!", player, 255, 255, 255, true)
    end
end)
addCommandHandler("elkol", function(player, cmd, targetArg, itemName, amountArg)
    executeCommandHandler("confiscate", player, targetArg, itemName, amountArg)
end)

addCommandHandler("confiscateweapons", function(player, cmd, targetArg)
    if not isElement(player) or not PDConfig.canAccess(player) then
        outputChatBox("#ef4444[LSPD]#ffffff Bu yetkiyi kullanmak için görevde bir polis memuru olmalısınız!", player, 255, 255, 255, true)
        return
    end

    local target = findTargetPlayer(player, targetArg)
    if not target or not isElement(target) then
        outputChatBox("#38bdf8[KULLANIM]#ffffff /" .. cmd .. " [oyuncu_id / isim]", player, 255, 255, 255, true)
        return
    end

    local px, py, pz = getElementPosition(player)
    local tx, ty, tz = getElementPosition(target)
    if getDistanceBetweenPoints3D(px, py, pz, tx, ty, tz) > 3.5 then
        outputChatBox("#ef4444[LSPD]#ffffff Şüpheliye yeterince yakın değilsiniz!", player, 255, 255, 255, true)
        return
    end

    if not exports.gzl_inventory or not exports.gzl_inventory.getPlayerItems or not exports.gzl_inventory.removeItem then
        outputChatBox("#ef4444[LSPD]#ffffff Envanter sistemi yanıt vermiyor!", player, 255, 255, 255, true)
        return
    end

    local items = exports.gzl_inventory:getPlayerItems(target) or {}
    local countConfiscated = 0
    local offName = getElementData(player, "character:name") or getPlayerName(player)
    local tarName = getElementData(target, "character:name") or getPlayerName(target)

    local toConfiscate = {}
    for _, itm in pairs(items) do
        if itm and itm.name then
            local illegal = isContraband(itm.name)
            if illegal then
                table.insert(toConfiscate, { name = itm.name, count = itm.count or 1 })
            end
        end
    end

    for _, cItm in ipairs(toConfiscate) do
        exports.gzl_inventory:removeItem(target, cItm.name, cItm.count)
        countConfiscated = countConfiscated + 1
        if exports.gzl_logs and exports.gzl_logs.logItem then
            pcall(function() exports.gzl_logs:logItem(target, "confiscate", cItm.name, cItm.count, player, "Mass Weapon Confiscation") end)
        end
    end

    if countConfiscated > 0 then
        broadcastLocalAction(player, string.format("* Memur %s, %s adlı şahsın üzerindeki tüm yasadışı silah ve mühimmatlara el koydu.", offName, tarName))
        outputChatBox(string.format("#34d399[LSPD]#ffffff %s adlı şahsın üzerindeki toplam #ef4444%d#ffffff parça yasadışı eşya/silaha el konuldu.", tarName, countConfiscated), player, 255, 255, 255, true)
        outputChatBox(string.format("#ef4444[LSPD]#ffffff Memur %s üzerinizdeki tüm yasadışı silah ve mühimmatlara el koydu!", offName), target, 255, 255, 255, true)
    else
        outputChatBox("#f59e0b[LSPD]#ffffff Şüphelinin üzerinde el konulacak herhangi bir yasadışı silah veya mühimmat bulunamadı.", player, 255, 255, 255, true)
    end
end)
addCommandHandler("elkoysilahlar", function(player, cmd, targetArg)
    executeCommandHandler("confiscateweapons", player, targetArg)
end)