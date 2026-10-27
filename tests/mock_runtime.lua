package.path = "mod/scripts/?.lua;" .. package.path
local Probe = require("dst_skin_probe")
local count = 0
local function test(name, fn)
    fn()
    count = count + 1
    print("PASS " .. name)
end
local function eq(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
local function fixture()
    local lines, calls = {}, {}
    local clothes = {base = "wilson_none", body = "original_shirt", hand = "", legs = "", feet = ""}
    local skinner = {skintype = "normal_skin", GetClothing = function() return clothes end}
    local inst = {prefab = "wilson", userid = "PRIVATE_ID", components = {skinner = skinner},
        IsValid = function() return true end}
    local inv = {CheckClientOwnership = function(_, userid, item)
        calls[#calls + 1] = {userid, item}
        return item == "original_shirt"
    end}
    local g = {TheWorld = {ismastersim = true, prefab = "forest"}, TheInventory = inv}
    local p = Probe.new(g, inst, "p1", function(line) lines[#lines + 1] = line end)
    return p, g, inst, clothes, lines, calls, skinner
end
test("snapshot queries real inventory result and excludes raw user ID", function()
    local p, g, inst, clothes, lines, calls = fixture()
    assert(p:capture("join", true))
    eq(#calls, 1); eq(calls[1][1], inst.userid)
    assert(lines[1]:find("body_ownership=owned", 1, true))
    assert(lines[1]:find("base_ownership=default_not_queried", 1, true))
    assert(not lines[1]:find(inst.userid, 1, true))
end)
test("unchanged polls suppressed; ownership changes still observed", function()
    local p, g, inst, clothes, lines = fixture()
    p:capture("join", true); eq(p:capture("poll", false), false)
    g.TheInventory.CheckClientOwnership = function() return false end
    assert(p:capture("poll", false)); eq(#lines, 2)
    assert(lines[2]:find("body_ownership=not_owned", 1, true))
    eq(clothes.body, "original_shirt")
end)
test("missing world and client instance do nothing", function()
    local p, g, inst, clothes, lines, calls = fixture()
    g.TheWorld = nil; eq(p:safe_capture("poll", false), false)
    g.TheWorld = {ismastersim = false}; eq(p:capture("poll", false), false)
    eq(#lines, 0); eq(#calls, 0)
end)
test("missing user, inventory and failed query are distinct", function()
    local p, g, inst = fixture()
    inst.userid = nil; eq(p:ownership("x", "body"), "no_user")
    inst.userid = "PRIVATE_ID"; g.TheInventory = nil; eq(p:ownership("x", "body"), "unavailable")
    g.TheInventory = {CheckClientOwnership = function() error("offline") end}
    eq(p:ownership("x", "body"), "error")
    g.TheInventory.CheckClientOwnership = function() return nil end
    eq(p:ownership("x", "body"), "unknown")
end)
test("missing component, invalid entity and malformed clothing skip", function()
    local p, g, inst, clothes, lines, calls, skinner = fixture()
    inst.components.skinner = nil; eq(p:capture("poll", false), false)
    inst.components.skinner = skinner; inst.IsValid = function() return false end
    eq(p:capture("poll", false), false)
    inst.IsValid = nil; skinner.GetClothing = function() return nil end
    eq(p:capture("poll", false), false)
end)
test("skin changes and log delimiters are encoded", function()
    local p, g, inst, clothes, lines = fixture()
    clothes.body = "original\tshirt\n=test"
    p:capture("poll", false)
    assert(lines[1]:find("original%09shirt%0A%3Dtest", 1, true))
end)
test("observer errors are isolated", function()
    local p = fixture(); p.emit = function() error("log failure") end
    eq(p:safe_capture("poll", true), false)
end)
test("method trace preserves self, arguments and nil return slots", function()
    local p, g, inst, clothes, lines, calls, skinner = fixture()
    local invoked = 0
    skinner.SetSkinName = function(self, a, b)
        eq(self, skinner); eq(a, "allowed"); eq(b, false); invoked = invoked + 1
        return nil, "ok", nil, 9, nil
    end
    p:trace(); p:trace()
    local function pack(...) return {n = select("#", ...), ...} end
    local result = pack(skinner:SetSkinName("allowed", false))
    eq(result.n, 5); eq(result[2], "ok"); eq(result[4], 9); eq(invoked, 1)
    eq(#lines, 1)
end)
test("original method error propagates unchanged", function()
    local p, g, inst, clothes, lines, calls, skinner = fixture()
    local sentinel = {}
    skinner.OnLoad = function() error(sentinel) end
    p:trace(); local ok, err = pcall(skinner.OnLoad, skinner, {})
    eq(ok, false); eq(err, sentinel); eq(#lines, 0)
end)
test("trace cannot turn logger failure into game failure", function()
    local p, g, inst, clothes, lines, calls, skinner = fixture()
    skinner.SetSkinMode = function() return 42 end
    p.emit = function() error("logger") end
    p:trace(); eq(skinner:SetSkinMode(), 42)
end)
test("modmain tolerates world absent during module loading", function()
    local callbacks = {}
    local env = setmetatable({GLOBAL = {}, GetModConfigData = function() return false end,
        AddPlayerPostInit = function(fn) callbacks[#callbacks + 1] = fn end}, {__index = _G})
    local chunk = assert(loadfile("mod/modmain.lua")); setfenv(chunk, env); chunk()
    eq(#callbacks, 1); callbacks[1]({}); eq(env.GLOBAL.TheWorld, nil)
end)
test("modmain schedules once and cancels periodic task on removal", function()
    local p, g, inst, clothes, lines = fixture()
    local callback, periodic, immediate, remove, cancelled, period
    g.print = function(line) lines[#lines + 1] = line end
    local env = setmetatable({GLOBAL = g, GetModConfigData = function() return false end,
        AddPlayerPostInit = function(fn) callback = fn end}, {__index = _G})
    local chunk = assert(loadfile("mod/modmain.lua")); setfenv(chunk, env); chunk()
    inst.DoTaskInTime = function(_, delay, fn) eq(delay, 0); immediate = fn end
    inst.DoPeriodicTask = function(_, delay, fn)
        period = delay; periodic = fn; return {Cancel = function() cancelled = true end}
    end
    inst.ListenForEvent = function(_, event, fn) eq(event, "onremove"); remove = fn end
    callback(inst); local observer = inst._dst_skin_probe; callback(inst)
    eq(inst._dst_skin_probe, observer); eq(period, 10)
    immediate(); periodic(); eq(#lines, 1); remove(); eq(cancelled, true)
end)
print("mock runtime: " .. count .. " tests passed (not a DST session)")
