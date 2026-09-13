local function sendAuthResponse(player, success, message, isLogin, accountData)
    if isElement(player) then
        triggerClientEvent(player, "auth:response", player, success, message, isLogin, accountData)
    end
end

addEventHandler("onPlayerJoin", root, function()
    local player = source
    setElementData(player, "loggedin", false, "broadcast", "deny")
    setElementFrozen(player, true)

    setTimer(function()
        if isElement(player) and not getElementData(player, "loggedin") then
            triggerClientEvent(player, "auth:showLoginScreen", player)
        end
    end, 1000, 1)
end)

addEventHandler("onPlayerResourceStart", root, function(res)
    if res == getThisResource() then
        if not getElementData(source, "loggedin") then
            setElementFrozen(source, true)
            triggerClientEvent(source, "auth:showLoginScreen", source)
        end
    end
end)

addEventHandler("onResourceStart", resourceRoot, function()
    for _, player in ipairs(getElementsByType("player")) do
        if not getElementData(player, "loggedin") then
            setElementFrozen(player, true)
            triggerClientEvent(player, "auth:showLoginScreen", player)
        end
    end
end)

addEvent("auth:checkLoginState", true)
addEventHandler("auth:checkLoginState", root, function()
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "auth:checkLoginState") then return end
    end
    local player = client or source
    if not isElement(player) then return end
    if not getElementData(player, "loggedin") then
        setElementFrozen(player, true)
        triggerClientEvent(player, "auth:showLoginScreen", player)
    end
end)

addEvent("auth:requestLogin", true)
addEventHandler("auth:requestLogin", root, function(username, password)
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "auth:requestLogin", username, password) then return end
    end
    local player = client or source
    if not isElement(player) or type(username) ~= "string" or type(password) ~= "string" or #username > 64 or #password > 128 then return end

    username = string.gsub(username, "%s+", "")
    if string.len(username) < AuthConfig.MinUsernameLength then
        sendAuthResponse(player, false, "Kullanıcı adı çok kısa!", true)
        return
    end

    local db = getDatabase()
    if not db then
        sendAuthResponse(player, false, "Veritabanına bağlanılamadı!", true)
        return
    end

    dbQuery(function(qh)
        local result = dbPoll(qh, 0)
        if result and #result > 0 then
            local row = result[1]
            local passwordMatch = false

            if string.sub(row.password, 1, 4) == "$2y$" or string.sub(row.password, 1, 4) == "$2a$" or string.sub(row.password, 1, 4) == "$2b$" then
                passwordMatch = passwordVerify(password, row.password)
            else
                passwordMatch = (password == row.password) or (sha256(password) == row.password)
            end

            if passwordMatch then
                local currentAdmin = tonumber(getElementData(player, "account:admin")) or 0
                local dbAdmin = tonumber(row.admin_level) or 0
                if currentAdmin > dbAdmin then
                    row.admin_level = currentAdmin
                    dbExec(db, "UPDATE accounts SET admin_level = ? WHERE id = ?", currentAdmin, row.id)
                end
                registerAdminSession(player, row)
                setElementData(player, "loggedin", true, "broadcast", "deny")
                setElementData(player, "account:id", row.id, "broadcast", "deny")
                setElementData(player, "account:username", row.username, "broadcast", "deny")
                setElementData(player, "account:admin", tonumber(row.admin_level) or 0, "broadcast", "deny")
                setElementFrozen(player, false)

                local currentSerial = getPlayerSerial(player)
                local currentIP = getPlayerIP(player)
                dbExec(db, "UPDATE accounts SET last_login = CURRENT_TIMESTAMP, serial = ?, ip = ? WHERE id = ?", currentSerial, currentIP, row.id)

                sendAuthResponse(player, true, "Giriş başarılı! Hoş geldiniz.", true, {
                    id = row.id,
                    username = row.username,
                    admin_level = row.admin_level
                })

                triggerEvent("gzl:onPlayerAccountLogin", player, row)
            else
                sendAuthResponse(player, false, "Hatalı şifre girdiniz!", true)
            end
        else
            sendAuthResponse(player, false, "Böyle bir kullanıcı hesabı bulunamadı!", true)
        end
    end, db, "SELECT * FROM accounts WHERE LOWER(username) = LOWER(?)", username)
end)

addEvent("auth:requestRegister", true)
addEventHandler("auth:requestRegister", root, function(username, password, passwordConfirm)
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "auth:requestRegister", username, password, passwordConfirm) then return end
    end
    local player = client or source
    if not isElement(player) or type(username) ~= "string" or type(password) ~= "string" or #username > 64 or #password > 128 then return end

    username = string.gsub(username, "%s+", "")
    if string.len(username) < AuthConfig.MinUsernameLength or string.len(username) > AuthConfig.MaxUsernameLength then
        sendAuthResponse(player, false, "Kullanıcı adı " .. AuthConfig.MinUsernameLength .. "-" .. AuthConfig.MaxUsernameLength .. " karakter olmalıdır!", false)
        return
    end

    if string.len(password) < AuthConfig.MinPasswordLength then
        sendAuthResponse(player, false, "Şifre en az " .. AuthConfig.MinPasswordLength .. " karakter olmalıdır!", false)
        return
    end

    if password ~= passwordConfirm then
        sendAuthResponse(player, false, "Girdiğiniz şifreler birbiriyle uyuşmuyor!", false)
        return
    end

    local db = getDatabase()
    if not db then
        sendAuthResponse(player, false, "Veritabanına bağlanılamadı!", false)
        return
    end

    local playerSerial = getPlayerSerial(player)
    local playerIP = getPlayerIP(player)

    dbQuery(function(qh)
        local result = dbPoll(qh, 0)
        if result and #result > 0 then
            sendAuthResponse(player, false, "Bu kullanıcı adı zaten kullanılmaktadır!", false)
            return
        end

        dbQuery(function(serialQh)
            local serialResult = dbPoll(serialQh, 0)
            local totalAccounts = (serialResult and serialResult[1] and tonumber(serialResult[1].count)) or 0
            if totalAccounts >= AuthConfig.MaxAccountsPerSerial then
                sendAuthResponse(player, false, "Bu bilgisayardan açılabilecek maksimum hesap sınırına ulaştınız!", false)
                return
            end

            local hashedPassword = passwordHash(password, "bcrypt", {cost = 10})
            dbExec(db, "INSERT INTO accounts (username, password, serial, ip) VALUES (?, ?, ?, ?)", username, hashedPassword, playerSerial, playerIP)

            sendAuthResponse(player, true, "Hesabınız başarıyla oluşturuldu! Şimdi giriş yapabilirsiniz.", false)
        end, db, "SELECT COUNT(id) as count FROM accounts WHERE serial = ?", playerSerial)

    end, db, "SELECT id FROM accounts WHERE LOWER(username) = LOWER(?)", username)
end)
