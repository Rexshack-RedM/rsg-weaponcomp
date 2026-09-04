local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()
local uiContainer = nil
-----------------------------------
-- UTILITYS -- INSPECTION
-----------------------------------
function getWeaponStats(wHash)
    local emptyStruct = DataView.ArrayBuffer(256)
    local charStruct = DataView.ArrayBuffer(256)
    Citizen.InvokeNative(0x886DFD3E185C8A89, 1, emptyStruct:Buffer(), GetHashKey("CHARACTER"), -1591664384, charStruct:Buffer()) -- InventoryGetGuidFromItemid(

    local unkStruct = DataView.ArrayBuffer(256)
    Citizen.InvokeNative(0x886DFD3E185C8A89, 1, charStruct:Buffer(), 923904168, -740156546, unkStruct:Buffer())

    local weaponStruct = DataView.ArrayBuffer(256)
    Citizen.InvokeNative(0x886DFD3E185C8A89, 1, unkStruct:Buffer(), wHash, -1591664384, weaponStruct:Buffer())
    return weaponStruct:Buffer()
end

function showstats()
    local _, weapon = GetCurrentPedWeapon(PlayerPedId(), true, 0, true)
    if weapon then
        local uiFlowBlock = RequestFlowBlock(GetHashKey("PM_FLOW_WEAPON_INSPECT"))
        uiContainer = DatabindingAddDataContainerFromPath("" , "ItemInspection")
        Citizen.InvokeNative(0x46DB71883EE9D5AF, uiContainer, "stats", getWeaponStats(weapon), PlayerPedId())
        DatabindingAddDataString(uiContainer, "tipText", locale('cl_lang_29'))
        DatabindingAddDataHash(uiContainer, "itemLabel", weapon)
        DatabindingAddDataBool(uiContainer, "Visible", true)

        Citizen.InvokeNative(0x10A93C057B6BD944, uiFlowBlock)
        Citizen.InvokeNative(0x3B7519720C9DCB45, uiFlowBlock, 0)
        Citizen.InvokeNative(0x4C6F2C4B7A03A266, -813354801, uiFlowBlock)
    end
end

RegisterNetEvent("rsg-weaponcomp:client:InspectionWeapon")
AddEventHandler("rsg-weaponcomp:client:InspectionWeapon", function()
    local wHash = GetPedCurrentHeldWeapon(PlayerPedId())
    local weaponType = GetWeaponType(wHash)
    local serial = exports['rsg-weapons']:weaponInHands()[wHash]
    local object = GetObjectIndexFromEntityIndex(GetCurrentPedWeaponEntityIndex(cache.ped, 0))
    local cleaning = false

    local hasGunOil = RSGCore.Functions.HasItem(Config.RepairItem)
    SetPedBlackboardBool(cache.ped, "GENERIC_WEAPON_CLEAN_PROMPT_AVAILABLE", true, -1) -- Citizen.InvokeNative(0xCB9401F918CB0F75, 

    local interaction, act = nil, nil
    if IsWeaponOneHanded(wHash) and weaponType == 'SHORTARM' then
        interaction, act = "SHORTARM_HOLD_ENTER", GetHashKey("SHORTARM_CLEAN_ENTER")
    elseif IsWeaponOneHanded(wHash) and weaponType == 'LONGARM' then
        interaction, act = "LONGARM_HOLD_ENTER", GetHashKey("LONGARM_CLEAN_ENTER")
    elseif IsWeaponOneHanded(wHash) and weaponType == 'SHOTGUN' then
        interaction, act = "LONGARM_HOLD_ENTER", GetHashKey("LONGARM_CLEAN_ENTER")
    elseif IsWeaponOneHanded(wHash) and weaponType == 'GROUP_BOW' then
    elseif IsWeaponOneHanded(wHash) and weaponType == 'MELEE_BLADE' then
    end
    if weaponType == 'GROUP_BOW' then return lib.notify({ title = locale('cl_notify_13'), description=locale('cl_notify_14'), type='error' }) end
    if wHash ~= -1569615261 and hasGunOil then
        if interaction then
            StartTaskItemInteraction(cache.ped, wHash, GetHashKey(interaction), 0,0,0)
        end
        if Config.showStats == true then showstats() end
        while not Citizen.InvokeNative(0xEC7E480FF8BD0BED, cache.ped) do Wait(300) end

        while Citizen.InvokeNative(0xEC7E480FF8BD0BED, cache.ped) do
            Wait(100)

            if IsDisabledControlJustReleased(0, 3002300392) then
                ClearPedTasks(cache.ped, 1, 1)
                Citizen.InvokeNative(0x4EB122210A90E2D8, -813354801) -- UiStateMachineDestroy(
            end

            if IsDisabledControlJustReleased(0, 3820983707) and not cleaning then
                cleaning = true
                local Cloth= CreateObject(GetHashKey('s_balledragcloth01x'), GetEntityCoords(cache.ped), false, true, false, false, true)
                local PropId = GetHashKey("CLOTH")
                Citizen.InvokeNative(0x72F52AA2D2B172CC, cache.ped, 1242464081, Cloth, PropId, act, 1, 0, -1.0) -- TaskItemInteraction2
                Wait(9500)
                TriggerServerEvent('rsg-weaponcomp:server:inspectkitConsume')
                TriggerServerEvent('rsg-weapons:server:repairweapon', serial)
                ClearPedTasks(cache.ped, 1, 1)

                if Config.showStats then
                    Citizen.InvokeNative(0x4EB122210A90E2D8, -813354801)
                    Citizen.InvokeNative(0xA7A57E89E965D839, object, 0.0, 0) -- SetWeaponDegradation(
                    Citizen.InvokeNative(0x812CE61DEBCAB948, object, 0.0, 0) -- SetWeaponDirt(
                end

                break
            end

        end

        if Config.showStats then Citizen.InvokeNative(0x4EB122210A90E2D8, -813354801) end
    end
end)

AddEventHandler('onResourceStop', function(r)
    if GetCurrentResourceName() ~= r then return end
    Citizen.InvokeNative(0x4EB122210A90E2D8, -813354801)
    if uiContainer ~= nil then
        DatabindingRemoveDataEntry(uiContainer)
    end
    --ReleaseFlowBlock(uiFlowBlock) --Citizen.InvokeNative(0xF320A77DD5F781DF, uiFlowBlock)
    Citizen.InvokeNative(0x8BC7C1F929D07BF3, GetHashKey("HUD_CTX_INSPECT_ITEM")) -- DisableHUDComponent
end)