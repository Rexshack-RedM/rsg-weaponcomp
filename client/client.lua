local RSGCore = exports['rsg-core']:GetCoreObject()

-----------------------------------
-- PLAYER DATA LOGGIN / CHECK  
-----------------------------------
local currentHash = nil
local currentSerial = nil
local currentName = nil
local inStore = false

-- LIST POSSIBLES CATEGORYES
local readComponent = {Components.LanguageWeapons[1], Components.LanguageWeapons[7], Components.LanguageWeapons[5], Components.LanguageWeapons[10], Components.LanguageWeapons[41], Components.LanguageWeapons[11], Components.LanguageWeapons[36],  Components.LanguageWeapons[2], Components.LanguageWeapons[37], Components.LanguageWeapons[27], Components.LanguageWeapons[31], Components.LanguageWeapons[39], Components.LanguageWeapons[38]}
local readMaterial = {Components.LanguageWeapons[13], Components.LanguageWeapons[19], Components.LanguageWeapons[3], Components.LanguageWeapons[4], Components.LanguageWeapons[6], Components.LanguageWeapons[9], Components.LanguageWeapons[16], Components.LanguageWeapons[21], Components.LanguageWeapons[24], Components.LanguageWeapons[26], Components.LanguageWeapons[22],  Components.LanguageWeapons[23], Components.LanguageWeapons[32]}
local readEngraving = {Components.LanguageWeapons[14], Components.LanguageWeapons[20], Components.LanguageWeapons[40], Components.LanguageWeapons[17], Components.LanguageWeapons[15], Components.LanguageWeapons[12], Components.LanguageWeapons[42], Components.LanguageWeapons[33], Components.LanguageWeapons[8], Components.LanguageWeapons[34] }
local readTints = {Components.LanguageWeapons[18], Components.LanguageWeapons[23], Components.LanguageWeapons[25], Components.LanguageWeapons[28], Components.LanguageWeapons[29], Components.LanguageWeapons[30], Components.LanguageWeapons[35],}

---------------
-- BLOCK KEYS
---------------
CreateThread(function()
    while true do
        Wait(1)
        if inStore then
            DisableControlAction(0, 0x295175BF, true) -- Disable break
            DisableControlAction(0, 0x6E9734E8, true) -- Disable suicide
            DisableControlAction(0, 0xD8F73058, true) -- Disable aiminair
            DisableControlAction(0, 0x4CC0E2FE, true) -- B key
            DisableControlAction(0, 0xDE794E3E, true) -- Cover
            DisableControlAction(0, 0x06052D11, true) -- Cover
            DisableControlAction(0, 0x5966D52A, true) -- Cover
            DisableControlAction(0, 0xCEFD9220, true) -- Cover
            DisableControlAction(0, 0xC75C27B0, true) -- Cover
            DisableControlAction(0, 0x41AC83D1, true) -- Cover
            DisableControlAction(0, 0xADEAF48C, true) -- Cover
            DisableControlAction(0, 0x9D2AEA88, true) -- Cover
            DisableControlAction(0, 0xE474F150, true) -- Cover
            DisableControlAction(0, 0xB2F377E8, true) -- Attack
            DisableControlAction(0, 0xC1989F95, true) -- Attack 2
            DisableControlAction(0, 0x07CE1E61, true) -- Melee Attack 1
            DisableControlAction(0, 0xF84FA74F, true) -- MOUSE2
            DisableControlAction(0, 0xCEE12B50, true) -- MOUSE3
            DisableControlAction(0, 0x8FFC75D6, true) -- Shift
            DisableControlAction(0, 0xD9D0E1C0, true) -- SPACE
            DisableControlAction(0, 0xF3830D8E, true) -- J
            DisableControlAction(0, 0x80F28E95, true) -- L
            DisableControlAction(0, 0xDB096B85, true) -- CTRL
            DisableControlAction(0, 0xE30CD707, true) -- R
            DisableControlAction(0, 0xAC4BD4F1, true) -- [OpenWheelMenu]
        end

        if not inStore then Wait(2000) end
    end
end)

-----------------------------------------
-- Open Creator Weapon 
-----------------------------------------
RegisterNetEvent('rsg-weaponcomp:client:OpenCreatorWeapon', function()
    local _, weaponHash = GetCurrentPedWeapon(cache.ped, true, 0, true)
    local weaponInHands = exports['rsg-weapons']:weaponInHands()
    local weaponName = Citizen.InvokeNative(0x89CF5FF3D363311E, weaponHash, Citizen.ResultAsString())
    local wepSerial = weaponInHands[weaponHash]
    local wep = GetCurrentPedWeaponEntityIndex(cache.ped, 0) -- Returns weaponObject

    currentHash = weaponHash
    currentSerial = wepSerial
    currentName = weaponName

    if currentHash == -1569615261  then lib.notify({ title = 'Item Needed', description = "You're not holding a weapon!", type = 'error', icon = 'fa-solid fa-gun', iconAnimation = 'shake', duration = 7000}) return end

    if wep ~= nil and wep ~= 0 then
        TriggerServerEvent("rsg-weaponcomp:server:check_comps") -- CHECK COMPONENTS EQUIPED
        Wait(100)
        mainCompMenu() -- ENTER MENU
    end
end)

-----------------------------------------
-- BASICS FUNTIONS COMPONENTS
-----------------------------------------
local ItemdatabaseFilloutItemInfo = function(ItemHash)
    local eventDataStruct = DataView.ArrayBuffer(8 * 8)
    local is_data_exists = Citizen.InvokeNative(0xFE90ABBCBFDC13B2, ItemHash, eventDataStruct:Buffer())
    if not is_data_exists then
        return false
    end
    return eventDataStruct
end

local ItemdatabaseGetBundleId = function(weaponHash)
    return Citizen.InvokeNative(0x891A45960B6B768A, weaponHash)
end

local ItemdatabaseGetBundleItemCount = function(boundleItemId, boundleInfo)
    return Citizen.InvokeNative(0x3332695B01015DF9, boundleItemId, boundleInfo)
end

local ItemdatabaseGetBundleItemInfo = function(boundleItemId, boundleInfoStruct, var0, weaponComponentStruct)
    return Citizen.InvokeNative(0x5D48A77E4B668B57, boundleItemId, boundleInfoStruct, var0, weaponComponentStruct)
end

local ItemHaveTag = function(weaponHash)
    return Citizen.InvokeNative(0xFF5FB5605AD56856, weaponHash, 1844906744, 1120943070)
end

local GetWeaponComponentTypeModel = function(weaponHash)
    return Citizen.InvokeNative(0x59DE03442B6C9598, weaponHash)
end

GiveWeaponComponentToEntity = function(ped, hash, weaponHash, unk)
    return Citizen.InvokeNative(0x74C9090FDD1BB48E, ped, hash, weaponHash, unk)
end

RemoveWeaponComponentFromPed = function(ped, hash, weaponHash)
    return Citizen.InvokeNative(0x19F70C4D80494FF8, ped, hash, weaponHash)
end

local RequestWeaponAsset = function(weaponHash)
    return Citizen.InvokeNative(0x72D4CB5DB927009C, weaponHash , -1 , 0)
end

local ItemdatabaseIsKeyValid = function(weaponHash, unk)
    return Citizen.InvokeNative(0x6D5D51B188333FD1, weaponHash , unk)
end

HasWeaponAssetLoaded = function(weaponHash)
    return Citizen.InvokeNative(0xFF07CF465F48B830, weaponHash)
end

local InventoryAddItemWithGuid = function(inventoryId, itemData, parentItem, itemHash, slotHash, amount, addReason)
    return Citizen.InvokeNative(0xCB5D11F9508A928D, inventoryId, itemData, parentItem, itemHash, slotHash, amount, addReason);
end

local InventoryEquipItemWithGuid = function(inventoryId , itemData , bEquipped)
    return Citizen.InvokeNative(0x734311E2852760D0, inventoryId , itemData , bEquipped)
end

