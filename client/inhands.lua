local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- Orden y prioridades
local PrimaryOrder = { "BARREL","GRIP","SIGHT","CLIP","MAG","STOCK","TUBE","TORCH_MATCHSTICK","GRIPSTOCK" }
local primaryIndex = {}
for i,cat in ipairs(PrimaryOrder) do primaryIndex[cat]=i end
local function suffixPriority(cat)
    if cat:find("_TINT$")             then return 5 end
    if cat:find("_ENGRAVING_MATERIAL$") then return 4 end
    if cat:find("_ENGRAVING$")        then return 3 end
    if cat:find("_MATERIAL$")         then return 2 end
    return 1
end
local function cmpCategories(a,b)
    local ia,ib = primaryIndex[a], primaryIndex[b]
    if ia and ib then return ia<ib end
    if ia then return true end
    if ib then return false end
    return suffixPriority(a) < suffixPriority(b)
end
local function getSortedKeys(t)
    local ks = {}
    for k in pairs(t) do ks[#ks+1]=k end
    table.sort(ks, cmpCategories)
    return ks
end

local function attachComponent(ped, compHash, weaponHash)
    local mdl = GetWeaponComponentTypeModel(compHash)
    -- print(mdl, compHash, weaponHash )
    if mdl and mdl ~= 0 then
        lib.requestModel(mdl)
        while not HasModelLoaded(mdl) do Wait(100) end
    end

    if IsEntityAPed(ped) then
        GiveWeaponComponentToEntity(ped, compHash, weaponHash, true)
        ApplyShopItemToPed(ped, compHash, true, true, true)
    else
        GiveWeaponComponentToEntity(ped, compHash, -1, true)
    end

    if mdl and mdl ~= 0 then
        SetModelAsNoLongerNeeded(mdl)
    end
end

local function clearAllComponents(ped, weaponHash)
    local wName = Citizen.InvokeNative(0x89CF5FF3D363311E, weaponHash, Citizen.ResultAsString())
    local weaponType = GetWeaponType(weaponHash)

    if Config.Shared[weaponType] then
        for _, list in pairs(Config.Shared[weaponType]) do
            for _, h in ipairs(list) do
                RemoveWeaponComponentFromPed(ped, h, weaponHash)
            end
        end
    end
    if Config.Specific[wName] then
        for _, list in pairs(Config.Specific[wName]) do
            for _, h in ipairs(list) do
                RemoveWeaponComponentFromPed(ped, h, weaponHash)
            end
        end
    end
end

RegisterNetEvent("rsg-weaponcomp:client:reloadWeapon")
AddEventHandler("rsg-weaponcomp:client:reloadWeapon", function()
    local ped     = PlayerPedId()
    local wHash   = GetPedCurrentHeldWeapon(ped)
    if wHash == GetHashKey("WEAPON_UNARMED") then return end

    local serial = exports['rsg-weapons']:weaponInHands()[wHash]
    if not serial then return end

    RSGCore.Functions.TriggerCallback('rsg-weaponcomp:server:getPlayerWeaponComponents', function(result)
        local comps = result and result.components or {}
        if not next(comps) then return end
        -- print(json.encode(comps))
        clearAllComponents(ped, wHash)

        for _, cat in ipairs(getSortedKeys(comps)) do
            local compName = comps[cat]

            if compName and compName ~= "" then
                local compHash = GetHashKey(compName)
                if compHash ~= 0 then
                    attachComponent(ped, compHash, wHash)
                end
            end
        end

        Citizen.InvokeNative(0x76A18844E743BF91, ped)
    end, serial)
end)