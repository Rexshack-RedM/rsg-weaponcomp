-- UI bridge for Wild West weapon UI (NUI)
-- Open UI with /weaponsui
RegisterCommand('weaponsui', function()
  SetNuiFocus(true, true)
  SendNUIMessage({ type = 'OPEN' })
  TriggerServerEvent('rsg-weaponcomp:getWeapons')
end, false)

RegisterNUICallback('close', function(data, cb)
  SetNuiFocus(false, false)
  cb('ok')
end)

-- Receive weapons data from server and pass to NUI
RegisterNetEvent('rsg-weaponcomp:weaponsData')
AddEventHandler('rsg-weaponcomp:weaponsData', function(data)
  SendNUIMessage({ type = 'WEAPONS_LIST', payload = data })
end)
