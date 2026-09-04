local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local WeaponsDataFile = 'weapons_data.json'
local PropsLoaded = false

----------------------------------------
-- JSON File Utilities
----------------------------------------
local function getResourceFilePath(filename)
    return GetResourcePath(GetCurrentResourceName()) .. '/' .. filename
end

local function loadJsonFile(filename)
    local path = getResourceFilePath(filename)
    local file = io.open(path, 'r')
    if file then
        local content = file:read('*all')
        file:close()
        return json.decode(content) or {}
    end
    return {}
end

local function saveJsonFile(filename, data)
    local path = getResourceFilePath(filename)
    local file = io.open(path, 'w')
    if file then
        file:write(json.encode(data, { indent = true }))
        file:close()
        return true
    end
    return false
end

----------------------------------------
-- Export All Weapons Data on Start
----------------------------------------
local function ExportAllWeaponsData()
   
    
    local weaponsData = {}
    
    -- Fetch all weapons from player_weapons table with correct columns
    local weapons = MySQL.query.await('SELECT id, serial, citizenid, components, components_before, price, town FROM player_weapons')
    
    if weapons and #weapons > 0 then
        for _, w in ipairs(weapons) do
            local citizenid = tostring(w.citizenid)
            local serial = tostring(w.serial)
            
            if not weaponsData[citizenid] then
                weaponsData[citizenid] = {
                    citizenid = citizenid,
                    weapons = {}
                }
            end
            
            -- Parse components JSON
            local comps = {}
            local compsBefore = {}
            
            if w.components and w.components ~= '' and w.components ~= '{}' then
                comps = json.decode(w.components) or {}
            end
            
            if w.components_before and w.components_before ~= '' and w.components_before ~= '{}' then
                compsBefore = json.decode(w.components_before) or {}
            end
            
            weaponsData[citizenid].weapons[serial] = {
                id = w.id,
                serial = serial,
                components = comps,
                componentsBefore = compsBefore,
                price = tonumber(w.price) or 0,
                town = w.town or 0
            }
        end
        
        
    else
       
    end
    
    -- Save to JSON
    saveJsonFile(WeaponsDataFile, weaponsData)
    
  
    return weaponsData
end

-- Export on resource start
CreateThread(function()
    Wait(2000) -- Wait for database connection
    
    -- Check if table exists first
    local tableCheck = MySQL.query.await([[
        SELECT COUNT(*) as count 
        FROM information_schema.tables 
        WHERE table_schema = DATABASE() 
        AND table_name = 'player_weapons'
    ]])
    
    if tableCheck and tableCheck[1] and tableCheck[1].count > 0 then
        ExportAllWeaponsData()
    else
       
    end
    
    -- Load props
    TriggerEvent('rsg-weaponcomp:server:getProps')
    PropsLoaded = true
end)

----------------------------------------
-- Usable Item
----------------------------------------
RSGCore.Functions.CreateUseableItem(Config.Gunsmithitem, function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    
    -- Check job requirement
    if Config.RequiredJob then
        local playerJob = Player.PlayerData.job.name
        if playerJob ~= Config.RequiredJob then
            TriggerClientEvent('ox_lib:notify', source, {
                title = locale('sv_lang_1') or 'Access Denied',
                description = 'You need to be a ' .. Config.RequiredJob .. ' to use this item.',
                type = 'error'
            })
            return
        end
    end
    
    TriggerClientEvent('rsg-weaponcomp:client:createprop', source, {
        propmodel = Config.Gunsmithprop,
        item = Config.Gunsmithitem
    })
end)

----------------------------------------
-- Commands
----------------------------------------
RSGCore.Commands.Add(Config.Commandinspect, locale('cl_lang_30') or 'Inspect weapon', {}, false, function(source)
    TriggerClientEvent('rsg-weaponcomp:client:InspectionWeapon', source)
end)

RSGCore.Commands.Add(Config.Commandloadweapon, locale('cl_lang_31') or 'Load weapon components', {}, false, function(source)
    TriggerClientEvent('rsg-weaponcomp:client:reloadWeapon', source)
end)

RSGCore.Commands.Add('reloadweaponcomps', 'Force reload weapon components (debug)', {}, false, function(source)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local ped = PlayerPedId()
    local wHash = GetPedCurrentHeldWeapon(ped)
    
    if wHash == 0 or wHash == `WEAPON_UNARMED` then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No weapon in hand' })
        return
    end
    
    local weaponInHands = exports['rsg-weapons']:weaponInHands()
    local serial = weaponInHands and weaponInHands[wHash]
    
    if not serial then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Could not get weapon serial' })
        return
    end
    
    TriggerClientEvent('rsg-weaponcomp:client:reloadWeapon', src)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Reloading weapon components...' })
end)



