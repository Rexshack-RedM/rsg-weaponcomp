----------------------------------------
-- Discord webhook logger
-- Usage: Discord.Log(channel, src, title, fields[, description])
--   channel = key of DiscordConfig.Webhooks
--   fields  = { { 'Name', 'value' }, ... } (inline) or { 'Name', 'value', false } (full width)
----------------------------------------
local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

Discord = {}

local MAX_FIELD = 1024
local MAX_DESC = 4000
local SEND_INTERVAL = 1100 -- ms between messages per webhook (Discord allows ~5 per 2s)

local queues = {}   -- [url] = { items, busy }

local function trim(text, limit)
    text = tostring(text or '')
    if #text > limit then text = text:sub(1, limit - 3) .. '...' end
    return text
end

local function getIdentifiers(src)
    local ids = {}
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        local kind, value = id:match('^(%w+):(.+)$')
        if kind then ids[kind] = value end
    end
    return ids
end

--- Common "who did it" fields for an embed.
local function playerFields(src)
    local fields = {}
    if not src or src == 0 then return fields end

    local Player = RSGCore.Functions.GetPlayer(src)
    local name = GetPlayerName(src) or locale('sv_dc_unknown')
    if Player then
        local ci = Player.PlayerData.charinfo or {}
        local charName = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', '')
        fields[#fields + 1] = { name = locale('sv_dc_character'), value = charName ~= '' and charName or locale('sv_dc_unknown'), inline = true }
        fields[#fields + 1] = { name = locale('sv_dc_citizenid'), value = Player.PlayerData.citizenid, inline = true }
    end
    fields[#fields + 1] = { name = locale('sv_dc_player'), value = ('%s (ID %s)'):format(name, src), inline = true }

    local ids, show = getIdentifiers(src), DiscordConfig.ShowIdentifiers or {}
    local lines = {}
    if show.discord and ids.discord then lines[#lines + 1] = ('Discord: <@%s>'):format(ids.discord) end
    if show.license and ids.license then lines[#lines + 1] = 'License: `' .. ids.license .. '`' end
    if show.steam and ids.steam then lines[#lines + 1] = 'Steam: `' .. ids.steam .. '`' end
    if show.ip and ids.ip then lines[#lines + 1] = 'IP: ||' .. ids.ip .. '||' end
    if #lines > 0 then fields[#fields + 1] = { name = locale('sv_dc_identifiers'), value = table.concat(lines, '\n'), inline = false } end

    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
        local c = GetEntityCoords(ped)
        fields[#fields + 1] = { name = locale('sv_dc_coords'), value = ('`%.2f, %.2f, %.2f`'):format(c.x, c.y, c.z), inline = false }
    end
    return fields
end

local function processQueue(url)
    local q = queues[url]
    if q.busy then return end
    q.busy = true

    CreateThread(function()
        while #q.items > 0 do
            local payload = table.remove(q.items, 1)
            local p = promise.new()
            PerformHttpRequest(url, function(status, _, headers, body)
                p:resolve({ status = status, body = body })
            end, 'POST', payload, { ['Content-Type'] = 'application/json' })

            local res = Citizen.Await(p)
            if res.status == 429 then
                -- rate limited: put it back and wait what Discord asks
                table.insert(q.items, 1, payload)
                local data = res.body and json.decode(res.body)
                Wait(math.ceil(((data and data.retry_after) or 2) * 1000))
            else
                if res.status < 200 or res.status >= 300 then
                    print(('^1[%s] %s^7'):format(GetCurrentResourceName(), locale('sv_dc_failed', res.status)))
                end
                Wait(SEND_INTERVAL)
            end
        end
        q.busy = false
    end)
end

local function enqueue(url, payload)
    queues[url] = queues[url] or { items = {}, busy = false }
    local q = queues[url]
    if #q.items >= 50 then table.remove(q.items, 1) end -- never let a flood eat memory
    q.items[#q.items + 1] = json.encode(payload)
    processQueue(url)
end

--- Sends an embed to a log channel.
function Discord.Log(channel, src, title, extraFields, description)
    if not DiscordConfig or not DiscordConfig.Enabled then return end

    local fields = {}
    for _, f in ipairs(extraFields or {}) do
        fields[#fields + 1] = { name = trim(f[1], 256), value = trim(f[2] ~= nil and f[2] ~= '' and f[2] or '-', MAX_FIELD), inline = f[3] ~= false }
    end
    for _, f in ipairs(playerFields(src)) do fields[#fields + 1] = f end
    while #fields > 25 do table.remove(fields) end

    if DiscordConfig.RsgLogName then
        local lines = {}
        for _, f in ipairs(fields) do lines[#lines + 1] = ('%s: **%s**'):format(f.name, f.value) end
        TriggerEvent('rsg-log:server:CreateLog', DiscordConfig.RsgLogName, title, channel == 'security' and 'red' or 'green', table.concat(lines, '\n'))
    end

    local url = DiscordConfig.Webhooks and DiscordConfig.Webhooks[channel]
    if not url or url == '' then return end

    local content
    if channel == 'security' and DiscordConfig.SecurityPing ~= '' then content = DiscordConfig.SecurityPing end

    enqueue(url, {
        username = DiscordConfig.BotName,
        avatar_url = DiscordConfig.Avatar ~= '' and DiscordConfig.Avatar or nil,
        content = content,
        allowed_mentions = { parse = { 'roles', 'users' } },
        embeds = { {
            title = trim(title, 256),
            description = description and trim(description, MAX_DESC) or nil,
            color = (DiscordConfig.Colours or {})[channel] or 9807270,
            fields = fields,
            footer = { text = DiscordConfig.Footer },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
    })
end

--- Shortcut for suspicious activity.
function Discord.Security(src, reason, details)
    Discord.Log('security', src, locale('sv_dc_security'), { { locale('sv_dc_reason'), reason, false }, details and { locale('sv_dc_details'), details, false } or nil })
end

--- Formats a component table as a readable list.
function Discord.FormatComponents(comps)
    if not comps or not next(comps) then return locale('sv_dc_factory') end
    local lines = {}
    for _, cat in ipairs(WeaponComp.SortedKeys(comps)) do
        lines[#lines + 1] = ('**%s**: %s'):format(locale(cat), locale(comps[cat]))
    end
    return table.concat(lines, '\n')
end
