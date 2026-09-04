-- Exports and UI data loader for weapons
local jsonLibrary = nil
pcall(function() jsonLibrary = require 'cjson' end)
if not jsonLibrary then
  pcall(function() jsonLibrary = require 'dkjson' end)
end

local function toJSON(data)
  if jsonLibrary == nil then
    -- Fallback minimal encoder
    return tostring(data)
  end
  if jsonLibrary.encode then
    return jsonLibrary.encode(data)
  end
  return jsonLibrary(data)
end

local function exportWeaponsToJson()
  local data = {}
  -- Build a citizen-centric structure
  MySQL.Async.fetchAll("SELECT citizenid, serial, weapon, ammo FROM playerweapons", {}, function(rows)
    local groups = {}
    for _, r in ipairs(rows) do
      local cid = tostring(r.citizenid or '')
      if not groups[cid] then groups[cid] = { citizenid = cid, weapons = {} } end
      table.insert(groups[cid].weapons, {
        weapon = r.weapon,
        serial = r.serial,
        ammo = tonumber(r.ammo) or 0
      })
    end
    for k, v in pairs(groups) do table.insert(data, v) end
    local resourcePath = GetResourcePath(GetCurrentResourceName())
    local filePath = resourcePath .. '/weapons_export.json'
    local f = io.open(filePath, 'w')
    if f then
      f:write(toJSON(data))
      f:close()
    end
  end)
end

RegisterCommand('export_weapons', function()
  exportWeaponsToJson()
  TriggerClientEvent('chat:addMessage', -1, { args = { '^2[WEAPON EXPORT]', 'Weapons exported to json.' } })
end, false)

-- Provide weapons data for UI requests from the client
RegisterNetEvent('rsg-weaponcomp:getWeapons')
AddEventHandler('rsg-weaponcomp:getWeapons', function()
  local src = source
  MySQL.Async.fetchAll("SELECT citizenid, serial, weapon, ammo FROM playerweapons", {}, function(rows)
    local groups = {}
    for _, r in ipairs(rows) do
      local cid = tostring(r.citizenid or '')
      if not groups[cid] then groups[cid] = { citizenid = cid, weapons = {} } end
      table.insert(groups[cid].weapons, { weapon = r.weapon, serial = r.serial, ammo = tonumber(r.ammo) or 0 })
    end
    local data = {}
    for _, v in pairs(groups) do table.insert(data, v) end
    -- save json export as well
    local jsonString = toJSON(data)
    local resourcePath = GetResourcePath(GetCurrentResourceName())
    local filePath = resourcePath .. '/weapons_export.json'
    local f = io.open(filePath, 'w')
    if f then f:write(jsonString) f:close() end
    TriggerClientEvent('rsg-weaponcomp:weaponsData', src, data)
  end)
end)