----------------------------------------
-- Helper Functions
----------------------------------------
local function GetWeaponItemEntry(Player, serial)
    for _, item in ipairs(Player.PlayerData.items) do
        if item.type == 'weapon' and item.info and item.info.serie == serial then
            return item
        end
    end
    return nil
end

local function UpdateWeaponsJson(citizenid, serial, componentData)
    local weaponsData = loadJsonFile(WeaponsDataFile)
    
    if not weaponsData[citizenid] then
        weaponsData[citizenid] = {
            citizenid = citizenid,
            weapons = {}
        }
    end
    
    if not weaponsData[citizenid].weapons[serial] then
        weaponsData[citizenid].weapons[serial] = {
            serial = serial,
            components = {},
            componentsBefore = {},
            price = 0,
            town = 0
        }
    end
    
    -- Store current as "before" and update with new
    weaponsData[citizenid].weapons[serial].componentsBefore = weaponsData[citizenid].weapons[serial].components or {}
    weaponsData[citizenid].weapons[serial].components = componentData.componentshash or {}
    
    saveJsonFile(WeaponsDataFile, weaponsData)
end

-- Update or insert weapon components in database
local function SaveWeaponToDatabase(citizenid, serial, components, componentsBefore, price, town)
    local compsJson = json.encode(components or {})
    local compsBeforeJson = json.encode(componentsBefore or {})
    
    -- Check if record exists
    local existing = MySQL.query.await('SELECT id FROM player_weapons WHERE serial = ? AND citizenid = ?', { serial, citizenid })
    
    if existing and existing[1] then
        -- Update existing record
        MySQL.update.await('UPDATE player_weapons SET components = ?, components_before = ?, price = ?, town = ? WHERE serial = ? AND citizenid = ?', 
            { compsJson, compsBeforeJson, price or 0, town or 0, serial, citizenid })
    else
        -- Insert new record
        MySQL.insert.await('INSERT INTO player_weapons (serial, citizenid, components, components_before, price, town) VALUES (?, ?, ?, ?, ?, ?)',
            { serial, citizenid, compsJson, compsBeforeJson, price or 0, town or 0 })
    end
end

----------------------------------------
-- Scope Callbacks
----------------------------------------
RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:equipScope', function(source, cb, serial)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end

    local weaponItem = GetWeaponItemEntry(Player, serial)
    if not weaponItem then return cb(false) end

    if weaponItem.info.equippedScope then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = locale('cl_scope_already_on') or 'Scope already equipped' })
        return cb(false)
    end

    weaponItem.info.equippedScope = true
    Player.Functions.SetInventory(Player.PlayerData.items)
    cb(true)
end)

RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:unequipScope', function(source, cb, serial)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end

    local weaponItem = GetWeaponItemEntry(Player, serial)
    if not weaponItem then return cb(false) end

    if not weaponItem.info.equippedScope then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = locale('cl_scope_already_off') or 'Scope not equipped' })
        return cb(false)
    end

    weaponItem.info.equippedScope = false
    Player.Functions.SetInventory(Player.PlayerData.items)
    cb(true)
end)

----------------------------------------
-- Data Callbacks
----------------------------------------
RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:countprop', function(source, cb, proptype)
    local ply = RSGCore.Functions.GetPlayer(source)
    if not ply then return cb(0) end
    local res = MySQL.prepare.await(
        "SELECT COUNT(*) as count FROM player_weapons_custom WHERE citizenid = ? AND item = ?",
        { ply.PlayerData.citizenid, proptype }
    )
    cb(res or 0)
end)

RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:getItemBySerial', function(source, cb, serial)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then cb(nil) return end

    -- Check inventory first
    for _, item in ipairs(Player.PlayerData.items) do
        if item.type == 'weapon' and item.info and item.info.serie == serial then
            cb({ components = item.info.componentshash or {} })
            return
        end
    end
    
    -- Check JSON file
    local citizenid = Player.PlayerData.citizenid
    local weaponsData = loadJsonFile(WeaponsDataFile)
    if weaponsData[citizenid] and weaponsData[citizenid].weapons and weaponsData[citizenid].weapons[serial] then
        local comps = weaponsData[citizenid].weapons[serial].components or {}
        if next(comps) then
            cb({ components = comps })
            return
        end
    end
    
    -- Check database
    local dbRecord = MySQL.query.await('SELECT components FROM player_weapons WHERE serial = ?', { serial })
    if dbRecord and dbRecord[1] and dbRecord[1].components then
        local comps = json.decode(dbRecord[1].components) or {}
        if next(comps) then
            cb({ components = comps })
            return
        end
    end

    cb(nil)
