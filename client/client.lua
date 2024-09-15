local RSGCore = exports['rsg-core']:GetCoreObject()

local num = tonumber
local match = string.match
local inCustom = false
local wepobject = nil
local camera = nil
local currentSerial = nil
local currentName = nil
local currentWep = nil

-- LIST POSSIBLES CATEGORYES
local readComponent = {Components.LanguageWeapons[1], Components.LanguageWeapons[7], Components.LanguageWeapons[5], Components.LanguageWeapons[10], Components.LanguageWeapons[41], Components.LanguageWeapons[11], Components.LanguageWeapons[36],  Components.LanguageWeapons[2], Components.LanguageWeapons[37], Components.LanguageWeapons[27], Components.LanguageWeapons[31], Components.LanguageWeapons[39], Components.LanguageWeapons[38]}
local readMaterial = {Components.LanguageWeapons[13], Components.LanguageWeapons[19], Components.LanguageWeapons[3], Components.LanguageWeapons[4], Components.LanguageWeapons[6], Components.LanguageWeapons[9], Components.LanguageWeapons[16], Components.LanguageWeapons[21], Components.LanguageWeapons[24], Components.LanguageWeapons[26], Components.LanguageWeapons[22],  Components.LanguageWeapons[23], Components.LanguageWeapons[32]}
local readEngraving = {Components.LanguageWeapons[14], Components.LanguageWeapons[20], Components.LanguageWeapons[40], Components.LanguageWeapons[17], Components.LanguageWeapons[15], Components.LanguageWeapons[12], Components.LanguageWeapons[42], Components.LanguageWeapons[33], Components.LanguageWeapons[8], Components.LanguageWeapons[34] }
local readTints = {Components.LanguageWeapons[18], Components.LanguageWeapons[23], Components.LanguageWeapons[25], Components.LanguageWeapons[28], Components.LanguageWeapons[29], Components.LanguageWeapons[30], Components.LanguageWeapons[35],}

---------------------------------
-- Price function
---------------------------------
local CalculatePrice = function(Table)
    local priceComp = 0.0
    local priceMat = 0.0
    local priceEng = 0.0
    local priceTint = 0.0
    local totalprice = 0.0

    if Table ~= nil then
        for category, hashname in pairs(Table) do

            for weaponType, weapons in pairs(Components.weapons_comp_list) do
                for weaponName, categories in pairs(weapons) do
                    if categories[category] then
                        for _, component in ipairs(categories[category]) do
                            if component.hashname == hashname and component.price ~= nil then
                                priceComp = priceComp + component.price
                            end
                        end
                    end
                end
            end

            for weaponType, categories in pairs(Components.SharedComponents) do
                if categories[category] then
                    for _, material in ipairs(categories[category]) do
                        if material.hashname == hashname and material.price ~= nil then
                            priceMat = priceMat + material.price
                        end
                    end
                end
            end

            for weaponType, categories in pairs(Components.SharedEngravingsComponents) do
                if categories[category] then
                    for _, engraving in ipairs(categories[category]) do
                        if engraving.hashname == hashname and engraving.price ~= nil then
                            priceEng = priceEng + engraving.price
                        end
                    end
                end
            end

            for weaponType, categories in pairs(Components.SharedTintsComponents) do
                if categories[category] then
                    for _, tint in ipairs(categories[category]) do
                        if tint.hashname == hashname and tint.price ~= nil then
                            priceTint = priceTint + tint.price
                        end
                    end
                end
            end

        end
        Wait(0)
    end

    if Config.Debug then print('totalprice', priceComp, priceMat, priceEng, priceTint) end
    totalprice = priceComp + priceMat + priceEng + priceTint

    Wait(0)
    return totalprice
end

local ComponentsTables = function(Table)
    if Table ~= nil then
        for category, hashname in pairs(Table) do

            for weaponType, weapons in pairs(Components.weapons_comp_list) do
                for weaponName, categories in pairs(weapons) do
                    if categories[category] then
                        for _, component in ipairs(categories[category]) do
                            if component.hashname == hashname then
                                apply_weapon_component(hashname)
                            end
                        end
                    end
                end
            end
            for weaponType, categories in pairs(Components.SharedComponents) do
                if categories[category] then
                    for _, component in ipairs(categories[category]) do
                        if component.hashname == hashname then
                            apply_weapon_component(hashname)
                        end
                    end
                end
            end
            for weaponType, categories in pairs(Components.SharedEngravingsComponents) do
                if categories[category] then
                    for _, component in ipairs(categories[category]) do
                        if component.hashname == hashname then
                            apply_weapon_component(hashname)
                        end
                    end
                end
            end
            for weaponType, categories in pairs(Components.SharedTintsComponents) do
                if categories[category] then
                    for _, component in ipairs(categories[category]) do
                        if component.hashname == hashname then
                            apply_weapon_component(hashname)
                        end
                    end
                end
            end
        end
    end
end