local getGuidFromItemId = function(inventoryId, itemData, category, slotId)
    local outItem = DataView.ArrayBuffer(8 * 13)
    local success = Citizen.InvokeNative(0x886DFD3E185C8A89, inventoryId, itemData and itemData or 0, category, slotId, outItem:Buffer())
    return success and outItem or nil;
end

local addWeaponInventoryItem = function(hash, slotHash)
    local addReason = GetHashKey("ADD_REASON_DEFAULT");
    local inventoryId = 1; -- INVENTORY_SP_PLAYER

    local isValid = ItemdatabaseIsKeyValid(hash, 0)
    if not isValid then return false end

    local characterItem = getGuidFromItemId(inventoryId, nil, GetHashKey("CHARACTER"), 0xA1212100);
    if not characterItem then return false end

    local unkStruct = getGuidFromItemId(inventoryId, characterItem:Buffer(), 923904168, -740156546);
    if not unkStruct then return false end

    local weaponItem = getGuidFromItemId(inventoryId, unkStruct:Buffer(), currentName, -1591664384);
    if not weaponItem then return false end

    -- WE CANT DO SAME FOR WRAP TINT IDK WHY BUT WORKS WITHOUT THIS 
    local gripItem;
    if slotHash == 0x57575690 then
        gripItem = getGuidFromItemId(inventoryId, weaponItem:Buffer(), GetHashKey(hash), -1591664384);
      if not gripItem then return false end
    end

    local itemData = DataView.ArrayBuffer(8 * 13)

    local isAdded = InventoryAddItemWithGuid(inventoryId, itemData:Buffer(), (slotHash == 0x57575690) and gripItem:Buffer() or weaponItem:Buffer(), hash, slotHash, 1, addReason);
    if not  isAdded then return false end

    local equipped = InventoryEquipItemWithGuid(inventoryId, itemData:Buffer(), true);

    return equipped
end

local LoadModel = function(model)
    local time = 0
	if not IsModelInCdimage(model) then return false end

	if not HasModelLoaded(model) then
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(time) end
    end

	return true
end