end)

RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:getPlayerWeaponComponents', function(source, cb, serial)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then cb(nil) return end

    local loadedComps = nil
    local citizenid = Player.PlayerData.citizenid
    
    -- Check inventory items first
    for _, item in ipairs(Player.PlayerData.items) do
        if item.type == 'weapon' and item.info and item.info.serie == serial then
            loadedComps = item.info.componentshash or {}
            break
        end
    end
    
    -- Try loading from JSON file
    if not loadedComps or not next(loadedComps) then
        local weaponsData = loadJsonFile(WeaponsDataFile)
        
        if weaponsData[citizenid] and weaponsData[citizenid].weapons and weaponsData[citizenid].weapons[serial] then
            loadedComps = weaponsData[citizenid].weapons[serial].components or {}
        end
    end
    
    -- Try loading from database as final fallback
    if not loadedComps or not next(loadedComps) then
        local dbRecord = MySQL.query.await('SELECT components FROM player_weapons WHERE serial = ?', { serial })
        if dbRecord and dbRecord[1] and dbRecord[1].components then
            local dbComps = json.decode(dbRecord[1].components)
            if dbComps and next(dbComps) then
                loadedComps = dbComps
                
                -- Sync back to inventory if found in database
                for _, item in ipairs(Player.PlayerData.items) do
                    if item.type == 'weapon' and item.info and item.info.serie == serial then
                        item.info.componentshash = loadedComps
                        Player.Functions.SetInventory(Player.PlayerData.items)
                        break
                    end
                end
            end
        end
    end
    
    if loadedComps and next(loadedComps) then
        return cb({ components = loadedComps })
    end

    cb(nil)
end)

----------------------------------------
-- Prop Management
----------------------------------------
local function CreategunsiteId()
    local UniqueFound = false
    local gunsiteId = nil
    while not UniqueFound do
        gunsiteId = 'CSID' .. math.random(11111111, 99999999)
        local query = "%" .. gunsiteId .. "%"
        local result = MySQL.prepare.await("SELECT COUNT(*) as count FROM player_weapons_custom WHERE gunsiteid LIKE ?", { query })
        if result == 0 then
            UniqueFound = true
        end
    end
    return gunsiteId
end

local function CreatePropId()
    local UniqueFound = false
    local PropId = nil
    while not UniqueFound do
        PropId = 'PID' .. math.random(11111111, 99999999)
        local query = "%" .. PropId .. "%"
        local result = MySQL.prepare.await("SELECT COUNT(*) as count FROM player_weapons_custom WHERE propid LIKE ?", { query })
        if result == 0 then
            UniqueFound = true
        end
    end
    return PropId
end

RegisterServerEvent('rsg-weaponcomp:server:createnewprop')
AddEventHandler('rsg-weaponcomp:server:createnewprop', function(propmodel, item, coords, heading)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local gunsiteid = CreategunsiteId()
    local propid = CreatePropId()
    local citizenid = Player.PlayerData.citizenid

    local PropData = {
        gunsitename = locale('cl_lang_32') or 'Gunsmith Workbench',
        gunsiteid = gunsiteid,
        propid = propid,
        item = item,
        x = coords.x,
        y = coords.y,
        z = coords.z,
        h = heading,
        propmodel = propmodel,
        citizenid = citizenid,
        buildttime = os.time()
    }

    local newpropdata = json.encode(PropData)

    MySQL.Async.execute(
        'INSERT INTO player_weapons_custom (gunsiteid, propid, citizenid, item, propdata) VALUES (@gunsiteid, @propid, @citizenid, @item, @propdata)',
        {
            ['@gunsiteid'] = gunsiteid,
            ['@propid'] = propid,
            ['@citizenid'] = citizenid,
            ['@item'] = item,
            ['@propdata'] = newpropdata
        }
    )

    table.insert(Config.PlayerProps, PropData)
    Player.Functions.RemoveItem(Config.Gunsmithitem, 1)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[Config.Gunsmithitem], 'remove', 1)
    TriggerClientEvent('rsg-weaponcomp:client:updatePropData', -1, Config.PlayerProps)
end)

