PhoneUtilities = {}
local routes = {
    ['gallery:createAlbum']=true,['gallery:deleteAlbum']=true,['gallery:addPhotoToAlbum']=true,
    ['gallery:addPhotosToAlbum']=true,['gallery:removePhotoFromAlbum']=true,['gallery:removePhotosFromAlbum']=true,
    ['gallery:batchRemoveFromAlbums']=true,['gallery:toggleFavorite']=true,
    ['mail:getMails']=true,['mail:removeMail']=true,['mail:sendMail']=true,['garage:getVehicles']=true,['garage:markVehicle']=true,
    ['yellowpage:removePost']=true
}
function PhoneUtilities.supports(endpoint) return routes[endpoint] == true end
function PhoneUtilities.handle(player,pData,endpoint,data,reply)
    local db=getPhoneDB()
    if endpoint:find('^gallery:') then
        pData.settings=pData.settings or {}
        local albums=pData.settings.photo_albums or {}
        local selected
        for _,album in ipairs(albums) do if tostring(album.id)==tostring(data.albumId or data.id) then selected=album end end
        if endpoint=='gallery:createAlbum' then
            local name=tostring(data.name or ''):sub(1,64)
            if name=='' then reply({success=false,error='Album name is required.'}) return end
            table.insert(albums,{id=tostring(getRealTime().timestamp)..'-'..tostring(getTickCount()),name=name,photos={}})
        elseif endpoint=='gallery:deleteAlbum' then
            for i=#albums,1,-1 do if tostring(albums[i].id)==tostring(data.id) then table.remove(albums,i) end end
        elseif endpoint=='gallery:toggleFavorite' then
            local found=false
            for _,photo in ipairs(pData.photos or {}) do
                if tostring(photo.id)==tostring(data.id) then photo.favorite=not photo.favorite found=true end
            end
            if not found then reply({success=false,error='Photo not found.'}) return end
            dbExec(db,'UPDATE phone_users SET photos=? WHERE char_id=?',toJSON(pData.photos),pData.charId)
        else
            local ids=data.photoIds or {data.photoId}
            if endpoint=='gallery:batchRemoveFromAlbums' then
                for _,album in ipairs(albums) do
                    local remove=(data.cleanupMap or {})[tostring(album.id)] or {}
                    for i=#album.photos,1,-1 do
                        local photo=album.photos[i]
                        local id=type(photo)=='table' and photo.id or photo
                        for _,target in ipairs(remove) do if tostring(id)==tostring(target) then table.remove(album.photos,i) break end end
                    end
                end
            elseif selected then
                selected.photos=selected.photos or {}
                for _,id in ipairs(ids) do
                    local existing
                    for i,photo in ipairs(selected.photos) do
                        if tostring(type(photo)=='table' and photo.id or photo)==tostring(id) then existing=i break end
                    end
                    if endpoint:find(':add') and not existing then table.insert(selected.photos,id)
                    elseif endpoint:find(':remove') and existing then table.remove(selected.photos,existing) end
                end
            else reply({success=false,error='Album not found.'}) return end
        end
        pData.settings.photo_albums=albums
        dbExec(db,'UPDATE phone_users SET settings=? WHERE char_id=?',toJSON(pData.settings),pData.charId)
        reply({success=true,albums=albums,photos=pData.photos})
    elseif endpoint=='mail:sendMail' then
        local recipient=tostring(data.recipient or ''):gsub('%s+','')
        local subject=tostring(data.subject or ''):sub(1,160)
        local message=tostring(data.message or ''):sub(1,8000)
        if recipient=='' or subject=='' or message=='' then reply({success=false,error='Recipient, subject and message are required.'}) return end
        dbQuery(function(q)
            local rows=dbPoll(q,0) or {}
            if not isElement(player) or tonumber(getElementData(player,'char:id') or getElementData(player,'character:id')) ~= tonumber(pData.charId) then return end
            if #rows==0 then reply({success=false,error='Recipient not found.'}) return end
            local target=rows[1]
            local address=target.mail_account or tostring(target.phone_number)..(Config.MailFormat or '@gzl.com')
            local sender=pData.mail or tostring(pData.number)..(Config.MailFormat or '@gzl.com')
            dbExec(db,'INSERT INTO phone_mail (owner_address,sender_address,sender_name,recipients,subject,content,time) VALUES (?,?,?,?,?,?,?)',
                address,sender,getPlayerName(player):gsub('#%x%x%x%x%x%x',''),toJSON({address}),subject,message,getRealTime().timestamp)
            reply({success=true})
            local targetPlayer=getPlayerByPhoneNumber(target.phone_number)
            if isElement(targetPlayer) then sendPhoneNotification(targetPlayer,'Mail',subject,'mail') end
        end,db,'SELECT phone_number,mail_account FROM phone_users WHERE mail_account=? OR phone_number=? LIMIT 1',recipient,recipient:match('^([^@]+)') or recipient)
    elseif endpoint=='mail:getMails' then
        local address=pData.mail or tostring(pData.number)..(Config.MailFormat or '@gzl.com')
        dbQuery(function(q) reply(dbPoll(q,0) or {}) end,db,'SELECT * FROM phone_mail WHERE owner_address=? ORDER BY time DESC LIMIT 100',address)
    elseif endpoint=='mail:removeMail' then
        local address=pData.mail or tostring(pData.number)..(Config.MailFormat or '@gzl.com')
        dbExec(db,'DELETE FROM phone_mail WHERE id=? AND owner_address=?',data.id,address)
        reply({success=true})
    elseif endpoint=='yellowpage:removePost' then
        dbExec(db,'DELETE FROM phone_ads WHERE id=? AND owner_number=?',data.id,pData.number)
        reply({success=true})
    elseif endpoint=='garage:getVehicles' or endpoint=='garage:markVehicle' then
        local res=getResourceFromName('gzl_vehicles')
        if not res or getResourceState(res)~='running' then reply({success=false,error='Vehicle service is offline.'}) return end
        local vehicleDB=exports.gzl_vehicles:getVehicleDB()
        if not vehicleDB then reply({success=false,error='Vehicle database is unavailable.'}) return end
        dbQuery(function(q)
            local rows=dbPoll(q,0) or {}
            local result={}
            for _,row in ipairs(rows) do
                local name=getVehicleNameFromModel(tonumber(row.model)) or tostring(row.model)
                local kind=getVehicleType(tonumber(row.model))
                table.insert(result,{id=row.id,plate=row.plate,model=name,label=name,class=kind=='Boat' and 14 or ((kind=='Bike' or kind=='BMX') and 8 or 0),
                    fuel=row.fuel,engine=row.health,body=row.health,state=row.in_garage,garage=row.in_garage==1 and 'Garage' or 'Outside',
                    coords={x=row.pos_x,y=row.pos_y,z=row.pos_z}})
            end
            if endpoint=='garage:markVehicle' then
                local requested=type(data.vehicle)=='table' and data.vehicle or {}
                for _,row in ipairs(result) do
                    if tostring(row.id)==tostring(requested.id) or row.plate==requested.plate then reply({success=true,coords=row.coords}) return end
                end
                reply({success=false,error='Vehicle not found.'}) return
            end
            reply(result)
        end,vehicleDB,'SELECT * FROM vehicles WHERE owner_id=?',pData.charId)
    end
end
