CylexCamera = {}

local active = false
local selfie = false
local yaw, pitch, zoom = 0, 0, 1
local originalTarget, originalMatrix
local originalControls = {}
local sources = {}
local pending
local encodeTimer
local previewSource, previewShader, viewport
local previewSampled = false
local screenWidth, screenHeight = guiGetScreenSize()
local controls = { "fire", "aim_weapon", "action", "next_weapon", "previous_weapon" }

local function updateCamera()
    if not active then return end
    local x, y, z = getPedBonePosition(localPlayer, 8)
    if not x then
        x, y, z = getElementPosition(localPlayer)
        z = z + 0.75
    end
    local horizontal = math.cos(pitch)
    local dx, dy, dz = -math.sin(yaw) * horizontal, math.cos(yaw) * horizontal, math.sin(pitch)
    local cx, cy, cz, tx, ty, tz
    if selfie then
        local distance = 1.25
        cx, cy, cz = x + dx * distance, y + dy * distance, z + dz * distance + 0.08
        tx, ty, tz = x, y, z - 0.18
        local hit, hx, hy, hz = processLineOfSight(x, y, z, cx, cy, cz, true, true, false, true, false, false, false, false, localPlayer)
        if hit then
            cx, cy, cz = hx - dx * 0.12, hy - dy * 0.12, hz - dz * 0.12
        end
    else
        cx, cy, cz = x + dx * 0.2, y + dy * 0.2, z + 0.08
        tx, ty, tz = cx + dx * 100, cy + dy * 100, cz + dz * 100
    end
    setCameraMatrix(cx, cy, cz, tx, ty, tz, 0, 70 / zoom)
end

local function sampleFrame()
    if viewport and isElement(previewSource) then
        previewSampled = dxUpdateScreenSource(previewSource, true)
    end
    if pending and not pending.sampled and isElement(pending.texture) then
        pending.sampled = dxUpdateScreenSource(pending.texture, true)
    end
end

local function finishFrame()
    if not pending then return end
    if not pending.sampled and getTickCount() - pending.started < 2500 then return end
    local request = pending
    pending = nil
    if isTimer(encodeTimer) then killTimer(encodeTimer) end
    encodeTimer = nil
    local pixels = request.sampled and dxGetTexturePixels(request.texture)
    local jpeg = pixels and dxConvertPixels(pixels, "jpeg", request.quality)
    local encoded = jpeg and encodeString("base64", jpeg)
    if encoded then
        request.callback("data:image/jpeg;base64," .. encoded)
    else
        request.callback(false, "camera_capture_failed")
    end
end

function CylexCamera.start()
    if active then return true end
    if isPedDead(localPlayer) then return false end
    originalTarget = getCameraTarget()
    originalMatrix = { getCameraMatrix() }
    local _, _, rotation = getElementRotation(localPlayer)
    yaw, pitch, zoom = math.rad(rotation), 0, 1
    selfie = false
    previewShader = dxCreateShader("components/camera-preview.fx")
    if previewShader then
        local width = math.min(screenWidth, 1920)
        previewSource = dxCreateScreenSource(width, math.floor(width * screenHeight / screenWidth))
        if previewSource then dxSetShaderValue(previewShader, "ScreenTexture", previewSource) end
    end
    for _, control in ipairs(controls) do
        originalControls[control] = isControlEnabled(control)
        toggleControl(control, false)
    end
    active = true
    addEventHandler("onClientPreRender", root, updateCamera)
    addEventHandler("onClientHUDRender", root, sampleFrame, true, "high+100")
    updateCamera()
    return true
end

function CylexCamera.stop()
    if not active then return end
    active = false
    removeEventHandler("onClientPreRender", root, updateCamera)
    removeEventHandler("onClientHUDRender", root, sampleFrame)
    if isTimer(encodeTimer) then killTimer(encodeTimer) end
    encodeTimer = nil
    local request = pending
    pending = nil
    for _, texture in pairs(sources) do
        if isElement(texture) then destroyElement(texture) end
    end
    sources = {}
    if isElement(previewSource) then destroyElement(previewSource) end
    if isElement(previewShader) then destroyElement(previewShader) end
    previewSource, previewShader, viewport = nil, nil, nil
    previewSampled = false
    for control, enabled in pairs(originalControls) do toggleControl(control, enabled) end
    originalControls = {}
    if isElement(originalTarget) then
        setCameraTarget(originalTarget)
    elseif originalMatrix and originalMatrix[1] then
        setCameraMatrix(unpack(originalMatrix))
    else
        setCameraTarget(localPlayer)
    end
    originalTarget, originalMatrix = nil, nil
    if request then request.callback(false, "camera_closed") end
