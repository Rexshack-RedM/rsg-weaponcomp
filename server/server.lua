local RSGCore = exports['rsg-core']:GetCoreObject()

-----------------------------------------------------------------------
-- version checker
-----------------------------------------------------------------------
local function versionCheckPrint(_type, log)
    local color = _type == 'success' and '^2' or '^1'

    print(('^5['..GetCurrentResourceName()..']%s %s^7'):format(color, log))
end

local function CheckVersion()
    PerformHttpRequest('https://raw.githubusercontent.com/Rexshack-RedM/rsg-weaponcomp/main/version.txt', function(err, text, headers)
        local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version')

        if not text then 
            versionCheckPrint('error', 'Currently unable to run a version check.')
            return 
        end

        --versionCheckPrint('success', ('Current Version: %s'):format(currentVersion))
        --versionCheckPrint('success', ('Latest Version: %s'):format(text))

        if text == currentVersion then
            versionCheckPrint('success', 'You are running the latest version.')
        else
            versionCheckPrint('error', ('You are currently running an outdated version, please update to version %s'):format(text))
        end
    end)
end

---------------------------------------------
-- send To Discord
-------------------------------------------
local sendToDiscord = function(color, name, message, footer, type)
    local embed = {
            {
                ["color"] = color,
                ["title"] = "**".. name .."**",
                ["description"] = message,
                ["footer"] = {
                ["text"] = footer
            }
        }
    }
    if type == "weapons" then
    	PerformHttpRequest(Config['Webhooks']['weaponCustom'], function(err, text, headers) end, 'POST', json.encode({username = name, embeds = embed}), { ['Content-Type'] = 'application/json' })
    end
end

--------------------------------------------
-- COMMAND 
--------------------------------------------
local permissions = {
    ["CreatorWeapon"] = Config.CommandPermisions,
}

RSGCore.Commands.Add("customweapon", "Opens the Custom Weapon Menu", "{}", false, function(source)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['CreatorWeapon']) or IsPlayerAceAllowed(src, 'command')  then
        TriggerClientEvent('rsg-weaponcomp:client:OpenCreatorWeapon', src)
    else
        TriggerClientEvent('ox_lib:notify', src, {title = 'No have permissions', description = 'No are admin', type = 'inform' })
    end
end)

RSGCore.Commands.Add("w_inspect", "Opens the inpect Weapon", "{}", false, function(source)
    local src = source
    if RSGCore.Functions.HasPermission(src, permissions['CreatorWeapon']) or IsPlayerAceAllowed(src, 'command')  then
        TriggerClientEvent('rsg-weaponcomp:client:InspectionWeapon', src)
    else
        TriggerClientEvent('ox_lib:notify', src, {title = 'No have permissions', description = 'No are admin', type = 'inform' })
    end
end)

RSGCore.Commands.Add("loadweapon", "Loading skinthe Custom Weapon", "{}", false, function(source)
    local src = source
    TriggerClientEvent("rsg-weaponcomp:client:LoadComponents", src)
end)

-------------------------------------------
-- Payment
-------------------------------------------
RegisterServerEvent('rsg-weaponcomp:server:price')
AddEventHandler('rsg-weaponcomp:server:price', function(price)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local currentCash = Player.Functions.GetMoney('cash')

    if currentCash < tonumber(price) then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Not Enough Cash! $' .. tonumber(price), description = 'you need more cash to do that!', type = 'error', duration = 5000 })
        TriggerClientEvent('rsg-weaponcomp:client:ExitCam', src)
        return
    else
        Player.Functions.RemoveMoney('cash', tonumber(price))

        if Config.Notify == 'rnotify' then
            TriggerClientEvent('rNotify:NotifyLeft', src, 'Custom $:' ..tonumber(price), 'your weapon is now', "generic_textures", "tick", 4000)
        elseif Config.Notify == 'ox_lib' then
            TriggerClientEvent('ox_lib:notify', src, {title = 'Custom $:' ..tonumber(price), description = 'your weapon is now', type = 'inform', duration = 5000 })
        end
    end

    Wait(1000)
    TriggerClientEvent('rsg-weaponcomp:client:animationSaved', src)

end)

--------------------------------------------
-- CHECK SLOT
--------------------------------------------
RegisterServerEvent('rsg-weaponcomp:server:slot')
AddEventHandler('rsg-weaponcomp:server:slot', function(serial)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    local weapons = {}
    for _, item in pairs(Player.PlayerData.items) do
        if item.type == 'weapon' then
            table.insert(weapons, item)
        end
    end

    local svslot = nil
    for _, weapon in pairs(weapons) do
        if weapon.info.serie == serial then
            svslot = weapon.slot
            break
        end
    end
    TriggerClientEvent('rsg-weaponcomp:client:returnSlot', src, svslot)
end)

