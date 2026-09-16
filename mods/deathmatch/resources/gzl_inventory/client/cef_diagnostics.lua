-- Diagnose local CEF failures in the resource that owns the browser.
local entryPath = "web/build/index.html"
local resourceName = getResourceName(getThisResource())
local eventName = resourceName .. ":cefDiagnostic"
local reported = {}

local function report(reason)
    local message = "[CEF][" .. resourceName .. "] " .. entryPath .. " | " .. tostring(reason)
    if reported[message] then return end
    reported[message] = true
    outputDebugString(message, 1)
    outputConsole(message)
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    if not fileExists(entryPath) then
        report("HTML dosyasi istemciye indirilmemis veya meta.xml file tanimi eksik.")
    end
end)

addEventHandler("onClientBrowserLoadingFailed", resourceRoot, function(url, code, description)
    if code == -3 then return end -- Navigation cancelled intentionally.
    report(tostring(url) .. " | " .. tostring(code) .. " | " .. tostring(description))
end)

-- HTTP error documents can fire DocumentReady instead of LoadingFailed.
addEvent(eventName, true)
addEventHandler(eventName, resourceRoot, function()
    if getElementType(source) ~= "browser" then return end
    report("403 - Access Denied (CEF yerel HTML erisimi reddedildi).")
end)

addEventHandler("onClientBrowserDocumentReady", resourceRoot, function(url)
    if type(url) ~= "string" or not url:find("http://mta/", 1, true) then return end
    local eventJSON = toJSON(eventName)
    local labelJSON = toJSON("[CEF] " .. resourceName .. " / " .. entryPath)
    executeBrowserJavascript(source, [[
        (function () {
            var body = document.body;
            if (!body || !/^\s*403\s*-\s*Access Denied\s*$/i.test(body.textContent)) return;
            var label = document.createElement('pre');
            label.textContent = ]] .. labelJSON .. [[;
            body.appendChild(label);
            if (window.mta) mta.triggerEvent(]] .. eventJSON .. [[);
        })();
    ]])
end)