end

function CylexCamera.capture(photo, callback)
    if not active then callback(false, "camera_closed") return end
    if pending then callback(false, "camera_busy") return end
    local width = math.min(screenWidth, photo and 1920 or 640)
    local texture = sources[width]
    if not isElement(texture) then
        texture = dxCreateScreenSource(width, math.floor(width * screenHeight / screenWidth))
        sources[width] = texture
    end
    if not texture then callback(false, "camera_texture_failed") return end
    pending = { texture = texture, quality = photo and 90 or 65, callback = callback, started = getTickCount(), sampled = false }
    encodeTimer = setTimer(finishFrame, 50, 0)
end

function CylexCamera.setViewport(data)
    if not active or not isElement(previewShader) or not isElement(previewSource) then return end
    if data.visible == false then viewport = nil return end
    local x, y, width, height = tonumber(data.x), tonumber(data.y), tonumber(data.width), tonumber(data.height)
    if not x or not y or not width or not height or width <= 0 or height <= 0 or width > screenWidth * 2 or height > screenHeight * 2 then return end
    local clip = data.clip
    if type(clip) ~= "table" or #clip ~= 4 then return end
    for i = 1, 4 do if type(clip[i]) ~= "number" then return end end
    viewport = { x = x, y = y, width = width, height = height, alpha = math.max(0, math.min(1, tonumber(data.alpha) or 1)) }
    local aspect = width / height
    local screenAspect = screenWidth / screenHeight
    dxSetShaderValue(previewShader, "DrawSize", width, height)
    dxSetShaderValue(previewShader, "ClipRect", clip[1] - x, clip[2] - y, clip[3], clip[4])
    dxSetShaderValue(previewShader, "ClipRadius", math.max(0, tonumber(data.radius) or 0))
    dxSetShaderValue(previewShader, "CameraRadius", math.max(0, tonumber(data.cameraRadius) or 0))
    dxSetShaderValue(previewShader, "CropScale", math.min(1, aspect / screenAspect), math.min(1, screenAspect / aspect))
    local colors = data.colors
    if type(colors) == "table" and #colors == 12 then
        for i = 1, 12 do if type(colors[i]) ~= "number" then return end end
        dxSetShaderValue(previewShader, "ColorR", colors[1], colors[2], colors[3], colors[4])
        dxSetShaderValue(previewShader, "ColorG", colors[5], colors[6], colors[7], colors[8])
        dxSetShaderValue(previewShader, "ColorB", colors[9], colors[10], colors[11], colors[12])
    end
end

function CylexCamera.draw()
    if not active or not viewport or not previewSampled or not isElement(previewShader) then return end
    dxDrawImage(viewport.x, viewport.y, viewport.width, viewport.height, previewShader, 0, 0, 0, tocolor(255, 255, 255, viewport.alpha * 255), true)
end

function CylexCamera.handle(endpoint, data)
    if endpoint == "camera:enter" then
        local success = CylexCamera.start()
        return { success = success, nativePreview = isElement(previewShader) and isElement(previewSource), selfie = selfie }
    end
    if endpoint == "camera:close" then CylexCamera.stop() return { success = true } end
    if not active then return { success = false, error = "camera_closed" } end
    if endpoint == "camera:frontCam" then
        selfie = not selfie
        if isElement(previewShader) then dxSetShaderValue(previewShader, "Mirror", selfie and 1 or 0) end
        local _, _, rotation = getElementRotation(localPlayer)
        yaw, pitch = math.rad(rotation), 0
        updateCamera()
        return { success = true, selfie = selfie }
    end
    if endpoint == "camera:look" then
        local x, y = tonumber(data.x) or 0, tonumber(data.y) or 0
        yaw = yaw + math.rad(math.max(-30, math.min(30, x)))
        pitch = math.max(-1.1, math.min(1.1, pitch + math.rad(math.max(-20, math.min(20, y)))))
    elseif endpoint == "camera:zoom" then
        zoom = math.max(0.8, math.min(3, tonumber(data.zoom) or 1))
    elseif endpoint ~= "camera:changeCamera" and endpoint ~= "camera:changeEffect" and endpoint ~= "camera:landscape" then
        return { success = false, error = "unsupported_camera_action" }
    end
    return { success = true, selfie = selfie, zoom = zoom }
end

addEventHandler("onClientResourceStop", resourceRoot, CylexCamera.stop)