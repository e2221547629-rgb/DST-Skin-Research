local Probe = {}
Probe.__index = Probe
local slots = {"base", "body", "hand", "legs", "feet"}
local function pack(...) return {n = select("#", ...), ...} end
local function escape(value)
    return (tostring(value):gsub("[^%w_%.:%-]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

function Probe.new(g, inst, label, emit)
    return setmetatable({g = g, inst = inst, label = label, emit = emit, seq = 0}, Probe)
end

function Probe:ownership(item, slot)
    if item == "" then return "empty" end
    if slot == "base" and item == self.inst.prefab .. "_none" then
        return "default_not_queried"
    end
    if self.inst.userid == nil or self.inst.userid == "" then return "no_user" end
    local inv = self.g.TheInventory
    if inv == nil or type(inv.CheckClientOwnership) ~= "function" then return "unavailable" end
    local ok, result = pcall(inv.CheckClientOwnership, inv, self.inst.userid, item)
    if not ok then return "error" end
    if result == true then return "owned" end
    if result == false then return "not_owned" end
    return "unknown"
end

function Probe:capture(event, force)
    local inst = self.inst
    if self.g.TheWorld == nil or not self.g.TheWorld.ismastersim then return false end
    if inst.IsValid ~= nil and not inst:IsValid() then return false end
    local skinner = inst.components and inst.components.skinner
    if skinner == nil or type(skinner.GetClothing) ~= "function" then return false end
    local clothes = skinner:GetClothing()
    if type(clothes) ~= "table" then return false end
    local fields = {"player=" .. escape(self.label), "prefab=" .. escape(inst.prefab),
        "mode=" .. escape(skinner.skintype or ""),
        "world=" .. escape(self.g.TheWorld.prefab or "unknown")}
    for _, slot in ipairs(slots) do
        local value = clothes[slot]
        if type(value) ~= "string" then value = "" end
        fields[#fields + 1] = slot .. "=" .. escape(value)
        fields[#fields + 1] = slot .. "_ownership=" .. self:ownership(value, slot)
    end
    local signature = table.concat(fields, "\t")
    if not force and self.last == signature then return false end
    self.seq = self.seq + 1
    self.emit("[DST-Skin-Probe]\tevent=" .. escape(event) .. "\tseq=" .. self.seq .. "\t" .. signature)
    self.last = signature
    return true
end

function Probe:safe_capture(event, force)
    -- Diagnostics failing must not fail a normal game method or periodic task.
    local ok, result = pcall(self.capture, self, event, force)
    return ok and result or false
end

function Probe:trace()
    local skinner = self.inst.components and self.inst.components.skinner
    if skinner == nil or self.traced then return end
    self.traced = true
    for _, method in ipairs({"SetSkinName", "SetSkinMode", "SetClothing", "OnLoad"}) do
        local original = skinner[method]
        if type(original) == "function" then
            local observer, event = self, method
            skinner[method] = function(component, ...)
                -- Never catch/replace the original error or change its return tuple.
                local result = pack(original(component, ...))
                observer:safe_capture(event .. "_complete", true)
                return unpack(result, 1, result.n)
            end
        end
    end
end

return Probe
