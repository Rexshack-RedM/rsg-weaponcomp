local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

----------------------------------------
-- Component whitelist (built from config)
----------------------------------------
local ValidComps = {}   -- ValidComps[category][componentName] = true
local FactoryComps = {} -- factory parts (first entry of structural lists such as the wood stock)

local function indexComponents(source)
    for cat, list in pairs(source or {}) do
        ValidComps[cat] = ValidComps[cat] or {}
        for i, comp in ipairs(list) do
            ValidComps[cat][comp] = true
            if i == 1 and WeaponComp.IsFactoryCategory(cat) then FactoryComps[comp] = true end
        end
    end
end

for _, groupComps in pairs(Config.Shared or {}) do indexComponents(groupComps) end
for _, weaponComps in pairs(Config.Specific or {}) do indexComponents(weaponComps) end

----------------------------------------
-- Helpers
----------------------------------------
local RestrictedWeapons = {}
for _, name in ipairs(Config.WeaponRestriction or {}) do RestrictedWeapons[joaat(name)] = true end

local Cooldowns = {}

-- Weapons already checked against the database this session (no saved row = skip next time).
-- The lookup runs on every weapon draw, so this avoids a query per draw for unmodified weapons.
local DbChecked = {}

local function onCooldown(src, key, ms)
    local now = GetGameTimer()
    Cooldowns[src] = Cooldowns[src] or {}
    if Cooldowns[src][key] and now - Cooldowns[src][key] < ms then return true end
    Cooldowns[src][key] = now
    return false
end

AddEventHandler('playerDropped', function()
    Cooldowns[source] = nil
end)

local function notify(src, title, description, nType)
    TriggerClientEvent('ox_lib:notify', src, {
        title = title,
        description = description,
        type = nType or 'inform',
        duration = 5000
    })
end

local function roundMoney(value)
    return math.floor(value * 100 + 0.5) / 100
end

local function hasRequiredJob(Player)
    return not Config.RequiredJob or Player.PlayerData.job.name == Config.RequiredJob
end

--- Finds the weapon item a customisation applies to.
--- Serialised weapons match on serial; melee/bows (serial == weapon hash) match on item name.
local function findWeaponItem(Player, serial, weaponName)
    if type(serial) ~= 'string' and type(serial) ~= 'number' then return nil end
    serial = tostring(serial)

    for _, item in pairs(Player.PlayerData.items) do
        if item.type == 'weapon' and item.info and item.info.serie and tostring(item.info.serie) == serial then
            return item, false
        end
    end

    -- compare modulo 2^32 so signed/unsigned hash representations both match
    local serialHash = tonumber(serial)
    if type(weaponName) == 'string' and serialHash and (serialHash - joaat(weaponName)) % 4294967296 == 0 then
        local wanted = weaponName:lower()
        for _, item in pairs(Player.PlayerData.items) do
            if item.type == 'weapon' and item.name and item.name:lower() == wanted then
                return item, true
            end
        end
    end

    return nil
end

