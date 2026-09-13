local bennyPed = nil
local officeZone = nil

local function initBennyNPC()
    local b = Config.BennyNPC
    bennyPed = createPed(b.model, b.x, b.y, b.z, b.rot)
    if bennyPed then
        setElementFrozen(bennyPed, true)
        setElementData(bennyPed, "ped:name", b.name)
        setElementData(bennyPed, "ped:subtext", b.subtext)
        setElementData(bennyPed, "name", b.name)

        addEventHandler("onDamage", bennyPed, cancelEvent)
    end

    officeZone = createColSphere(b.x, b.y, b.z, 5.0)
    if officeZone then
        addEventHandler("onColShapeHit", officeZone, function(hitElement, matchingDimension)
            if matchingDimension and isElement(hitElement) and getElementType(hitElement) == "player" then
                if exports.gzl_ui and exports.gzl_ui.showNotification then
                    exports.gzl_ui:showNotification(hitElement, "Benny (Atölye Sahibi)", "Selam dostum! Los Santos'un en sağlam custom atölyesine hoş geldin. Arabanı yenilemek veya modifiye etmek için istasyonlara yanaşabilirsin!", "info", 6000)
                else
                    outputChatBox("#F5A623[Benny]: #FFFFFFSelam dostum! Atölyeme hoş geldin. Arabanı tamir ve modifiye etmek için istasyonlara yanaşabilirsin.", hitElement, 255, 255, 255, true)
                end
            end
        end)
    end
end

addEventHandler("onResourceStart", resourceRoot, initBennyNPC)