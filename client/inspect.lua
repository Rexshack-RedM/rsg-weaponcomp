local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local INSPECT_UI = -813354801            -- weapon inspect UI state machine
local CONTROL_CANCEL = 3002300392
local CONTROL_CLEAN = 3820983707
local uiContainer

local INTERACTIONS = {
    SHORTARM = { hold = `SHORTARM_HOLD_ENTER`, clean = `SHORTARM_CLEAN_ENTER` },
    LONGARM = { hold = `LONGARM_HOLD_ENTER`, clean = `LONGARM_CLEAN_ENTER` },
    SHOTGUN = { hold = `LONGARM_HOLD_ENTER`, clean = `LONGARM_CLEAN_ENTER` },
}

local function isInspecting(ped)
    return Citizen.InvokeNative(0xEC7E480FF8BD0BED, ped) -- IsPedRunningInspectionTask
end

local function getWeaponStats(wHash)
    local emptyStruct = DataView.ArrayBuffer(256)
    local charStruct = DataView.ArrayBuffer(256)
    Citizen.InvokeNative(0x886DFD3E185C8A89, 1, emptyStruct:Buffer(), `CHARACTER`, -1591664384, charStruct:Buffer()) -- InventoryGetGuidFromItemid

    local unkStruct = DataView.ArrayBuffer(256)
    Citizen.InvokeNative(0x886DFD3E185C8A89, 1, charStruct:Buffer(), 923904168, -740156546, unkStruct:Buffer())

    local weaponStruct = DataView.ArrayBuffer(256)
    Citizen.InvokeNative(0x886DFD3E185C8A89, 1, unkStruct:Buffer(), wHash, -1591664384, weaponStruct:Buffer())
    return weaponStruct:Buffer()
end

local function closeStats()
    Citizen.InvokeNative(0x4EB122210A90E2D8, INSPECT_UI) -- UiStateMachineDestroy
    if uiContainer then
        DatabindingRemoveDataEntry(uiContainer)
        uiContainer = nil
    end
end

local function showStats(wHash)
    closeStats() -- don't stack a new data container on every inspection
    local flowBlock = RequestFlowBlock(`PM_FLOW_WEAPON_INSPECT`)
    uiContainer = DatabindingAddDataContainerFromPath('', 'ItemInspection')
    Citizen.InvokeNative(0x46DB71883EE9D5AF, uiContainer, 'stats', getWeaponStats(wHash), cache.ped)
    DatabindingAddDataString(uiContainer, 'tipText', locale('cl_lang_29'))
    DatabindingAddDataHash(uiContainer, 'itemLabel', wHash)
    DatabindingAddDataBool(uiContainer, 'Visible', true)

    Citizen.InvokeNative(0x10A93C057B6BD944, flowBlock)
    Citizen.InvokeNative(0x3B7519720C9DCB45, flowBlock, 0)
    Citizen.InvokeNative(0x4C6F2C4B7A03A266, INSPECT_UI, flowBlock)
end

local function cleanWeapon(ped, serial, cleanAct, weaponObj)
    local p = promise.new()
    RSGCore.Functions.TriggerCallback('rsg-weaponcomp:server:useRepairKit', function(res) p:resolve(res) end, serial)
    local ok = Citizen.Await(p)
    if not ok then
        local item = RSGCore.Shared.Items[Config.RepairItem]
        lib.notify({ title = locale('cl_notify_13'), description = locale('cl_no_repair_item', item and item.label or Config.RepairItem), type = 'error' })
        ClearPedTasks(ped, 1, 1)
        return
    end

    local cloth = CreateObject(`s_balledragcloth01x`, GetEntityCoords(ped), false, true, false, false, true)
    Citizen.InvokeNative(0x72F52AA2D2B172CC, ped, 1242464081, cloth, `CLOTH`, cleanAct, 1, 0, -1.0) -- TaskItemInteraction_2
    Wait(9500)

    TriggerServerEvent('rsg-weapons:server:repairweapon', serial)
    if weaponObj and weaponObj ~= 0 then
        Citizen.InvokeNative(0xA7A57E89E965D839, weaponObj, 0.0, 0) -- SetWeaponDegradation
        Citizen.InvokeNative(0x812CE61DEBCAB948, weaponObj, 0.0, 0) -- SetWeaponDirt
    end

    ClearPedTasks(ped, 1, 1)
    if DoesEntityExist(cloth) then DeleteEntity(cloth) end
end

RegisterNetEvent('rsg-weaponcomp:client:InspectionWeapon', function()
    local ped = cache.ped
    local wHash = GetPedCurrentHeldWeapon(ped)
    local interaction = INTERACTIONS[GetWeaponType(wHash)]
    local serial = exports['rsg-weapons']:weaponInHands()[wHash]

    -- bows, melee and unarmed have no inspection interaction
    if not interaction or not serial then
        return lib.notify({ title = locale('cl_notify_13'), description = locale('cl_notify_14'), type = 'error' })
    end
    if not RSGCore.Functions.HasItem(Config.RepairItem) then
        local item = RSGCore.Shared.Items[Config.RepairItem]
        return lib.notify({ title = locale('cl_notify_13'), description = locale('cl_no_repair_item', item and item.label or Config.RepairItem), type = 'error' })
    end

    local weaponObj = GetObjectIndexFromEntityIndex(GetCurrentPedWeaponEntityIndex(ped, 0))
    SetPedBlackboardBool(ped, 'GENERIC_WEAPON_CLEAN_PROMPT_AVAILABLE', true, -1)
    StartTaskItemInteraction(ped, wHash, interaction.hold, 0, 0, 0)
    if Config.showStats then showStats(wHash) end

    -- wait for the inspection to start (give up after 3s instead of hanging forever)
    local timeout = GetGameTimer() + 3000
    while not isInspecting(ped) do
        if GetGameTimer() > timeout then closeStats() return end
        Wait(100)
    end

    -- controls must be polled every frame or "just released" presses get missed
    while isInspecting(ped) do
        if IsDisabledControlJustReleased(0, CONTROL_CANCEL) then
            ClearPedTasks(ped, 1, 1)
            break
        end
        if IsDisabledControlJustReleased(0, CONTROL_CLEAN) then
            cleanWeapon(ped, serial, interaction.clean, weaponObj)
            break
        end
        Wait(0)
    end

    closeStats()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closeStats()
end)
