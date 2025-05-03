local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

---------------------------------------
-- aply in hands
---------------------------------------
-- Initialize player set comp
local PrimaryOrder = { "BARREL","GRIP","SIGHT","CLIP","MAG","STOCK","TUBE","TORCH_MATCHSTICK","GRIPSTOCK"}
local primaryIndex = {}
for i, cat in ipairs(PrimaryOrder) do
    primaryIndex[cat] = i
end

local function suffixPriority(cat)
    if cat:find("_TINT$") then return 5 end
    if cat:find("_ENGRAVING_MATERIAL$") then return 4 end
    if cat:find("_ENGRAVING$") then return 3 end
    if cat:find("_MATERIAL$") then return 2 end
    return 1
end

local function cmpCategories(a,b)
    local ia,ib = primaryIndex[a], primaryIndex[b]
    if ia and ib then          return ia < ib end
    if ia then                 return true end
    if ib then                 return false end
    local pa,pb = suffixPriority(a), suffixPriority(b)
    if pa~=pb then             return pa<pb end
    return a < b
end

local function getSortedKeys(t)
    local ks = {}
    for k in pairs(t) do ks[#ks+1]=k end
    table.sort(ks, cmpCategories)
    return ks
end

local function removeDuplicates(list)
    local seen, out = {}, {}
    for _, v in ipairs(list) do
        if not seen[v] then
            seen[v] = true
            out[#out+1] = v
        end
    end
    return out
end

local function applyAllComponents(wHash, components)
    local ped = PlayerPedId()
    for _, compName in ipairs(components) do
        local compHash = GetHashKey(compName)
        if not HasPedGotWeaponComponent(ped, wHash, compHash) then
            GiveWeaponComponentToPed(ped, wHash, compHash)
            ApplyShopItemToPed(ped, wHash, true, true, true)
        end
    end
    Citizen.InvokeNative(0x76A18844E743BF91, ped) -- REFRESH_WEAPON_VISUALS
end

local function applyPlayerWeaponComponent(ped, nextComp, wHash)
end

-----------------------
-- load components in hand
-----------------------
RegisterNetEvent("rsg-weaponcomp:client:reloadWeapon")
AddEventHandler("rsg-weaponcomp:client:reloadWeapon", function()
    local ped   = PlayerPedId()
    -- local wep = GetCurrentPedWeaponEntityIndex(ped, 0)
    local wHash = GetPedCurrentHeldWeapon(ped)
    if wHash == GetHashKey("WEAPON_UNARMED") then return end
    local serial = exports['rsg-weapons']:weaponInHands()[wHash]
    if not serial then return end

    RSGCore.Functions.TriggerCallback('rsg-weaponcomp:server:getPlayerWeaponComponents', function(data)
        local comps = data.components or {}
        comps = removeDuplicates(comps)

        local ordered = {}
        for _, cat in ipairs(getSortedKeys(comps)) do
            table.insert(ordered, comps[cat])
        end
        comps = ordered

        -- GiveWeaponToPed(ped, wHash, 0, false, true)
        SetCurrentPedWeapon(ped, wHash, true)
        applyAllComponents(wHash, comps)
    end, serial)
end)