--- Returns a clean component table containing only whitelisted, non-factory parts.
--- Factory parts are dropped so only real modifications are stored and charged.
--- Second return value lists anything that isn't in the config at all (tampering).
local function sanitizeComponents(comps)
    if type(comps) ~= 'table' then return nil end
    local clean, invalid, count = {}, {}, 0
    for cat, comp in pairs(comps) do
        count = count + 1
        if count > 64 then return nil, { 'more than 64 entries' } end
        local valid = type(cat) == 'string' and type(comp) == 'string' and ValidComps[cat] and ValidComps[cat][comp]
        if not valid then
            invalid[#invalid + 1] = ('%s = %s'):format(tostring(cat), tostring(comp))
        elseif cat ~= 'FRAME_VERTDATA' and not FactoryComps[comp] then
            clean[cat] = comp
        end
    end
    return clean, invalid
end

local function calculateRemovePrice(current)
    local total = 0
    for cat in pairs(current) do
        total = total + (Config.price[cat] or 0)
    end
    return roundMoney(total * (Config.RemovePrice or 0.5))
end

local function buildLabels(comps)
    local labels = {}
    for cat, comp in pairs(comps) do labels[cat] = locale(comp) end
    return labels
end

local function saveToDatabase(citizenid, serial, components, componentsBefore, price)
    local params = { json.encode(components), json.encode(componentsBefore), price, serial, citizenid }
    local updated = MySQL.update.await('UPDATE player_weapons SET components = ?, components_before = ?, price = ? WHERE serial = ? AND citizenid = ?', params)
    if updated == 0 then
        MySQL.insert.await('INSERT INTO player_weapons (components, components_before, price, serial, citizenid) VALUES (?, ?, ?, ?, ?)', params)
    end
end

local function logChange(src, item, serial, before, after, price)
    local isReset = not next(after)
    local fields = {
        { locale('sv_dc_weapon'), RSGCore.Shared.Items[item.name] and RSGCore.Shared.Items[item.name].label or item.name },
        { locale('sv_dc_serial'), tostring(serial) },
        { locale('sv_dc_paid'), ('%s%.2f (%s)'):format(locale('ui_currency'), price, Config.PaymentType or 'cash') },
    }
    if DiscordConfig.ShowComponents then
        fields[#fields + 1] = { locale('sv_dc_before'), Discord.FormatComponents(before), false }
        if not isReset then fields[#fields + 1] = { locale('sv_dc_after'), Discord.FormatComponents(after), false } end
    end
    Discord.Log(isReset and 'reset' or 'purchase', src, locale(isReset and 'sv_dc_reset' or 'sv_dc_purchase'), fields)
end

--- Applies a new component set to the weapon item, charges the player and persists it.
local function applyWeaponChange(src, Player, item, serial, newComps, price, wHash)
    local paymentType = Config.PaymentType or 'cash'

    if price > 0 then
        if Player.Functions.GetMoney(paymentType) < price then
            notify(src, locale('sv_lang_10'), locale('sv_lang_11', price), 'error')
            return false
        end
        if not Player.Functions.RemoveMoney(paymentType, price, 'weapon-customisation') then
            return false
        end
    end

    local before = sanitizeComponents(item.info.componentshash) or {}
    item.info.componentshash = next(newComps) and newComps or nil
    item.info.components = next(newComps) and buildLabels(newComps) or nil
    Player.Functions.SetInventory(Player.PlayerData.items)

    saveToDatabase(Player.PlayerData.citizenid, tostring(serial), newComps, before, price)
    DbChecked[Player.PlayerData.citizenid .. ':' .. tostring(serial)] = true
    logChange(src, item, serial, before, newComps, price)

    notify(src, locale('sv_lang_12'), locale('sv_lang_13', price), 'success')
    TriggerClientEvent('rsg-weaponcomp:client:animationSaved', src, wHash)
    return true
end

----------------------------------------
-- Purchase / Reset
----------------------------------------
RegisterNetEvent('rsg-weaponcomp:server:purchase', function(serial, wHash, weaponName, comps)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or onCooldown(src, 'purchase', 3000) then return end
    if type(wHash) ~= 'number' or RestrictedWeapons[wHash] then return end

    local item = findWeaponItem(Player, serial, weaponName)
    if not item then
        notify(src, locale('cl_notify_13'), locale('cl_no_weapon'), 'error')
        return
    end
    if RestrictedWeapons[joaat(item.name)] then -- don't trust the client's hash
        Discord.Security(src, locale('sv_sec_restricted'), item.name)
        return
    end

    local newComps, invalid = sanitizeComponents(comps)
    if not newComps or (invalid and #invalid > 0) then
        Discord.Security(src, locale('sv_sec_invalid'), invalid and table.concat(invalid, '\n') or locale('sv_sec_not_table'))
    end
    if not newComps then return end

    local current = sanitizeComponents(item.info.componentshash) or {}
    local price, changed = WeaponComp.ChangePrice(current, newComps)
    if not changed then
        notify(src, locale('ui_notify_title'), locale('cl_notify_10'), 'error')
        return
    end

    applyWeaponChange(src, Player, item, serial, newComps, price, wHash)
end)

RegisterNetEvent('rsg-weaponcomp:server:reset', function(serial, wHash, weaponName)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or onCooldown(src, 'purchase', 3000) then return end
    if type(wHash) ~= 'number' then return end

    local item = findWeaponItem(Player, serial, weaponName)
    if not item then
        notify(src, locale('cl_notify_13'), locale('cl_cannot_reset'), 'error')
        return
    end

    local current = sanitizeComponents(item.info.componentshash) or {}
    if not next(current) then
        notify(src, locale('ui_notify_title'), locale('cl_notify_12'), 'error')
        return
    end

    applyWeaponChange(src, Player, item, serial, {}, calculateRemovePrice(current), wHash)
end)

----------------------------------------
-- Component lookup
----------------------------------------
RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:getPlayerWeaponComponents', function(source, cb, serial, weaponName)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end

    local item = findWeaponItem(Player, serial, weaponName)
    if item and item.info.componentshash and next(item.info.componentshash) then
        return cb({ components = item.info.componentshash })
    end

    local key = Player.PlayerData.citizenid .. ':' .. tostring(serial)
    if DbChecked[key] then return cb(nil) end
    DbChecked[key] = true

    -- Fallback to the database (e.g. inventory data lost) and sync it back
    local row = MySQL.single.await('SELECT components FROM player_weapons WHERE serial = ? AND citizenid = ?',
        { tostring(serial), Player.PlayerData.citizenid })
    local comps = row and sanitizeComponents(json.decode(row.components or '{}'))
    if comps and next(comps) then
        if item then
            item.info.componentshash = comps
            item.info.components = buildLabels(comps)
            Player.Functions.SetInventory(Player.PlayerData.items)
        end
        return cb({ components = comps })
    end

    cb(nil)
end)

----------------------------------------
-- Scope
----------------------------------------
local function setScope(source, cb, serial, equip)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end

    local item = findWeaponItem(Player, serial)
    if not item then return cb(false) end

    if (item.info.equippedScope == true) == equip then
        notify(source, nil, locale(equip and 'cl_scope_already_on' or 'cl_scope_already_off'), 'error')
        return cb(false)
    end

    item.info.equippedScope = equip
    Player.Functions.SetInventory(Player.PlayerData.items)
    cb(true)
end

RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:equipScope', function(source, cb, serial)
    setScope(source, cb, serial, true)
end)

RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:unequipScope', function(source, cb, serial)
    setScope(source, cb, serial, false)
end)

----------------------------------------
-- Gunsmith workbench props
----------------------------------------
local function syncProps(target)
    TriggerClientEvent('rsg-weaponcomp:client:updatePropData', target or -1, Config.PlayerProps)
end

local function generateId(prefix, column)
    while true do
        local id = prefix .. math.random(11111111, 99999999)
        local exists = MySQL.scalar.await(('SELECT 1 FROM player_weapons_custom WHERE %s = ?'):format(column), { id })
        if not exists then return id end
    end
end

local function countPlayerProps(citizenid)
    local count = 0
    for _, prop in ipairs(Config.PlayerProps) do
        if prop.citizenid == citizenid then count = count + 1 end
    end
    return count
end

CreateThread(function()
    local rows = MySQL.query.await('SELECT propdata FROM player_weapons_custom') or {}
    for _, row in ipairs(rows) do
        local data = json.decode(row.propdata)
        if data then Config.PlayerProps[#Config.PlayerProps + 1] = data end
    end
    syncProps()
end)

RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:getProps', function(_, cb)
    cb(Config.PlayerProps)
end)

RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:countprop', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    cb(Player and countPlayerProps(Player.PlayerData.citizenid) or 0)
end)

