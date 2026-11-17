local RSGCore = exports['rsg-core']:GetCoreObject()

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

-- Per-weapon sets, so a part that only exists for one weapon can't be applied to another
local SpecificSets = {} -- SpecificSets[joaat(weaponName)] = { name = 'WEAPON_X', cats = { [cat] = { [comp] = true } } }
for weaponName, cats in pairs(Config.Specific or {}) do
    local entry = { name = weaponName, cats = {} }
    for cat, list in pairs(cats) do
        if #list > 0 then -- an empty list falls back to the shared list, like the client
            entry.cats[cat] = {}
            for _, comp in ipairs(list) do entry.cats[cat][comp] = true end
        end
    end
    SpecificSets[joaat(weaponName)] = entry
end

local SharedSets = {} -- SharedSets[cat][comp] = true (any weapon type)
for _, groupComps in pairs(Config.Shared or {}) do
    for cat, list in pairs(groupComps) do
        SharedSets[cat] = SharedSets[cat] or {}
        for _, comp in ipairs(list) do SharedSets[cat][comp] = true end
    end
end

--- True when `comp` is offered for `cat` on this weapon (mirrors the client's GetAvailableComponents).
--- The weapon-type group is a client-side native, so shared lists are checked against every type.
local function isOfferedFor(weaponName, cat, comp)
    local specific = SpecificSets[joaat(weaponName)]
    if specific and specific.cats[cat] then return specific.cats[cat][comp] == true end
    if not (SharedSets[cat] and SharedSets[cat][comp]) then return false end
    return WeaponComp.SharedCategoryAllowed(cat, weaponName, specific and Config.Specific[specific.name])
end

----------------------------------------
-- Helpers
----------------------------------------
local RestrictedWeapons = {}
for _, name in ipairs(Config.WeaponRestriction or {}) do RestrictedWeapons[joaat(name)] = true end

local Cooldowns = {}

-- Weapons already checked against the database this session (no saved row = skip next time).
-- The lookup runs on every weapon draw, so this avoids a query per draw for unmodified weapons.
local DbChecked = {}
local DbCheckedCount = 0

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
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = title,
        description = description,
        type = nType or 'inform',
        duration = 5000
    })
end

local function isFinite(n)
    return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end

local function roundMoney(value)
    return math.floor(value * 100 + 0.5) / 100
end

local function hasRequiredJob(Player)
    return not Config.RequiredJob or Player.PlayerData.job.name == Config.RequiredJob
end

--- Finds the weapon item a customisation applies to.
--- Serialised weapons match on serial; melee/bows (serial == weapon hash) match on item name.
local ACCESS_MODES = { everyone = true, owner = true, job = true, gang = true }
local lastSaved = {} -- propid -> os.time() of the last persisted lastused value

--- True when the player may use this workbench (public benches are open to all).
local function canUseBench(prop, Player)
    if prop.public then return true end
    local access = prop.access
    if type(access) ~= 'table' then return true end -- benches placed before access modes existed
    local mode = access.type
    if mode == 'owner' then return prop.citizenid == Player.PlayerData.citizenid end
    if mode == 'job' then return Player.PlayerData.job and Player.PlayerData.job.name == access.value end
    if mode == 'gang' then return Player.PlayerData.gang and Player.PlayerData.gang.name == access.value end
    return true
end

local function touchBench(prop)
    local now = os.time()
    prop.lastused = now
    if prop.public then return end
    if now - (lastSaved[prop.propid] or 0) >= 600 then
        lastSaved[prop.propid] = now
        MySQL.update('UPDATE player_weapons_custom SET propdata = ? WHERE propid = ?', { json.encode(prop), prop.propid })
    end
end

