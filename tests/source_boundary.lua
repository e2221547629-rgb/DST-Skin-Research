-- Optional characterization of UNMODIFIED installed Lua functions.
-- Synthetic catalogs/inventory and native stubs; never a live account or game test.
local count = 0
local function test(name, fn)
    fn(); count = count + 1; print("PASS source: " .. name)
end
local function eq(a,b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
function table.contains(t, value)
    for _, x in pairs(t or {}) do if x == value then return true end end
    return false
end
function ExceptionArrays(list, exceptions)
    local out = {}; for _, x in ipairs(list) do
        if not table.contains(exceptions, x) then out[#out + 1] = x end
    end; return out
end
DST_CHARACTERLIST = {"testchar"}
MODCHARACTERLIST = {"original_character"}
MODCHARACTEREXCEPTIONS_DST = {}
SEAMLESSSWAP_CHARACTERLIST = {}
PREFAB_SKINS = {testchar = {"testchar_none", "owned_base"}}
local owned, queries, gameplay = {}, {}, true
TheInventory = {CheckClientOwnership = function(_, user, item)
    queries[#queries + 1] = {user, item}; return owned[item] == true
end}
function IsClothingItem(item) return item == "original_shirt" end
function InGamePlay() return gameplay end
local f = assert(io.open(".local-source/networking.lua", "rb"))
local networking = f:read("*a"); f:close()
local validation = assert(networking:match("(function ValidateSpawnPrefabRequest%(.-)\nend")) .. "\nend"
assert(loadstring(validation, "@local-networking-validation"))()
local function validate(base, body, prefab)
    return ValidateSpawnPrefabRequest("synthetic_user", prefab or "testchar", base, body or "", "", "", "", false)
end
test("default base skips ownership query", function()
    owned, queries = {}, {}; local prefab, base = validate("testchar_none")
    eq(prefab, "testchar"); eq(base, "testchar_none"); eq(#queries, 0)
end)
test("owned base must also belong to chosen character", function()
    owned = {owned_base = true, wrong_character = true}
    local _, base = validate("owned_base"); eq(base, "owned_base")
    _, base = validate("wrong_character"); eq(base, nil)
end)
test("unowned base rejected", function()
    owned = {}; local _, base = validate("owned_base"); eq(base, nil)
end)
test("clothing requires ownership and catalog membership", function()
    owned = {original_shirt = true, not_clothing = true}
    local _, _, body = validate("testchar_none", "original_shirt"); eq(body, "original_shirt")
    _, _, body = validate("testchar_none", "not_clothing"); eq(body, nil)
    owned = {}; _, _, body = validate("testchar_none", "original_shirt"); eq(body, nil)
end)
test("mod character does not use official base skin", function()
    owned = {owned_base = true}; local prefab, base = validate("owned_base", "", "original_character")
    eq(prefab, "original_character"); eq(base, nil)
end)
test("invalid character falls back", function()
    local prefab, base = validate("owned_base", "", "invalid"); eq(prefab, "testchar"); eq(base, nil)
end)
function Class(constructor)
    local cls = {}; cls.__index = cls
    return setmetatable(cls, {__call = function(_, ...)
        local obj = setmetatable({}, cls); constructor(obj, ...); return obj
    end})
end
Prefabs = {testchar_none = {skins = {normal_skin = "default_build"}},
    owned_base = {skins = {normal_skin = "original_build", ghost_skin = "original_ghost_build"}}}
CLOTHING_SYMBOLS = {}; HIDE_SYMBOLS = {}; SKIN_TYPES_THAT_RECEIVE_CLOTHING = {}
local Skinner = assert(loadfile(".local-source/components/skinner.lua"))()
local function fixture(userid)
    local order = {}
    local inst = {prefab = "testchar", userid = userid, components = {},
        AnimState = {SetSkin = function(_, build, fallback)
            order[#order+1] = {"anim", build, fallback}
        end, ClearSymbolExchanges = function() end},
        Network = {SetPlayerSkin = function(_, ...) order[#order+1] = {"network", ...} end}}
    local skinner = Skinner(inst); inst.components.skinner = skinner
    return skinner, order
end
test("SetSkinMode sends animation build then five skin identifiers", function()
    local s, order = fixture("synthetic_user")
    s:SetSkinName("owned_base", true, true); s:SetSkinMode("ghost_skin", "fallback")
    eq(order[1][1], "anim"); eq(order[1][2], "original_ghost_build"); eq(order[1][3], "fallback")
    eq(order[2][1], "network"); eq(order[2][2], "owned_base"); eq(#order[2], 6)
    eq(order[2][3], ""); eq(order[2][6], "")
end)
test("GetClothing includes base and returns a new table", function()
    local s = fixture("synthetic_user"); s:SetSkinName("owned_base", true, true)
    local clothes = s:GetClothing(); eq(clothes.base, "owned_base")
    clothes.body = "changed"; eq(s.clothing.body, "")
end)
test("in-game reload rejects no-longer-owned skin and clothing", function()
    gameplay, owned, queries = true, {}, {}
    local s = fixture("synthetic_user")
    s:OnLoad({skin_name = "owned_base", clothing = {body = "original_shirt", hand = "", legs = "", feet = ""}, skinoverrides = {}})
    eq(s.skin_name, "testchar_none"); eq(s.clothing.body, ""); eq(#queries, 2)
end)
test("in-game reload retains owned selections", function()
    gameplay, owned = true, {owned_base = true, original_shirt = true}
    local s = fixture("synthetic_user")
    s:OnLoad({skin_name = "owned_base", clothing = {body = "original_shirt"}, skinoverrides = {}})
    eq(s.skin_name, "owned_base"); eq(s.clothing.body, "original_shirt")
end)
test("snapshot restoration deliberately defers inventory validation", function()
    gameplay, owned, queries = false, {}, {}
    local s = fixture(nil)
    s:OnLoad({skin_name = "owned_base", clothing = {body = "original_shirt"}, skinoverrides = {}})
    eq(s.skin_name, "owned_base"); eq(s.clothing.body, "original_shirt"); eq(#queries, 0)
end)
test("gameplay without userid falls back base but defers clothing check", function()
    gameplay, owned, queries = true, {}, {}
    local s = fixture(nil)
    s:OnLoad({skin_name = "owned_base", clothing = {body = "original_shirt"}, skinoverrides = {}})
    eq(s.skin_name, "testchar_none"); eq(s.clothing.body, "original_shirt"); eq(#queries, 0)
end)
print("local source: " .. count .. " tests passed; all native methods were stubs")
