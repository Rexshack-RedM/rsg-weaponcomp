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

-- Save weapon components
RegisterNetEvent('rsg-weaponcomp:server:saveWeaponComponents', function(serial, components)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    MySQL.update(
        "UPDATE player_weapons SET components = ? WHERE serial = ?",
        { json.encode(components), serial }
    )

    TriggerEvent('rsg-weaponcomp:server:updateProps', src)

    local citizenid = Player.PlayerData.citizenid
    local ingameId = Player.PlayerData.cid
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    local job = Player.PlayerData.job.name
    local msg = 'Citizenid:** ' .. citizenid .. '**' ..
      '\nIngame ID:** ' .. ingameId .. '**' ..
      '\nName:** ' .. firstname .. ' ' .. lastname .. '**' ..
      '\nJob:** ' .. job .. '**' ..
      '\nSerial:** ' .. serial .. '**' ..
      '\nComponents Specific:** ' .. json.encode(components) .. '**'

    TriggerEvent('rsg-log:server:CreateLog',
        Config.WebhookName,
        Config.WebhookTitle,
        Config.WebhookColour,
        msg
    )
end)

-- Provide saved components
RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:getPlayerWeaponComponents', function(source, cb, serial)
  local res = MySQL.query.await(
    "SELECT components FROM player_weapons WHERE serial = ?",
    { serial }
  )
  if res[1] then cb({ components = json.decode(res[1].components) }) else cb({}) end
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

---------------------------------------------
-- getPlayerWeaponComponents
---------------------------------------------
RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:getPlayerWeaponComponents', function(source, cb, serial)
    local result = MySQL.query.await("SELECT components FROM player_weapons WHERE serial = ?", { serial })
    if result[1] then
        cb({ components = json.decode(result[1].components_before) })
    else
        cb({})
    end
end)

-- --------------------------------------------
-- -- COMMAND 
-- --------------------------------------------

RSGCore.Commands.Add(Config.Commandinspect, locale('label_40'), {}, false, function(source)
    local src = source
    TriggerClientEvent('rsg-weaponcomp:client:InspectionWeapon', src)
end)

-- RSGCore.Commands.Add(Config.Commandloadweapon, locale('label_41'), {}, false, function(source)
--     local src = source
--     TriggerClientEvent('rsg-weaponcomp:client:LoadComponents', src)
-- end)

-- -------------------------------------------
-- -- Payment
-- -------------------------------------------
RegisterServerEvent('rsg-weaponcomp:server:price')
AddEventHandler('rsg-weaponcomp:server:price', function(price, objecthash, serial, selectedCache)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if Config.Payment == 'money' then
        local currentCash = Player.Functions.GetMoney(Config.PaymentType)
        if currentCash < tonumber(price) then
            TriggerClientEvent('ox_lib:notify', src, {title = locale('notify_46') .. tonumber(price), description = locale('notify_47'), type = 'error', duration = 5000 })
            TriggerClientEvent('rsg-weaponcomp:client:ExitCam', src)
            return
        else
            if selectedCache ~= nil then
                TriggerEvent('rsg-weaponcomp:server:saveWeaponComponents', src, serial, selectedCache)
            else
                TriggerEvent('rsg-weaponcomp:server:saveWeaponComponents', src, serial, nil)
            end
            Player.Functions.RemoveMoney(Config.PaymentType, tonumber(price))
            TriggerClientEvent('rsg-weaponcomp:client:animationSaved', src, objecthash, serial)

            TriggerClientEvent('ox_lib:notify', src, {title = locale('notify_48') ..tonumber(price), description = locale('notify_49'), type = 'inform', duration = 5000 })
        end
    end

end)

-- --------------------------------------------
-- -- CHECK COMPONENTS SQL
-- --------------------------------------------
RegisterNetEvent('rsg-weaponcomp:server:check_comps') -- EQUIPED
AddEventHandler('rsg-weaponcomp:server:check_comps', function(serial)
    local src = source
    TriggerClientEvent('rsg-weapons:client:reloadWeapon', src, serial)
end)

