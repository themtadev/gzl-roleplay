PerfProbe = {}
local stages = {}
function PerfProbe.record(name, elapsed)
    local item = stages[name] or {count = 0, sum = 0, max = 0}
    item.count = item.count + 1
    item.sum = item.sum + elapsed
    item.max = math.max(item.max, elapsed)
    stages[name] = item
end

local frames, started, label
local function capture(dt)
    if not isMTAWindowFocused() then
        frames = nil
        removeEventHandler("onClientPreRender", root, capture)
        outputConsole("[PERF] Capture cancelled: focus lost.")
        return
    end
    if #frames < 60000 then frames[#frames + 1] = dt end
    if getTickCount() - started < 30000 and #frames < 60000 then return end
    removeEventHandler("onClientPreRender", root, capture)
    local sum, long = 0, 0
    for _, value in ipairs(frames) do sum = sum + value; if value > 16.67 then long = long + 1 end end
    table.sort(frames)
    outputConsole(string.format("[PERF %s] frames=%d FPS=%.1f mean=%.3fms p99=%.3fms >16.67ms=%d",
        label, #frames, #frames * 1000 / math.max(1, sum), sum / #frames,
        frames[math.max(1, math.ceil(#frames * 0.99))], long))
    frames = nil
end
addCommandHandler("perfbench", function(_, name)
    if frames then removeEventHandler("onClientPreRender", root, capture) end
    frames, started, label = {}, getTickCount(), tostring(name or "test")
    addEventHandler("onClientPreRender", root, capture)
    outputConsole("[PERF] 30 second capture started: " .. label)
end)
addCommandHandler("ramprofile", function()
    for name, item in pairs(stages) do
        outputConsole(string.format("[PERF] %s: n=%d avg=%.2fms max=%dms (1ms clock)",
            name, item.count, item.sum / item.count, item.max))
    end
end)