local table_contains = function(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

local GetWeaponType = function(objecthash)
    local weapon_type = nil
    if objecthash ~= nil then
        if GetHashKey('GROUP_REPEATER') == GetWeapontypeGroup(objecthash) then
            weapon_type = "LONGARM"
        elseif GetHashKey('GROUP_SHOTGUN') == GetWeapontypeGroup(objecthash) then
            weapon_type = "SHOTGUN"
        elseif GetHashKey('GROUP_HEAVY') == GetWeapontypeGroup(objecthash) then
            weapon_type = "LONGARM"
        elseif GetHashKey('GROUP_RIFLE') == GetWeapontypeGroup(objecthash) then
            weapon_type = "LONGARM"
        elseif GetHashKey('GROUP_SNIPER') == GetWeapontypeGroup(objecthash) then
            weapon_type = "LONGARM"
        elseif GetHashKey('GROUP_REVOLVER') == GetWeapontypeGroup(objecthash) then
            weapon_type = "SHORTARM"
        elseif GetHashKey('GROUP_PISTOL') == GetWeapontypeGroup(objecthash) then
            weapon_type = "SHORTARM"
        elseif GetHashKey('GROUP_BOW') == GetWeapontypeGroup(objecthash) then
            weapon_type = "GROUP_BOW"
        elseif GetHashKey('GROUP_MELEE') == GetWeapontypeGroup(objecthash) then
            weapon_type = "MELEE_BLADE"
        end
    end
    return weapon_type
end

---------------------------------------
-- weapon custom prompt
---------------------------------------
local WeaponCustomGroup = GetRandomIntInRange(0, 0xffffff)
local WeaponCustom = nil

local WeaponCustomPrompt = function()
    local str = 'Customise Weapon'
    local stra = CreateVarString(10, 'LITERAL_STRING', str)
    WeaponCustom = PromptRegisterBegin()
    PromptSetControlAction(WeaponCustom, RSGCore.Shared.Keybinds[Config.Keybinds])
    PromptSetText(WeaponCustom, stra)
    PromptSetEnabled(WeaponCustom, 1)
    PromptSetVisible(WeaponCustom, 1)
    PromptSetHoldMode(WeaponCustom, true)
    PromptSetGroup(WeaponCustom, WeaponCustomGroup)
    PromptRegisterEnd(WeaponCustom)
end

CreateThread(function()
    WeaponCustomPrompt()
    while true do
        local playerCoords = GetEntityCoords(cache.ped)
        local waittime = 1000
        for i = 1, #Config.CustomLocations do
            local customlocation = Config.CustomLocations[i]
            local distance = #(playerCoords - customlocation.coords)

            if inCustom == false and distance < 1.0 then
                waittime = 4
                local label = CreateVarString(10, 'LITERAL_STRING', 'Weapon Custom Shop')
                PromptSetActiveGroupThisFrame(WeaponCustomGroup, label)
                if PromptHasHoldModeCompleted(WeaponCustom) then
                    TriggerEvent('rsg-weaponcomp:client:startcustom', customlocation.prompt)
                    waittime = 1000
                end
            end

        end
        Wait(waittime)
    end
end)

---------------------------------
-- apply
---------------------------------
function apply_weapon_component(weapon_component_hash)
	local weapon_component_model_hash = Citizen.InvokeNative(0x59DE03442B6C9598, GetHashKey(weapon_component_hash))
	if weapon_component_model_hash and weapon_component_model_hash ~= 0 then
		RequestModel(weapon_component_model_hash)
		local i = 0
		while not HasModelLoaded(weapon_component_model_hash) and i <= 300 do
			i = i + 1
			Wait(100)
		end
		if HasModelLoaded(weapon_component_model_hash) then
            if inCustom == true then
                Citizen.InvokeNative(0x74C9090FDD1BB48E, wepobject, GetHashKey(weapon_component_hash), -1, true)
                SetModelAsNoLongerNeeded(weapon_component_model_hash)
                Wait(100)
                Citizen.InvokeNative(0xD3A7B003ED343FD9, wepobject, GetHashKey(weapon_component_hash), true, true, true) -- ApplyShopItemToPed( -- RELOADING THE LIVE MODEL
            else
                Citizen.InvokeNative(0x74C9090FDD1BB48E, cache.ped, GetHashKey(weapon_component_hash), -1, true)
                SetModelAsNoLongerNeeded(weapon_component_model_hash)
                Wait(100)
                Citizen.InvokeNative(0xD3A7B003ED343FD9, cache.ped, GetHashKey(weapon_component_hash), true, true, true) -- ApplyShopItemToPed( -- RELOADING THE LIVE MODEL
            end
        end
	else
        if inCustom == true then
            Citizen.InvokeNative(0x74C9090FDD1BB48E, wepobject, GetHashKey(weapon_component_hash), -1, true)
            Citizen.InvokeNative(0xD3A7B003ED343FD9, wepobject, GetHashKey(weapon_component_hash), true, true, true) -- ApplyShopItemToPed( -- RELOADING THE LIVE MODEL
        else
            Citizen.InvokeNative(0x74C9090FDD1BB48E, cache.ped, GetHashKey(weapon_component_hash), -1, true)
            Citizen.InvokeNative(0xD3A7B003ED343FD9, cache.ped, GetHashKey(weapon_component_hash), true, true, true) -- ApplyShopItemToPed( -- RELOADING THE LIVE MODEL
        end
    end
end

---------------------------------
-- Cams and object
---------------------------------
function StartCam(x,y,z,zoom)
    if camera then
        DestroyCam(camera, true)
        camera = nil
    end
    camera = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", x, y, z, -90.00, 00.00, -180.0, zoom, true, 0)
    SetCamActive(camera, true)
    RenderScriptCams(true, true, 2000, true, true)
end

local function getWordsFromHash(hash)
    local words = {}
    for word in hash:gmatch("[^|']+") do
        table.insert(words, word)
    end
    return words
end

function GameCam(hash, move_coords, objecthash)
    local weaponType = GetWeaponType(objecthash)
    local words = getWordsFromHash(hash)

    for _, word in ipairs(words) do
        if weaponType == "LONGARM" then
            if string.match(word, "SIGHT") then
                StartCam(move_coords.x+0.15, move_coords.y-0.10, move_coords.z+0.30, 60.0)
            elseif string.match(word, "SCOPE") then
                StartCam(move_coords.x+0.20, move_coords.y-0.05, move_coords.z+0.30, 60.0)

            elseif string.match(word, "WRAP") then
                StartCam(move_coords.x+0.20, move_coords.y+0.00, move_coords.z+0.40, 90.0-5.0)
            elseif string.match(word, "GRIP") then
                StartCam(move_coords.x+0.20, move_coords.y+0.00, move_coords.z+0.40, 90.0-5.0)

            elseif string.match(word, "BARREL") then
                StartCam(move_coords.x+0.40, move_coords.y+0.00, move_coords.z+0.40, 90.0-15.0)
            elseif string.match(word, "TRIGGER") then
                 StartCam(move_coords.x+0.00, move_coords.y+0.00, move_coords.z+0.30, 60.0)
            elseif string.match(word, "CYLINDER") then
                StartCam(move_coords.x+0.0, move_coords.y+0.00, move_coords.z+0.30, 75.0)
            else
                StartCam(move_coords.x+0.20, move_coords.y, move_coords.z+0.5, 75.0)
            end
        elseif weaponType == "SHOTGUN" then
            if string.match(word, "SIGHT") then
                StartCam(move_coords.x+0.15, move_coords.y-0.10, move_coords.z+0.20, 60.0)
            elseif string.match(word, "SCOPE") then
                StartCam(move_coords.x+0.20, move_coords.y-0.05, move_coords.z+0.30, 60.0)
            elseif string.match(word, "WRAP") then
                StartCam(move_coords.x+0.20, move_coords.y+0.00, move_coords.z+0.40, 90.0-10.0)
            elseif string.match(word, "GRIP") then
                StartCam(move_coords.x+0.20, move_coords.y+0.00, move_coords.z+0.40, 90.0-10.0)
            elseif string.match(word, "BARREL") then
                StartCam(move_coords.x+0.40, move_coords.y+0.00, move_coords.z+0.40, 90.0-15.0)
            elseif string.match(word, "TRIGGER") then
                 StartCam(move_coords.x+0.00, move_coords.y+0.00, move_coords.z+0.30, 60.0)
            elseif string.match(word, "CYLINDER") then
                StartCam(move_coords.x+0.0, move_coords.y+0.00, move_coords.z+0.30, 75.0)
            else
                StartCam(move_coords.x+0.20, move_coords.y, move_coords.z+0.5, 75.0)
            end
        elseif weaponType == "SHORTARM" then
            if string.match(word, "GRIP") then
                StartCam(move_coords.x-0.08, move_coords.y+0.02, move_coords.z+0.25, 60.0)
            elseif string.match(word, "SIGHT") then
                StartCam(move_coords.x-0.01, move_coords.y-0.05, move_coords.z+0.20, 60.0)
            elseif string.match(word, "CLIP") then
                StartCam(move_coords.x+0.03, move_coords.y-0.02, move_coords.z+0.25, 60.0)
            else
                StartCam(move_coords.x+0.08, move_coords.y, move_coords.z+0.30, 90.0-10.0)
            end
        elseif weaponType == "GROUP_BOW" then
            StartCam(move_coords.x-0.02, move_coords.y-0.1, move_coords.z+0.4, 90.0)
        elseif weaponType == "MELEE_BLADE" then
            StartCam(move_coords.x+0.10, move_coords.y-0.15, move_coords.z+0.4, 90.0-15)
        end
        if Config.Debug then
            print('hey Cam Move', weaponType, hash, word, move_coords.x, move_coords.y, move_coords.z)
        end
    end
end

local LoadModel = function(model)
	-- if not IsModelInCdimage(GetHashKey(model)) then return false end
	RequestModel(GetHashKey(model))
	while not HasModelLoaded(GetHashKey(model)) do
        Wait(4)
    end
    return true
end

local function applyfirst(objecthash)
    local weapon_type = GetWeaponType(objecthash)
    local weaponData = Components.weapons_comp_list[weapon_type]

    for _, components in pairs(weaponData) do
        for weaponObjectHash, weaponObjectName in pairs(Components.weaponObject) do
            if GetHashKey(weaponObjectHash) == objecthash then
                for componentCategory, componentList in pairs(components) do
                    local componentHashname = componentList[1].hashname
                    apply_weapon_component(componentHashname)
                end
            end
        end
    end
end

local function createobject(x, y, z, objecthash)

    if wepobject ~= nil and DoesEntityExist(wepobject) then
        DeleteObject(wepobject)
        wepobject = nil
    end

    wepobject = Citizen.InvokeNative(0x9888652B8BA77F73, objecthash, 0, x, y, z, false, 1.0)

    if wepobject and DoesEntityExist(wepobject) then
        SetEntityCoords(wepobject, x, y, z)
        SetEntityRotation(wepobject, 90.0, 0, 270, 1, true)
    else
        print("Error: No se pudo crear el objeto con el hash:", objecthash)
    end
end

RegisterNetEvent('rsg-weaponcomp:client:StartCamObj')
AddEventHandler("rsg-weaponcomp:client:StartCamObj", function(hash, coords, objecthash)
    while not HasCollisionLoadedAroundEntity(cache.ped) do
        Wait(500)
    end

    DoScreenFadeOut(100)
    Wait(100)
    DoScreenFadeIn(100)
    GameCam(hash, coords, objecthash)
    if Config.Debug then print('hey Cam', coords.x, coords.y, coords.z) end
end)

---------------------------------
-- EVENT PRINCIPAL ACCESS
---------------------------------

RegisterNetEvent('rsg-weaponcomp:client:startcustom', function(prompt)-- , custcoords
    local weaponHash = GetPedCurrentHeldWeapon(cache.ped)
    local weaponInHands = exports['rsg-weapons']:weaponInHands()
    local weaponName = Citizen.InvokeNative(0x89CF5FF3D363311E, weaponHash, Citizen.ResultAsString())
    local serial = weaponInHands[weaponHash]
    local wep = GetCurrentPedWeaponEntityIndex(cache.ped, 0)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local playerjob = PlayerData.job.type

    currentSerial = serial
    currentName = weaponName
    currentWep = wep

    if currentSerial == nil or weaponHash == -1569615261 then lib.notify({ title = 'Item Needed', description = "You're not holding a weapon!", type = 'error', icon = 'fa-solid fa-gun', iconAnimation = 'shake', duration = 7000}) return end
    if playerjob ~= Config.JobType then lib.notify({ title = 'Item Needed Job', description = "You're not have job for custom weapon!", type = 'error', icon = 'fa-solid fa-gun', iconAnimation = 'shake', duration = 7000}) return end

    inCustom = true

    for i = 1, #Config.CustomLocations do
        local customlocation = Config.CustomLocations[i]
        if playerjob == Config.JobType and customlocation.prompt == prompt then
            StartCam(customlocation.custcoords.x+0.2, customlocation.custcoords.y+0.15 , customlocation.custcoords.z+1.0, customlocation.custcoords.w)
            Wait(500)
            mainCompMenu(weaponHash) -- ENTER MENU

            createobject(customlocation.custcoords.x, customlocation.custcoords.y, customlocation.custcoords.z, weaponHash)

            applyfirst(weaponHash)
        end
    end
end)

-----------------------------------
-- LOAD COMP/MAT/ENG 
-----------------------------------

RegisterNetEvent("rsg-weaponcomp:client:LoadComponents")
AddEventHandler("rsg-weaponcomp:client:LoadComponents", function()
    local weaponHash = GetPedCurrentHeldWeapon(cache.ped)
    local weaponInHands = exports['rsg-weapons']:weaponInHands()
    local wepSerial = weaponInHands[weaponHash]
    local wep = GetCurrentPedWeaponEntityIndex(cache.ped, 0)
    local componentsSql = {}
    local callbackFinished = false
    RSGCore.Functions.TriggerCallback('rsg-weapons:server:getweaponinfo', function(result)
        if result and #result > 0 then
            for i = 1, #result do
                componentsSql = json.decode(result[i].components)
            end
        end
        callbackFinished = true
    end, wepSerial)

    while not callbackFinished do Wait(100) end

    if componentsSql ~= nil and wep ~= nil then
        if Config.Debug then print( 'rsg-weaponcomp:client:LoadComponents"')  print('weaponHash: ', weaponHash, 'component: ', json.encode(componentsSql)) end
        for category, hashname in pairs(componentsSql) do

            if table_contains(readComponent, category)  then
                RemoveWeaponComponentFromPed(wep, GetHashKey(hashname), -1)
            end
            if table_contains(readMaterial, category) then
                RemoveWeaponComponentFromPed(wep, GetHashKey(hashname), -1)
            end
            if table_contains(readEngraving, category) then
                RemoveWeaponComponentFromPed(wep, GetHashKey(hashname), -1)
            end
            if table_contains(readTints, category) then
                RemoveWeaponComponentFromPed(wep, GetHashKey(hashname), -1)
            end
        end

        ComponentsTables(componentsSql)
    end
    Wait(100)
    componentsSql = nil
end)
RegisterNetEvent("rsg-weaponcomp:client:LoadComponents")
AddEventHandler("rsg-weaponcomp:client:LoadComponents", function(component, wepHash)
    local ped = PlayerPedId()
    local shared = Config.Shared
    local specific = Config.Specific
    local weapon_type = nil

    _, wepHash = GetCurrentPedWeapon(ped, true, 0, true)
    local grouphash = num(GetWeapontypeGroup(wepHash))

    if num(`GROUP_REPEATER`) == grouphash then
        weapon_type = 'LONGARM'
    elseif num(`GROUP_SHOTGUN`) == grouphash then
        weapon_type = 'SHOTGUN'
    elseif num(`GROUP_HEAVY`) == grouphash then
        weapon_type = 'LONGARM'
    elseif num(`GROUP_RIFLE`) == grouphash then
        weapon_type = 'LONGARM'
    elseif num(`GROUP_SNIPER`) == grouphash then
        weapon_type = 'LONGARM'
    elseif num(`GROUP_REVOLVER`) == grouphash then
        weapon_type = 'SHORTARM'
    elseif num(`GROUP_PISTOL`) == grouphash then
        weapon_type = 'SHORTARM'
    elseif num(`GROUP_BOW`) == grouphash then
        weapon_type = 'GROUP_BOW'
    elseif num(`GROUP_MELEE`) == grouphash then
        weapon_type = 'MELEE_BLADE'
    end

    Wait(0)

    for k, v in pairs(shared) do
        if k ~= weapon_type then goto continue end

        for _, v2 in pairs(v) do
            for i = 1, 100 do
                if v2[i] then
                    RemoveWeaponComponentFromPed(ped, GetHashKey(v2[i]), wepHash)
                end
            end
        end

        ::continue::
    end

    for k, v in pairs(specific) do
        if num(GetHashKey(k)) ~= num(wepHash) then goto continue end

        for k2, v2 in pairs(v) do
            for i = 1, 100 do
                if v2[i] then
                    RemoveWeaponComponentFromPed(ped, GetHashKey(v2[i]), wepHash)
                end

                if k2 == 'BARREL' then
                    Citizen.InvokeNative(0x74C9090FDD1BB48E, ped, GetHashKey(v2[1]), wepHash, true)
                end

                if k2 == 'GRIP' then
                    Citizen.InvokeNative(0x74C9090FDD1BB48E, ped, GetHashKey(v2[1]), wepHash, true)
                end
            end
        end

        ::continue::
    end

    Wait(5)

end)

exports('InWeaponCustom', function()
    return inCustom
end)

RegisterNetEvent("rsg-weaponcomp:client:LoadComponents_selection") -- SELECTION
AddEventHandler("rsg-weaponcomp:client:LoadComponents_selection", function()

    local componentsPreSql = {}
    local callbackFinished = false

    RSGCore.Functions.TriggerCallback('rsg-weapons:server:getweaponinfo', function(result)
        if result and #result > 0 then
            for i = 1, #result do
                componentsPreSql = json.decode(result[i].components_before)
            end
        end
        callbackFinished = true
    end, currentSerial)

    while not callbackFinished do Wait(100) end

    if componentsPreSql ~= nil and currentWep ~= nil then
        for category, hashname in pairs(componentsPreSql) do

            if  table_contains(readComponent, category) or
                table_contains(readMaterial, category) or
                table_contains(readEngraving, category) or
                table_contains(readTints, category) then
            local componentHash = GetHashKey(hashname)
            if componentHash then
                RemoveWeaponComponentFromPed(currentWep, componentHash, -1)
            else
                print('Error: Hash del componente no vlido:', hashname)
            end
        end

        end

        ComponentsTables(componentsPreSql)
    end
    Wait(100)
    componentsPreSql = nil
	TriggerEvent('rsg-weaponcomp:client:LoadComponents')
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

local creatorCache = {}

local function resetCache()
    creatorCache = {}
end

local mainWeaponCompMenus = {
    ["component"] = function(objecthash) OpenComponentMenu(objecthash) end,
    ["material"] = function(objecthash) OpenMaterialMenu(objecthash) end,
    ["engraving"] = function(objecthash) OpenEngravingMenu(objecthash) end,
    ["tints"] = function(objecthash) OpenTintsMenu(objecthash) end,
    ["applycommponent"] = function(objecthash) ButtomApplyAllComponents(objecthash) end,
    ["removecommponent"] = function(objecthash) ButtomRemoveAllComponents(objecthash) end,
    ["exitcommponent"] = function() TriggerEvent('rsg-weaponcomp:client:ExitCam') end
}

-- MAIN MENU JOB
mainCompMenu = function(objecthash)
    MenuData.CloseAll()
    FreezeEntityPosition(cache.ped, true)
    LocalPlayer.state:set("inv_busy", true, true) -- BLOCK INVENTORY

    Wait(100)
    local elements = {
        {label = 'Components',  value = 'component',        desc = ""},
        {label = 'Materials',   value = 'material',         desc = ""},
        {label = 'Engravings',  value = 'engraving',        desc = ""},
        {label = 'Tints',       value = 'tints',            desc = ""},
        {label = 'Apply $',     value = 'applycommponent',  desc = ""},
        {label = 'Remove $',    value = 'removecommponent', desc = ""},
        {label = 'EXIT',        value = 'exitcommponent',   desc = ""},
    }

    MenuData.Open('default', GetCurrentResourceName(), 'main_weapons_creator_menu', {
    title = "Weapons Menu",
    subtext = 'Options ',
    align = "bottom-left",
    elements = elements,
    itemHeight = "2vh"
    }, function(data, menu)
        local action = mainWeaponCompMenus[data.current.value]
        if action then
            action(objecthash)
        else
            print('Error: Acción:', data.current.value)
        end
        TriggerServerEvent("rsg-weaponcomp:server:check_comps_selection")

    end, function(data, menu)

        menu.close()
        TriggerEvent('rsg-weaponcomp:client:ExitCam')
        TriggerServerEvent("rsg-weaponcomp:server:removeComponents_selection", "DEFAULT", currentSerial) -- sql clean custom
        resetCache()
        Wait(1000)

    end)
end

---------------------
-- COMP SUB MENU WITH OPTIONS
---------------------
OpenComponentMenu = function(objecthash)
    local elements = {}
    local weapon_type = GetWeaponType(objecthash)
    local weaponData = Components.weapons_comp_list[weapon_type] or {}
    local weaponComponents = weaponData[currentName] or {}
    local coords = GetEntityCoords(wepobject)

    for category, componentList in pairs(weaponComponents) do
        local newElement = {
            label = category,
            value = 1,
            type = "slider",
            min = 1,
            max = #componentList,
            category = category,
            components = {}
        }
        --[[ -- Insert "Original" option as the first component
        table.insert(newElement.components, {
            label = "Original",
            value = nil,
            v = nil,
        }) ]]
        for i, component in ipairs(componentList) do
            table.insert(newElement.components, {label = component.title, value = component.hashname, price = component.price})
        end

        table.insert(elements, newElement)
    end

    MenuData.Open('default', GetCurrentResourceName(), 'component_weapon_menu', { title = 'Custom Component', subtext = 'Options ' .. currentName, align = "bottom-left", elements = elements, itemHeight = "2vh",
    }, function(data, menu)

        if data.current then
            local selectedCategory = data.current.category
            local selectedIndex = data.current.value
            local selectedHash = nil

            -- if selectedIndex == 0 then
            --     selectedHash = nil
            --     Citizen.InvokeNative(0xD3A7B003ED343FD9, wepobject, -1, true, true, true) -- ApplyShopItemToPed (reloading the original model)
            -- else
            if selectedIndex > 0 and selectedIndex <= #data.current.components then
                selectedHash = data.current.components[selectedIndex].value
                Citizen.InvokeNative(0xD3A7B003ED343FD9, wepobject, GetHashKey(selectedHash), true, true, true)
            end

            if Config.Debug then print('selected', selectedHash) end
            if selectedHash ~= creatorCache[selectedCategory] then
                creatorCache[selectedCategory] = selectedHash
                TriggerEvent("rsg-weaponcomp:client:update_selection", creatorCache)
                if Config.StartCamObj == true then
                    TriggerEvent('rsg-weaponcomp:client:StartCamObj', selectedHash, coords, objecthash)
                end
                TriggerServerEvent("rsg-weaponcomp:server:check_comps_selection")
            end
        end
        menu.refresh()
    end, function(data, menu)
        menu.close()
        mainCompMenu(objecthash) -- BACK MAIN MENU
    end)
end

OpenMaterialMenu = function(objecthash)
    local weapon_type = GetWeaponType(objecthash)
    local elements = {}
    local weaponData = Components.SharedComponents[weapon_type] or {}
    local coords = GetEntityCoords(wepobject)

    for category, materialList in pairs(weaponData) do
        local newElement = {
            label = category,
            value = 1,
            type = "slider",
            min = 1,
            max = #materialList,
            category = category,
            materials = {}
        }
        --[[ -- Insert "Original" option as the first component
        table.insert(newElement.materials, {
            label = "Original",
            value = nil,
            v = nil,
        }) ]]
        for i, material in ipairs(materialList) do
            table.insert(newElement.materials, {label = material.title, value = material.hashname, price = material.price})
        end

        table.insert(elements, newElement)

    end

    MenuData.Open('default', GetCurrentResourceName(), 'material_weapon_menu', { title = 'Custom Materials', subtext = 'Options ' .. currentName, align = "bottom-left", elements = elements, itemHeight = "2vh",
    }, function(data, menu)
        if data.current then
            local selectedCategory = data.current.category
            local selectedIndex = data.current.value
            local selectedHash = nil

            -- if selectedIndex == 0 then
            --     selectedHash = nil
            --     Citizen.InvokeNative(0xD3A7B003ED343FD9, wepobject, -1, true, true, true) -- ApplyShopItemToPed (reloading the original model)
            -- else
            if selectedIndex > 0 and selectedIndex <= #data.current.materials then
                selectedHash = data.current.materials[selectedIndex].value
            end
            if Config.Debug then print( 'selected', selectedHash) end
            if selectedHash ~= creatorCache[selectedCategory] then
                creatorCache[selectedCategory] = selectedHash
                TriggerEvent("rsg-weaponcomp:client:update_selection", creatorCache)
                if Config.StartCamObj == true then
                    TriggerEvent('rsg-weaponcomp:client:StartCamObj', selectedHash, coords, objecthash)
                end
                TriggerServerEvent("rsg-weaponcomp:server:check_comps_selection")
            end
        end
        menu.refresh()

    end, function(data, menu)
        menu.close()
        mainCompMenu(objecthash)
    end)
end

OpenEngravingMenu = function(objecthash)
    local weapon_type = GetWeaponType(objecthash)
    local elements = {}
    local weaponData = Components.SharedEngravingsComponents[weapon_type] or {}
    local coords = GetEntityCoords(wepobject)

    for category, engravingList in pairs(weaponData) do
        local newElement = {
            label = category,
            value = 1,
            type = "slider",
            min = 1,
            max = #engravingList,
            category = category,
            engravings = {}
        }
        --[[ -- Insert "Original" option as the first component
        table.insert(newElement.engravings, {
            label = "Original",
            value = nil,
            v = nil,
        }) ]]

        for i, engraving in ipairs(engravingList) do
            table.insert(newElement.engravings, {label = engraving.title, value = engraving.hashname, price = engraving.price})
        end

        table.insert(elements, newElement)
    end

    MenuData.Open('default', GetCurrentResourceName(), 'engraving_weapon_menu', { title = 'Custom Engravings', subtext = 'Options ' .. currentName, align = "bottom-left", elements = elements, itemHeight = "2vh",
    }, function(data, menu)
        if data.current then
            local selectedCategory = data.current.category
            local selectedIndex = data.current.value
            local selectedHash = nil

            -- if selectedIndex == 0 then
            --     selectedHash = nil
            --     Citizen.InvokeNative(0xD3A7B003ED343FD9, wepobject, -1, true, true, true) -- ApplyShopItemToPed (reloading the original model)
            -- else
            if selectedIndex > 0 and selectedIndex <= #data.current.engravings then
                selectedHash = data.current.engravings[selectedIndex].value
            end

            if Config.Debug then print( 'selected', selectedHash) end
            if selectedHash ~= creatorCache[selectedCategory] then
                creatorCache[selectedCategory] = selectedHash
                TriggerEvent("rsg-weaponcomp:client:update_selection", creatorCache)
                if Config.StartCamObj == true then
                    TriggerEvent('rsg-weaponcomp:client:StartCamObj', selectedHash, coords, objecthash)
                end
                TriggerServerEvent("rsg-weaponcomp:server:check_comps_selection")
            end
        end
        menu.refresh()

    end, function(data, menu)
        menu.close()
        mainCompMenu(objecthash)
    end)
end

OpenTintsMenu = function(objecthash)
    TriggerServerEvent("rsg-weaponcomp:server:check_comps_selection")
    Wait(0)

    local weapon_type = GetWeaponType(objecthash)
    local elements = {}
    local weaponData = Components.SharedTintsComponents[weapon_type] or {}
    local coords = GetEntityCoords(wepobject)

    for category, tintsList in pairs(weaponData) do
        local newElement = {
            label = category,
            value = 1,
            type = "slider",
            min = 1,
            max = #tintsList,
            category = category,
            tints = {}
        }

        --[[ -- Insert "Original" option as the first component
        table.insert(newElement.tints, {
            label = "Original",
            value = nil,
            price = nil,
        }) ]]
        for index, tint in ipairs(tintsList) do
            table.insert(newElement.tints, {label = tint.title, value = tint.hashname, price = tint.price})
        end
        table.insert(elements, newElement)
    end

    MenuData.Open('default', GetCurrentResourceName(), 'tints_weapon_menu', { title = 'Custom tints', subtext = 'Options ' .. currentName, align = "bottom-left", elements = elements, itemHeight = "2vh",
    }, function(data, menu)

        if data.current then
            local selectedCategory = data.current.category
            local selectedIndex = data.current.value
            local selectedHash = nil

            -- if selectedIndex == 0 then
            --     selectedHash = nil
            --     Citizen.InvokeNative(0xD3A7B003ED343FD9, wepobject, -1, true, true, true) -- ApplyShopItemToPed (reloading the original model)
            -- else
            if selectedIndex > 0 and selectedIndex <= #data.current.tints then
                selectedHash = data.current.tints[selectedIndex].value
            end

            if Config.Debug then print( 'selected', selectedHash) end
            if selectedHash ~= creatorCache[selectedCategory] then
                creatorCache[selectedCategory] = selectedHash
                TriggerEvent("rsg-weaponcomp:client:update_selection", creatorCache)
                if Config.StartCamObj == true then
                    TriggerEvent('rsg-weaponcomp:client:StartCamObj', selectedHash, coords, objecthash)
                end
            end
        end
        menu.refresh()
    end,
    function(data, menu)
        menu.close()
        mainCompMenu(objecthash)
    end)
end

-----------------------------------
-- APPLY BUTTOM -- REMOVE BUTTOM -- JOB
-----------------------------------

ButtomApplyAllComponents = function (objecthash)

    MenuData.CloseAll()
    local componentsApplyPreSql = {}

    RSGCore.Functions.TriggerCallback('rsg-weapons:server:getweaponinfo', function(result)
        if result and #result > 0 then
            for i = 1, #result do
                componentsApplyPreSql = json.decode(result[i].components_before)
            end
        end
    end, currentSerial)

    Wait(200)
    local currentPrice = CalculatePrice(componentsApplyPreSql)
    Wait(200)

    if currentPrice == 0.0 or componentsApplyPreSql == nil then TriggerEvent('rsg-weaponcomp:client:ExitCam') return end
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

        TriggerServerEvent('rsg-weaponcomp:server:price', currentPrice, objecthash)
        Wait(1000)
        TriggerServerEvent("rsg-weaponcomp:server:apply_weapon_components", creatorCache, currentName, currentSerial)
        Wait(100)
        resetCache()
    end

end

ButtomRemoveAllComponents = function (objecthash)
    MenuData.CloseAll()
    local componentsRemoveSql = {}

    RSGCore.Functions.TriggerCallback('rsg-weapons:server:getweaponinfo', function(result)
        if result and #result > 0 then
            for i = 1, #result do
                componentsRemoveSql = json.decode(result[i].components)
            end
        end
    end, currentSerial)

    Wait(200)
    local currentRemove = CalculatePrice(componentsRemoveSql)
    Wait(200)

    if currentRemove == 0.0 or componentsRemoveSql == nil then TriggerEvent('rsg-weaponcomp:client:ExitCam') return end

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

        TriggerServerEvent('rsg-weaponcomp:server:price', currentRemove, objecthash)
        Wait(1000)
        TriggerServerEvent("rsg-weaponcomp:server:removeComponents", "DEFAULT", currentName, currentSerial) -- update SQL
        TriggerServerEvent("rsg-weaponcomp:server:removeComponents_selection", "DEFAULT", currentSerial) -- update SQL
        Wait(100)
        resetCache()
    end
    componentsRemoveSql = nil
end
-----------------------------------
-- UPDATE SELECTION
-----------------------------------
RegisterNetEvent('rsg-weaponcomp:client:update_selection')
AddEventHandler("rsg-weaponcomp:client:update_selection", function(selectedComp)
    if Config.Debug then print("Data update_selection send:", json.encode(selectedComp)) end

    TriggerServerEvent("rsg-weaponcomp:server:update_selection", selectedComp, currentSerial)

    Wait(0)

    local selectedAdd = nil
    selectedAdd = selectedComp

    if currentWep ~= nil then

        for category, component in ipairs(selectedAdd) do
            if table_contains(readComponent, category) then
                for i = 1, #selectedAdd do
                    if selectedAdd[i] ~= 0 then RemoveWeaponComponentFromPed(currentWep, GetHashKey(selectedAdd[i]), -1) end
                end
                Citizen.InvokeNative(0xD3A7B003ED343FD9, currentWep, GetHashKey(component), true, true, true)
            end
            if table_contains(readMaterial, category) then
                for i = 1, #selectedAdd do
                    if selectedAdd[i] ~= 0 then RemoveWeaponComponentFromPed(currentWep, GetHashKey(selectedAdd[i]), -1) end
                end
                Citizen.InvokeNative(0xD3A7B003ED343FD9, currentWep, GetHashKey(component), true, true, true)
            end
            if table_contains(readEngraving, category) then
                for i = 1, #selectedAdd do
                    if selectedAdd[i] ~= 0 then RemoveWeaponComponentFromPed(currentWep, GetHashKey(selectedAdd[i]), -1) end
                end
                Citizen.InvokeNative(0xD3A7B003ED343FD9, currentWep, GetHashKey(component), true, true, true)
            end
            if table_contains(readTints, category) then
                for i = 1, #selectedAdd do
                    if selectedAdd[i] ~= 0 then RemoveWeaponComponentFromPed(currentWep, GetHashKey(selectedAdd[i]), -1) end
                end
                Citizen.InvokeNative(0xD3A7B003ED343FD9, currentWep, GetHashKey(component), true, true, true)
            end
        end

        Wait(100)
        ComponentsTables(selectedAdd)
    end

    selectedAdd = nil
end)

--------------------------------------------
-- CAMS EVENT FINISH
--------------------------------------------
local c_zoom = nil
local c_offset = nil
local playerHeading = nil
local weaponCamera = nil

local StartCamClean = function(zoom, offset)
    DestroyAllCams(true)

    DoScreenFadeOut(1000)
    Wait(0)
    DoScreenFadeIn(1000)

    local coords = GetEntityCoords(cache.ped)
    local zoomOffset = tonumber(zoom)
    local angle

    if playerHeading == nil then
        playerHeading = GetEntityHeading(cache.ped)
        angle = playerHeading * math.pi / 180.0
    else
        angle = playerHeading * math.pi / 180.0
    end

    local pos = {
        x = coords.x - tonumber(zoomOffset * math.sin(angle)),
        y = coords.y + tonumber(zoomOffset * math.cos(angle)),
        z = coords.z + offset
    }

    if not weaponCamera then
        local camera_pos = GetObjectOffsetFromCoords(pos.x, pos.y, pos.z, 0.0, 1.0, 1.0, 1.0)

        weaponCamera = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", pos.x, pos.y, pos.z + 0.5, 300.00, 0.00, 0.00, 50.00, false, 0)
        local pCoords = GetEntityCoords(cache.ped)
        PointCamAtCoord(weaponCamera, pCoords.x, pCoords.y, pCoords.z + offset)

        SetCamActive(weaponCamera, true)
        RenderScriptCams(true, true, 1000, true, true)

    end
end

RegisterNetEvent("rsg-weaponcomp:client:animationSaved")
AddEventHandler("rsg-weaponcomp:client:animationSaved", function(objecthash)

    TriggerServerEvent("rsg-weaponcomp:server:check_comps_selection")
    SetCurrentPedWeapon(cache.ped, objecthash, true)

    if wepobject ~= nil and DoesEntityExist(wepobject) then
        DeleteObject(wepobject)
        wepobject = nil -- Limpiar la variable después de eliminar el objeto
    else
        if Config.Debug then print("No hay objeto para eliminar o ya ha sido eliminado -- Animacion save") end
    end

    local weapon_type = GetWeaponType(objecthash)
    local boneIndex2 = GetEntityBoneIndexByName(cache.ped, "SKEL_L_Finger00")
    local Cloth = CreateObject(GetHashKey('s_balledragcloth01x'), GetEntityCoords(cache.ped), false, true, false, false, true)
    local animDict = nil
    local animName = nil

    if weapon_type == 'SHORTARM' then
        animDict = "mech_inspection@weapons@shortarms@volcanic@base"
        animName = "clean_loop"
        c_zoom = 0.85
        c_offset = 0.10
    elseif weapon_type == 'LONGARM' then
        animDict = "mech_inspection@weapons@longarms@sniper_carcano@base"
        animName = "clean_loop"
        c_zoom = 1.5
        c_offset = 0.20
    elseif weapon_type == 'SHOTGUN' then
        animDict = "mech_inspection@weapons@longarms@shotgun_double_barrel@base"
        animName = "clean_loop"
        c_zoom = 1.2
        c_offset = 0.15
    elseif weapon_type == 'GROUP_BOW' then
        c_zoom = 1.5
        c_offset = 0.15
    elseif weapon_type == 'MELEE_BLADE' then
        c_zoom = 1.2
        c_offset = 0.15
    end

    StartCamClean(c_zoom, c_offset)
    Wait(100)
    if animDict ~= nil and animName ~= nil then
      AttachEntityToEntity(Cloth, cache.ped, boneIndex2, 0.02, -0.035, 0.00, 20.0, -24.0, 165.0, true, false, true, false, 0, true)
      lib.progressBar({
	duration = tonumber(Config.animationSave),
	useWhileDead = false,
	canCancel = false,
	disable = { move = true, car = true, combat= true, mouse= false, sprint = true, },
	anim = { dict = animDict, clip = animName, flag = 15, },
	label = 'Weapon Attachments.. ',
      })
      SetEntityAsNoLongerNeeded(Cloth)
      DeleteEntity(Cloth)
    end
    TriggerServerEvent("rsg-weaponcomp:server:check_comps")
    TriggerEvent('rsg-weaponcomp:client:ExitCam')
    resetCache()
end)

RegisterNetEvent('rsg-weaponcomp:client:ExitCam')
AddEventHandler('rsg-weaponcomp:client:ExitCam', function()

    RenderScriptCams(false, true, 2000, true, false)
    DestroyCam(camera, false)
    camera = nil
    DestroyAllCams(true)

    if wepobject ~= nil and DoesEntityExist(wepobject) then
        DeleteObject(wepobject)
        wepobject = nil -- Limpiar la variable después de eliminar el objeto
    else
        if Config.Debug then print("No hay objeto para eliminar o ya ha sido eliminado -- Exit Menu") end
    end

    MenuData.CloseAll()
    inCustom = false

    DoScreenFadeOut(1000)
    Wait(0)
    DoScreenFadeIn(1000)
    SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
    LocalPlayer.state:set("inv_busy", false, true)

    FreezeEntityPosition(cache.ped, false)
    ClearPedTasks(cache.ped)
    ClearPedSecondaryTask(cache.ped)

end)

-----------------------------------
-- START AND STOP RESOURCE CLEAN UP
-----------------------------------

local function PreloadAllComponents()
    local function preloadComponentFirst(componentList, categoryName)
        for weaponType, componentsListA in pairs(componentList) do
            for k, v in pairs(Components.weaponObject) do
                for weaponName, components in pairs(componentsListA) do
                    if k == weaponName then
                        for _, category in pairs(components) do
                            for _, component in pairs(category) do
                                LoadModel(component.hashname)
                                print('Componente precargado exitosamente en ' .. categoryName .. ':', component.hashname)
                            end
                        end
                    end
                end
            end
        end
    end

    local function preloadComponentList(componentList, categoryName)
        for weaponType, components in pairs(componentList) do
            for _, v in pairs(components) do
                for _, component in pairs(v) do
                    LoadModel(component.hashname)
                    print('Componente precargado exitosamente en ' .. categoryName .. ':', component.hashname)
                end
            end
        end
    end

    preloadComponentFirst(Components.weapons_comp_list, 'Componentes de armas')
    preloadComponentList(Components.SharedComponents, 'Materiales compartidos')
    preloadComponentList(Components.SharedEngravingsComponents, 'Grabados compartidos')
    preloadComponentList(Components.SharedTintsComponents, 'Tintes compartidos')
end

RegisterCommand('preloadModels', function()
        PreloadAllComponents()
end, false)

AddEventHandler('RSGCore:Client:OnPlayerLoaded', function()
    LocalPlayer.state:set('isLoggedIn', true, false)
    PlayerData = RSGCore.Functions.GetPlayerData()
    Wait(5000)
    TriggerServerEvent('rsg-weaponcomp:server:check_comps')
end)

AddEventHandler('onResourceStart', function(r)
    if GetCurrentResourceName() ~= r then return end
    TriggerEvent('RSGCore:client:OnPlayerLoaded')
    -- PreloadAllComponents()
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    LocalPlayer.state:set('isLoggedIn', false, false)
    PlayerData = {}
end)

AddEventHandler('onResourceStop', function(r)
    if GetCurrentResourceName() ~= r then return end

    if wepobject ~= nil then
        DeleteObject(wepobject)
    end

    inCustom = false
    DestroyAllCams(true)
    MenuData.CloseAll()
    LocalPlayer.state:set("inv_busy", false, true) -- DISABLE BLOCK INVENTORY
    FreezeEntityPosition(cache.ped , false) -- DISABLE BLOCK PLAYER

end)
