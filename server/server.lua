local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- When player uses the gunsmith item, open the prop placer
RSGCore.Functions.CreateUseableItem(Config.Gunsmithitem, function(source)
  TriggerClientEvent('rsg-weaponcomp:client:createprop', source, {
    propmodel = Config.Gunsmithprop,
    item      = Config.Gunsmithitem
  })
end)

--------------------------------------------
-- COMMAND 
--------------------------------------------
RSGCore.Commands.Add(Config.Commandinspect, locale('cl_lang_30'), {}, false, function(source)
    local src = source
    TriggerClientEvent('rsg-weaponcomp:client:InspectionWeapon', src)
end)

RSGCore.Commands.Add(Config.Commandloadweapon, locale('cl_lang_31'), {}, false, function(source)
    local src = source
    TriggerEvent('rsg-weaponcomp:server:check_comps', src)
end)

-- Helper para buscar el item de arma por serie
local function GetWeaponItemEntry(Player, serial)
    for _, item in ipairs(Player.PlayerData.items) do
        if item.type == 'weapon'
        and item.info
        and item.info.serie == serial
        then
            return item
        end
    end
    return nil
end

-- EQUIPAR SCOPE
RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:equipScope', function(source, cb, serial)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end

    local weaponItem = GetWeaponItemEntry(Player, serial)
    if not weaponItem then
        return cb(false)
    end

    if weaponItem.info.equippedScope then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = locale('cl_scope_already_on') })
        return cb(false)
    end

    weaponItem.info.equippedScope = true
    Player.Functions.SetInventory(Player.PlayerData.items)
    cb(true)
end)

-- REMOVER SCOPE
RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:unequipScope', function(source, cb, serial)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end

    local weaponItem = GetWeaponItemEntry(Player, serial)
    if not weaponItem then
        return cb(false)
    end

    if not weaponItem.info.equippedScope then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = locale('cl_scope_already_off') })
        return cb(false)
    end

    weaponItem.info.equippedScope = false
    Player.Functions.SetInventory(Player.PlayerData.items)
    cb(true)
end)

--------------------------------------------
-- Callback
--------------------------------------------
-- Count how many sites player has
RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:countprop', function(source, cb, proptype)
  local ply = RSGCore.Functions.GetPlayer(source)
  local res = MySQL.prepare.await( "SELECT COUNT(*) as count FROM player_weapons_custom WHERE citizenid = ? AND item = ?",
    { ply.PlayerData.citizenid, proptype }
  )
  cb(res or 0)
end)

RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:getItemBySerial', function(source, cb, serial)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then cb(nil); return end

    for _, item in ipairs(Player.PlayerData.items) do
        if item.type == 'weapon' and item.info and item.info.serie == serial then
            cb({ components = item.info.componentshash})
            return
        end
    end

    cb(nil)
end)

RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:getPlayerWeaponComponents', function(source, cb, serial)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then cb(nil); return end

    for _, item in ipairs(Player.PlayerData.items) do
        if item.type == 'weapon'
        and item.info
        and item.info.serie == serial
        then
            local comps = item.info.componentshash or {}

            if not item.info.equippedScope then
                local filtered = {}
                for cat, name in pairs(comps) do
                    if cat ~= "SCOPE" then
                        filtered[cat] = name
                    end
                end
                comps = filtered
            end

            return cb({ components = comps })
        end
    end

    cb(nil)
end)

---------------------------------------------
-- create new gunsite in database
---------------------------------------------
-- create gunsite id
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

-- create prop id
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

    local PropData =
    {
        gunsitename = locale('cl_lang_32'),
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

    -- add gunsite to database
    MySQL.Async.execute('INSERT INTO player_weapons_custom (gunsiteid, propid, citizenid, item, propdata) VALUES (@gunsiteid, @propid, @citizenid, @item, @propdata)', {
        ['@gunsiteid'] = gunsiteid,
        ['@propid'] = propid,
        ['@citizenid'] = citizenid,
        ['@item'] = item,
        ['@propdata'] = newpropdata
    })

    table.insert(Config.PlayerProps, PropData)
    Player.Functions.RemoveItem(Config.Gunsmithitem, 1)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[Config.Gunsmithitem], 'remove', 1)
    TriggerEvent('rsg-weaponcomp:server:updateProps', src)

end)

---------------------------------------------
-- update props
---------------------------------------------
RegisterServerEvent('rsg-weaponcomp:server:updateProps')
AddEventHandler('rsg-weaponcomp:server:updateProps', function()
    local src = source
    TriggerClientEvent('rsg-weaponcomp:client:updatePropData', src, Config.PlayerProps)
end)

-- update prop
CreateThread(function()
    while true do
        Wait(5000)
        if PropsLoaded then
            TriggerClientEvent('rsg-weaponcomp:client:updatePropData', -1, Config.PlayerProps)
        end
    end
end)

