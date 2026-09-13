addEvent("gzl_animations:setPedIdleAnim", true)
addEventHandler("gzl_animations:setPedIdleAnim", root, function(animName)
    if client and isElement(client) and not isPedInVehicle(client) and not isPedDead(client) then
        if animName and type(animName) == "string" then
            setPedAnimation(client, "lcs_playidles", animName, -1, false, false, true, false)
        else
            setPedAnimation(client)
        end
    end
end)