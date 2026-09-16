PhoneDark = {}
local function read(sql,...)
    return dbPoll(dbQuery(getPhoneDB(),sql,...),-1) or {}
end
local function decode(text)
    local value=fromJSON(text or '')
    return type(value)=='table' and value or {}
end
function PhoneDark.snapshot(number)
    local result={}
    for _,group in ipairs(read('SELECT * FROM phone_darkgroups')) do
        local members=decode(group.members)
        if members[number] then
            local messages=read('SELECT * FROM (SELECT * FROM phone_darkmessages WHERE group_id=? ORDER BY id DESC LIMIT 50) ORDER BY id',group.id)
            for _,message in ipairs(messages) do
                local payload=decode(message.message)
                message.message=payload.message or message.message
                message.image=payload.image; message.video=payload.video;message.coords=payload.coords
            end
            local names={}
            for key,member in pairs(members) do names[key]=member.name or key end
            result[tostring(group.id)]={id=tostring(group.id),name=group.name,owner=group.creator,picture=group.photo or '',
                list=members,name_list=names,messages=messages,hasMore=false,unread=0,type='group'}
        end
    end
    return result
end
function PhoneDark.handle(player,pData,endpoint,data,reply)
    local action=endpoint:sub(10)
    local number=tostring(pData.number)
    local id=tonumber(data.selectedMessageId or data.messageId or data.id or data.data)
    local function finish(value)
        reply({mtaDark=PhoneDark.snapshot(number),value=value or {success=true}})
        for _,other in ipairs(getElementsByType('player')) do
            if other~=player then
                local otherNumber=getPhoneNumber(other)
                if otherNumber then triggerClientEvent(other,'cylex_phone:darkUpdate',resourceRoot,PhoneDark.snapshot(tostring(otherNumber))) end
            end
        end
    end
    local function fail(message) reply({success=false,error=message}) end
    if action=='getConversations' or action=='fetchConversations' then finish(PhoneDark.snapshot(number)) return end
    if action=='changeNickname' then
        local nickname=tostring(data.nickname or ''):sub(1,32)
        if nickname=='' then fail('Nickname is required.') return end
        pData.darkchat=pData.darkchat or {};pData.darkchat.nickname=nickname
        dbExec(getPhoneDB(),'UPDATE phone_users SET darkchat_user=? WHERE char_id=?',toJSON(pData.darkchat),pData.charId)
        for _,group in ipairs(read('SELECT * FROM phone_darkgroups')) do
            local members=decode(group.members)
            if members[number] then members[number].name=nickname dbExec(getPhoneDB(),'UPDATE phone_darkgroups SET members=? WHERE id=?',toJSON(members),group.id) end
        end
        finish() return
    end
    local nickname=pData.darkchat and pData.darkchat.nickname or number
    if action=='createNewChat' then
        local name=tostring(data.name or ''):sub(1,64)
        if name=='' then fail('Group name is required.') return end
        local count=read('SELECT COUNT(*) AS total FROM phone_darkgroups WHERE creator=?',number)
        if (tonumber(count[1] and count[1].total) or 0)>=20 then fail('Group limit reached.') return end
        passwordHash(tostring(data.password or ''),'bcrypt',{cost=10},function(encoded)
            if not isElement(player) or tonumber(getElementData(player,'char:id') or getElementData(player,'character:id'))~=tonumber(pData.charId) then return end
            if not encoded then fail('Unable to create group.') return end
            dbExec(getPhoneDB(),'INSERT INTO phone_darkgroups (name,code,creator,members,bans) VALUES (?,?,?,?,?)',name,encoded,number,toJSON({[number]={phoneNumber=number,name=nickname}}),'[]')
            finish()
        end)
        return
    end
    local group=read('SELECT * FROM phone_darkgroups WHERE id=?',id or -1)[1]
    if not group then fail('Group not found.') return end
    local members=decode(group.members)
    if action=='joinChat' then
        passwordVerify(tostring(data.password or ''),group.code,{},function(valid)
            if not isElement(player) or tonumber(getElementData(player,'char:id') or getElementData(player,'character:id'))~=tonumber(pData.charId) then return end
            if not valid then fail('Incorrect group password.') return end
            local current=read('SELECT members FROM phone_darkgroups WHERE id=?',id)[1]
            if not current then fail('Group no longer exists.') return end
            local updated=decode(current.members)
            updated[number]={phoneNumber=number,name=nickname}
            dbExec(getPhoneDB(),'UPDATE phone_darkgroups SET members=? WHERE id=?',toJSON(updated),id)
            finish()
        end)
        return
    end
    if not members[number] then fail('You are not a member of this group.') return end
    if action=='getSpecificMessage' then finish({found=true,messageId=tostring(id),messageData=PhoneDark.snapshot(number)[tostring(id)]}) return end
    if action=='fetchChatMessages' or action=='setMessageId' then finish({success=true}) return end
    if action=='sendMessage' then
        local payload={message=tostring(data.message or data.text or ''):sub(1,4000),image=data.image,video=data.video}
        if data.type=='location' then local x,y,z=getElementPosition(player) payload.coords={x=x,y=y,z=z} end
        if payload.message=='' and not payload.image and not payload.video and not payload.coords then fail('Message is empty.') return end
        dbExec(getPhoneDB(),'INSERT INTO phone_darkmessages (group_id,sender,message,time) VALUES (?,?,?,?)',id,number,toJSON(payload),getRealTime().timestamp)
    elseif action=='leaveGroup' or action=='removeAllMessage' then
        members[number]=nil
        if group.creator==number and next(members) then group.creator=next(members) end
        dbExec(getPhoneDB(),'UPDATE phone_darkgroups SET members=?,creator=? WHERE id=?',toJSON(members),group.creator,id)
    elseif action=='removeSingleMessage' then
        local message=type(data.msgData)=='table' and data.msgData or {}
        dbExec(getPhoneDB(),'DELETE FROM phone_darkmessages WHERE group_id=? AND sender=? AND id=?',id,number,message.id or -1)
    elseif action=='clearChatMessages' or action=='changeGroupName' or action=='changeGroupPhoto' or action=='removeGroupMember' then
        if group.creator~=number then fail('Only the group owner can do this.') return end
        if action=='clearChatMessages' then dbExec(getPhoneDB(),'DELETE FROM phone_darkmessages WHERE group_id=?',id)
        elseif action=='changeGroupName' then dbExec(getPhoneDB(),'UPDATE phone_darkgroups SET name=? WHERE id=?',tostring(data.name):sub(1,64),id)
        elseif action=='changeGroupPhoto' then dbExec(getPhoneDB(),'UPDATE phone_darkgroups SET photo=? WHERE id=?',tostring(data.url or ''):sub(1,2048),id)
        else members[tostring(data.targetNumber)]=nil dbExec(getPhoneDB(),'UPDATE phone_darkgroups SET members=? WHERE id=?',toJSON(members),id) end
    else fail('This group action is unavailable.') return end
    finish()
end
