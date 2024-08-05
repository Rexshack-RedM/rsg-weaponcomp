
--[[ -- NEXT STEP INTERACTION WITH PLAYERS

local RSGCore = exports['rsg-core']:GetCoreObject()

---------------------------------
-- customs prompts
---------------------------------
CreateThread(function()
    local jobtype = RSGCore.Functions.GetPlayerData().job.type
    while true do
        Wait(0)
        local pos = GetEntityCoords(cache.ped)
        if inCustom == false then
            for _, v in pairs(Config.CustomLocations) do
                local dist = #(pos - v.coords)
                if dist < 1 then
                    local message = "~COLOR_GOLD~Press [J] to enter Weapon Custom Menu"
                    local text = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", message, Citizen.ResultAsLong())
                    Citizen.InvokeNative(0xFA233F8FE190514C, text)
                    Citizen.InvokeNative(0xE9990552DEC71600)

                    if jobtype ~= Config.JobType then
                        if IsControlJustReleased(0, RSGCore.Shared.Keybinds['J']) then
                            TriggerEvent('rsg-weaponcomp:client:startcustom_nojob', v.custcoords)
                        end
                    end
          
                end
            end
        end
    end
end)

----------------------------------
-- NO JOB MENU
----------------------------------
RegisterNetEvent('rsg-weaponcomp:client:startcustom_nojob', function(custcoords)
    local weaponHash = GetPedCurrentHeldWeapon(cache.ped)
    local weaponInHands = exports['rsg-weapons']:weaponInHands()
    local weaponName = Citizen.InvokeNative(0x89CF5FF3D363311E, weaponHash, Citizen.ResultAsString())
    local serial = weaponInHands[weaponHash]
    local weapon_type = GetWeaponType(weaponHash)
    local wep = GetCurrentPedWeaponEntityIndex(cache.ped, 0)

    currentSerial = serial
    currentName = weaponName
    currentWep = wep

    if inCustom == true then return end
    if weaponHash == -1569615261 then lib.notify({ title = 'Item Needed', description = "You're not holding a weapon!", type = 'error', icon = 'fa-solid fa-gun', iconAnimation = 'shake', duration = 7000}) return end
    if weapon_type ~= nil and currentSerial ~= nil then

        createobject(custcoords.x, custcoords.y, custcoords.z, weaponHash)
        StartCam(custcoords.x+0.2, custcoords.y+0.1, custcoords.z+4.0, custcoords.h)

        TriggerServerEvent("rsg-weaponcomp:server:check_comps") -- CHECK COMPONENTS EQUIPED
        Wait(100)
        mainCompMenu_nojob(weaponHash) -- ENTER MENU

    else
        TriggerEvent('rsg-weaponcomp:client:ExitCam')
    end

end)

local mainWeaponCompMenus_nojob = {
    ["component"] = function(objecthash) OpenComponentMenu(objecthash) end,
    ["material"] = function(objecthash) OpenMaterialMenu(objecthash) end,
    ["engraving"] = function(objecthash) OpenEngravingMenu(objecthash) end,
    ["tints"] = function(objecthash) OpenTintsMenu(objecthash) end,
    ["makecommponent"] = function(objecthash) ButtomMakeComponents(objecthash) end,
    ["deletecommponent"] = function(objecthash) ButtomDeleteAllComponents(objecthash) end,
    ["exitcommponent"] = function() TriggerEvent('rsg-weaponcomp:client:ExitCam') end
}

-- MAIN MENU NO JOB
 mainCompMenu_nojob = function(objecthash)
    MenuData.CloseAll()
    FreezeEntityPosition(cache.ped, true)
    LocalPlayer.state:set("inv_busy", true, true) -- BLOCK INVENTORY
    inCustom = true

    Wait(100)
    local elements = {
        {label = 'Components',  value = 'component',        desc = ""},
        {label = 'Materials',   value = 'material',         desc = ""},
        {label = 'Engravings',  value = 'engraving',        desc = ""},
        {label = 'Tints',       value = 'tints',            desc = ""},
        {label = 'Make an order',     value = 'makecommponent',  desc = ""},
        {label = 'delete order',    value = 'deletecommponent', desc = ""},
        {label = 'EXIT',        value = 'exitcommponent',   desc = ""},
    }

    MenuData.Open('default', GetCurrentResourceName(), 'main_weapons_creator_menu_nojob', {
    title = "Weapons Menu",
    subtext = 'Options ',
    align = "bottom-left",
    elements = elements,
    itemHeight = "2vh"
    }, function(data, menu)

        mainWeaponCompMenus_nojob[data.current.value](objecthash) -- MENU BUTTOMS
        TriggerServerEvent("rsg-weaponcomp:server:check_comps_selection")

    end, function(data, menu)

        menu.close()
        TriggerEvent('rsg-weaponcomp:client:ExitCam')
        Wait(1000)

    end)
end

ButtomMakeComponents = function (objecthash)
end
ButtomDeleteAllComponents = function(objecthash)
end

]]
