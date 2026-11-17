local RSGCore = exports['rsg-core']:GetCoreObject()

local isPlacing = false

--- Workbench placement uses the framework's rsg-gizmo (the standard prop placement gizmo).
--- Place blocks until the player confirms or cancels, so it runs in its own thread.
local function placeProp(propmodel)
    if isPlacing then return end
    isPlacing = true

    CreateThread(function()
        local res = exports['rsg-gizmo']:Place(propmodel, {
            rotation = 'z',
            maxDistance = Config.PlaceDistance or 5.0,
        })
        isPlacing = false
        if not res then return end -- cancelled / invalid

        TriggerEvent('rsg-weaponcomp:client:setupgunzone', res.coords, res.heading or res.rotation.z)
    end)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isPlacing then exports['rsg-gizmo']:Cancel() end
end)

RegisterNetEvent('rsg-weaponcomp:client:createprop', function(data)
    placeProp(data.propmodel)
end)

-- Admin: place a public workbench (/createworkbench). The server re-checks the permission and placement.
RegisterNetEvent('rsg-weaponcomp:client:adminplace', function()
    if isPlacing then return end
    isPlacing = true
    CreateThread(function()
        local res = exports['rsg-gizmo']:Place(Config.Gunsmithprop, {
            rotation = 'z',
            maxDistance = Config.PlaceDistance or 5.0,
        })
        isPlacing = false
        if not res then return end
        TriggerServerEvent('rsg-weaponcomp:server:adminplace', res.coords, res.heading or res.rotation.z)
    end)
end)

-- Admin: /listworkbenches prints to the F8 console
RegisterNetEvent('rsg-weaponcomp:client:printlist', function(lines)
    if type(lines) ~= 'table' then return end
    print(('[rsg-weaponcomp] %d workbenches'):format(#lines))
    for _, line in ipairs(lines) do print(line) end
    RSGCore.Functions.Notify({ title = locale('ui_notify_title'), description = locale('cl_list_printed', #lines), type = 'inform' })
end)