--- Returns the nearest workbench within UseDistance that the player may use, or nil.
local function nearWorkbench(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local pos = GetEntityCoords(GetPlayerPed(src))
    local maxDist = Config.UseDistance or 6.0
    for _, prop in ipairs(Config.PlayerProps) do
        if #(pos - vector3(prop.x, prop.y, prop.z)) <= maxDist and canUseBench(prop, Player) then
            touchBench(prop)
            return prop
        end
    end
    return nil
end

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
--- Second return value lists anything that isn't offered (tampering). Pass `weaponName`
--- to also require that each part is offered for that weapon.
local function sanitizeComponents(comps, weaponName)
    if type(comps) ~= 'table' then return nil end
    weaponName = type(weaponName) == 'string' and weaponName:upper() or nil
    local clean, invalid, count = {}, {}, 0
    for cat, comp in pairs(comps) do
        count = count + 1
        if count > 64 then return nil, { 'more than 64 entries' } end
        local valid = type(cat) == 'string' and type(comp) == 'string' and ValidComps[cat] and ValidComps[cat][comp]
        if valid and weaponName then valid = isOfferedFor(weaponName, cat, comp) end
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
    price = math.min(price, 999.99) -- column is decimal(5,2)
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

--- Discount fraction (0..0.9) from the player's gunsmith job.
local function getDiscount(Player)
    local job = Player.PlayerData.job
    local cfg = job and Config.GunsmithJobs and Config.GunsmithJobs[job.name]
    if not cfg then return 0.0 end
    if cfg.requireDuty and not job.onduty then return 0.0 end
    return math.max(0.0, math.min(tonumber(cfg.discount) or 0.0, 0.9))
end

local function getXP(Player)
    return math.max(0, math.floor(tonumber(Player.Functions.GetMetaData(Config.Skill.MetaKey)) or 0))
end

local function levelFromXP(xp)
    local level = 0
    for i, need in ipairs(Config.Skill.Levels or {}) do
        if xp >= need then level = i end
    end
    return level
end

--- Cleans free text for names/engravings. Returns the cleaned string ('' when empty) or nil when invalid.
local function cleanText(text, max)
    if text == nil then return '' end
    if type(text) ~= 'string' or #text > 400 then return nil end
    text = text:gsub('[%c<>"\\]', ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    local len = utf8.len(text)
    if not len or len > max then return nil end
    return text
end

local function identityOf(item)
    return { name = item.info.customname or '', engraving = item.info.engraving or '' }
end

--- Totals the material items needed for the parts that are new or changed.
local function requiredMaterials(current, newComps)
    local need = {}
    for cat, comp in pairs(newComps) do
        if current[cat] ~= comp and Config.PartItems and Config.PartItems[cat] then
            for _, m in ipairs(Config.PartItems[cat]) do
                need[m.item] = (need[m.item] or 0) + (tonumber(m.amount) or 1)
            end
        end
    end
    return need
end

--- Applies a new component set to the weapon item, charges the player and persists it.
local function applyWeaponChange(src, Player, item, serial, newComps, price, wHash, materials)
    local paymentType = Config.PaymentType or 'cash'
    materials = materials or {}

    for name, amount in pairs(materials) do
        if (exports['rsg-inventory']:GetItemCount(src, name) or 0) < amount then
            local label = RSGCore.Shared.Items[name] and RSGCore.Shared.Items[name].label or name
            notify(src, locale('ui_notify_title'), locale('sv_missing_material', amount, label), 'error')
            return false
        end
    end

    if price > 0 then
        if Player.Functions.GetMoney(paymentType) < price then
            notify(src, locale('sv_lang_10'), locale('sv_lang_11', price), 'error')
            return false
        end
        if not Player.Functions.RemoveMoney(paymentType, price, 'weapon-customisation') then
            return false
        end
    end

    local removed = {}
    for name, amount in pairs(materials) do
        if exports['rsg-inventory']:RemoveItem(src, name, amount, nil, 'weapon-customisation') then
            removed[#removed + 1] = { name, amount }
            TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[name], 'remove', amount)
        else -- could not take every material: undo everything
            for _, r in ipairs(removed) do exports['rsg-inventory']:AddItem(src, r[1], r[2], nil, nil, 'weapon-customisation-refund') end
            if price > 0 then Player.Functions.AddMoney(paymentType, price, 'weapon-customisation-refund') end
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
    TriggerEvent('rsg-weaponcomp:server:weaponCustomised', src, tostring(serial), item.name, newComps, identityOf(item))

    if Config.Skill.Enabled and next(newComps) and price > 0 then
        local oldXP = getXP(Player)
        local gain = (Config.Skill.XPPerPurchase or 0) + (getDiscount(Player) > 0 and (Config.Skill.XPJobBonus or 0) or 0)
        if gain > 0 then
            local newXP = oldXP + gain
            Player.Functions.SetMetaData(Config.Skill.MetaKey, newXP)
            if levelFromXP(newXP) > levelFromXP(oldXP) then
                notify(src, locale('ui_notify_title'), locale('sv_level_up', levelFromXP(newXP)), 'success')
            end
        end
    end
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
    if not nearWorkbench(src) then
        Discord.Security(src, locale('sv_sec_no_bench'), locale('sv_sec_no_bench_desc'))
        return
    end

    local item = findWeaponItem(Player, serial, weaponName)
    if not item then
        notify(src, locale('cl_notify_13'), locale('cl_no_weapon'), 'error')
        return
    end
    if RestrictedWeapons[joaat(item.name)] then -- don't trust the client's hash
        Discord.Security(src, locale('sv_sec_restricted'), item.name)
        return
    end

    local newComps, invalid = sanitizeComponents(comps, item.name)
    if not newComps or #invalid > 0 then
        Discord.Security(src, locale('sv_sec_invalid'), invalid and #invalid > 0 and table.concat(invalid, '\n') or locale('sv_sec_not_table'))
        return
    end

    local current = sanitizeComponents(item.info.componentshash) or {}
    local price, changed = WeaponComp.ChangePrice(current, newComps)
    if not changed then
        notify(src, locale('ui_notify_title'), locale('cl_notify_10'), 'error')
        return
    end

    if Config.Skill.Enabled then
        local level = levelFromXP(getXP(Player))
        for cat, comp in pairs(newComps) do
            local need = Config.Skill.Unlocks and Config.Skill.Unlocks[cat]
            if need and current[cat] ~= comp and level < need then
                notify(src, locale('ui_notify_title'), locale('sv_skill_locked', need), 'error')
                return
            end
        end
    end

    price = roundMoney(price * (1 - getDiscount(Player)))
    applyWeaponChange(src, Player, item, serial, newComps, price, wHash, requiredMaterials(current, newComps))
end)

RegisterNetEvent('rsg-weaponcomp:server:reset', function(serial, wHash, weaponName)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or onCooldown(src, 'purchase', 3000) then return end
    if type(wHash) ~= 'number' then return end
    if not nearWorkbench(src) then
        Discord.Security(src, locale('sv_sec_no_bench'), locale('sv_sec_no_bench_desc'))
        return
    end

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

    applyWeaponChange(src, Player, item, serial, {}, roundMoney(calculateRemovePrice(current) * (1 - getDiscount(Player))), wHash)
end)

----------------------------------------
-- Component lookup
----------------------------------------
RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:getPlayerWeaponComponents', function(source, cb, serial, weaponName)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end

    local item = findWeaponItem(Player, serial, weaponName)
    local replyTo = cb
    cb = function(res) -- every reply carries the player's discount, skill and weapon identity
        res = res or {}
        res.discount = getDiscount(Player)
        if Config.Skill.Enabled then
            local xp = getXP(Player)
            res.xp, res.level = xp, levelFromXP(xp)
        end
        res.identity = item and identityOf(item) or { name = '', engraving = '' }
        replyTo(res)
    end
    local quality = item and math.floor(tonumber(item.info.quality) or 100) or 100
    if item and item.info.componentshash and next(item.info.componentshash) then
        return cb({ components = item.info.componentshash, quality = quality })
    end

    local key = Player.PlayerData.citizenid .. ':' .. tostring(serial)
    if DbChecked[key] then return cb({ quality = quality }) end
    DbChecked[key] = true
    DbCheckedCount = DbCheckedCount + 1
    if DbCheckedCount > 5000 then DbChecked, DbCheckedCount = { [key] = true }, 1 end -- keep it from growing forever

    -- Fallback to the database (e.g. inventory data lost) and sync it back
    local row = MySQL.single.await('SELECT components FROM player_weapons WHERE serial = ? AND citizenid = ?',
        { tostring(serial), Player.PlayerData.citizenid })
    local comps = row and sanitizeComponents((json.decode(row.components or '{}')))
    if comps and next(comps) then
        if item then
            item.info.componentshash = comps
            item.info.components = buildLabels(comps)
            Player.Functions.SetInventory(Player.PlayerData.items)
        end
        return cb({ components = comps, quality = quality })
    end

    cb({ quality = quality })
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
    if Config.AutoDatabase and not EnsureDatabase() then return end
    local rows = MySQL.query.await('SELECT propdata FROM player_weapons_custom') or {}
    for _, row in ipairs(rows) do
        local data = json.decode(row.propdata)
        if data then
            data.lastused = data.lastused or os.time() -- benches from before expiry existed start counting now
            Config.PlayerProps[#Config.PlayerProps + 1] = data
        end
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
    if type(coords) ~= 'vector3' or not isFinite(coords.x) or not isFinite(coords.y) or not isFinite(coords.z) or not isFinite(heading) then return end
    if not hasRequiredJob(Player) then return end

    if not exports['rsg-gizmo']:IsPlacementValid(src, coords, (Config.PlaceDistance or 5.0) + 2.0) then
        Discord.Security(src, locale('sv_sec_place_range'), locale('sv_sec_distance', #(GetEntityCoords(GetPlayerPed(src)) - coords)))
        return
    end

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

    if not Player.Functions.RemoveItem(Config.Gunsmithitem, 1, nil, 'gunsmith-placed') then
        notify(src, locale('ui_notify_title'), locale('sv_no_workbench_item'), 'error')
        return
    end
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
        buildttime = os.time(),
        lastused = os.time(),
        access = { type = ACCESS_MODES[Config.DefaultAccess] and Config.DefaultAccess or 'everyone' },
    }
    if propData.access.type == 'job' then propData.access.value = Player.PlayerData.job.name
    elseif propData.access.type == 'gang' then propData.access.value = Player.PlayerData.gang.name end

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

    -- refuse when the item can't be returned, otherwise the workbench would be lost
    if not exports['rsg-inventory']:CanAddItem(src, Config.Gunsmithitem, 1) then
        notify(src, locale('cl_lang_23'), locale('sv_inventory_full'), 'error')
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
-- Weapon identity (custom name + engraving)
----------------------------------------
RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:setIdentity', function(source, cb, serial, weaponName, name, engraving)
    local Player = RSGCore.Functions.GetPlayer(source)
    local cfg = Config.Identity
    if not Player or not cfg or not cfg.Enabled or onCooldown(source, 'identity', 2000) then return cb(false) end
    if not nearWorkbench(source) then return cb(false) end

    local item = findWeaponItem(Player, serial, weaponName)
    if not item or RestrictedWeapons[joaat(item.name)] then return cb(false) end

    local newName = cleanText(name, cfg.MaxNameLength or 24)
    local newEngr = cleanText(engraving, cfg.MaxEngravingLength or 40)
    if not newName or not newEngr then
        notify(source, locale('ui_notify_title'), locale('sv_identity_invalid'), 'error')
        return cb(false)
    end

    local oldName, oldEngr = item.info.customname or '', item.info.engraving or ''
    local price = 0.0
    if newName ~= oldName and newName ~= '' then price = price + (cfg.NamePrice or 0) end
    if newEngr ~= oldEngr and newEngr ~= '' then price = price + (cfg.EngravePrice or 0) end
    if newName == oldName and newEngr == oldEngr then return cb(false) end
    price = roundMoney(price * (1 - getDiscount(Player)))

    local paymentType = Config.PaymentType or 'cash'
    if price > 0 then
        if Player.Functions.GetMoney(paymentType) < price then
            notify(source, locale('sv_lang_10'), locale('sv_lang_11', price), 'error')
            return cb(false)
        end
        if not Player.Functions.RemoveMoney(paymentType, price, 'weapon-identity') then return cb(false) end
    end

    item.info.customname = newName ~= '' and newName or nil
    item.info.engraving = newEngr ~= '' and newEngr or nil
    Player.Functions.SetInventory(Player.PlayerData.items)

    local citizenid, sn = Player.PlayerData.citizenid, tostring(serial)
    local updated = MySQL.update.await('UPDATE player_weapons SET customname = ?, engraving = ? WHERE serial = ? AND citizenid = ?',
        { item.info.customname, item.info.engraving, sn, citizenid })
    if updated == 0 then
        MySQL.insert.await('INSERT INTO player_weapons (components, components_before, price, serial, citizenid, customname, engraving) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { json.encode(sanitizeComponents(item.info.componentshash) or {}), '{}', 0, sn, citizenid, item.info.customname, item.info.engraving })
    end

    notify(source, locale('sv_lang_12'), locale('sv_identity_saved', price), 'success')
    TriggerEvent('rsg-weaponcomp:server:weaponCustomised', source, sn, item.name, sanitizeComponents(item.info.componentshash) or {}, identityOf(item))
    cb(true, identityOf(item))
end)

----------------------------------------
-- Presets (saved loadouts per weapon)
----------------------------------------
local function isWeaponItem(name)
    local def = type(name) == 'string' and #name <= 64 and RSGCore.Shared.Items[name:lower()]
    return def and def.type == 'weapon' or false
end

RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:listPresets', function(source, cb, weaponName)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not isWeaponItem(weaponName) then return cb({}) end
    local rows = MySQL.query.await('SELECT id, name, components FROM player_weapons_presets WHERE citizenid = ? AND weapon = ? ORDER BY id',
        { Player.PlayerData.citizenid, weaponName:upper() }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = { id = r.id, name = r.name, components = sanitizeComponents(json.decode(r.components or '{}'), weaponName) or {} }
    end
    cb(out)
end)

RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:savePreset', function(source, cb, weaponName, name, comps)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not isWeaponItem(weaponName) or onCooldown(source, 'preset', 1000) then return cb(false) end
    local clean = cleanText(name, 32)
    local sanitized, invalid = sanitizeComponents(comps, weaponName)
    if not clean or clean == '' or not sanitized or #invalid > 0 or not next(sanitized) then
        notify(source, locale('ui_notify_title'), locale('sv_preset_invalid'), 'error')
        return cb(false)
    end
    local citizenid, weapon = Player.PlayerData.citizenid, weaponName:upper()
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM player_weapons_presets WHERE citizenid = ? AND weapon = ?', { citizenid, weapon }) or 0
    if count >= (Config.MaxPresets or 5) then
        notify(source, locale('ui_notify_title'), locale('sv_preset_full', Config.MaxPresets or 5), 'error')
        return cb(false)
    end
    MySQL.insert.await('INSERT INTO player_weapons_presets (citizenid, weapon, name, components) VALUES (?, ?, ?, ?)',
        { citizenid, weapon, clean, json.encode(sanitized) })
    cb(true)
end)

RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:deletePreset', function(source, cb, id)
    local Player = RSGCore.Functions.GetPlayer(source)
    id = tonumber(id)
    if not Player or not id then return cb(false) end
    local n = MySQL.update.await('DELETE FROM player_weapons_presets WHERE id = ? AND citizenid = ?', { id, Player.PlayerData.citizenid })
    cb(n and n > 0 or false)
end)

----------------------------------------
-- Exports for other resources (e.g. rsg-lawman)
----------------------------------------
--- Returns the stored record of a weapon by serial: { serial, citizenid, components, customname, engraving } or nil.
exports('GetWeaponRecord', function(serial)
    if serial == nil then return nil end
    local row = MySQL.single.await('SELECT serial, citizenid, components, customname, engraving FROM player_weapons WHERE serial = ?', { tostring(serial) })
    if not row then return nil end
    row.components = json.decode(row.components or '{}') or {}
    return row
end)

----------------------------------------
-- Workbench access mode (owner only)
----------------------------------------
RegisterNetEvent('rsg-weaponcomp:server:setaccess', function(propid, mode)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(propid) ~= 'string' or type(mode) ~= 'string' or not ACCESS_MODES[mode] then return end
    if onCooldown(src, 'setaccess', 1000) then return end

    for _, prop in ipairs(Config.PlayerProps) do
        if prop.propid == propid then
            if prop.public or prop.citizenid ~= Player.PlayerData.citizenid then
                notify(src, locale('sv_access_denied'), nil, 'error')
                return
            end
            local value
            if mode == 'job' then value = Player.PlayerData.job.name
            elseif mode == 'gang' then value = Player.PlayerData.gang.name end
            if (mode == 'job' or mode == 'gang') and (not value or value == 'none' or value == 'unemployed') then
                notify(src, locale('ui_notify_title'), locale('sv_access_no_group'), 'error')
                return
            end
            prop.access = { type = mode, value = value }
            MySQL.update('UPDATE player_weapons_custom SET propdata = ? WHERE propid = ?', { json.encode(prop), propid })
            syncProps()
            notify(src, locale('ui_notify_title'), locale('sv_access_set', locale('ui_access_' .. mode)), 'success')
            return
        end
    end
end)

----------------------------------------
-- Admin workbenches (public) and expiry
----------------------------------------
RegisterNetEvent('rsg-weaponcomp:server:adminplace', function(coords, heading)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not RSGCore.Functions.HasPermission(src, Config.AdminPermission) then return end
    if type(coords) ~= 'vector3' or not isFinite(coords.x) or not isFinite(coords.y) or not isFinite(coords.z) or not isFinite(heading) then return end
    if onCooldown(src, 'adminplace', 2000) then return end
    if not exports['rsg-gizmo']:IsPlacementValid(src, coords, (Config.PlaceDistance or 5.0) + 2.0) then return end

    local propData = {
        gunsitename = locale('cl_lang_32'),
        gunsiteid = generateId('CSID', 'gunsiteid'),
        propid = generateId('PID', 'propid'),
        item = Config.Gunsmithitem,
        x = coords.x, y = coords.y, z = coords.z,
        h = heading % 360.0,
        propmodel = Config.Gunsmithprop,
        citizenid = 'public',
        public = true,
        access = { type = 'everyone' },
        buildttime = os.time(),
        lastused = os.time(),
    }
    MySQL.insert.await('INSERT INTO player_weapons_custom (gunsiteid, propid, citizenid, item, propdata) VALUES (?, ?, ?, ?, ?)',
        { propData.gunsiteid, propData.propid, 'public', propData.item, json.encode(propData) })
    Config.PlayerProps[#Config.PlayerProps + 1] = propData
    syncProps()
    notify(src, locale('ui_notify_title'), locale('sv_admin_placed', propData.gunsiteid), 'success')
    Discord.Log('workbench', src, locale('sv_dc_admin_placed'), {
        { locale('sv_dc_workbench_id'), propData.gunsiteid },
        { locale('sv_dc_location'), ('`%.2f, %.2f, %.2f`'):format(coords.x, coords.y, coords.z) },
    })
end)

local function removeBenchAt(index)
    local prop = table.remove(Config.PlayerProps, index)
    syncProps()
    MySQL.query.await('DELETE FROM player_weapons_custom WHERE propid = ?', { prop.propid })
    lastSaved[prop.propid] = nil
    return prop
end

RSGCore.Commands.Add(Config.CommandAdminPlace, locale('sv_cmd_admin_place'), {}, false, function(source)
    TriggerClientEvent('rsg-weaponcomp:client:adminplace', source)
end, Config.AdminPermission)

RSGCore.Commands.Add(Config.CommandAdminList, locale('sv_cmd_admin_list'), {}, false, function(source)
    local lines = {}
    for _, p in ipairs(Config.PlayerProps) do
        lines[#lines + 1] = ('%s | %s | %.1f %.1f %.1f | %s'):format(p.gunsiteid, p.public and 'PUBLIC' or p.citizenid, p.x, p.y, p.z, (p.access and p.access.type) or 'everyone')
    end
    if source == 0 then
        print(('[rsg-weaponcomp] %d workbenches'):format(#lines))
        for _, l in ipairs(lines) do print(l) end
    else
        TriggerClientEvent('rsg-weaponcomp:client:printlist', source, lines)
    end
end, Config.AdminPermission)

RSGCore.Commands.Add(Config.CommandAdminRemove, locale('sv_cmd_admin_remove'), {
    { name = 'id', help = locale('sv_cmd_admin_remove_arg') },
}, false, function(source, args)
    local id = args[1]
    if source == 0 and not id then return print('[rsg-weaponcomp] usage: removeworkbench <id>') end
    local index
    if id then
        for i, p in ipairs(Config.PlayerProps) do if p.gunsiteid == id then index = i break end end
    else
        local pos, best = GetEntityCoords(GetPlayerPed(source)), 5.0
        for i, p in ipairs(Config.PlayerProps) do
            local d = #(pos - vector3(p.x, p.y, p.z))
            if d <= best then best, index = d, i end
        end
    end
    if not index then
        if source == 0 then return print(locale('sv_admin_none_found')) end
        notify(source, locale('ui_notify_title'), locale('sv_admin_none_found'), 'error')
        return
    end
    local prop = removeBenchAt(index)
    if source == 0 then print(locale('sv_admin_removed', prop.gunsiteid)) else
        notify(source, locale('ui_notify_title'), locale('sv_admin_removed', prop.gunsiteid), 'success')
    end
    if source == 0 then return end
    Discord.Log('workbench', source, locale('sv_dc_admin_removed'), {
        { locale('sv_dc_workbench_id'), prop.gunsiteid },
        { locale('sv_dc_location'), ('`%.2f, %.2f, %.2f`'):format(prop.x, prop.y, prop.z) },
    })
end, Config.AdminPermission)

-- Remove player workbenches that have not been used for Config.WorkbenchExpireDays
CreateThread(function()
    while true do
        Wait(3600000)
        local days = tonumber(Config.WorkbenchExpireDays) or 0
        if days > 0 then
            local cutoff = os.time() - days * 86400
            for i = #Config.PlayerProps, 1, -1 do
                local p = Config.PlayerProps[i]
                if not p.public and (p.lastused or p.buildttime or os.time()) < cutoff then
                    removeBenchAt(i)
                    print(('[rsg-weaponcomp] workbench %s expired (unused for %d days)'):format(p.gunsiteid, days))
                end
            end
        end
    end
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
    if (tonumber(item.info.quality) or 100) >= 100 then
        notify(source, locale('cl_notify_13'), locale('cl_already_repaired'), 'inform')
        return cb(false)
    end
    if not Player.Functions.RemoveItem(Config.RepairItem, 1, nil, 'weapon-cleaned') then
        local it = RSGCore.Shared.Items[Config.RepairItem]
        notify(source, locale('cl_notify_13'), locale('cl_no_repair_item', it and it.label or Config.RepairItem), 'error')
        return cb(false)
    end
    TriggerClientEvent('rsg-inventory:client:ItemBox', source, RSGCore.Shared.Items[Config.RepairItem], 'remove', 1)

    -- restore weapon condition (rsg-weapons stores it in info.quality)
    item.info.quality = 100
    Player.Functions.SetInventory(Player.PlayerData.items)
    cb(true)

    Discord.Log('repair', source, locale('sv_dc_repair'), {
        { locale('sv_dc_weapon'), RSGCore.Shared.Items[item.name] and RSGCore.Shared.Items[item.name].label or item.name },
        { locale('sv_dc_serial'), tostring(serial) },
        { locale('sv_dc_used'), RSGCore.Shared.Items[Config.RepairItem] and RSGCore.Shared.Items[Config.RepairItem].label or Config.RepairItem },
    })
end)

--- Gun oil: takes one oil; the client then clears dirt/soot (purely visual, no condition change).
RSGCore.Functions.CreateCallback('rsg-weaponcomp:server:useGunOil', function(source, cb, serial)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not Config.GunOilItem or onCooldown(source, 'gunoil', 5000) then return cb(false) end
    local item = findWeaponItem(Player, serial)
    if not item then return cb(false) end
    if not Player.Functions.RemoveItem(Config.GunOilItem, 1, nil, 'weapon-oiled') then
        local it = RSGCore.Shared.Items[Config.GunOilItem]
        notify(source, locale('cl_notify_13'), locale('cl_no_gun_oil', it and it.label or Config.GunOilItem), 'error')
        return cb(false)
    end
    TriggerClientEvent('rsg-inventory:client:ItemBox', source, RSGCore.Shared.Items[Config.GunOilItem], 'remove', 1)
    cb(true)

    Discord.Log('repair', source, locale('sv_dc_oiled'), {
        { locale('sv_dc_weapon'), RSGCore.Shared.Items[item.name] and RSGCore.Shared.Items[item.name].label or item.name },
        { locale('sv_dc_serial'), tostring(serial) },
    })
end)

if Config.GunOilItem then
    RSGCore.Functions.CreateUseableItem(Config.GunOilItem, function(source)
        TriggerClientEvent('rsg-weaponcomp:client:oilWeapon', source)
    end)
end

RSGCore.Commands.Add(Config.Commandinspect, locale('cl_lang_30'), {}, false, function(source)
    TriggerClientEvent('rsg-weaponcomp:client:InspectionWeapon', source)
end)

RSGCore.Commands.Add(Config.Commandloadweapon, locale('cl_lang_31'), {}, false, function(source)
    TriggerClientEvent('rsg-weaponcomp:client:reloadWeapon', source)
end)
