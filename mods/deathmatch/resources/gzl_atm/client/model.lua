addEventHandler("onClientResourceStart", resourceRoot, function()

    local txd = engineLoadTXD("assets/otb_machine.txd")
    if txd then
        engineImportTXD(txd, ATMConfig.ModelID)
    end

    local dff = engineLoadDFF("assets/otb_machine.dff")
    if dff then
        engineReplaceModel(dff, ATMConfig.ModelID)
    end

    local fTxd = engineLoadTXD("assets/fleeca.txd", true)
    if fTxd then
        engineImportTXD(fTxd, 4006)
    end

    local fDff = engineLoadDFF("assets/fleeca.dff", 0)
    if fDff then
        engineReplaceModel(fDff, 4006)
    end

    local fCol = engineLoadCOL("assets/fleeca.col")
    if fCol then
        engineReplaceCOL(fCol, 4006)
    end

    engineSetModelLODDistance(4006, 1000)

    removeWorldModel(4006, 500, 1394.36, -1620.66, 32.15, 0)
    removeWorldModel(4055, 500, 1394.36, -1620.66, 32.15, 0)

    for _, obj in ipairs(getElementsByType("object", resourceRoot)) do
        local model = getElementModel(obj)
        if model == 4006 then
            setElementDoubleSided(obj, true)
            setObjectBreakable(obj, false)
        else
            local breakable = getElementData(obj, "breakable")
            if breakable ~= nil then
                setObjectBreakable(obj, breakable == "true" or breakable == true)
            end
        end
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    restoreWorldModel(4006, 500, 1394.36, -1620.66, 32.15, 0)
    restoreWorldModel(4055, 500, 1394.36, -1620.66, 32.15, 0)
end)