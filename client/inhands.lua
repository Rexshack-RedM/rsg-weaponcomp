local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local UNARMED = `WEAPON_UNARMED`
local reloadingWeapon = false

local function isArmed(wHash)
    return wHash and wHash ~= 0 and wHash ~= UNARMED
end

local function attachComponent(ped, compHash, wHash)
    if compHash == 0 then return end
    local mdl = GetWeaponComponentTypeModel(compHash)
    local loaded = mdl and mdl ~= 0 and pcall(lib.requestModel, mdl, 1000)

    GiveWeaponComponentToEntity(ped, compHash, wHash, true)
    ApplyShopItemToPed(ped, compHash, true, true, true)

    if loaded then SetModelAsNoLongerNeeded(mdl) end
end

local function clearAllComponents(ped, wHash, available)
    for _, list in pairs(available) do
        for _, comp in ipairs(list) do
            RemoveWeaponComponentFromPed(ped, joaat(comp), wHash)
        end
    end
end

--- Saved modifications plus the factory part for every structural slot that wasn't modified,
--- so the weapon never ends up without its wood stock/grip/barrel after the clear.
local function buildLoadout(available, saved)
    local loadout = {}
    for cat, list in pairs(available) do
        if saved[cat] then
            loadout[cat] = saved[cat]
        elseif WeaponComp.IsFactoryCategory(cat) and list[1] then
            loadout[cat] = list[1]
        end
    end
    return loadout
end

local function applyLoadout(ped, wHash, loadout, finishesOnly)
    for _, cat in ipairs(WeaponComp.SortedKeys(loadout)) do
        if not finishesOnly or WeaponComp.Priority(cat) >= 20 then
            attachComponent(ped, joaat(loadout[cat]), wHash)
            if WeaponComp.Priority(cat) >= 20 then Wait(25) end
        end
    end
    Citizen.InvokeNative(0x76A18844E743BF91, ped) -- refresh ped visuals
end

--- force = true re-applies even when nothing is saved (after a reset, to strip old parts)
AddEventHandler('rsg-weaponcomp:client:reloadWeapon', function(force)
    if reloadingWeapon then return end
    reloadingWeapon = true

    local ped = cache.ped
    local wHash = GetPedCurrentHeldWeapon(ped)
    if not isArmed(wHash) then reloadingWeapon = false return end

    Wait(500) -- let rsg-weapons finish registering the weapon
    if GetPedCurrentHeldWeapon(ped) ~= wHash then reloadingWeapon = false return end

    local weaponName = GetWeaponNameFromHash(wHash)
    local serial = exports['rsg-weapons']:weaponInHands()[wHash] or tostring(wHash)

    RSGCore.Functions.TriggerCallback('rsg-weaponcomp:server:getPlayerWeaponComponents', function(result)
        local saved = result and result.components or {}
        if (not next(saved) and not force) or GetPedCurrentHeldWeapon(ped) ~= wHash or not HasPedGotWeapon(ped, wHash, false, false) then
            reloadingWeapon = false
            return
        end

        local available = GetAvailableComponents(weaponName, wHash)
        local loadout = buildLoadout(available, saved)

        clearAllComponents(ped, wHash, available)
        Wait(150)
        applyLoadout(ped, wHash, loadout)

        -- finishes sometimes don't stick on the first pass; re-apply them a few times
        for _ = 1, 3 do
            Wait(500)
            if GetPedCurrentHeldWeapon(ped) ~= wHash then break end
            applyLoadout(ped, wHash, loadout, true)
        end
        reloadingWeapon = false
    end, serial, weaponName)
end)
RegisterNetEvent('rsg-weaponcomp:client:reloadWeapon')

-- Re-apply components whenever the held weapon changes
CreateThread(function()
    local lastWeapon
    while true do
        Wait(500)
        local current = GetPedCurrentHeldWeapon(cache.ped)
        if isArmed(current) then
            if current ~= lastWeapon then
                lastWeapon = current
                TriggerEvent('rsg-weaponcomp:client:reloadWeapon')
            end
        else
            lastWeapon = nil
        end
    end
end)

----------------------------------------
-- Scope
----------------------------------------
local SCOPE_ANIM = { dict = 'mech_inspection@weapons@longarms@rifle_bolt_action@base', clip = 'aim_enter', duration = 2000 }

local function playScopeAnim(ped)
    if not pcall(lib.requestAnimDict, SCOPE_ANIM.dict, 2000) then return end
    TaskPlayAnim(ped, SCOPE_ANIM.dict, SCOPE_ANIM.clip, 8.0, -8.0, SCOPE_ANIM.duration, 0, 0, false, false, false)
    RemoveAnimDict(SCOPE_ANIM.dict)
end

local function getSavedScope(serial)
    for _, item in pairs(RSGCore.Functions.GetPlayerData().items or {}) do
        if item.info and tostring(item.info.serie) == tostring(serial) then
            return item.info.componentshash and item.info.componentshash.SCOPE
        end
    end
end

local function toggleScope(equip)
    local ped = cache.ped
    local wHash = GetPedCurrentHeldWeapon(ped)
    if not isArmed(wHash) then return end

    local serial = exports['rsg-weapons']:weaponInHands()[wHash]
    if not serial then return end

    local scopeName = getSavedScope(serial)
    if not scopeName then return end

    local cbName = equip and 'rsg-weaponcomp:server:equipScope' or 'rsg-weaponcomp:server:unequipScope'
    RSGCore.Functions.TriggerCallback(cbName, function(success)
        if not success or GetPedCurrentHeldWeapon(ped) ~= wHash then return end
        playScopeAnim(ped)
        if equip then
            attachComponent(ped, joaat(scopeName), wHash)
        else
            RemoveWeaponComponentFromPed(ped, joaat(scopeName), wHash)
        end
        lib.notify({ type = 'success', description = locale(equip and 'cl_scope_equipped_ok' or 'cl_scope_removed_ok') })
    end, serial)
end

RegisterCommand(Config.Commandequipscope, function() toggleScope(true) end, false)
RegisterCommand(Config.Commanddesequipscope, function() toggleScope(false) end, false)
