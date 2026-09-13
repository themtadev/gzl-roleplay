LobbyServer = {}

local activeTeams = {}
local playerTeamMap = {}
local pendingInvites = {}

local function getNearbyPlayersFor(player)
    local list = {}
    if not isElement(player) then return list end
    local px, py, pz = getElementPosition(player)
    for _, other in ipairs(getElementsByType("player")) do
        if other ~= player and not playerTeamMap[other] then
            local ox, oy, oz = getElementPosition(other)
            local dist = getDistanceBetweenPoints3D(px, py, pz, ox, oy, oz)
            if dist <= 30.0 then
                table.insert(list, other)
            end
        end
    end
    return list
end

function LobbyServer.getTeam(player)
    local teamId = playerTeamMap[player]
    return teamId and activeTeams[teamId] or nil
end

function LobbyServer.syncLobby(player)
    local team = LobbyServer.getTeam(player)
    local lobbyData = nil

    if team then
        local membersData = {}
        for _, m in ipairs(team.members) do
            if isElement(m) then
                table.insert(membersData, { element = m, name = getPlayerName(m) })
            end
        end
        lobbyData = {
            isGroup = true,
            teamId = team.id,
            leader = team.leader,
            members = membersData
        }
    else
        lobbyData = {
            isGroup = false,
            leader = player,
            members = { { element = player, name = getPlayerName(player) } }
        }
    end

    local nearby = getNearbyPlayersFor(player)
    triggerClientEvent(player, "windowCleaning:clientUpdateLobby", player, lobbyData, nearby)
end

function LobbyServer.broadcastTeamLobby(team)
    if not team then return end
    for _, member in ipairs(team.members) do
        if isElement(member) then
            LobbyServer.syncLobby(member)
        end
    end
end

function LobbyServer.createTeam(player)
    if playerTeamMap[player] then return end
    local teamId = "team_" .. tostring(getTickCount()) .. "_" .. tostring(getElementData(player, "character:id") or math.random(100, 999))
    local newTeam = {
        id = teamId,
        leader = player,
        members = { player }
    }
    activeTeams[teamId] = newTeam
    playerTeamMap[player] = teamId
    LobbyServer.broadcastTeamLobby(newTeam)
end

function LobbyServer.leaveTeam(player)
    local teamId = playerTeamMap[player]
    if not teamId then return end
    local team = activeTeams[teamId]
    if not team then return end

    playerTeamMap[player] = nil

    if team.leader == player then
        for _, m in ipairs(team.members) do
            playerTeamMap[m] = nil
            if isElement(m) and m ~= player then
                LobbyServer.syncLobby(m)
            end
        end
        activeTeams[teamId] = nil
    else
        for idx, m in ipairs(team.members) do
            if m == player then
                table.remove(team.members, idx)
                break
            end
        end
        LobbyServer.broadcastTeamLobby(team)
    end

    LobbyServer.syncLobby(player)
end

function LobbyServer.invitePlayer(leader, targetPlayer)
    local team = LobbyServer.getTeam(leader)
    if not team or team.leader ~= leader then return end
    if #team.members >= Config.MaxGroupMembers then return end
    if playerTeamMap[targetPlayer] then return end

    table.insert(team.members, targetPlayer)
    playerTeamMap[targetPlayer] = team.id
    LobbyServer.broadcastTeamLobby(team)
end

function LobbyServer.handlePlayerDisconnect(player)
    LobbyServer.leaveTeam(player)
end

addEvent("windowCleaning:requestOpenLobby", true)
addEventHandler("windowCleaning:requestOpenLobby", root, function()
    local ply = client or source
    local team = LobbyServer.getTeam(ply)
    local lobbyData = nil

    if team then
        local membersData = {}
        for _, m in ipairs(team.members) do
            if isElement(m) then
                table.insert(membersData, { element = m, name = getPlayerName(m) })
            end
        end
        lobbyData = {
            isGroup = true,
            teamId = team.id,
            leader = team.leader,
            members = membersData
        }
    else
        lobbyData = {
            isGroup = false,
            leader = ply,
            members = { { element = ply, name = getPlayerName(ply) } }
        }
    end

    local nearby = getNearbyPlayersFor(ply)
    triggerClientEvent(ply, "windowCleaning:clientOpenLobby", ply, lobbyData, nearby)
end)

addEvent("windowCleaning:createTeam", true)
addEventHandler("windowCleaning:createTeam", root, function()
    local ply = client or source
    LobbyServer.createTeam(ply)
end)

addEvent("windowCleaning:leaveTeam", true)
addEventHandler("windowCleaning:leaveTeam", root, function()
    local ply = client or source
    LobbyServer.leaveTeam(ply)
end)

addEvent("windowCleaning:invitePlayer", true)
addEventHandler("windowCleaning:invitePlayer", root, function(targetPlayer)
    local ply = client or source
    if isElement(targetPlayer) then
        LobbyServer.invitePlayer(ply, targetPlayer)
    end
end)