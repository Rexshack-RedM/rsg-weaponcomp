local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- When player uses the gunsmith item, open the prop placer
RSGCore.Functions.CreateUseableItem(Config.Gunsmithitem, function(source)
  TriggerClientEvent('rsg-weaponcomp:client:createprop', source, {
    propmodel = Config.Gunsmithprop,
    item      = Config.Gunsmithitem,
  })
end)

-- Count how many sites player has
RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:countprop', function(source, cb, proptype)
  local ply = RSGCore.Functions.GetPlayer(source)
  local res = MySQL.prepare.await(
    "SELECT COUNT(*) as count FROM hdrp_weapons_custom WHERE citizenid = ? AND item = ?",
    { ply.PlayerData.citizenid, proptype }
  )
  cb(res or 0)
end)

-- Provide saved components
RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:getPlayerWeaponComponents', function(source, cb, serial)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then cb(nil); return end

    for _, item in pairs(Player.PlayerData.items) do
        if item.type == 'weapon' and item.info and item.info.serie == serial then
            local comps = item.info.components or nil
            cb({ components = comps })
            return
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
        local result = MySQL.prepare.await("SELECT COUNT(*) as count FROM hdrp_weapons_custom WHERE gunsiteid LIKE ?", { query })
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
        local result = MySQL.prepare.await("SELECT COUNT(*) as count FROM hdrp_weapons_custom WHERE propid LIKE ?", { query })
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
        gunsitename = 'Player gunsite',
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
    MySQL.Async.execute('INSERT INTO hdrp_weapons_custom (gunsiteid, propid, citizenid, item, propdata) VALUES (@gunsiteid, @propid, @citizenid, @item, @propdata)', { 
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
-- update prop data
---------------------------------------------
CreateThread(function()
    while true do
        Wait(5000)
        if PropsLoaded then
            TriggerClientEvent('rsg-weaponcomp:client:updatePropData', -1, Config.PlayerProps)
        end
    end
end)

---------------------------------------------
-- get props
---------------------------------------------
CreateThread(function()
    TriggerEvent('rsg-weaponcomp:server:getProps', source)
    PropsLoaded = true
end)

---------------------------------------------
-- remove item
---------------------------------------------
RegisterServerEvent('rsg-weaponcomp:server:removeitem')
AddEventHandler('rsg-weaponcomp:server:removeitem', function(item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    Player.Functions.RemoveItem(item, amount)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'remove', amount)
end)

---------------------------------------------
-- add item
---------------------------------------------
RegisterServerEvent('rsg-weaponcomp:server:additem')
AddEventHandler('rsg-weaponcomp:server:additem', function(item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    Player.Functions.AddItem(item, amount)
    TriggerClientEvent('rNotify:ShowAdvancedRightNotification', src, amount .." x "..RSGCore.Shared.Items[item].label, "generic_textures" , "tick" , "COLOR_PURE_WHITE", 4000)
end)

---------------------------------------------
-- remove gunsite props
---------------------------------------------
RegisterServerEvent('rsg-weaponcomp:server:removegunsiteprops')
AddEventHandler('rsg-weaponcomp:server:removegunsiteprops', function(propid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    local result = MySQL.query.await('SELECT * FROM hdrp_weapons_custom WHERE propid = ?', { propid })
    if not result or not result[1] then return end
    local propData = json.decode(result[1].propdata)

    if propData.citizenid ~= citizenid then
        print('[rsg-weaponcomp] Intento no autorizado de eliminar un prop de otro jugador.')
        return
    end

    MySQL.Async.execute('DELETE FROM hdrp_weapons_custom WHERE propid = @propid', { ['@propid'] = propid })

    for k, v in pairs(Config.PlayerProps) do
        if v.propid == propid then
            table.remove(Config.PlayerProps, k)
            break
        end
    end

    print(('[rsg-weaponcomp] %s intentó recoger %s'):format(citizenid, propid))

    TriggerClientEvent('rsg-weaponcomp:client:updatePropData', -1, Config.PlayerProps)
    TriggerClientEvent('rsg-weaponcomp:client:ExitCam', src)
end)

---------------------------------------------
-- get props
---------------------------------------------
RegisterServerEvent('rsg-weaponcomp:server:getProps')
AddEventHandler('rsg-weaponcomp:server:getProps', function()
    local result = MySQL.query.await('SELECT * FROM hdrp_weapons_custom')
    if not result[1] then return end
    for i = 1, #result do
        local propData = json.decode(result[i].propdata)
        if Config.LoadNotification then
            print(locale('sv_lang_1')..propData.item..locale('sv_lang_2')..propData.propid)
        end
        table.insert(Config.PlayerProps, propData)
    end
end)

---------------------------------------------
-- update props
---------------------------------------------
RegisterServerEvent('rsg-weaponcomp:server:updateProps')
AddEventHandler('rsg-weaponcomp:server:updateProps', function()
    local src = source
    TriggerClientEvent('rsg-weaponcomp:client:updatePropData', src, Config.PlayerProps)
end)

-- --------------------------------------------
-- -- COMMAND 
-- --------------------------------------------
RSGCore.Commands.Add(Config.Commandinspect, locale('label_40'), {}, false, function(source)
    local src = source
    TriggerClientEvent('rsg-weaponcomp:client:InspectionWeapon', src)
end)

RSGCore.Commands.Add(Config.Commandloadweapon, locale('label_41'), {}, false, function(source)
    local src = source
    TriggerEvent('rsg-weaponcomp:server:check_comps', src)
end)

-- -------------------------------------------
-- -- Payment
-- -------------------------------------------
local function saveWeaponComponents(serial, comps, Player)
    -- Inventario
    for _, item in ipairs(Player.PlayerData.items) do
        if item.type == 'weapon' and item.info.serie == serial then
            item.info.components = (type(comps) == "table" and next(comps)) and comps or nil
            break
        end
    end
    Player.Functions.SetInventory(Player.PlayerData.items)

    -- Logging
    local msg = table.concat({
        'Citizenid:** '..Player.PlayerData.citizenid..'**',
        'Ingame ID:** '..Player.PlayerData.cid..'**',
        'Serial:** '..serial..'**',
        'Components:** '..json.encode(comps)
    }, '\n')
    TriggerEvent('rsg-log:server:CreateLog', Config.WebhookName, Config.WebhookTitle, Config.WebhookColour, msg)
end

RegisterServerEvent('rsg-weaponcomp:server:price')
AddEventHandler('rsg-weaponcomp:server:price', function(price, objecthash, serial, selectedCache)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if Config.Payment == 'money' then
        local currentCash = Player.Functions.GetMoney(Config.PaymentType)
        if currentCash < price then
            TriggerClientEvent('ox_lib:notify', src, { title = locale('notify_46', price), description = locale('notify_47'), type = 'error' })
            return
        end

        Player.Functions.RemoveMoney(Config.PaymentType, price)
        -- print(objecthash, serial, selectedCache, json.encode(selectedCache))

        saveWeaponComponents(serial, selectedCache, Player)
        TriggerClientEvent('rsg-weaponcomp:client:animationSaved', src, objecthash, serial)
        TriggerClientEvent('ox_lib:notify', src, { title = locale('notify_48', price), description = locale('notify_49'), type = 'inform' })
    end
end)

-- --------------------------------------------
-- -- CHECK COMPONENTS SQL
-- --------------------------------------------
RegisterNetEvent('rsg-weaponcomp:server:check_comps') -- EQUIPED
AddEventHandler('rsg-weaponcomp:server:check_comps', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    TriggerClientEvent('rsg-weapons:client:reloadWeapon', src)
end)