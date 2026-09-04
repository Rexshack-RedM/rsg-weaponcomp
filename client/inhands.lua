local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local reloadingWeapon = false

local WeaponTypeMap = {
    [GetHashKey('GROUP_REPEATER')] = "LONGARM",
    [GetHashKey('GROUP_SHOTGUN')] = "SHOTGUN",
    [GetHashKey('GROUP_PISTOL')] = "SHORTARM",
    [GetHashKey('GROUP_REVOLVER')] = "SHORTARM",
    [GetHashKey('GROUP_RIFLE')] = "LONGARM",
    [GetHashKey('GROUP_SNIPER')] = "LONGARM",
    [GetHashKey('GROUP_MELEE')] = "MELEE_BLADE",
    [GetHashKey('GROUP_BOW')] = "GROUP_BOW",
}

function GetWeaponType(hash)
    return WeaponTypeMap[GetWeapontypeGroup(hash)]
end

-- Component application order - this is CRITICAL
-- Base components first, then materials, then engravings, then tints, then wraps last
local function getComponentPriority(cat)
    if not cat then return 50 end
    local catUpper = cat:upper()
    
    -- Base structural components (applied first)
    if catUpper == "BARREL" then return 1 end
    if catUpper == "GRIP" then return 2 end
    if catUpper == "GRIPSTOCK" then return 3 end
    if catUpper == "STOCK" then return 4 end
    if catUpper == "SIGHT" then return 5 end
    if catUpper == "SCOPE" then return 6 end
    if catUpper == "CLIP" then return 7 end
    if catUpper == "MAG" then return 8 end
    if catUpper == "TUBE" then return 9 end
    if catUpper == "CYLINDER" then return 10 end
    if catUpper == "FRAME" then return 11 end
    if catUpper == "HAMMER" then return 12 end
    if catUpper == "TRIGGER" then return 13 end
    
    -- Rifling
    if catUpper:find("RIFLING") then return 20 end
    
    -- Materials (applied after base components)
    if catUpper:find("_MATERIAL") and not catUpper:find("ENGRAVING_MATERIAL") then return 30 end
    
    -- Engravings
    if catUpper:find("_ENGRAVING") and not catUpper:find("_MATERIAL") then return 40 end
    
    -- Engraving materials
    if catUpper:find("ENGRAVING_MATERIAL") then return 45 end
    
    -- Tints (but not wrap tints)
    if catUpper:find("_TINT") and not catUpper:find("WRAP") then return 50 end
    
    -- Base wrap (must be applied before wrap tint/material)
    if catUpper == "WRAP" then return 60 end
    
    -- Wrap material
    if catUpper == "WRAP_MATERIAL" then return 65 end
    
    -- Wrap tint (applied last)
    if catUpper == "WRAP_TINT" then return 70 end
    
    return 35 -- Default for unknown categories
end