RSGCore.Functions.CreateUseableItem(Config.Gunsmithitem, function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

    if not hasRequiredJob(Player) then
        notify(source, locale('sv_access_denied'), locale('sv_job_required', Config.RequiredJob), 'error')
        return
    end

    TriggerClientEvent('rsg-weaponcomp:client:createprop', source, {
        propmodel = Config.Gunsmithprop,
        item = Config.Gunsmithitem
    })
end)

RegisterNetEvent('rsg-weaponcomp:server:createnewprop', function(coords, heading)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or onCooldown(src, 'createprop', 5000) then return end
    if type(coords) ~= 'vector3' or type(heading) ~= 'number' then return end
    if not hasRequiredJob(Player) then return end

    local citizenid = Player.PlayerData.citizenid
    local pedCoords = GetEntityCoords(GetPlayerPed(src))
    if #(pedCoords - coords) > (Config.PlaceDistance or 5.0) + 2.0 then
        notify(src, locale('cl_lang_15'), locale('cl_lang_16'), 'error')
        Discord.Security(src, locale('sv_sec_place_range'), locale('sv_sec_distance', #(pedCoords - coords)))
        return
    end

    if countPlayerProps(citizenid) >= (Config.MaxGunsites or 5) then
        notify(src, locale('cl_lang_17'), locale('cl_lang_18'), 'error')
        return
    end

    for _, prop in ipairs(Config.PlayerProps) do
        if #(coords - vector3(prop.x, prop.y, prop.z)) < (Config.gunZoneSize or 3.0) then
            notify(src, locale('cl_lang_19'), locale('cl_lang_20'), 'error')
            return
        end
    end

    if not Player.Functions.RemoveItem(Config.Gunsmithitem, 1, nil, 'gunsmith-placed') then return end
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[Config.Gunsmithitem], 'remove', 1)

    local propData = {
        gunsitename = locale('cl_lang_32'),
        gunsiteid = generateId('CSID', 'gunsiteid'),
        propid = generateId('PID', 'propid'),
        item = Config.Gunsmithitem,
        x = coords.x, y = coords.y, z = coords.z,
        h = heading % 360.0,
        propmodel = Config.Gunsmithprop,
        citizenid = citizenid,
        buildttime = os.time()
    }

    MySQL.insert.await('INSERT INTO player_weapons_custom (gunsiteid, propid, citizenid, item, propdata) VALUES (?, ?, ?, ?, ?)',
        { propData.gunsiteid, propData.propid, citizenid, propData.item, json.encode(propData) })

    Config.PlayerProps[#Config.PlayerProps + 1] = propData
    syncProps()

    Discord.Log('workbench', src, locale('sv_dc_placed'), {
        { locale('sv_dc_workbench_id'), propData.gunsiteid },
        { locale('sv_dc_location'), ('`%.2f, %.2f, %.2f`'):format(coords.x, coords.y, coords.z) },
        { locale('sv_dc_owned'), ('%d / %d'):format(countPlayerProps(citizenid), Config.MaxGunsites or 5) },
    })
end)

RegisterNetEvent('rsg-weaponcomp:server:removegunsiteprops', function(propid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(propid) ~= 'string' or onCooldown(src, 'removeprop', 3000) then return end

    local index
    for i, prop in ipairs(Config.PlayerProps) do
        if prop.propid == propid then index = i break end
    end
    if not index then return end

    local prop = Config.PlayerProps[index]
    if prop.citizenid ~= Player.PlayerData.citizenid then
        notify(src, locale('sv_access_denied'), nil, 'error')
        Discord.Security(src, locale('sv_sec_not_owner'), locale('sv_sec_owner', prop.gunsiteid, prop.citizenid))
        return
    end

    local pedCoords = GetEntityCoords(GetPlayerPed(src))
    if #(pedCoords - vector3(prop.x, prop.y, prop.z)) > 10.0 then
        Discord.Security(src, locale('sv_sec_pack_range'), prop.gunsiteid)
        return
    end

    -- remove from memory first (index is only valid before any await), then the DB
    table.remove(Config.PlayerProps, index)
    syncProps()
    MySQL.query.await('DELETE FROM player_weapons_custom WHERE propid = ?', { propid })

    local returned = Player.Functions.AddItem(Config.Gunsmithitem, 1, nil, nil, 'gunsmith-packed')
    if returned then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[Config.Gunsmithitem], 'add', 1)
    end

    Discord.Log('workbench', src, locale('sv_dc_packed'), {
        { locale('sv_dc_workbench_id'), prop.gunsiteid },
        { locale('sv_dc_location'), ('`%.2f, %.2f, %.2f`'):format(prop.x, prop.y, prop.z) },
        { locale('sv_dc_item_returned'), locale(returned and 'sv_dc_yes' or 'sv_dc_no_full') },
    })
end)

----------------------------------------
-- Inspect / commands
----------------------------------------
--- Takes one repair kit; the client only repairs the weapon when this returns true.
RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:useRepairKit', function(source, cb, serial)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not Config.RepairItem or onCooldown(source, 'inspectkit', 8000) then return cb(false) end
    local item = findWeaponItem(Player, serial)
    if not item then return cb(false) end
    if not Player.Functions.RemoveItem(Config.RepairItem, 1, nil, 'weapon-cleaned') then return cb(false) end
    TriggerClientEvent('rsg-inventory:client:ItemBox', source, RSGCore.Shared.Items[Config.RepairItem], 'remove', 1)
    cb(true)

    Discord.Log('repair', source, locale('sv_dc_repair'), {
        { locale('sv_dc_weapon'), RSGCore.Shared.Items[item.name] and RSGCore.Shared.Items[item.name].label or item.name },
        { locale('sv_dc_serial'), tostring(serial) },
        { locale('sv_dc_used'), RSGCore.Shared.Items[Config.RepairItem] and RSGCore.Shared.Items[Config.RepairItem].label or Config.RepairItem },
    })
end)

RSGCore.Commands.Add(Config.Commandinspect, locale('cl_lang_30'), {}, false, function(source)
    TriggerClientEvent('rsg-weaponcomp:client:InspectionWeapon', source)
end)

RSGCore.Commands.Add(Config.Commandloadweapon, locale('cl_lang_31'), {}, false, function(source)
    TriggerClientEvent('rsg-weaponcomp:client:reloadWeapon', source)
end)
