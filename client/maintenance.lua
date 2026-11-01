local RSGCore = exports['rsg-core']:GetCoreObject()

----------------------------------------
-- Weapon maintenance: gun oil quick clean + condition helpers
-- Natives (natives/db/WEAPON.md): _GET_WEAPON_DIRT 0x810E8AE9AFEA7E54,
-- _SET_WEAPON_DIRT 0x812CE61DEBCAB948, _SET_WEAPON_SOOT 0xA9EF4AD10BDDDB57,
-- _SET_WEAPON_DEGRADATION 0xA7A57E89E965D839
----------------------------------------
Maintenance = {}

local OIL_ANIMS = {
    SHORTARM = 'mech_inspection@weapons@shortarms@volcanic@base',
    LONGARM = 'mech_inspection@weapons@longarms@sniper_carcano@base',
    SHOTGUN = 'mech_inspection@weapons@longarms@shotgun_double_barrel@base',
}
local oiling = false

--- Weapon object currently held by the ped (0 when none).
function Maintenance.GetHeldWeaponObject(ped)
    local ent = GetCurrentPedWeaponEntityIndex(ped, 0)
    if not ent or ent == 0 then return 0 end
    return GetObjectIndexFromEntityIndex(ent)
end

--- Dirt level 0.0 - 1.0 of the held weapon (0 when unknown).
function Maintenance.GetDirt(ped)
    local obj = Maintenance.GetHeldWeaponObject(ped)
    if obj == 0 then return 0.0 end
    return Citizen.InvokeNative(0x810E8AE9AFEA7E54, obj, Citizen.ResultAsFloat()) or 0.0
end

function Maintenance.ClearDirt(obj)
    if not obj or obj == 0 then return end
    Citizen.InvokeNative(0x812CE61DEBCAB948, obj, 0.0, false) -- SetWeaponDirt
    Citizen.InvokeNative(0xA9EF4AD10BDDDB57, obj, 0.0, false) -- SetWeaponSoot
end

function Maintenance.ClearDegradation(obj)
    if not obj or obj == 0 then return end
    Citizen.InvokeNative(0xA7A57E89E965D839, obj, 0.0) -- SetWeaponDegradation
end

local function heldSerial(ped)
    local wHash = GetPedCurrentHeldWeapon(ped)
    if wHash == 0 or wHash == `WEAPON_UNARMED` then return end
    return exports['rsg-weapons']:weaponInHands()[wHash], wHash
end

RegisterNetEvent('rsg-weaponcomp:client:oilWeapon', function()
    if oiling then return end
    local ped = PlayerPedId()
    local serial, wHash = heldSerial(ped)
    if not serial then
        return RSGCore.Functions.Notify({ title = locale('cl_notify_13'), description = locale('cl_no_weapon'), type = 'error' })
    end
    if Maintenance.GetDirt(ped) < 0.01 then
        return RSGCore.Functions.Notify({ title = locale('cl_notify_13'), description = locale('cl_already_clean'), type = 'inform' })
    end

    oiling = true
    local dict = OIL_ANIMS[GetWeaponType(wHash)]
    local cloth = CreateObject(`s_balledragcloth01x`, GetEntityCoords(ped), false, true, false, false, true)
    AttachEntityToEntity(cloth, ped, GetEntityBoneIndexByName(ped, 'SKEL_L_Finger00'), 0.02, -0.035, 0.0, 20.0, -24.0, 165.0, true, false, true, false, 0, true)

    local done = RSGCore.Functions.ProgressBar({
        duration = Config.GunOilTime or 6000,
        label = locale('cl_oil_cleaning'),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, combat = true, sprint = true },
        anim = dict and { dict = dict, clip = 'clean_loop', flag = 15 } or nil,
    })
    ClearPedTasks(ped)
    if DoesEntityExist(cloth) then DeleteEntity(cloth) end

    if done and GetPedCurrentHeldWeapon(ped) == wHash then
        local ok = RSGCore.Functions.AwaitCallback('rsg-weaponcomp:server:useGunOil', 5000, serial)
        if ok then
            Maintenance.ClearDirt(Maintenance.GetHeldWeaponObject(ped))
            RSGCore.Functions.Notify({ title = locale('ui_notify_title'), description = locale('cl_oil_done'), type = 'success' })
        end
    end
    oiling = false
end)
