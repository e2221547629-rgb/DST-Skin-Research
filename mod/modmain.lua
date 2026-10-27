local G = GLOBAL
local Probe = require("dst_skin_probe")
local next_player = 0
local interval = GetModConfigData("poll_seconds")
if interval ~= 5 and interval ~= 10 and interval ~= 30 then interval = 10 end

-- TheWorld may not exist when modmain runs. Check inside the callback.
AddPlayerPostInit(function(inst)
    if G.TheWorld == nil or not G.TheWorld.ismastersim then return end
    if inst._dst_skin_probe ~= nil then return end
    next_player = next_player + 1
    local observer = Probe.new(G, inst, "p" .. next_player, function(line) G.print(line) end)
    inst._dst_skin_probe = observer
    if GetModConfigData("trace_methods") == true then observer:trace() end
    inst:DoTaskInTime(0, function() observer:safe_capture("join", true) end)
    local task = inst:DoPeriodicTask(interval, function() observer:safe_capture("poll", false) end)
    inst:ListenForEvent("onremove", function()
        if task ~= nil then task:Cancel() end
    end)
end)
