PhoneHomes = {}
local homes, entered = nil, {}
local function state()
    if not homes then
        local rows=dbPoll(dbQuery(getPhoneDB(),'SELECT data FROM phone_app_state WHERE app=?','utility:homes'),-1)
        if not rows then return nil end
        homes=rows[1] and fromJSON(rows[1].data) or {nextId=0,items={}}
    end
    return homes
end
local function save()
    return dbExec(getPhoneDB(),'INSERT OR REPLACE INTO phone_app_state (app,data) VALUES (?,?)','utility:homes',toJSON(homes))
end
local function character(player)
    return tonumber(getElementData(player,'char:id') or getElementData(player,'character:id'))
end
local function allowed(home,id) return id and (home.owner==id or home.keys[tostring(id)]) end
function PhoneHomes.list(id)
    local data=state();local result={}
    if not data then return result end
    for _,home in ipairs(data.items) do
        if allowed(home,id) then
            local keys={};for target in pairs(home.keys) do table.insert(keys,target) end
            table.insert(result,{id=home.id,name=home.name,zone=home.zone,tier=home.interior,
                owned=home.owner==id,can_lock=true,can_transfer=home.owner==id,unlocked=not home.locked,
                access={keyAccess=keys},coords=home.outside})
        end
    end
    return result
end
function PhoneHomes.handle(player,pData,endpoint,data,reply)
    local store=state()
    if not store then reply({success=false,error='Housing database unavailable.'}) return end
    local function finish() reply({success=true,homes=PhoneHomes.list(pData.charId)}) end
    if endpoint=='house:getHomes' then finish() return end
    local home
    for _,item in ipairs(store.items) do if item.id==tonumber(data.id) then home=item break end end
    if not home or not allowed(home,pData.charId) then reply({success=false,error='You do not have a key to this property.'}) return end
    if endpoint=='house:markHouse' then reply({success=true,coords=home.outside}) return end
    if endpoint=='house:lock' or endpoint=='house:unlock' then
        home.locked=endpoint=='house:lock';save();finish();return
    end
    if home.owner~=pData.charId then reply({success=false,error='Only the owner can manage property access.'}) return end
    if endpoint=='house:removeKey' then
        home.keys[tostring(data.target)]=nil;save();finish();return
    end
    if endpoint~='house:giveKey' and endpoint~='house:transferHouse' then reply({success=false,error='Unknown housing operation.'}) return end
    local target=tonumber(data.targetCitizenId)
    if not target or target<1 or target%1~=0 or target==home.owner then reply({success=false,error='Enter another valid character ID.'}) return end
    local resource=getResourceFromName('gzl_characters')
    if not resource or getResourceState(resource)~='running' then reply({success=false,error='Character service is offline.'}) return end
    local db=exports.gzl_characters:getCharacterDB()
    if not db then reply({success=false,error='Character database unavailable.'}) return end
    dbQuery(function(q)
        local rows=dbPoll(q,0) or {}
        if not isElement(player) or character(player)~=pData.charId or home.owner~=pData.charId then return end
        if not rows[1] then reply({success=false,error='Character not found.'}) return end
        if endpoint=='house:giveKey' then home.keys[tostring(target)]=true
        else home.owner=target;home.keys={};home.locked=true end
        save();finish()
    end,db,'SELECT id FROM characters WHERE id=?',target)
end
local function leave(player)
    local home=entered[player]
    if home and isElement(player) then
        setElementInterior(player,home.outside.interior)
        setElementDimension(player,home.outside.dimension)
        setElementPosition(player,home.outside.x,home.outside.y,home.outside.z)
    end
    entered[player]=nil
end
-- Administrators explicitly place a property and choose an interior spawn.
addCommandHandler('phonehomecreate',function(player,_,owner,interior,x,y,z,...)
    if not isElement(player) or not character(player) then return end
    owner,interior,x,y,z=tonumber(owner),tonumber(interior),tonumber(x),tonumber(y),tonumber(z)
    if not owner or owner<1 or owner%1~=0 or not interior or interior<0 or interior>255 or interior%1~=0 or not x or not y or not z then
        outputChatBox('Usage: /phonehomecreate <character-id> <interior> <x> <y> <z> <name>',player);return
    end
    local store=state();if not store then return end
    if store.nextId>=5000 then outputChatBox('Property capacity reached.',player);return end
    local px,py,pz=getElementPosition(player)
    store.nextId=store.nextId+1
    table.insert(store.items,{id=store.nextId,owner=owner,keys={},locked=true,name=table.concat({...},' '):sub(1,80),
        zone=getZoneName(px,py,pz),interior=interior,inside={x=x,y=y,z=z},
        outside={x=px,y=py,z=pz,interior=getElementInterior(player),dimension=getElementDimension(player)}})
    save();outputChatBox('Property created: '..store.nextId,player)
end,true,false)
addCommandHandler('enterhome',function(player)
    local id=character(player);local store=state()
    if not id or not store or entered[player] or isPedInVehicle(player) then return end
    local x,y,z=getElementPosition(player)
    for _,home in ipairs(store.items) do
        local pos=home.outside
        if getElementInterior(player)==pos.interior and getElementDimension(player)==pos.dimension and getDistanceBetweenPoints3D(x,y,z,pos.x,pos.y,pos.z)<=3 then
            if home.locked and not allowed(home,id) then outputChatBox('This property is locked.',player);return end
            entered[player]=home;setElementInterior(player,home.interior);setElementDimension(player,60000+home.id)
            setElementPosition(player,home.inside.x,home.inside.y,home.inside.z);return
        end
    end
    outputChatBox('Stand near a property entrance.',player)
end)
addCommandHandler('leavehome',leave)
addEventHandler('onPlayerQuit',root,function() entered[source]=nil end)
addEventHandler('onElementDataChange',root,function(key)
    if key=='char:id' or key=='character:id' then entered[source]=nil end
end)
addEventHandler('onPlayerWasted',root,function() leave(source) end)
addEventHandler('onResourceStop',resourceRoot,function() for player in pairs(entered) do leave(player) end end)
