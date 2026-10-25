----------------------------------------
-- Discord webhooks (SERVER ONLY)
-- This file is never sent to clients, so webhook URLs stay private.
-- Leave a URL empty ('') to turn that log off.
----------------------------------------
DiscordConfig = {}

DiscordConfig.Enabled = true

DiscordConfig.BotName = 'Gunsmith'
DiscordConfig.Avatar = ''          -- optional image URL for the webhook avatar
DiscordConfig.Footer = 'rsg-weaponcomp'

-- Ping a role for security alerts, e.g. '<@&123456789012345678>' ('' = no ping)
DiscordConfig.SecurityPing = ''

-- Also send each log through rsg-log (set to the rsg-log webhook name, or nil to skip)
DiscordConfig.RsgLogName = nil

-- One webhook per log channel. Several channels can share the same URL.
DiscordConfig.Webhooks = {
    purchase  = '',   -- weapon modified (parts bought / removed)
    reset     = '',   -- all modifications removed
    workbench = '',   -- workbench placed / packed up
    repair    = '',   -- weapon cleaned with a repair kit
    security  = '',   -- suspicious activity (invalid data, distance checks, ownership)
}

-- Embed colours (decimal)
DiscordConfig.Colours = {
    purchase  = 15844367, -- gold
    reset     = 15105570, -- orange
    workbench = 3447003,  -- blue
    repair    = 3066993,  -- green
    security  = 15158332, -- red
}

-- Which player identifiers to show in embeds
DiscordConfig.ShowIdentifiers = {
    license = true,
    discord = true,
    steam = false,
    ip = false,
}

-- List every component in purchase logs (can be long on heavily modified weapons)
DiscordConfig.ShowComponents = true