----------------------------------------
-- Props Update
----------------------------------------
RegisterServerEvent('rsg-weaponcomp:server:updateProps')
AddEventHandler('rsg-weaponcomp:server:updateProps', function()
    TriggerClientEvent('rsg-weaponcomp:client:updatePropData', -1, Config.PlayerProps)
end)

CreateThread(function()
    while true do
        Wait(5000)
        if PropsLoaded then
            TriggerClientEvent('rsg-weaponcomp:client:updatePropData', -1, Config.PlayerProps)
        end
    end
end)

RegisterServerEvent('rsg-weaponcomp:server:getProps')
AddEventHandler('rsg-weaponcomp:server:getProps', function()
    local result = MySQL.query.await('SELECT * FROM player_weapons_custom')
    if not result or not result[1] then return end
    for i = 1, #result do
        local propData = json.decode(result[i].propdata)
        table.insert(Config.PlayerProps, propData)
    end
   
end)

----------------------------------------
-- Item Management
----------------------------------------
RegisterServerEvent('rsg-weaponcomp:server:additem')
AddEventHandler('rsg-weaponcomp:server:additem', function(item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    Player.Functions.AddItem(item, amount)
    TriggerClientEvent('ox_lib:notify', src, { 
        title = 'Item Received', 
        description = amount .. 'x ' .. (RSGCore.Shared.Items[item] and RSGCore.Shared.Items[item].label or item), 
        type = 'success' 
    })
end)

RegisterServerEvent('rsg-weaponcomp:server:removeitem')
AddEventHandler('rsg-weaponcomp:server:removeitem', function(item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    Player.Functions.RemoveItem(item, amount)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'remove', amount)
end)

RegisterServerEvent('rsg-weaponcomp:server:removegunsiteprops')
AddEventHandler('rsg-weaponcomp:server:removegunsiteprops', function(propid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    local result = MySQL.query.await('SELECT * FROM player_weapons_custom WHERE propid = ?', { propid })
    if not result or not result[1] then return end
    local propData = json.decode(result[1].propdata)

    if propData.citizenid ~= citizenid then return end

    MySQL.Async.execute('DELETE FROM player_weapons_custom WHERE propid = @propid', { ['@propid'] = propid })

    for k, v in pairs(Config.PlayerProps) do
        if v.propid == propid then
            table.remove(Config.PlayerProps, k)
            break
        end
    end

    TriggerClientEvent('rsg-weaponcomp:client:updatePropData', -1, Config.PlayerProps)
    TriggerClientEvent('rsg-weaponcomp:client:ExitCam', src)
end)

----------------------------------------
-- Save Components & Payment
----------------------------------------
local function saveWeaponComponents(serial, comps, compslabel, Player, wHash, weaponName)
    local weaponSaved = false
    local citizenid = Player.PlayerData.citizenid
    
    local isMeleeOrBow = false
    if serial and tonumber(serial) == wHash then
        isMeleeOrBow = true
    end

    local function getWeaponBaseName(weaponNameOrHash)
        if not weaponNameOrHash then return nil end
        local name = tostring(weaponNameOrHash):lower()
        local base = string.match(name, "weapon_melee_(%w+)") or 
                     string.match(name, "weapon_(%w+)") or 
                     name
        return base
    end

    local targetBaseName = nil
    if isMeleeOrBow and weaponName then
        targetBaseName = getWeaponBaseName(weaponName)
    end

    local function tryMatch(itemNameLower, targetBase)
        if not itemNameLower then return false end
        if targetBase then
            if string.find(itemNameLower, targetBase, 1, true) then
                return true
            end
        end
        return false
    end

    local saveSerial = serial
    local componentsBefore = {}
    
    -- Check inventory and get current components
    for _, item in ipairs(Player.PlayerData.items) do
        if item.type == 'weapon' then
            local match = false
            local itemNameLower = string.lower(item.name or "")
            
            if isMeleeOrBow then
                if targetBaseName and tryMatch(itemNameLower, targetBaseName) then
                    match = true
                end
            else
                if serial and item.info and item.info.serie then
                    if item.info.serie == serial or tostring(item.info.serie) == tostring(serial) then
                        match = true
                        saveSerial = item.info.serie
                    end
                end
            end
            
            if match then
                -- Store previous components
                componentsBefore = item.info.componentshash or {}
                
                -- Set new components - create new tables to avoid reference issues
                if type(comps) == "table" and next(comps) then
                    item.info.componentshash = {}
                    for k, v in pairs(comps) do
                        item.info.componentshash[k] = v
                    end
                else
                    item.info.componentshash = nil
                end
                
                if type(compslabel) == "table" and next(compslabel) then
                    item.info.components = {}
                    for k, v in pairs(compslabel) do
                        item.info.components[k] = v
                    end
                else
                    item.info.components = nil
                end
                
                weaponSaved = true
                break
            end
        end
    end
    
    -- Calculate total price for this transaction
    local totalPrice = 0
    for cat, _ in pairs(comps or {}) do
        totalPrice = totalPrice + (Config.price and Config.price[cat] or 0)
    end
    
    -- Save to weapons_data.json
    if saveSerial then
        UpdateWeaponsJson(citizenid, saveSerial, {
            componentshash = comps,
            components = compslabel
        })
    end
    
    -- Also save to database for persistence
    if saveSerial then
        SaveWeaponToDatabase(citizenid, saveSerial, comps, componentsBefore, totalPrice, 0)
    end

    -- Update player inventory
    Player.Functions.SetInventory(Player.PlayerData.items)
    if Player.PlayerData.metadata then
        Player.Functions.SetMetaData(Player.PlayerData.metadata)
    end

    -- Logging
    local serialStr = serial or ("hash:" .. tostring(wHash))
    local msg = table.concat({
        (locale('sv_lang_6') or 'Citizen') .. ': **' .. citizenid .. '**',
        (locale('sv_lang_7') or 'CID') .. ': **' .. Player.PlayerData.cid .. '**',
        (locale('sv_lang_8') or 'Serial') .. ': **' .. serialStr .. '**',
        (locale('sv_lang_9') or 'Components') .. ': **' .. json.encode(comps) .. '**'
    }, '\n')
    
    if Config.WebhookName then
        TriggerEvent('rsg-log:server:CreateLog', Config.WebhookName, Config.WebhookTitle or 'Weapon Components', Config.WebhookColour or 'green', msg)
    end
    
    return weaponSaved
end

RegisterServerEvent('rsg-weaponcomp:server:price')
AddEventHandler('rsg-weaponcomp:server:price', function(price, objecthash, serial, selectedCache, selectedLabels, wHash, weaponName)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local paymentType = Config.PaymentType or 'cash'
    local currentCash = Player.Functions.GetMoney(paymentType)
    
    if currentCash < price then
        TriggerClientEvent('ox_lib:notify', src, { 
            title = (locale('sv_lang_10') or 'Not Enough Money'), 
            description = (locale('sv_lang_11') or 'You need $' .. price), 
            type = 'error' 
        })
        TriggerClientEvent('rsg-weaponcomp:client:ExitCam', src)
        return
    end

    Player.Functions.RemoveMoney(paymentType, price)

    saveWeaponComponents(serial, selectedCache, selectedLabels, Player, wHash, weaponName)
    TriggerClientEvent('rsg-weaponcomp:client:animationSaved', src, objecthash, serial)
    TriggerClientEvent('ox_lib:notify', src, { 
        title = (locale('sv_lang_12') or 'Purchase Complete'), 
        description = (locale('sv_lang_13') or 'Paid $' .. price), 
        type = 'success' 
    })
end)

----------------------------------------
-- Reload on Login/Equip
----------------------------------------
-- Disabled - causes issues when no weapon is equipped on login
-- AddEventHandler('rsg-core:server:playerLoggedIn', function(playerId, player)
--     Wait(2000)
--     TriggerClientEvent('rsg-weaponcomp:client:reloadWeapon', playerId)
-- end)

RegisterNetEvent('rsg-weapons:server:saveEquippedKnife')
AddEventHandler('rsg-weapons:server:saveEquippedKnife', function(knifeName, equipped)
    local src = source
    if equipped then
        Wait(500)
        TriggerClientEvent('rsg-weaponcomp:client:reloadWeapon', src)
    end
end)

RegisterNetEvent('rsg-weapons:server:saveEquippedWeapon')
AddEventHandler('rsg-weapons:server:saveEquippedWeapon', function(weaponData, equipped)
    local src = source
    if equipped then
        Wait(500)
        TriggerClientEvent('rsg-weaponcomp:client:reloadWeapon', src)
    end
end)

RegisterNetEvent('rsg-weaponcomp:server:check_comps')
AddEventHandler('rsg-weaponcomp:server:check_comps', function()
    local src = source
    TriggerClientEvent('rsg-weaponcomp:client:reloadWeapon', src)
end)

RegisterServerEvent('rsg-weaponcomp:server:inspectkitConsume')
AddEventHandler('rsg-weaponcomp:server:inspectkitConsume', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if Config.RepairItem then
        Player.Functions.RemoveItem(Config.RepairItem, 1)
    end
end)