--------------------------------------------
-- ADD COMPONENTS SQL
--------------------------------------------
-- Server event for storing components in the database
RegisterNetEvent('rsg-weaponcomp:server:apply_weapon_components')
AddEventHandler('rsg-weaponcomp:server:apply_weapon_components', function(components, weaponName, serial)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    -- ADD CUSTOM EVER
    MySQL.Async.execute('UPDATE player_weapons SET components = @components WHERE serial = @serial', {
        ['@components'] = json.encode(components),
        ['@serial'] = serial
    }, function(rowsChanged)
        if rowsChanged > 0 then

            sendToDiscord(16753920,	"Craft | WEAPON CUSTOM", "**Citizenid:** "..Player.PlayerData.citizenid.."\n**Ingame ID:** "..Player.PlayerData.cid.. "\n**Name:** "..Player.PlayerData.charinfo.firstname.." "..Player.PlayerData.charinfo.lastname.. "\n**Job:** ".. 'job' .."\n**Weapon:** "..weaponName .. "\n**Serial:** "..serial .. "\n**Components Specific:** ".. json.encode(components),	"Weapon Craft  for RSG Framework", "weapons")
            Wait(1000)
            if Config.Notify == 'rnotify' then
                TriggerClientEvent('rNotify:NotifyLeft', src, 'Components and assets', 'updated successfully!', "generic_textures", "tick", 4000)
            elseif Config.Notify == 'ox_lib' then
                TriggerClientEvent('ox_lib:notify', src, {title = 'Components and assets updated successfully!', type = 'inform', duration = 5000 })
            end
            if Config.Debug then
                print('Weapon components have been successfully updated for the serial:', serial, json.encode(components))
            end

            Wait(100)
            TriggerClientEvent('rsg-weaponcomp:client:LoadComponents', src)
        end
    end)

    -- DELETE CUSTOM TABLE
    Wait(100)
    TriggerEvent("rsg-weaponcomp:server:removeComponents_selection", {}, serial) -- update SQL

end)

RegisterNetEvent('rsg-weaponcomp:server:update_selection')
AddEventHandler('rsg-weaponcomp:server:update_selection', function(components, serial)
    local src = source
    -- ADD CUSTOM SELECTION
    MySQL.Async.execute('UPDATE player_weapons SET components_before = @components_before WHERE serial = @serial', {
        ['@components_before'] = json.encode(components),
        ['@serial'] = serial
    }, function(rowsChanged)
        if rowsChanged > 0 then
            TriggerClientEvent('rsg-weaponcomp:client:LoadComponents_selection', src)
        end
    end)
end)

-------------------------------------------
-- update/REMOVE components SQL
-------------------------------------------
RegisterServerEvent('rsg-weaponcomp:server:removeComponents', function(components, weaponName, serial)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if components == "{}" then
        MySQL.Async.execute('UPDATE player_weapons SET components = NULL WHERE serial = @serial', {
            ['@serial'] = serial
        }, function(rowsChanged)
            if rowsChanged > 0 then
                sendToDiscord(16753920,	"Craft | WEAPON CUSTEM", "**Citizenid:** "..Player.PlayerData.citizenid.."\n**Ingame ID:** "..Player.PlayerData.cid.. "\n**Name:** "..Player.PlayerData.charinfo.firstname.." "..Player.PlayerData.charinfo.lastname.. "\n**Job:** ".. 'job' .."\n**Weapon:** ".. weaponName .. "\n**Serial:** "..serial .. "\n**Components Specific:** ".. '{}',	"Weapon Craft  for RSG Framework", "weapons")
                Wait(2000)
                if Config.Notify == 'rnotify' then
                    TriggerClientEvent('rNotify:NotifyLeft', src, "Components and assets", "removed successfully!" ,"generic_textures", "tick", 4000)
                elseif Config.Notify == 'ox_lib' then
                    TriggerClientEvent('ox_lib:notify', src, {title = 'Components and assets removed successfully!', type = 'inform', duration = 5000 })
                end

                Wait(100)
                TriggerClientEvent('rsg-weaponcomp:client:LoadComponents', src)

            end
        end)
    end
end)

RegisterServerEvent('rsg-weaponcomp:server:removeComponents_selection', function(components, serial)
    local src = source
    if components == "{}" then
        MySQL.Async.execute('UPDATE player_weapons SET components_before = NULL WHERE serial = @serial', {
            ['@serial'] = serial
        }, function()
            TriggerClientEvent('rsg-weaponcomp:client:LoadComponents_selection', src)
        end)
    end
end)

--------------------------------------------
-- VISION COMPONENTS / IN TEST
--------------------------------------------
RegisterNetEvent('rsg-weaponcomp:server:inspectWeapon')
AddEventHandler('rsg-weaponcomp:server:inspectWeapon', function(weaponHash)
    local src = source
    local stats = getWeaponStats(weaponHash)
    TriggerClientEvent('rsg-weaponcomp:client:viewweapon', src, weaponHash, stats)
end)

--------------------------------------------
-- CHECK COMPONENTS SQL
--------------------------------------------
RegisterNetEvent('rsg-weaponcomp:server:check_comps') -- EQUIPED
AddEventHandler('rsg-weaponcomp:server:check_comps', function()
    local src = source
    TriggerClientEvent('rsg-weaponcomp:client:LoadComponents', src)
end)

RegisterNetEvent('rsg-weaponcomp:server:check_comps_selection') -- EQUIPED
AddEventHandler('rsg-weaponcomp:server:check_comps_selection', function()
    local src = source
    TriggerClientEvent('rsg-weaponcomp:client:LoadComponents_selection', src)
end)

--------------------------------------------------------------------------------------------------
-- start version check
--------------------------------------------------------------------------------------------------
CheckVersion()