-- --------------------------------------------
-- -- ADD COMPONENTS SQL
-- --------------------------------------------
-- -- Server event for storing components in the database
-- RegisterNetEvent('rsg-weaponcomp:server:apply_weapon_components')
-- AddEventHandler('rsg-weaponcomp:server:apply_weapon_components', function(components, weaponName, serial)
--     local src = source
--     local Player = RSGCore.Functions.GetPlayer(src)

--     -- ADD CUSTOM EVER
--     MySQL.Async.execute('UPDATE player_weapons SET components = @components WHERE serial = @serial', {
--         ['@components'] = json.encode(components),
--         ['@serial'] = serial
--     }, function(rowsChanged)
--         if rowsChanged > 0 then

--             sendToDiscord(16753920,	'Craft | WEAPON CUSTOM', '**Citizenid:** '..Player.PlayerData.citizenid..'\n**Ingame ID:** '..Player.PlayerData.cid.. '\n**Name:** '..Player.PlayerData.charinfo.firstname..' '..Player.PlayerData.charinfo.lastname.. '\n**Job:** '.. 'job' ..'\n**Weapon:** '..weaponName .. '\n**Serial:** '..serial .. '\n**Components Specific:** '.. json.encode(components),	'Weapon Craft  for RSG Framework', 'weapons')
--             Wait(1000)
--             TriggerClientEvent('ox_lib:notify', src, {title = locale('notify_50'), type = 'inform', duration = 5000 })

--             if Config.Debug then print('Weapon components have been successfully updated for the serial:', serial, json.encode(components)) end

--             Wait(100)
--             TriggerClientEvent('rsg-weaponcomp:client:LoadComponents', src)
--         end
--     end)

--     -- DELETE CUSTOM TABLE
--     Wait(100)
--     TriggerEvent('rsg-weaponcomp:server:removeComponents_selection', 'DEFAULT', serial) -- update SQL

-- end)

-- RegisterNetEvent('rsg-weaponcomp:server:update_selection')
-- AddEventHandler('rsg-weaponcomp:server:update_selection', function(components, serial)
--     local src = source
--     -- ADD CUSTOM SELECTION
--     MySQL.Async.execute('UPDATE player_weapons SET components_before = @components_before WHERE serial = @serial', {
--         ['@components_before'] = json.encode(components),
--         ['@serial'] = serial
--     }, function(rowsChanged)
--         if rowsChanged > 0 then
--             TriggerClientEvent('rsg-weaponcomp:client:LoadComponents_selection', src)
--         end
--     end)
-- end)

-- -------------------------------------------
-- -- update/REMOVE components SQL
-- -------------------------------------------
-- RegisterServerEvent('rsg-weaponcomp:server:removeComponents', function(components, weaponName, serial)
--     local src = source
--     local Player = RSGCore.Functions.GetPlayer(src)
--     if components == 'DEFAULT' then
--         MySQL.Async.execute('UPDATE player_weapons SET components = DEFAULT WHERE serial = @serial', {
--             ['@serial'] = serial
--         }, function(rowsChanged)
--             if rowsChanged > 0 then
--                 sendToDiscord(16753920,	'Craft | WEAPON CUSTEM', '**Citizenid:** '..Player.PlayerData.citizenid..'\n**Ingame ID:** '..Player.PlayerData.cid.. '\n**Name:** '..Player.PlayerData.charinfo.firstname..' '..Player.PlayerData.charinfo.lastname.. '\n**Job:** '.. 'job' ..'\n**Weapon:** '.. weaponName .. '\n**Serial:** '..serial .. '\n**Components Specific:** '.. '{}',	'Weapon Craft  for RSG Framework', 'weapons')
--                 Wait(2000)
--                 TriggerClientEvent('ox_lib:notify', src, {title = locale('notify_51'), type = 'inform', duration = 5000 })

--                 Wait(100)
--                 TriggerClientEvent('rsg-weaponcomp:client:LoadComponents', src)

--             end
--         end)
--     end
-- end)

-- RegisterServerEvent('rsg-weaponcomp:server:removeComponents_selection', function(components, serial)
--     local src = source
--     if components == 'DEFAULT' then
--         MySQL.Async.execute('UPDATE player_weapons SET components_before = DEFAULT WHERE serial = @serial', {
--             ['@serial'] = serial
--         }, function()
--             TriggerClientEvent('rsg-weaponcomp:client:LoadComponents_selection', src)
--         end)
--     end
-- end)

-- --------------------------------------------
-- -- VISION COMPONENTS / IN TEST
-- --------------------------------------------
-- RegisterNetEvent('rsg-weaponcomp:server:inspectWeapon')
-- AddEventHandler('rsg-weaponcomp:server:inspectWeapon', function(weaponHash)
--     local src = source
--     local stats = getWeaponStats(weaponHash)
--     TriggerClientEvent('rsg-weaponcomp:client:viewweapon', src, weaponHash, stats)
-- end)


-- RegisterNetEvent('rsg-weaponcomp:server:inspectkitConsume')
-- AddEventHandler('rsg-weaponcomp:server:inspectkitConsume', function()
--     local src = source
--     local cashItem = Player.Functions.GetItemByName(Config.RepairItem)

--     if not cashItem then
--         TriggerClientEvent('ox_lib:notify', src, {title = locale('notify_52'), description = locale('notify_53'), type = 'error', duration = 5000 })
--         return
--     else
--         Player.Functions.RemoveItem(Config.RepairItem, 1, 'custom-weapon')
--         TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[Config.RepairItem], 'remove')
--     end
-- end)