-- get props
CreateThread(function()
    TriggerEvent('rsg-weaponcomp:server:getProps', source)
    PropsLoaded = true
end)

RegisterServerEvent('rsg-weaponcomp:server:getProps')
AddEventHandler('rsg-weaponcomp:server:getProps', function()
    local result = MySQL.query.await('SELECT * FROM player_weapons_custom')
    if not result[1] then return end
    for i = 1, #result do
        local propData = json.decode(result[i].propdata)
        if Config.LoadNotification then print(locale('sv_lang_1')..propData.item..locale('sv_lang_2')..propData.propid) end
        table.insert(Config.PlayerProps, propData)
    end
end)

---------------------------------------------
-- items
---------------------------------------------
-- add item
RegisterServerEvent('rsg-weaponcomp:server:additem')
AddEventHandler('rsg-weaponcomp:server:additem', function(item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    Player.Functions.AddItem(item, amount)
    TriggerClientEvent('rNotify:ShowAdvancedRightNotification', src, amount .." x "..RSGCore.Shared.Items[item].label, "generic_textures" , "tick" , "COLOR_PURE_WHITE", 4000)
end)

-- remove
RegisterServerEvent('rsg-weaponcomp:server:removeitem')
AddEventHandler('rsg-weaponcomp:server:removeitem', function(item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    Player.Functions.RemoveItem(item, amount)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'remove', amount)
end)

-- remove gunsite props
RegisterServerEvent('rsg-weaponcomp:server:removegunsiteprops')
AddEventHandler('rsg-weaponcomp:server:removegunsiteprops', function(propid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    local result = MySQL.query.await('SELECT * FROM player_weapons_custom WHERE propid = ?', { propid })
    if not result or not result[1] then return end
    local propData = json.decode(result[1].propdata)

    if propData.citizenid ~= citizenid then print(locale('sv_lang_3')) return end

    MySQL.Async.execute('DELETE FROM player_weapons_custom WHERE propid = @propid', { ['@propid'] = propid })

    for k, v in pairs(Config.PlayerProps) do
        if v.propid == propid then
            table.remove(Config.PlayerProps, k)
            break
        end
    end

    -- print((locale('sv_lang_4').. " %s ".. locale('sv_lang_5') .." %s"):format(citizenid, propid))

    TriggerClientEvent('rsg-weaponcomp:client:updatePropData', -1, Config.PlayerProps)
    TriggerClientEvent('rsg-weaponcomp:client:ExitCam', src)
end)

-------------------------------------------
-- Save / Payment
-------------------------------------------
local function saveWeaponComponents(serial, comps, compslabel, Player)

    for _, item in ipairs(Player.PlayerData.items) do
        if item.type == 'weapon' and item.info.serie == serial then
            item.info.componentshash = (type(comps) == "table" and next(comps)) and comps or nil
            item.info.components = (type(compslabel) == "table" and next(compslabel)) and compslabel or nil
            break
        end
    end

    Player.Functions.SetInventory(Player.PlayerData.items)

    -- Logging
    local msg = table.concat({
        locale('sv_lang_6') .. ':** '..Player.PlayerData.citizenid..'**',
        locale('sv_lang_7') .. ':** '..Player.PlayerData.cid..'**',
        locale('sv_lang_8') .. ':** '..serial..'**',
        locale('sv_lang_9') .. ':** '..json.encode(comps)
    }, '\n')
    TriggerEvent('rsg-log:server:CreateLog', Config.WebhookName, Config.WebhookTitle, Config.WebhookColour, msg)
end

RegisterServerEvent('rsg-weaponcomp:server:price')
AddEventHandler('rsg-weaponcomp:server:price', function(price, objecthash, serial, selectedCache, selectedLabels)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local currentCash = Player.Functions.GetMoney(Config.PaymentType)
    if currentCash < price then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_lang_10', price), description = locale('sv_lang_11'), type = 'error' })
        TriggerClientEvent('rsg-weaponcomp:client:ExitCam', src)
        return
    end

    Player.Functions.RemoveMoney(Config.PaymentType, price)
    -- print(objecthash, serial, selectedCache, json.encode(selectedCache))

    saveWeaponComponents(serial, selectedCache, selectedLabels, Player)
    TriggerClientEvent('rsg-weaponcomp:client:animationSaved', src, objecthash, serial)
    TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_lang_12', price), description = locale('sv_lang_13'), type = 'inform' })
end)

--------------------------------------------
-- CHECK COMPONENTS SQL
--------------------------------------------
RegisterNetEvent('rsg-weaponcomp:server:check_comps') -- EQUIPED
AddEventHandler('rsg-weaponcomp:server:check_comps', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    TriggerClientEvent('rsg-weaponcomp:client:reloadWeapon', src)
end)
