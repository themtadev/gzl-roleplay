function checkLauncherACL()
    for _, right in ipairs({"function.startResource", "function.stopResource"}) do
        if not hasObjectPermissionTo(getThisResource(), right, false) then
            outputServerLog("[GZL LAUNCHER] Missing scoped permission: " .. right)
            return false
        end
    end
    return true
end