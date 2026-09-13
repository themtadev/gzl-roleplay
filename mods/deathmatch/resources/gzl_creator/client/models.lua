
local modelsLoaded = false

function loadCreatorModels()
    if modelsLoaded then return true end

    local maleTXD = engineLoadTXD("assets/models/male/Male.txd")
    local maleTXD_ok = maleTXD and engineImportTXD(maleTXD, CreatorConfig.MaleSkinID)
    local maleDFF = engineLoadDFF("assets/models/male/Male.dff")
    local maleDFF_ok = maleDFF and engineReplaceModel(maleDFF, CreatorConfig.MaleSkinID, true)

    local femaleTXD = engineLoadTXD("assets/models/female/Female.txd")
    local femaleTXD_ok = femaleTXD and engineImportTXD(femaleTXD, CreatorConfig.FemaleSkinID)
    local femaleDFF = engineLoadDFF("assets/models/female/Female.dff")
    local femaleDFF_ok = femaleDFF and engineReplaceModel(femaleDFF, CreatorConfig.FemaleSkinID, true)

    modelsLoaded = maleTXD_ok and maleDFF_ok and femaleTXD_ok and femaleDFF_ok
    outputConsole(string.format("[GZL-CREATOR] Male: TXD=%s, DFF=%s | Female: TXD=%s, DFF=%s",
        tostring(maleTXD_ok), tostring(maleDFF_ok), tostring(femaleTXD_ok), tostring(femaleDFF_ok)))
    return modelsLoaded
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    loadCreatorModels()
end)