-- local textureId = -1
-- local ApplyTextureWeapon = function(textureTarget, hash)
--     if textureId ~= -1 then
--         ClearPedTexture(textureId) -- Citizen.InvokeNative(0xB63B9178D0F58D82, -- reset texture
--         ReleaseTexture(textureId) -- Citizen.InvokeNative(0x6BEFAA907B076859, -- remove texture
--     end

--     while not IsTextureValid(textureId) do Wait(0) end -- Citizen.InvokeNative(0x31DC8D3F216D8509,  -- wait till texture fully loaded

--     UpdatePedTexture(textureId) -- Citizen.InvokeNative(0x92DAABA2C1C10B0E, -- update texture
--     ResetPedTexture(textureId) -- Citizen.InvokeNative(0x8472A1789478F82F, -- reset texture
--     ApplyTextureOnPed(textureTarget, GetHashKey(hash), textureId) -- Citizen.InvokeNative(0x0B46E25761519058, overlayTarget, GetHashKey("heads"), textureId) -- apply texture to current component in category "heads"
--     UpdatePedVariation(textureTarget, 0, 1, 1, 1, false) -- Citizen.InvokeNative(0xCC8CA3E88256E58F, overlayTarget, 0, 1, 1, 1, false); -- refresh ped components
-- end

local GetWeaponType = function(weaponHash)
    local weaponType = nil
    local groupHash = tonumber(GetWeapontypeGroup(weaponHash))

    if tonumber(`GROUP_REPEATER`) == groupHash then
        weaponType = 'LONGARM'
    elseif tonumber(`GROUP_SHOTGUN`) == groupHash then
        weaponType = 'SHOTGUN'
    elseif tonumber(`GROUP_HEAVY`) == groupHash then
        weaponType = 'LONGARM'
    elseif tonumber(`GROUP_RIFLE`) == groupHash then
        weaponType = 'LONGARM'
    elseif tonumber(`GROUP_SNIPER`) == groupHash then
        weaponType = 'LONGARM'
    elseif tonumber(`GROUP_REVOLVER`) == groupHash then
        weaponType = 'SHORTARM'
    elseif tonumber(`GROUP_PISTOL`) == groupHash then
        weaponType = 'SHORTARM'
    elseif tonumber(`GROUP_BOW`) == groupHash then
        weaponType = 'GROUP_BOW'
    elseif tonumber(`GROUP_MELEE`) == groupHash then
        weaponType = 'MELEE_BLADE'
    end

    return weaponType
end

local table_contains = function(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

-----------------------------------
-- APPLY COMPONENTS - Calculate Price
-----------------------------------
local svslot = nil

local ApplyToFirstWeaponComponent = function(hash)
    local _, weaponHash = GetCurrentPedWeapon(cache.ped, true, 0, true)
    local modelHash = GetWeaponComponentTypeModel(weaponHash)

    RequestWeaponAsset(weaponHash, 0, true)
    -- HasWeaponAssetLoaded(weaponHash)
    if modelHash and modelHash ~= 0 then
        if not HasModelLoaded(hash) then LoadModel(hash) end
        if HasModelLoaded(hash) then
            ItemdatabaseIsKeyValid(weaponHash, true)
            GiveWeaponComponentToEntity(cache.ped, hash, -1, true)
            SetModelAsNoLongerNeeded(hash) -- THE MODEL IS NO LONGER NEEDED

            Citizen.InvokeNative(0xD3A7B003ED343FD9, cache.ped, hash, true, true, true) -- ApplyShopItemToPed( -- RELOADING THE LIVE MODEL
        end
    else
        GiveWeaponComponentToEntity(cache.ped, hash, -1, true)
    end
end

local ApplyToSecondWeaponComponent = function(hash)
    local _, weaponHash = GetCurrentPedWeapon(cache.ped, true, 0, true)
    local modelHash = GetWeaponComponentTypeModel(weaponHash)
    -- local wep = GetObjectIndexFromEntityIndex(GetCurrentPedWeaponEntityIndex(cache.ped, 0)) -- Returns weaponObject

    RequestWeaponAsset(weaponHash, 0, true)
    -- HasWeaponAssetLoaded(weaponHash)

    if modelHash and modelHash ~= 0 then
        if not HasModelLoaded(hash) then LoadModel(hash) end
        if HasModelLoaded(hash) then
            ItemdatabaseIsKeyValid(weaponHash, true)
            GiveWeaponComponentToEntity(cache.ped,  hash, -1, true)
            SetModelAsNoLongerNeeded(hash)

            -- ApplyTextureWeapon(wep, hash) -- function for refresh texture 

            Citizen.InvokeNative(0xD3A7B003ED343FD9, cache.ped, hash, true, true, true)
        end
    else
        GiveWeaponComponentToEntity(cache.ped, hash, -1, true)
    end
end

local ApplyToThreeWeaponComponent = function(hash)
    local _, weaponHash = GetCurrentPedWeapon(cache.ped, true, 0, true)
    local modelHash = GetWeaponComponentTypeModel(weaponHash)
    local wep = GetObjectIndexFromEntityIndex(GetCurrentPedWeaponEntityIndex(cache.ped, 0))

    RequestWeaponAsset(weaponHash, 0, true)
    -- HasWeaponAssetLoaded(weaponHash)

    if modelHash and modelHash ~= 0 then
        if not HasModelLoaded(hash) then LoadModel(hash) end
        if HasModelLoaded(hash) then
            ItemdatabaseIsKeyValid(weaponHash, true)
            GiveWeaponComponentToEntity(cache.ped,  hash, -1, true)
            SetModelAsNoLongerNeeded(hash)

            -- ApplyTextureWeapon(wep, hash)

            Citizen.InvokeNative(0xD3A7B003ED343FD9, cache.ped, hash, true, true, true)
        end
    else
        GiveWeaponComponentToEntity(cache.ped,  hash, -1, true)
    end
end

local RemoveAllWeaponComponents = function()
    local _, weaponHash = GetCurrentPedWeapon(cache.ped, true, 0, true)
    local modelHash = GetWeaponComponentTypeModel(weaponHash)
    local weaponObject = GetCurrentPedWeaponEntityIndex(cache.ped, 0)
    local boundleInfoStruct = DataView.ArrayBuffer(8 * 8)
    boundleInfoStruct:SetInt32(0 * 8, 1)
    local weaponComponentStruct = DataView.ArrayBuffer(8 * 8)
    local boundleItemId = ItemdatabaseGetBundleId(currentHash)

    if Config.Debug then print('boundleItemId', boundleInfoStruct, weaponComponentStruct, boundleItemId) end

    if boundleItemId ~= 0 then
        local weaponComponentsCount = ItemdatabaseGetBundleItemCount(boundleItemId, boundleInfoStruct:Buffer())
        local var0 = 0

        if Config.Debug then print('remove', var0, weaponComponentsCount) end
        if weaponComponentsCount ~= false then
            while var0 < weaponComponentsCount do

                if ItemdatabaseGetBundleItemInfo(boundleItemId, boundleInfoStruct:Buffer(), var0, weaponComponentStruct:Buffer()) then

                    local itemInfoStruct = ItemdatabaseFilloutItemInfo(weaponComponentStruct:GetInt32(0 * 8))
                    if not itemInfoStruct then Wait(0) return end

                    local componentHash = itemInfoStruct:GetInt32(0 * 8)
                    local weaponModType = itemInfoStruct:GetInt32(2 * 8)

                    if weaponModType == GetHashKey("WEAPON_MOD") then

                        if not HasWeaponGotWeaponComponent(weaponObject, componentHash) then
                            if weaponModType == GetHashKey("WEAPON_DECORATION") then
                                if not HasWeaponGotWeaponComponent(weaponObject, componentHash) then Wait(0) return end
                                LoadModel(GetHashKey(componentHash))
                                RemoveWeaponComponentFromPed(weaponObject, GetHashKey(componentHash), -1)
                            end
                            return
                        end
                        LoadModel(GetHashKey(componentHash))
                        RemoveWeaponComponentFromPed(weaponObject, GetHashKey(componentHash), -1)
                    end
                    if weaponModType == GetHashKey("WEAPON_DECORATION") then
                        if not HasWeaponGotWeaponComponent(weaponObject, componentHash) then Wait(0) return end
                        LoadModel(GetHashKey(componentHash))
                        RemoveWeaponComponentFromPed(weaponObject, GetHashKey(componentHash), -1)
                    end
                end
                var0 = var0 + 1
            end
        end
    end

    Wait(100)
end

local ApplyToAllWeaponComponent = function(serial, selectedTable, slotHash)
    local _, weaponHash = GetCurrentPedWeapon(cache.ped, true, 0, true)
    local modelHash = GetWeaponComponentTypeModel(weaponHash)
    local weaponObject = GetCurrentPedWeaponEntityIndex(cache.ped, 0)

    for k, v in ipairs(selectedTable) do

        if modelHash and modelHash ~= 0 then
            if not HasModelLoaded(v) then LoadModel(GetHashKey(v)) end
        end

        if not DoesEntityExist(weaponObject) then
            while not DoesEntityExist(weaponObject) do
                Wait(100)
                weaponObject = GetCurrentPedWeaponEntityIndex(cache.ped, 0)
            end
        end

        local itemInfoStruct = ItemdatabaseFilloutItemInfo(v)
        local modType = itemInfoStruct:GetInt32(2 * 8)

        if Config.Debug then print('apply all ', serial, 'components ', json.encode(selectedTable)) print('hash ', v, 'slot ', slotHash) end
        if serial ~= nil then Wait(0) return end

        RemoveAllWeaponComponents()

        Wait(100)

        if modType == GetHashKey("WEAPON_MOD") then

            if not IsModelValid(v) then
                LoadModel(GetHashKey(v))
                if modType == GetHashKey("WEAPON_DECORATION") then
                    if not ItemHaveTag(v) and not HasWeaponGotWeaponComponent(weaponObject, v) then
                        addWeaponInventoryItem(v, slotHash)
                    end
                end
                return
            end

            LoadModel(GetHashKey(v))
            if not ItemHaveTag(v) and not HasWeaponGotWeaponComponent(weaponObject, v) then
                addWeaponInventoryItem(v, slotHash)
            end
        end

        Wait(100)

        if modType == GetHashKey("WEAPON_DECORATION") then
            LoadModel(GetHashKey(v))
            if not ItemHaveTag(v) and not HasWeaponGotWeaponComponent(weaponObject, v) then
                addWeaponInventoryItem(v, slotHash)
            end
        end
    end
end

local CalculatePrice = function(selectedTable)
    local priceComp = 0
    local priceMat = 0
    local priceEng = 0
    local priceTint = 0

    if selectedTable ~= nil then
        for category, hashname in pairs(selectedTable) do

            for weaponType, weapons in pairs(Components.weapons_comp_list) do
                for weaponName, categories in pairs(weapons) do
                    if categories[category] then
                        for _, component in ipairs(categories[category]) do
                            if component.hashname == hashname then
                                if component.price ~= nil then
                                    priceComp = priceComp + component.price
                                end
                            end
                        end
                    end
                end
            end

            for weaponType, categories in pairs(Components.SharedComponents) do
                if categories[category] then
                    for _, component in ipairs(categories[category]) do
                        if component.hashname == hashname then
                            if component.price ~= nil then
                                priceMat = priceMat + component.price
                            end
                        end
                    end
                end
            end

            for weaponType, categories in pairs(Components.SharedEngravingsComponents) do
                if categories[category] then
                    for _, component in ipairs(categories[category]) do
                        if component.hashname == hashname then
                            if component.price ~= nil then
                                priceEng = priceEng + component.price
                            end
                        end
                    end
                end
            end

            for weaponType, categories in pairs(Components.SharedTintsComponents) do
                if categories[category] then
                    for _, component in ipairs(categories[category]) do
                        if component.hashname == hashname then
                            if component.price ~= nil then
                                priceTint = priceTint + component.price
                            end
                        end
                    end
                end
            end
        end
    end

    if Config.Debug then print('totalprice', priceComp, priceMat, priceEng, priceTint) end

    local totalprice = 0
    Wait(0)
    totalprice = priceComp + priceMat + priceEng + priceTint
    Wait(0)
    return totalprice
end

-----------------------------------------
-- Serial weapon for take Slot inv
-----------------------------------------
RegisterNetEvent('rsg-weaponcomp:client:returnSlot')
AddEventHandler('rsg-weaponcomp:client:returnSlot', function(slot)
    svslot = slot
end)

-----------------------------------
-- LOAD COMP/MAT/ENG 
-----------------------------------
RegisterNetEvent("rsg-weaponcomp:client:LoadComponents") -- EQUIPED
AddEventHandler("rsg-weaponcomp:client:LoadComponents", function()
    local _, weaponHash = GetCurrentPedWeapon(cache.ped, true, 0, true)
    local weaponInHands = exports['rsg-weapons']:weaponInHands()
    local wepSerial = weaponInHands[weaponHash]

    local componentsSql = {}
    RSGCore.Functions.TriggerCallback('rsg-weapons:server:getweaponinfo', function(result)
        if result and #result > 0 then
            for i = 1, #result do
                componentsSql = json.decode(result[i].components)
            end
        end
    end, wepSerial)

    Wait(0)
    while next(componentsSql) == nil do Wait(100) end
    Wait(0)

    if Config.Debug then print( 'rsg-weaponcomp:client:LoadComponents"')  print('weaponHash: ', weaponHash, 'component: ', json.encode(componentsSql)) end

    for category, hashname in pairs(componentsSql) do

        if Config.Debug then print('for category, hashname in pairs(componentsSql) do: ', category, hashname) end

        if table_contains(readComponent, category)  then
            RemoveWeaponComponentFromPed(cache.ped, GetHashKey(hashname), -1)
            Wait(0)
            ApplyToFirstWeaponComponent(GetHashKey(hashname))
        end

        if table_contains(readMaterial, category) then
            RemoveWeaponComponentFromPed(cache.ped, GetHashKey(hashname), -1)
            Wait(0)
            ApplyToSecondWeaponComponent(GetHashKey(hashname))
        end

        if table_contains(readEngraving, category) then
            RemoveWeaponComponentFromPed(cache.ped, GetHashKey(hashname), -1)
            Wait(0)
            ApplyToThreeWeaponComponent(GetHashKey(hashname))
        end

        if table_contains(readTints, category) then
            RemoveWeaponComponentFromPed(cache.ped, GetHashKey(hashname), -1)
            Wait(0)
            ApplyToThreeWeaponComponent(GetHashKey(hashname))
        end
    end

    TriggerServerEvent('rsg-weaponcomp:server:slot', wepSerial)
    Wait(100)
    local slotHash = svslot
    ApplyToAllWeaponComponent(wepSerial, componentsSql, slotHash)

    componentsSql = nil
end)

RegisterNetEvent("rsg-weaponcomp:client:LoadComponents_selection") -- SELECTION
AddEventHandler("rsg-weaponcomp:client:LoadComponents_selection", function()
    local weaponInHands = exports['rsg-weapons']:weaponInHands()
    local _, weaponHash = GetCurrentPedWeapon(cache.ped, true, 0, true)
    local wepSerial = weaponInHands[weaponHash]

    local componentsPreSql
    componentsPreSql = componentsPreSql or {}

    RSGCore.Functions.TriggerCallback('rsg-weapons:server:getweaponinfo', function(result)
        if result and #result > 0 then
            for i = 1, #result do
                componentsPreSql = json.decode(result[i].components_before)
            end
        end
    end, wepSerial)

    Wait(0)
    while next(componentsPreSql) == nil do Wait(100) end
    Wait(0)

    if Config.Debug then print('do: ', json.encode(componentsPreSql)) end

    for category, hashname in pairs(componentsPreSql) do

        if Config.Debug then print('for category, hashname in pairs(componentsPreSql) do: ', category, hashname) end

        if table_contains(readComponent, category)  then
            RemoveWeaponComponentFromPed(cache.ped, GetHashKey(hashname), -1)
            Wait(0)
            LoadModel(GetHashKey(hashname))
            ApplyToFirstWeaponComponent(GetHashKey(hashname))
        end

        if table_contains(readMaterial, category) then
            RemoveWeaponComponentFromPed(cache.ped, GetHashKey(hashname), -1)
            Wait(0)
            LoadModel(GetHashKey(hashname))
            ApplyToSecondWeaponComponent(GetHashKey(hashname))
        end

        if table_contains(readEngraving, category) then
            RemoveWeaponComponentFromPed(cache.ped, GetHashKey(hashname), -1)
            Wait(0)
            LoadModel(GetHashKey(hashname))
            ApplyToThreeWeaponComponent(GetHashKey(hashname))
        end

        if table_contains(readTints, category) then
            RemoveWeaponComponentFromPed(cache.ped, GetHashKey(hashname), -1)
            Wait(0)
            LoadModel(GetHashKey(hashname))
            ApplyToThreeWeaponComponent(GetHashKey(hashname))
        end

    end

   TriggerEvent('rsg-weaponcomp:client:StartCam')
   componentsPreSql = nil

end)

-----------------------------------
-- MENU DATA -- MENU MAIN CUSTOM
-----------------------------------
MenuData = {}
if Config.MenuData == 'rsg-menubase' then
    TriggerEvent("rsg-menubase:getData", function(call)
        MenuData = call
    end)
elseif Config.MenuData == 'menu_base' then
    TriggerEvent("menu_base:getData", function(call)
        MenuData = call
    end)
end

local creatorCache = nil
local selectedComponents = nil
creatorCache = creatorCache or {}
selectedComponents = selectedComponents or {}

local YesselectedComponents = nil
YesselectedComponents = YesselectedComponents or {}
local NoselectedComponents = nil
NoselectedComponents = NoselectedComponents or {}

local mainWeaponCompMenus = {
    ["component"] = function() OpenComponentMenu() end,
    ["material"] = function() OpenMaterialMenu() end,
    ["engraving"] = function() OpenEngravingMenu() end,
    ["tints"] = function() OpenTintsMenu() end,
    ["applycommponent"] = function() ButtomApplyAllComponents() end,
    ["removecommponent"] = function() ButtomRemoveAllComponents() end
}

local PriceMenu = nil
local RemoveMenu = nil

-- MAIN MENU
mainCompMenu = function()
    MenuData.CloseAll()
    inStore = true
    LocalPlayer.state:set("inv_busy", true, true) -- BLOCK INVENTORY
    FreezeEntityPosition(cache.ped, true) -- BLOCK PLAYER

    RSGCore.Functions.TriggerCallback('rsg-weapons:server:getweaponinfo', function(result)
        if result and #result > 0 then
            for i = 1, #result do
                YesselectedComponents = json.decode(result[i].components_before)
                NoselectedComponents = json.decode(result[i].components)
            end
        end
    end, currentSerial)

    Wait(100)
    TriggerEvent('rsg-weaponcomp:client:StartCam') -- NEED START CAM

    if selectedComponents ~= nil then
        PriceMenu = tonumber(CalculatePrice(YesselectedComponents))
        RemoveMenu = tonumber(CalculatePrice(NoselectedComponents)) * Config.RemovePrice
    else
        PriceMenu = 0.0
        RemoveMenu = tonumber(CalculatePrice(NoselectedComponents)) * Config.RemovePrice -- (0 - 1) = 100% price custom
    end

    NoselectedComponents = nil
    YesselectedComponents = nil -- finish price mathematics

    local elements = {
        {label = 'Components', value = 'component',   desc = ""},
        {label = 'Materials',  value = 'material',   desc = ""},
        {label = 'Engravings', value = 'engraving',   desc = ""},
        {label = 'Tints', value = 'tints',   desc = ""},
        {label = 'Apply $'.. PriceMenu,  value = 'applycommponent',   desc = ""},
        {label = 'Remove $'..RemoveMenu, value = 'removecommponent',   desc = ""},
    }

    -- local labelWeapon =  RSGCore.Shared.Items['"'..currentName..'"'].label

    MenuData.Open('default', GetCurrentResourceName(), 'main_weapons_creator_menu', {  title = "Weapons Menu", subtext = 'Options ', align = "bottom-left", elements = elements, itemHeight = "4vh"
        }, function(data, menu)

            inStore = true -- BLOCK KEYS
            mainWeaponCompMenus[data.current.value](currentHash) -- MENU BUTTOMS
            TriggerServerEvent("rsg-weaponcomp:server:check_comps_selection")

        end, function(data, menu)

            menu.close()
            TriggerServerEvent("rsg-weaponcomp:server:removeComponents_selection", "DEFAULT", currentSerial) -- update SQL
            inStore = false -- BLOCK KEYS
            TriggerEvent('rsg-weaponcomp:client:ExitCam')
            Wait(100)

            TriggerServerEvent("rsg-weaponcomp:server:check_comps")

        end
    )
end

---------------------
-- COMP SUB MENU WITH OPTIONS
---------------------
OpenComponentMenu = function()
    TriggerServerEvent("rsg-weaponcomp:server:check_comps_selection")
    Wait(0)
    local elements = {}
    for _, weaponData in pairs(Components.weapons_comp_list) do
        if weaponData[currentName] then
            for category, componentList in pairs(weaponData[currentName]) do
                if next(componentList) ~= nil then
                    local minIndex = 0
                    local a = 1

                    elements[#elements+1] = {
                        label = category,
                        value = minIndex,
                        type = "slider",
                        min = minIndex,
                        max = #componentList,
                        category = category,
                        components = {},
                        id = a
                    }

                    a = a + 1
                    for _, component in ipairs(componentList) do
                        elements[#elements].components[#elements[#elements].components + 1] = {
                            label = component.title,
                            value = component.hashname or 0,
                            v = component.category_hashname,
                        }
                    end

                end
            end
        end
    end

    MenuData.Open('default', GetCurrentResourceName(), 'component_weapon_menu', { title = 'Custom Component', subtext = 'Options ' .. currentName, align = "bottom-left", elements = elements, itemHeight = "2vh",
        }, function(data, menu)

            if data.current then
                local selectedCategory = data.current.category
                local selectedValue = data.current.value
                local selectedDeleted = data.current.value + 1
                local selectedHash = nil

                if selectedValue == 0 then
                    selectedHash = data.current.components[selectedDeleted].value
                    if not selectedHash == 0 then

                        if selectedComponents[selectedCategory] ~= selectedHash then
                            selectedComponents[selectedCategory] = selectedHash
                        end

                        TriggerEvent("rsg-weaponcomp:client:update_selection", selectedComponents, currentSerial) -- updateSQL
                        return
                    else
                        selectedHash = 0
                    end
                else
                    selectedHash = data.current.components[selectedValue].value 
                end

                if creatorCache[selectedCategory] ~= selectedValue then
                    creatorCache[selectedCategory] = selectedValue
                end

                if selectedComponents[selectedCategory] ~= selectedHash then
                    selectedComponents[selectedCategory] = selectedHash
                end

                if Config.Debug then print( 'selected', selectedHash) end

                TriggerEvent("rsg-weaponcomp:client:update_selection", selectedComponents, currentSerial) 
            end
            menu.refresh()
        end, function(data, menu)
            menu.close()
            mainCompMenu() -- BACK MAIN MENU
        end
    )
end

OpenMaterialMenu = function()
    TriggerServerEvent("rsg-weaponcomp:server:check_comps_selection")
    Wait(0)
    local _, weaponHash = GetCurrentPedWeapon(cache.ped, true, 0, true)
    local weaponType = GetWeaponType(weaponHash)
    local componentModel = GetWeaponComponentTypeModel(weaponHash)
    local elements = {}

    for category, materialList in pairs(Components.SharedComponents[weaponType] ) do
        if next(materialList) ~= nil then
            local minIndex = 0
            local a = 1

            elements[#elements+1] = {
                label = category,
                value = minIndex,
                type = "slider",
                min = minIndex,
                max = #materialList,
                category = category,
                materials = {},
                id = a
            }

            a = a + 1
            for _, materialData in ipairs(materialList) do
                -- if componentModel ~= 0 and ItemdatabaseIsKeyValid(materialData.hashname, 0) then
                    elements[#elements].materials[#elements[#elements].materials + 1] = {
                        label = materialData.title,
                        value = materialData.hashname or 0,
                        v = materialData.category_hashname,
                    }
                -- end
            end
        end
    end

    MenuData.Open('default', GetCurrentResourceName(), 'material_weapon_menu', { title = 'Custom Materials', subtext = 'Options ' .. currentName, align = "bottom-left", elements = elements, itemHeight = "2vh",
        }, function(data, menu)
            if data.current then
                local selectedCategory = data.current.category
                local selectedValue = data.current.value
                local selectedDeleted = data.current.value + 1
                local selectedHash = nil

                if selectedValue == 0 then
                    selectedHash = data.current.materials[selectedDeleted].value
                    if not selectedHash == 0 then

                        if selectedComponents[selectedCategory] ~= selectedHash then
                            selectedComponents[selectedCategory] = selectedHash
                        end

                        TriggerEvent("rsg-weaponcomp:client:update_selection", selectedComponents, currentSerial) 
                        return
                    else
                        selectedHash = 0
                    end
                else
                    selectedHash = data.current.materials[selectedValue].value
                end

                if creatorCache[selectedCategory] ~= selectedValue then
                    creatorCache[selectedCategory] = selectedValue
                end

                if selectedComponents[selectedCategory]  ~= selectedHash then
                    selectedComponents[selectedCategory] = selectedHash
                end

                if Config.Debug then print( 'selected', selectedHash) end

                TriggerEvent("rsg-weaponcomp:client:update_selection", selectedComponents, currentSerial)
            end
            menu.refresh()

        end, function(data, menu)
            menu.close()
            mainCompMenu()
        end
    )
end

OpenEngravingMenu = function()
    TriggerServerEvent("rsg-weaponcomp:server:check_comps_selection")
    Wait(0)
    local _, weaponHash = GetCurrentPedWeapon(cache.ped, true, 0, true)
    local weaponType = GetWeaponType(weaponHash)
    local componentModel = GetWeaponComponentTypeModel(weaponHash)
    local elements = {}

    for category, engravingList in pairs(Components.SharedEngravingsComponents[weaponType]) do
        if next(engravingList) ~= nil then
            local minIndex = 0
            local a = 1

            elements[#elements+1] = {
                label = category,
                value = minIndex,
                type = "slider",
                min = minIndex,
                max = #engravingList,
                category = category,
                engravings = {},
                id = a
            }
            a = a + 1
            for _, engravingData in ipairs(engravingList) do
                -- if componentModel ~= 0 and  ItemdatabaseIsKeyValid(engravingData.hashname, 0) then
                    elements[#elements].engravings[#elements[#elements].engravings + 1] = {
                        label = engravingData.title,
                        value = engravingData.hashname or 0,
                        v = engravingData.category_hashname,
                    }
                -- end
            end
        end
    end

    MenuData.Open('default', GetCurrentResourceName(), 'engraving_weapon_menu', { title = 'Custom Engravings', subtext = 'Options ' .. currentName, align = "bottom-left", elements = elements, itemHeight = "2vh",
        }, function(data, menu)
            if data.current then
                local selectedCategory = data.current.category
                local selectedValue = data.current.value
                local selectedDeleted = data.current.value + 1
                local selectedHash = nil

                if selectedValue == 0 then
                    selectedHash = data.current.engravings[selectedDeleted].value
                    if not selectedHash == 0 then

                        if selectedComponents[selectedCategory] ~= selectedHash then
                            selectedComponents[selectedCategory] = selectedHash
                        end

                        TriggerEvent("rsg-weaponcomp:client:update_selection", selectedComponents, currentSerial)
                        return
                    else
                        selectedHash = 0
                    end
                else
                    selectedHash = data.current.engravings[selectedValue].value -- SELECT COMPONENTS
                end

                if creatorCache[selectedCategory] ~= selectedValue then
                    creatorCache[selectedCategory] = selectedValue
                end

                if selectedComponents[selectedCategory]  ~= selectedHash then
                    selectedComponents[selectedCategory] = selectedHash
                end

                if Config.Debug then print('selected', selectedHash) end

                TriggerEvent("rsg-weaponcomp:client:update_selection", selectedComponents, currentSerial)
            end
            menu.refresh()

        end, function(data, menu)
            menu.close()
            mainCompMenu()
        end
    )
end

OpenTintsMenu = function()
    local _, weaponHash = GetCurrentPedWeapon(cache.ped, true, 0, true)
    local weaponType = GetWeaponType(weaponHash)
    local componentModel = GetWeaponComponentTypeModel(weaponHash)
    local elements = {}

    for category, tintsList in pairs(Components.SharedTintsComponents[weaponType]) do
        if next(tintsList) ~= nil then

            local minIndex = 0
            local a = 1

            elements[#elements+1] = {
                label = category,
                value = minIndex,
                type = "slider",
                min = minIndex,
                max = #tintsList,
                category = category,
                tints = {},
                id = a
            }
            a = a + 1
            for _, tintsData in ipairs(tintsList) do
                -- if componentModel ~= 0 and ItemdatabaseIsKeyValid(tintsData.hashname, true) then
                    elements[#elements].tints[#elements[#elements].tints + 1] = {
                        label = tintsData.title,
                        value = tintsData.hashname or 0,
                        v = tintsData.category_hashname,
                    }
                -- end
            end
        end
    end

    MenuData.Open('default', GetCurrentResourceName(), 'tints_weapon_menu', { title = 'Custom tints', subtext = 'Options ' .. currentName, align = "bottom-left", elements = elements, itemHeight = "2vh",
        }, function(data, menu)

            if data.current then
                local selectedCategory = data.current.category
                local selectedValue = data.current.value
                local selectedDeleted = data.current.value + 1
                local selectedHash = nil

                if selectedValue == 0 then
                    selectedHash = data.current.tints[selectedDeleted].value
                    if not selectedHash == 0 then

                        if selectedComponents[selectedCategory] ~= selectedHash then
                            selectedComponents[selectedCategory] = selectedHash
                        end

                        TriggerEvent("rsg-weaponcomp:client:update_selection", selectedComponents, currentSerial)
                        return
                    else
                        selectedHash = 0
                    end
                else
                    selectedHash = data.current.tints[selectedValue].value
                end

                if creatorCache[selectedCategory] ~= selectedValue then
                    creatorCache[selectedCategory] = selectedValue
                end

                if selectedComponents[selectedCategory]  ~= selectedHash then
                    selectedComponents[selectedCategory] = selectedHash
                end

                if Config.Debug then print( 'selected', selectedHash) end

                TriggerEvent("rsg-weaponcomp:client:update_selection", selectedComponents, currentSerial)
            end
            menu.refresh()
        end,
        function(data, menu)
            menu.close()
            mainCompMenu()
        end
    )
end

-----------------------------------
-- UPDATE SELECTION
-----------------------------------
RegisterNetEvent('rsg-weaponcomp:client:update_selection')
AddEventHandler("rsg-weaponcomp:client:update_selection", function(selectedComp, serial)
    --local wepobject = GetCurrentPedWeaponEntityIndex(cache.ped, 0) -- Returns weaponObject
    if Config.Debug then print("Data update_selection send:", json.encode(selectedComp)) end

    TriggerServerEvent("rsg-weaponcomp:server:update_selection", selectedComp, serial)

    Wait(0)

    local selectedAdd = nil
    selectedAdd = selectedComp

    for category, component in ipairs(selectedAdd) do
        if table_contains(readComponent, category) then
            for i = 1, #selectedAdd do
                if selectedAdd[i] ~= 0 then LoadModel(GetHashKey(selectedAdd[i])) Wait(0) RemoveWeaponComponentFromPed(cache.ped, GetHashKey(selectedAdd[i]), -1) end
                ApplyToFirstWeaponComponent(GetHashKey(selectedAdd[i]))
                if selectedAdd[i] ~= 0 then SetModelAsNoLongerNeeded(GetHashKey(selectedAdd[i])) end
            end
            Citizen.InvokeNative(0xD3A7B003ED343FD9, cache.ped, GetHashKey(component), true, true, true)
            TriggerServerEvent("rsg-weaponcomp:server:update_selection", selectedAdd, serial)
        end
        if table_contains(readMaterial, category) then
            for i = 1, #selectedAdd do
                if selectedAdd[i] ~= 0 then LoadModel(GetHashKey(selectedAdd[i])) Wait(0) RemoveWeaponComponentFromPed(cache.ped, GetHashKey(selectedAdd[i]), -1) end
                ApplyToSecondWeaponComponent(GetHashKey(selectedAdd[i]))
                if selectedAdd[i] ~= 0 then SetModelAsNoLongerNeeded(GetHashKey(selectedAdd[i])) end
            end
            Citizen.InvokeNative(0xD3A7B003ED343FD9, cache.ped, GetHashKey(component), true, true, true)
            TriggerServerEvent("rsg-weaponcomp:server:update_selection", selectedAdd, serial)
        end
        if table_contains(readEngraving, category) then
            for i = 1, #selectedAdd do
                if selectedAdd[i] ~= 0 then LoadModel(GetHashKey(selectedAdd[i])) Wait(0) RemoveWeaponComponentFromPed(cache.ped, GetHashKey(selectedAdd[i]), -1) end
                ApplyToThreeWeaponComponent(GetHashKey(selectedAdd[i]))
                if selectedAdd[i] ~= 0 then SetModelAsNoLongerNeeded(GetHashKey(selectedAdd[i])) end
            end
            Citizen.InvokeNative(0xD3A7B003ED343FD9, cache.ped, GetHashKey(component), true, true, true)
            TriggerServerEvent("rsg-weaponcomp:server:update_selection", selectedAdd, serial)
        end
        if table_contains(readTints, category) then
            for i = 1, #selectedAdd do
                if selectedAdd[i] ~= 0 then LoadModel(GetHashKey(selectedAdd[i])) Wait(0) RemoveWeaponComponentFromPed(cache.ped, GetHashKey(selectedAdd[i]), -1) end
                ApplyToThreeWeaponComponent(GetHashKey(selectedAdd[i]))
                if selectedAdd[i] ~= 0 then SetModelAsNoLongerNeeded(GetHashKey(selectedAdd[i])) end
            end
            Citizen.InvokeNative(0xD3A7B003ED343FD9, cache.ped, GetHashKey(component), true, true, true)
            TriggerServerEvent("rsg-weaponcomp:server:update_selection", selectedAdd, serial)
        end
    end
end)

-----------------------------------
-- APPLY BUTTOM -- REMOVE BUTTOM
-----------------------------------
local c_zoom = 1.5
local c_offset = 0.15

ButtomApplyAllComponents = function ()
    EndCam()

    MenuData.CloseAll()
    local currentPrice = PriceMenu

    if currentSerial ~= nil and selectedComponents then

        if Config.Debug then print('currentPrice '.. currentPrice) end

        local options = {
            {   label = 'Do you want to proceed, sure?',
                type = 'select',
                options = {
                    { value = 'yes', label = 'Yes' },
                    { value = 'no', label = 'No' }
                },
                required = true,
            },
        }
        local input = lib.inputDialog('Custom cost '.. tonumber(currentPrice) .. '$', options)

        if not input then TriggerEvent('rsg-weaponcomp:client:ExitCam') return end
        if input[1] == 'no' then TriggerEvent('rsg-weaponcomp:client:ExitCam') return end

        if input[1] == 'yes' then

            TriggerServerEvent('rsg-weaponcomp:server:slot', currentSerial)
            TriggerServerEvent('rsg-weaponcomp:server:price', currentPrice)

            RemoveAllWeaponComponents()

            Wait(100)

            local slotHash = svslot
            TriggerServerEvent("rsg-weaponcomp:server:apply_weapon_components", selectedComponents, currentName, currentSerial)
            Wait(100)
            ApplyToAllWeaponComponent(currentSerial, selectedComponents, slotHash)
        end
    else
        TriggerEvent('rsg-weaponcomp:client:ExitCam')
    end
    currentPrice = nil
    PriceMenu = nil
end

ButtomRemoveAllComponents = function ()
    EndCam()

    MenuData.CloseAll()

    local currentRemove = RemoveMenu

    local options = {
        {   label = 'Do you want to proceed, sure?',
            type = 'select',
            options = {
                { value = 'yes', label = 'Yes' },
                { value = 'no', label = 'No' }
            },
            required = true,
        },
    }
    local input = lib.inputDialog('Remove custom cost '.. tonumber(currentRemove) .. '$', options)
    if not input then TriggerEvent('rsg-weaponcomp:client:ExitCam') return end
    if input[1] == 'no' then TriggerEvent('rsg-weaponcomp:client:ExitCam') return end

    if input[1] == 'yes' then
        TriggerServerEvent('rsg-weaponcomp:server:price', currentRemove)

        RemoveAllWeaponComponents()
        TriggerServerEvent("rsg-weaponcomp:server:removeComponents", "DEFAULT", currentName, currentSerial) -- update SQL
        TriggerServerEvent("rsg-weaponcomp:server:removeComponents_selection", "DEFAULT", currentSerial) -- update SQL
        Wait(100)
        TriggerServerEvent('rsg-weaponcomp:server:check_comps')
    end
    currentRemove = nil
    RemoveMenu = nil
end

-----------------------------------
-- UTILITYS -- CAMS
-----------------------------------
local playerHeading = nil
local weaponCamera = nil

StartCam = function(zoom, offset)
    DestroyAllCams(true)

    DisplayHud(false)
    DisplayRadar(false)

    local coords = GetEntityCoords(cache.ped)
    local zoomOffset = zoom
    local angle

    if playerHeading == nil then
        playerHeading = GetEntityHeading(cache.ped)
        angle = playerHeading * math.pi / 180.0
    else
        angle = playerHeading * math.pi / 180.0
    end

    local pos = {
        x = coords.x - (zoomOffset * math.sin(angle)),
        y = coords.y + (zoomOffset * math.cos(angle)),
        z = coords.z + offset
    }

    if not weaponCamera then

        DestroyAllCams(true)
        local camera_pos = GetObjectOffsetFromCoords(pos.x, pos.y, pos.z, 0.0, 1.0, 1.0, 1.0)

        weaponCamera = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", pos.x, pos.y, pos.z + 0.5, 300.00, 0.00, 0.00, 50.00, false, 0)
        local pCoords = GetEntityCoords(cache.ped)
        PointCamAtCoord(weaponCamera, pCoords.x, pCoords.y, pCoords.z + offset)

        SetCamActive(weaponCamera, true)
        RenderScriptCams(true, true, 1000, true, true)
        DisplayRadar(false)

    end
end

EndCam = function()
    RenderScriptCams(false, true, 1000, true, false)
    DisplayHud(true)
    DisplayRadar(true)
    DestroyAllCams(true)
    weaponCamera = nil
    playerHeading = nil
end

-----------------------------------
-- ANIMATIONS CAM
-----------------------------------
RegisterNetEvent('rsg-weaponcomp:client:StartCam')
AddEventHandler("rsg-weaponcomp:client:StartCam", function()
    local _, weaponHash = GetCurrentPedWeapon(cache.ped, true, 0, true)
    local weaponType = GetWeaponType(weaponHash)
    local interaction = nil
    local timeShop = 0

    while not HasCollisionLoadedAroundEntity(cache.ped) do Wait(0) end

    if IsWeaponOneHanded(currentHash) and weaponType == 'SHORTARM' then
        interaction = "SHORTARM_HOLD_ENTER"
    elseif IsWeaponOneHanded(currentHash) and weaponType == 'LONGARM' then
        interaction = "LONGARM_HOLD_ENTER"
    elseif IsWeaponOneHanded(currentHash) and weaponType == 'SHOTGUN' then
        interaction = "LONGARM_HOLD_ENTER"
    elseif IsWeaponOneHanded(currentHash) and weaponType == 'GROUP_BOW' then
    elseif IsWeaponOneHanded(currentHash) and weaponType == 'MELEE_BLADE' then
        interaction = "SHORTARM_HOLD_ENTER"
    end

    Wait(0)
    if currentHash ~= -1569615261 and interaction ~= nil then
        StartTaskItemInteraction(cache.ped, currentHash, GetHashKey(interaction), 0, 0, 0)
        while not IsPedRunningTaskItemInteraction(cache.ped) do
            Wait(timeShop)
        end
    end
end)

RegisterNetEvent("rsg-weaponcomp:client:animationSaved")
AddEventHandler("rsg-weaponcomp:client:animationSaved", function()
    local _, weaponHash = GetCurrentPedWeapon(cache.ped, true, 0, true)
    local weaponType = GetWeaponType(weaponHash)
    local boneIndex2 = GetEntityBoneIndexByName(cache.ped, "SKEL_L_Finger00")
    local Cloth = CreateObject(GetHashKey('s_balledragcloth01x'), GetEntityCoords(cache.ped), false, true, false, false, true)
    local animDict = nil
    local animName = nil

    if IsWeaponOneHanded(currentHash) and weaponType == 'SHORTARM' then
        animDict = "mech_inspection@weapons@shortarms@volcanic@base"
        animName = "clean_loop"
        c_zoom = 0.85
        c_offset = 0.10
    elseif IsWeaponOneHanded(currentHash) and weaponType == 'LONGARM' then
        animDict = "mech_inspection@weapons@longarms@sniper_carcano@base"
        animName = "clean_loop"
        c_zoom = 1.5
        c_offset = 0.20
    elseif IsWeaponOneHanded(currentHash) and weaponType == 'SHOTGUN' then
        animDict = "mech_inspection@weapons@longarms@shotgun_double_barrel@base"
        animName = "clean_loop"
        c_zoom = 1.2
        c_offset = 0.15
    elseif IsWeaponOneHanded(currentHash) and weaponType == 'GROUP_BOW' then
    elseif IsWeaponOneHanded(currentHash) and weaponType == 'MELEE_BLADE' then
    end

    Wait(100)
    AttachEntityToEntity(Cloth, cache.ped, boneIndex2, 0.02, -0.04, 0.00, 20.0, -25.0, 165.0, true, false, true, false, 0, true)
    StartCam(c_zoom, c_offset)

    Wait(100)
    if lib.progressCircle({
        duration = tonumber(Config.animationSave),
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disable = { move = true, car = true, combat= true, mouse= false, sprint = true, },
        anim = { dict = animDict, clip = animName, flag = 15, },
        -- prop = { model = GetHashKey('s_balledragcloth01x'), bone = GetHashKey("SKEL_L_Finger00"), pos = vec3(0.02, -0.04, 0.00), rot = vec3(0.0, .0, -1.5) },
        label = 'Weapon Attachments.. ',
    }) then

        SetEntityAsNoLongerNeeded(Cloth)
        DeleteEntity(Cloth)
        TriggerEvent('rsg-weaponcomp:client:ExitCam')
        Wait(0)

        TriggerServerEvent("rsg-weaponcomp:server:check_comps")
    end

end)

RegisterNetEvent('rsg-weaponcomp:client:ExitCam')
AddEventHandler('rsg-weaponcomp:client:ExitCam', function()
    local _, weaponHash = GetCurrentPedWeapon(cache.ped, true, 0, true)
    local weaponType = GetWeaponType(weaponHash)
    local interaction = nil
    local timeShop = 0

    if IsWeaponOneHanded(currentHash) and weaponType == 'SHORTARM' then
        interaction = "SHORTARM_HOLD_EXIT"
    elseif IsWeaponOneHanded(currentHash) and weaponType == 'LONGARM' then
        interaction = "LONGARM_HOLD_EXIT"
    elseif IsWeaponOneHanded(currentHash) and weaponType == 'SHOTGUN' then
        interaction = "LONGARM_HOLD_EXIT"
    elseif IsWeaponOneHanded(currentHash) and weaponType == 'GROUP_BOW' then
    elseif IsWeaponOneHanded(currentHash) and weaponType == 'MELEE_BLADE' then
    end

    Wait(0)
    if currentHash ~= -1569615261 and interaction ~= nil then
        StartTaskItemInteraction(cache.ped, currentHash, GetHashKey(interaction), 0, 0, 0)
        while not IsPedRunningTaskItemInteraction(cache.ped) do
            Wait(timeShop)
        end
    end

    EndCam()
    Wait(0)

    DoScreenFadeOut(1000)
    Wait(0)
    DoScreenFadeIn(1000)
    FreezeEntityPosition(cache.ped, false)
    ClearPedTasks(cache.ped)
    ClearPedSecondaryTask(cache.ped)

    LocalPlayer.state:set("inv_busy", false, true)
    inStore = false

end)

-----------------------------------
-- UTILITYS -- INSPECTION
-----------------------------------
getWeaponStats = function(weaponHash)
    local emptyStruct = DataView.ArrayBuffer(256)
    local charStruct = DataView.ArrayBuffer(256)
    Citizen.InvokeNative(0x886DFD3E185C8A89, 1, emptyStruct:Buffer(), GetHashKey("CHARACTER"), -1591664384, charStruct:Buffer()) -- InventoryGetGuidFromItemid(

    local unkStruct = DataView.ArrayBuffer(256)
    Citizen.InvokeNative(0x886DFD3E185C8A89, 1, charStruct:Buffer(), 923904168, -740156546, unkStruct:Buffer())

    local weaponStruct = DataView.ArrayBuffer(256)
    Citizen.InvokeNative(0x886DFD3E185C8A89, 1, unkStruct:Buffer(), weaponHash, -1591664384, weaponStruct:Buffer())
    return weaponStruct:Buffer()
end

showstats = function()
    local _, weapon = GetCurrentPedWeapon(PlayerPedId(), true, 0, true)
    if weapon then
        local uiFlowBlock = RequestFlowBlock(GetHashKey("PM_FLOW_WEAPON_INSPECT"))
        local uiContainer = DatabindingAddDataContainerFromPath("" , "ItemInspection")
        Citizen.InvokeNative(0x46DB71883EE9D5AF, uiContainer, "stats", getWeaponStats(weapon), PlayerPedId())
        DatabindingAddDataString(uiContainer, "tipText", 'Weapon Information')
        DatabindingAddDataHash(uiContainer, "itemLabel", weapon)
        DatabindingAddDataBool(uiContainer, "Visible", true)

        Citizen.InvokeNative(0x10A93C057B6BD944, uiFlowBlock)
        Citizen.InvokeNative(0x3B7519720C9DCB45, uiFlowBlock, 0)
        Citizen.InvokeNative(0x4C6F2C4B7A03A266, -813354801, uiFlowBlock)
    end
end

RegisterNetEvent("rsg-weaponcomp:client:InspectionWeapon")
AddEventHandler("rsg-weaponcomp:client:InspectionWeapon", function()
    local retval, weaponHash = GetCurrentPedWeapon(PlayerPedId(), true, 0, true)
    local weaponType = GetWeaponType(weaponHash)
    local interaction
    local act
    local object = GetObjectIndexFromEntityIndex(GetCurrentPedWeaponEntityIndex(cache.ped, 0))
    local cleaning = false

    SetPedBlackboardBool(cache.ped, "GENERIC_WEAPON_CLEAN_PROMPT_AVAILABLE", true, -1) -- Citizen.InvokeNative(0xCB9401F918CB0F75, 

    if IsWeaponOneHanded(currentHash) and weaponType == 'SHORTARM' then
        interaction = "SHORTARM_HOLD_ENTER"
        act = GetHashKey("SHORTARM_CLEAN_ENTER")
    elseif IsWeaponOneHanded(currentHash) and weaponType == 'LONGARM' then
        interaction = "LONGARM_HOLD_ENTER"
        act = GetHashKey("LONGARM_CLEAN_ENTER")
    elseif IsWeaponOneHanded(currentHash) and weaponType == 'SHOTGUN' then
        interaction = "LONGARM_HOLD_ENTER"
        act = GetHashKey("LONGARM_CLEAN_ENTER")
    elseif IsWeaponOneHanded(currentHash) and weaponType == 'GROUP_BOW' then
    elseif IsWeaponOneHanded(currentHash) and weaponType == 'MELEE_BLADE' then
    end

    if weaponHash ~= -1569615261 then

        StartTaskItemInteraction(cache.ped, weaponHash, GetHashKey(interaction), 0,0,0)

        if Config.showStats then showstats() end
        while not Citizen.InvokeNative(0xEC7E480FF8BD0BED, cache.ped) do Wait(300) end

        while Citizen.InvokeNative(0xEC7E480FF8BD0BED, cache.ped) do
            Wait(1)

            if IsDisabledControlJustReleased(0, 3002300392) then
                ClearPedTasks(cache.ped, 1, 1)
                Citizen.InvokeNative(0x4EB122210A90E2D8, -813354801) -- UiStateMachineDestroy(
            end

            if IsDisabledControlJustReleased(0, 3820983707) and not cleaning then
                cleaning = true
                local Cloth= CreateObject(GetHashKey('s_balledragcloth01x'), GetEntityCoords(cache.ped), false, true, false, false, true)
                local PropId = GetHashKey("CLOTH")
                Citizen.InvokeNative(0x72F52AA2D2B172CC, cache.ped, 1242464081, Cloth, PropId, act, 1, 0, -1.0) -- TaskItemInteraction2
                Wait(9500)
                ClearPedTasks(cache.ped, 1, 1)

                if Config.showStats then
                    Citizen.InvokeNative(0x4EB122210A90E2D8, -813354801)
                    Citizen.InvokeNative(0xA7A57E89E965D839, object, 0.0, 0) -- SetWeaponDegradation(
                    Citizen.InvokeNative(0x812CE61DEBCAB948, object, 0.0, 0) -- SetWeaponDirt(
                end

                break
            end

        end

        if Config.showStats then Citizen.InvokeNative(0x4EB122210A90E2D8, -813354801) end
    end
end)

-----------------------------------
-- UTILITYS -- CHANGE DAMAGE -- Damage
-----------------------------------
--[[ 
RegisterCommand('w_damage', function(source, args, rawCommand)
    -- local player = PlayerPedId()
    -- weaponHash = Citizen.InvokeNative(0x8425C5F057012DAB, player)
    local damageModifier = GetWeaponComponentDamageModifier(GetHashKey('COMPONENT_REVOLVER_CATTLEMAN_BARREL_LONG'))
    if Config.Debug then
        print(currentHash, damageModifier)
    end
end, false)

RegisterCommand('w_damage', function(source, args, rawCommand)
    CreateThread(function ()
        while true do
            for weaponHash, damageModifier in pairs(Config.WeaponDamageModifiers) do
                SetPlayerWeaponTypeDamageModifier(GetPlayerIndex(), weaponHash, damageModifier)
            --  print("Damage modifier set to " .. tostring(damageModifier) .. " for weapon hash: " .. tostring(weaponHash))
            end

            Wait(500)
        end
    end)
end, false)
--]]

-----------------------------------
-- UTILITYS -- --[[ -- APPLY / REMOVE SCOPE WEAPON --]]
-----------------------------------
--[[ local weapon_scope = false
RegisterCommand("w_scope", function(source)
    local _, weaponHash = GetCurrentPedWeapon(cache.ped, true, 0, true)
    local weaponInHands = exports['rsg-weapons']:weaponInHands()
    local serial = weaponInHands[weaponHash]
    local readScope = {'COMPONENT_RIFLE_SCOPE02', 'COMPONENT_RIFLE_SCOPE03', 'COMPONENT_RIFLE_SCOPE04'}
    local componentsPreSql = {}
    Wait(1000)

    RSGCore.Functions.TriggerCallback('rsg-weapons:server:getweaponinfo', function(result)
        if result and #result > 0 then
            for i = 1, #result do
                componentsPreSql = json.decode(result[i].components) -- recibe all components to SQL
            end
        end
    end, serial)

    while next(componentsPreSql) == nil do
        Wait(0)
    end
    for _, components in ipairs(componentsPreSql) do
        if components ==  readScope then
            ApplyToFirstWeaponComponent(GetHashKey(readScope))
        end
    end

    for _, v in pairs(Components.SharedComponents) do
        for k2, v2 in pairs(v) do
            for k3, v3 in pairs(v2) do
                if string.match(v3.hashname, "SCOPE") then
                    if v3.hashname == readScope then
                        if weapon_scope == false then
                            weapon_scope = true
                            TriggerServerEvent("rsg-weaponcomp:server:check_comps")
                            RemoveWeaponComponentFromPed(cache.ped, GetHashKey(readScope), -1) -- RemoveWeaponComponentFromPed(cache.ped, GetHashKey(v), weaponHash) -- RemoveWeaponComponentFromPed(ped, hash, weaponHash) -- This is the server-side RPC native equivalent of the client native REMOVE_WEAPON_COMPONENT_FROM_PED. / 0x412AA00D
                            LoadModel(GetHashKey(readScope))
                        else
                            weapon_scope = false
                            TriggerServerEvent("rsg-weaponcomp:server:check_comps")
                        end
                    end
                end
            end
        end
    end
end, false) ]]

-----------------------------------
-- START AND STOP RESOURCE
-----------------------------------
AddEventHandler('RSGCore:Client:OnPlayerLoaded', function()
    LocalPlayer.state:set("inv_busy", false, true)
    PlayerData = RSGCore.Functions.GetPlayerData()

    Wait(5000)
    TriggerServerEvent('rsg-weaponcomp:server:check_comps')

end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    TriggerEvent('RSGCore:client:OnPlayerLoaded')
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    LocalPlayer.state:set("inv_busy", true, true)
    PlayerData = {}
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    MenuData.CloseAll()
    EndCam()

    FreezeEntityPosition(cache.ped , false) -- DISABLE BLOCK PLAYER
    LocalPlayer.state:set("inv_busy", false, true) -- DISABLE BLOCK INVENTORY

    UiStateMachineDestroy(-813354801) -- SHOW STATS

end)