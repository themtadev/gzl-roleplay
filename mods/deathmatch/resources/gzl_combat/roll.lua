GZLRoll = {}
local state, last = nil, -10000
local controls = {"fire","aim_weapon","jump","sprint","forwards","backwards","left","right"}
local function clearAnimation(ped)
    local block,anim = getPedAnimation(ped)
    if block and string.lower(block)=="ped" and
        (string.lower(anim)=="crouch_roll_l" or string.lower(anim)=="crouch_roll_r") then
        setPedAnimation(ped)
    end
end
function GZLRoll.stop()
    if not state then return end
    local finalX = state.lastX or state.startX
    local finalY = state.lastY or state.startY
    local startZ = state.startZ
    clearAnimation(localPlayer)
    for control,enabled in pairs(state.controls) do
        setPedControlState(localPlayer,control,false)
        toggleControl(control,enabled)
    end
    if not isPedInVehicle(localPlayer) then
        local _,_,vz=getElementVelocity(localPlayer)
        setElementVelocity(localPlayer,0,0,vz)
    end

    if finalX and finalY and startZ then
        local hit,hx,hy,hz=processLineOfSight(state.startX,state.startY,startZ+0.5,finalX,finalY,startZ+0.5,true,true,true,true,true,false,false,false,localPlayer)
        local px = hit and (hx-state.dx*0.2) or finalX
        local py = hit and (hy-state.dy*0.2) or finalY
        local offset = state.pedZOffset or 1.0
        local gz = getGroundPosition(px,py,startZ+2)
        local pz = (gz and gz > 0 and math.abs(gz-(startZ-offset)) < 2.0) and (gz+offset) or startZ
        setElementPosition(localPlayer,px,py,pz)
    end
    state=nil
    triggerServerEvent("gzl_combat:rollEnd",localPlayer)
end
function GZLRoll.start(yaw,right,forward)
    local now=getTickCount()
    if state or now-last<CombatConfig.rollCooldown or not isPedOnGround(localPlayer)
        or isPedReloadingWeapon(localPlayer) or getPedAnimation(localPlayer)
        or isPedDucked(localPlayer) or getPedContactElement(localPlayer) then return false end
    local length=math.sqrt(right*right+forward*forward)
    if length==0 then right,forward,length=1,0,1 end
    local a=math.rad(yaw)
    local dx=(math.cos(a)*right-math.sin(a)*forward)/length
    local dy=(math.sin(a)*right+math.cos(a)*forward)/length
    local x,y,z=getElementPosition(localPlayer)
    if not isLineOfSightClear(x,y,z,x+dx*0.7,y+dy*0.7,z,true,true,true,true,true,false,false,localPlayer) then return false end
    local sgz=getGroundPosition(x,y,z+1)
    local pedZOffset=(sgz and sgz>0 and (z-sgz)>0.4 and (z-sgz)<1.6) and (z-sgz) or 1.0
    local anim=right<0 and "crouch_roll_l" or "crouch_roll_r"
    local heading=math.deg(math.atan2(-dx,dy))+(right<0 and -90 or 90)
    setElementRotation(localPlayer,0,0,heading,"default",true)
    if not setPedAnimation(localPlayer,"ped",anim,CombatConfig.rollDuration,false,true,false,false,150) then return false end
    local cx,cy,cz,tx,ty,tz,_,fov=getCameraMatrix()
    local sbx,sby,sbz=getPedBonePosition(localPlayer,3)
    local boneOffsetX = sbx and (sbx-x) or 0
    local boneOffsetY = sby and (sby-y) or 0
    state={
        tick=now,
        dx=dx,
        dy=dy,
        heading=heading,
        controls={},
        startX=x,
        startY=y,
        startZ=z,
        pedZOffset=pedZOffset,
        lastX=x,
        lastY=y,
        boneOffsetX=boneOffsetX,
        boneOffsetY=boneOffsetY,
        camera={cx-x,cy-y,cz-z,tx-cx,ty-cy,tz-cz,fov or 70}
    }
    for _,control in ipairs(controls) do
        state.controls[control]=isControlEnabled(control)
        toggleControl(control,false)
        setPedControlState(localPlayer,control,false)
    end
    last=now
    triggerServerEvent("gzl_combat:rollStart",localPlayer,anim)
    return true
end
function GZLRoll.update()
    if not state then return false end
    local elapsed = getTickCount()-state.tick
    if elapsed>=CombatConfig.rollDuration or not isPedOnGround(localPlayer) then
        GZLRoll.stop();return false
    end

    local curX, curY
    local bx, by = getPedBonePosition(localPlayer, 3)
    if bx and by then
        local bxRel = bx - state.boneOffsetX
        local byRel = by - state.boneOffsetY
        local distFromStart = math.sqrt((bxRel - state.startX)^2 + (byRel - state.startY)^2)
        if distFromStart > 0.05 then
            curX, curY = bxRel, byRel
        end
    end

    if not curX then
        local moveDuration = math.min(750, CombatConfig.rollDuration * 0.72)
        local progress = math.min(1, elapsed / moveDuration)
        local t = math.sin(progress * math.pi * 0.5)
        local dist = (CombatConfig.rollDistance or 2.5) * t
        curX = state.startX + state.dx * dist
        curY = state.startY + state.dy * dist
    end
    local curZ = state.startZ

    state.lastX = curX
    state.lastY = curY

    for _,offset in ipairs({-0.25,0,0.25}) do
        local sx,sy=curX-state.dy*offset,curY+state.dx*offset
        if not isLineOfSightClear(sx,sy,curZ-0.25,sx+state.dx*0.5,sy+state.dy*0.5,curZ-0.25,true,true,true,true,true,false,false,localPlayer) then
            GZLRoll.stop();return false
        end
    end

    local _,_,vz=getElementVelocity(localPlayer)
    setElementRotation(localPlayer,0,0,state.heading,"default",true)

    local c=state.camera
    local cx,cy,cz=curX+c[1],curY+c[2],curZ+c[3]
    local hit,hx,hy,hz=processLineOfSight(curX,curY,curZ+0.5,cx,cy,cz,true,true,false,true,true,false,false,false,localPlayer)
    if hit then
        local dx,dy,dz=cx-curX,cy-curY,cz-curZ-0.5
        local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
        if distance>0.001 then cx,cy,cz=hx-dx/distance*0.15,hy-dy/distance*0.15,hz-dz/distance*0.15 end
    end
    setCameraMatrix(cx,cy,cz,cx+c[4],cy+c[5],cz+c[6],0,c[7])
    return true
end
addEvent("gzl_combat:rollVisual",true)
addEventHandler("gzl_combat:rollVisual",root,function(anim)
    if source==localPlayer or not isElement(source) or getElementType(source)~="player" then return end
    if anim==false then clearAnimation(source)
    elseif anim=="crouch_roll_l" or anim=="crouch_roll_r" then
        setPedAnimation(source,"ped",anim,CombatConfig.rollDuration,false,true,false,false,150)
    end
end)