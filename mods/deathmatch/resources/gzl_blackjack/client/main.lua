local customTableDff, customTableTxd, customTableCol
local customDealerDff, customDealerTxd
local tableFeltShader, tableChairShader, dealerFixShader

addEventHandler("onClientResourceStart", resourceRoot, function()

    local txdFile = "assets/models/blackjack_table.txd"
    local dffFile = "assets/models/blackjack_table.dff"
    local colFile = "assets/models/blackjack_table.col"

    if fileExists(txdFile) and fileExists(dffFile) then
        customTableTxd = engineLoadTXD(txdFile)
        if customTableTxd then
            engineImportTXD(customTableTxd, Config.Models.tableBaseID)
        end

        customTableDff = engineLoadDFF(dffFile)
        if customTableDff then
            engineReplaceModel(customTableDff, Config.Models.tableBaseID)
        end

        if fileExists(colFile) then
            customTableCol = engineLoadCOL(colFile)
            if customTableCol then
                engineReplaceCOL(customTableCol, Config.Models.tableBaseID)
            end
        end
        engineSetModelLODDistance(Config.Models.tableBaseID, 300)
        outputDebugString("[BLACKJACK] Özel Diamond Casino masası modeli başarıyla yüklendi (ID: " .. Config.Models.tableBaseID .. ").")
    end

    local dealerTxdFile = "assets/models/dealer.txd"
    local dealerDffFile = "assets/models/dealer.dff"

    if fileExists(dealerTxdFile) and fileExists(dealerDffFile) then
        customDealerTxd = engineLoadTXD(dealerTxdFile)
        if customDealerTxd then
            engineImportTXD(customDealerTxd, Config.Models.dealerBaseID)
        end

        customDealerDff = engineLoadDFF(dealerDffFile)
        if customDealerDff then
            engineReplaceModel(customDealerDff, Config.Models.dealerBaseID)
        end
        outputDebugString("[BLACKJACK] Özel kurpiyer modeli başarıyla yüklendi (ID: " .. Config.Models.dealerBaseID .. ").")
    end

    if fileExists("assets/shaders/table_tint.fx") then
        tableFeltShader = dxCreateShader("assets/shaders/table_tint.fx", 0, 0, false, "world,object")
        if tableFeltShader then

            dxSetShaderValue(tableFeltShader, "gColor", 0.08, 0.38, 0.22, 1.0)
            dxSetShaderValue(tableFeltShader, "gBrightness", 0.78)
            engineApplyShaderToWorldTexture(tableFeltShader, "prop_vw_casino_table_felt_d")
        end

        tableChairShader = dxCreateShader("assets/shaders/table_tint.fx", 0, 0, false, "world,object")
        if tableChairShader then

            dxSetShaderValue(tableChairShader, "gColor", 0.14, 0.15, 0.17, 1.0)
            dxSetShaderValue(tableChairShader, "gBrightness", 0.75)
            engineApplyShaderToWorldTexture(tableChairShader, "prop_casino_track_chair_d")
            engineApplyShaderToWorldTexture(tableChairShader, "prop_vw_casino_table_4f2057")
        end
    end

    if fileExists("assets/shaders/dealer_fix.fx") then
        dealerFixShader = dxCreateShader("assets/shaders/dealer_fix.fx", 0, 0, false, "ped")
        if dealerFixShader then
            engineApplyShaderToWorldTexture(dealerFixShader, "uppr*")
            engineApplyShaderToWorldTexture(dealerFixShader, "jbib*")
            engineApplyShaderToWorldTexture(dealerFixShader, "lowr*")
            engineApplyShaderToWorldTexture(dealerFixShader, "feet*")
        end
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isElement(tableFeltShader) then
        engineRemoveShaderFromWorldTexture(tableFeltShader, "prop_vw_casino_table_felt_d")
        destroyElement(tableFeltShader)
    end
    if isElement(tableChairShader) then
        engineRemoveShaderFromWorldTexture(tableChairShader, "prop_casino_track_chair_d")
        engineRemoveShaderFromWorldTexture(tableChairShader, "prop_vw_casino_table_4f2057")
        destroyElement(tableChairShader)
    end
    if isElement(dealerFixShader) then
        engineRemoveShaderFromWorldTexture(dealerFixShader, "uppr*")
        engineRemoveShaderFromWorldTexture(dealerFixShader, "jbib*")
        engineRemoveShaderFromWorldTexture(dealerFixShader, "lowr*")
        engineRemoveShaderFromWorldTexture(dealerFixShader, "feet*")
        destroyElement(dealerFixShader)
    end

    if customTableDff then
        engineRestoreModel(Config.Models.tableBaseID)
        destroyElement(customTableDff)
    end
    if customTableTxd then
        destroyElement(customTableTxd)
    end
    if customTableCol then
        engineRestoreCOL(Config.Models.tableBaseID)
        destroyElement(customTableCol)
    end

    if customDealerDff then
        engineRestoreModel(Config.Models.dealerBaseID)
        destroyElement(customDealerDff)
    end
    if customDealerTxd then
        destroyElement(customDealerTxd)
    end
end)