local function getSortedComponentKeys(comps)
    local keys = {}
    for k in pairs(comps) do 
        keys[#keys + 1] = k 
    end
    table.sort(keys, function(a, b)
        return getComponentPriority(a) < getComponentPriority(b)
    end)
    return keys
end

-- Check if category is a visual component that might need reapplication
local function isVisualComponent(cat)
    if not cat then return false end
    local catUpper = cat:upper()
    return catUpper:find("_TINT") or 
           catUpper:find("WRAP") or 
           catUpper:find("_MATERIAL") or 
           catUpper:find("_ENGRAVING") or
           catUpper:find("COLOR") or
           catUpper:find("COLOUR")
end

local function attachComponent(ped, compHash, weaponHash)
    if compHash == 0 then return false end
    
    local mdl = GetWeaponComponentTypeModel(compHash)
    if mdl and mdl ~= 0 then
        lib.requestModel(mdl)
        local timeout = 0
        while not HasModelLoaded(mdl) and timeout < 100 do 
            Wait(10) 
            timeout = timeout + 1
        end
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
    
    return true
end

local function clearAllComponents(ped, weaponHash)
    local wName = Citizen.InvokeNative(0x89CF5FF3D363311E, weaponHash, Citizen.ResultAsString())
    local weaponType = GetWeaponType(weaponHash)

    if weaponType and Config.Shared and Config.Shared[weaponType] then
        for _, list in pairs(Config.Shared[weaponType]) do
            for _, h in ipairs(list) do
                local compHash = type(h) == "string" and GetHashKey(h) or h
                RemoveWeaponComponentFromPed(ped, compHash, weaponHash)
            end
        end
    end
    
    if wName and Config.Specific and Config.Specific[wName] then
        for _, list in pairs(Config.Specific[wName]) do
            for _, h in ipairs(list) do
                local compHash = type(h) == "string" and GetHashKey(h) or h
                RemoveWeaponComponentFromPed(ped, compHash, weaponHash)
            end
        end
    end
end

local function applyAllComponents(ped, wHash, comps)
    if not comps or not next(comps) then return end
    
    -- Get keys sorted by priority
    local sortedKeys = getSortedComponentKeys(comps)
    
   
    
    -- Apply all components in priority order with small delays for visual components
    for _, cat in ipairs(sortedKeys) do
        local compName = comps[cat]
        if compName and compName ~= "" then
            local compHash = GetHashKey(compName)
            if compHash ~= 0 then
               
                attachComponent(ped, compHash, wHash)
                
                -- Small delay after visual components to let them apply
                if isVisualComponent(cat) then
                    Wait(50)
                end
            end
        end
    end
    
    -- Force refresh the weapon appearance
    Wait(100)
    Citizen.InvokeNative(0x76A18844E743BF91, ped)
end

local function reapplyVisualComponents(ped, wHash, comps)
    if not comps or not next(comps) then return end
    
    -- Get sorted keys for visual components only
    local sortedKeys = getSortedComponentKeys(comps)
    
    for _, cat in ipairs(sortedKeys) do
        local compName = comps[cat]
        if compName and compName ~= "" and isVisualComponent(cat) then
            local compHash = GetHashKey(compName)
            if compHash ~= 0 then
                GiveWeaponComponentToEntity(ped, compHash, wHash, true)
                ApplyShopItemToPed(ped, compHash, true, true, true)
                Wait(25)
            end
        end
    end
    
    Citizen.InvokeNative(0x76A18844E743BF91, ped)
end

RegisterNetEvent("rsg-weaponcomp:client:reloadWeapon")
AddEventHandler("rsg-weaponcomp:client:reloadWeapon", function()
    if reloadingWeapon then return end
    reloadingWeapon = true
    
    
    
    local ped = PlayerPedId()
    local wHash = GetPedCurrentHeldWeapon(ped)
    
    if wHash == 0 or wHash == GetHashKey("WEAPON_UNARMED") then 
        reloadingWeapon = false
        return 
    end

    local weaponType = GetWeaponType(wHash)
    local isMeleeOrBow = (weaponType == 'MELEE_BLADE' or weaponType == 'GROUP_BOW')
    local serial = nil
    
    -- Wait for weapon to be fully registered
    Wait(500)
    
    -- Verify weapon is still equipped after wait
    local currentWeapon = GetPedCurrentHeldWeapon(ped)
    if currentWeapon ~= wHash or currentWeapon == 0 or currentWeapon == GetHashKey("WEAPON_UNARMED") then
        reloadingWeapon = false
        return
    end
    
    local inventorySerial = exports['rsg-weapons']:weaponInHands()[wHash]
    
    if inventorySerial then
        serial = inventorySerial
    elseif isMeleeOrBow then
        serial = tostring(wHash)
    else
        serial = tostring(wHash)
    end

  

    RSGCore.Functions.TriggerCallback('rsg-weaponcomp:server:getPlayerWeaponComponents', function(result)
       
        
        local comps = result and result.components or {}
        
        local count = 0
        for _ in pairs(comps) do count = count + 1 end
        if count == 0 then 
           
            reloadingWeapon = false
            return 
        end
        
       
        
        -- Verify weapon is still equipped and exists on ped
        local verifyWeapon = GetPedCurrentHeldWeapon(ped)
        if verifyWeapon ~= wHash then
          
            reloadingWeapon = false
            return
        end
        
        if not HasPedGotWeapon(ped, wHash) then
           
            reloadingWeapon = false
            return
        end
        
        -- Clear existing components first
       
        clearAllComponents(ped, wHash)
        
        Wait(150)
        
        -- Apply all components in correct order
        applyAllComponents(ped, wHash, comps)
        
        -- Retry mechanism: reapply visual components multiple times to ensure they stick
        CreateThread(function()
            for i = 1, 5 do
                Wait(500)
                local currentWeapon = GetPedCurrentHeldWeapon(ped)
                if currentWeapon == wHash and HasPedGotWeapon(ped, wHash) then
                   
                    reapplyVisualComponents(ped, wHash, comps)
                else
                   
                    break
                end
            end
            reloadingWeapon = false
            
        end)
    end, serial)
end)

-- Listen for weapon changes and reload components
CreateThread(function()
    local lastWeapon = nil
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local currentWeapon = GetPedCurrentHeldWeapon(ped)
        
        -- Check if weapon changed (and it's not unarmed)
        if currentWeapon ~= lastWeapon and currentWeapon ~= 0 and currentWeapon ~= GetHashKey("WEAPON_UNARMED") then
            lastWeapon = currentWeapon
            -- Delay to ensure weapon is fully initialized in rsg-weapons
            Wait(500)
            TriggerEvent("rsg-weaponcomp:client:reloadWeapon")
        elseif currentWeapon == 0 or currentWeapon == GetHashKey("WEAPON_UNARMED") then
            lastWeapon = nil
        end
    end
end)

RegisterCommand(Config.Commandequipscope, function()
    local ped = PlayerPedId()
    local wHash = GetPedCurrentHeldWeapon(ped)
    if wHash == GetHashKey("WEAPON_UNARMED") then return end

    local serial = exports['rsg-weapons']:weaponInHands()[wHash]
    if not serial then return end

    RSGCore.Functions.TriggerCallback('rsg-weaponcomp:server:equipScope', function(success)
        if success then
            local Player = RSGCore.Functions.GetPlayerData()
            for _, item in pairs(Player.items or {}) do
                if item.info and item.info.serie == serial then
                    local scopeName = item.info.componentshash and item.info.componentshash["SCOPE"]
                    if scopeName then
                        TriggerEvent('rsg-weaponcomp:client:equipScope', scopeName)
                        lib.notify({ type = 'success', description = locale('cl_scope_equipped_ok') })
                    end
                    break
                end
            end
        end
    end, serial)
end, false)

RegisterCommand(Config.Commanddesequipscope, function()
    local ped = PlayerPedId()
    local wHash = GetPedCurrentHeldWeapon(ped)
    if wHash == GetHashKey("WEAPON_UNARMED") then return end

    local serial = exports['rsg-weapons']:weaponInHands()[wHash]
    if not serial then return end

    RSGCore.Functions.TriggerCallback('rsg-weaponcomp:server:unequipScope', function(success)
        if success then
            local Player = RSGCore.Functions.GetPlayerData()
            for _, item in pairs(Player.items or {}) do
                if item.info and item.info.serie == serial then
                    local scopeName = item.info.componentshash and item.info.componentshash["SCOPE"]
                    if scopeName then
                        TriggerEvent('rsg-weaponcomp:client:unequipScope', scopeName)
                        lib.notify({ type = 'success', description = locale('cl_scope_removed_ok') })
                    end
                    break
                end
            end
        end
    end, serial)
end, false)

local anim = {
    Animation = true,
    AnimDict = "mech_inspection@weapons@longarms@rifle_bolt_action@base",
    AnimName = "aim_enter",
    AnimDuration = 2000
}

local function playScopeAnim(ped)
    lib.requestAnimDict(anim.AnimDict)
    TaskPlayAnim(ped,
        anim.AnimDict, anim.AnimName,
        8.0, -8.0,
        anim.AnimDuration or 1500,
        0, 0, false, false, false
    )
    RemoveAnimDict(anim.AnimDict)
end

RegisterNetEvent('rsg-weaponcomp:client:equipScope', function(scopeName)
    local ped = PlayerPedId()
    local wHash = GetPedCurrentHeldWeapon(ped)
    if wHash == GetHashKey("WEAPON_UNARMED") then return end
    local serial = exports['rsg-weapons']:weaponInHands()[wHash]
    if not serial then return end

    playScopeAnim(ped)

    local compHash = GetHashKey(scopeName)
    if compHash ~= 0 then
        attachComponent(ped, compHash, wHash)
    end
end)

RegisterNetEvent('rsg-weaponcomp:client:unequipScope', function(scopeName)
    local ped = PlayerPedId()
    local wHash = GetPedCurrentHeldWeapon(ped)
    if wHash == GetHashKey("WEAPON_UNARMED") then return end
    local serial = exports['rsg-weapons']:weaponInHands()[wHash]
    if not serial then return end

    playScopeAnim(ped)

    local compHash = GetHashKey(scopeName)
    if compHash ~= 0 then
        RemoveWeaponComponentFromPed(ped, compHash, wHash)
    end
end)