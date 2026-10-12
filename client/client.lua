local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

----------------------------------------
-- State
----------------------------------------
local SpawnedProps = {}     -- [propid] = { obj = entity, zone = zone }
local ingunZone = false
local isBusy = false
local wepObj = nil
local camera = nil
local selectedCache = {}    -- current selection in the menu
local baselineCache = {}    -- what the weapon had when the menu opened
local currentWeaponData = nil
local promptThreadActive = false
local promptGroup = GetRandomIntInRange(0, 0xffffff)
local cameraPrompts = {}

local UNARMED = `WEAPON_UNARMED`
local PROP_RENDER_DISTANCE = 50.0

local UI_LOCALE_KEYS = {
    'ui_page_title', 'ui_title', 'ui_modifications', 'ui_components', 'ui_back', 'ui_total_cost',
    'ui_purchase', 'ui_reset', 'ui_exit', 'ui_scroll', 'ui_zoom', 'ui_random_view', 'ui_reset_camera',
    'ui_unknown_weapon', 'ui_serial', 'ui_parts', 'ui_packup', 'ui_all_parts', 'ui_no_options',
    'ui_no_mods_selected',
}

-- Category display order for the menu (related parts grouped together)
local CATEGORY_ORDER = {
    BARREL = 1, BARREL_TINT = 2, BARREL_MATERIAL = 3, BARREL_ENGRAVING = 4, BARREL_ENGRAVING_MATERIAL = 5, BARREL_RIFLING = 6,
    TUBE = 10, MAG = 11, MAGAZINE = 12, CLIP = 13, STOCK = 14,
    CYLINDER_MATERIAL = 20, CYLINDER_TINT = 21, CYLINDER_ENGRAVING = 22, CYLINDER_ENGRAVING_MATERIAL = 23,
    FRAME_MATERIAL = 30, FRAME_ENGRAVING = 31, FRAME_ENGRAVING_MATERIAL = 32,
    HAMMER_MATERIAL = 35, TRIGGER_MATERIAL = 40, TRIGGER_TINT = 41,
    GRIP = 50, GRIP_TINT = 51, GRIP_MATERIAL = 52, GRIPSTOCK_ENGRAVING = 60, GRIPSTOCK_TINT = 61,
    SIGHT = 70, SIGHT_MATERIAL = 71, SCOPE = 80, SCOPE_TINT = 81,
    WRAP = 90, WRAP_TINT = 91, WRAP_MATERIAL = 92, STRAP = 100, STRAP_TINT = 101,
    MELEE_BLADE_MATERIAL = 110, MELEE_BLADE_ENGRAVING = 111, MELEE_BLADE_ENGRAVING_MATERIAL = 112,
    TORCH_MATCHSTICK = 1000,
}

local WeaponTypeMap = {
    [`GROUP_REPEATER`] = 'LONGARM',
    [`GROUP_SHOTGUN`] = 'SHOTGUN',
    [`GROUP_PISTOL`] = 'SHORTARM',
    [`GROUP_REVOLVER`] = 'SHORTARM',
    [`GROUP_RIFLE`] = 'LONGARM',
    [`GROUP_SNIPER`] = 'LONGARM',
    [`GROUP_MELEE`] = 'MELEE_BLADE',
    [`GROUP_BOW`] = 'GROUP_BOW',
}

function GetWeaponType(hash)
    return WeaponTypeMap[GetWeapontypeGroup(hash)]
end

function GetWeaponNameFromHash(hash)
    return Citizen.InvokeNative(0x89CF5FF3D363311E, hash, Citizen.ResultAsString())
end

local function cloneTable(t)
    local copy = {}
    for k, v in pairs(t) do copy[k] = v end
    return copy
end

--- Loads a model, returning false instead of erroring on timeout.
local function loadModel(model, timeout)
    return pcall(lib.requestModel, model, timeout)
end

local function toModelHash(model)
    return type(model) == 'number' and model or joaat(model)
end

----------------------------------------
-- Utility
----------------------------------------
local function setPlayerFrozen(state)
    local ped = cache.ped
    FreezeEntityPosition(ped, state)
    SetEntityInvincible(ped, state)
    SetBlockingOfNonTemporaryEvents(ped, state)
    SetPedCanRagdoll(ped, not state)
end

local function mergeComponents(merged, source)
    for cat, list in pairs(source or {}) do
        merged[cat] = merged[cat] or {}
        for _, comp in ipairs(list) do
            merged[cat][#merged[cat] + 1] = comp
        end
    end
end

function GetAvailableComponents(weaponName, wHash)
    local merged = {}
    local group = GetWeaponType(wHash)
    if group and Config.Shared then mergeComponents(merged, Config.Shared[group]) end
    if Config.Specific then mergeComponents(merged, Config.Specific[weaponName]) end
    merged.FRAME_VERTDATA = nil -- conflicts with other component visuals
    return merged
end

--- Price of the categories that differ from what the weapon had when the menu opened.
local function calculatePrice()
    local total = 0
    for cat, comp in pairs(selectedCache) do
        if baselineCache[cat] ~= comp then
            total = total + (Config.price[cat] or 0)
        end
    end
    return math.floor(total * 100 + 0.5) / 100
end

local function loadComponentModel(compHash)
    local mdl = GetWeaponComponentTypeModel(compHash)
    if mdl and mdl ~= 0 then
        loadModel(mdl, 2500)
    end
end

----------------------------------------
-- Camera
----------------------------------------
local function startCamOnWeapon(obj, fov)
    if not (obj and DoesEntityExist(obj)) then return end
    ClearFocus()
    local forward, right, up, origin = GetEntityMatrix(obj)
    local camPos = origin - forward * (Config.distBack or 0.8) + right * (Config.distSide or 0.3) + up * (Config.distUp or 0.2)

    if camera then DestroyCam(camera, true) end
    camera = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, 0, 0, 0, fov or 75.0, false, 0)
    SetCamActive(camera, true)
    RenderScriptCams(true, true, 1000, true, false)
    PointCamAtCoord(camera, origin.x, origin.y, origin.z + 0.1)
end

local function setRandomCameraAroundWeapon()
    if not camera or not wepObj then return end
    local c = GetEntityCoords(wepObj)
    local yaw, pitch = math.rad(math.random(1, 360)), math.rad(math.random(-10, 50))
    local r = 0.5
    SetCamCoord(camera, c.x + r * math.cos(yaw) * math.cos(pitch), c.y + r * math.sin(yaw) * math.cos(pitch), c.z + r * math.sin(pitch))
    PointCamAtCoord(camera, c.x, c.y, c.z)
end

local function adjustZoom(zoomIn)
    if not camera then return end
    local cam = camera
    local fromFov = GetCamFov(cam)
    local toFov = math.max(15.0, math.min(90.0, fromFov + (zoomIn and -5.0 or 5.0)))
    CreateThread(function()
        local start, duration = GetGameTimer(), 150
        while GetGameTimer() - start < duration and DoesCamExist(cam) do
            SetCamFov(cam, fromFov + (toFov - fromFov) * ((GetGameTimer() - start) / duration))
            Wait(0)
        end
        if DoesCamExist(cam) then SetCamFov(cam, toFov) end
    end)
end

local function destroyCamera()
    ClearFocus()
    RenderScriptCams(false, false, 0, true, false)
    if camera then DestroyCam(camera, true) end
    camera = nil
end

local function deleteWeaponObject()
    if wepObj and DoesEntityExist(wepObj) then
        SetEntityAsMissionEntity(wepObj, true, true)
        DeleteObject(wepObj)
    end
    wepObj = nil
end

----------------------------------------
-- Camera prompts
----------------------------------------
local function clearCameraPrompts()
    for _, prompt in pairs(cameraPrompts) do PromptDelete(prompt) end
    cameraPrompts = {}
end

local function registerPrompt(control, textKey, hold)
    local p = PromptRegisterBegin()
    PromptSetControlAction(p, control)
    PromptSetText(p, CreateVarString(10, 'LITERAL_STRING', locale(textKey)))
    PromptSetEnabled(p, true)
    PromptSetVisible(p, true)
    if hold then PromptSetHoldMode(p, true) else PromptSetStandardMode(p, true) end
    PromptSetGroup(p, promptGroup)
    PromptRegisterEnd(p)
    return p
end

local function startPromptThread()
    if promptThreadActive or not Config.prompts then return end
    promptThreadActive = true

    local controls = Config.prompts
    cameraPrompts = {
        registerPrompt(controls.ranPos, 'weapon_cam_rand'),
        registerPrompt(controls.zoIn, 'zoom_in'),
        registerPrompt(controls.zoOut, 'zoom_out'),
        registerPrompt(controls.re, 'weapon_cam_reset', true),
    }

    local function pressed(control)
        return IsControlJustPressed(2, control) or IsDisabledControlJustPressed(2, control)
    end

    CreateThread(function()
        local groupLabel = CreateVarString(10, 'LITERAL_STRING', locale('cl_camera_controls'))
        while promptThreadActive and camera do
            PromptSetActiveGroupThisFrame(promptGroup, groupLabel)
            DisableControlAction(0, 0xCEFD9220, true) -- INPUT_CURSOR_ACCEPT
            DisableControlAction(0, 0x156F7119, true) -- INPUT_CURSOR_CANCEL

            if pressed(controls.zoIn) then adjustZoom(true) end
            if pressed(controls.zoOut) then adjustZoom(false) end
            if pressed(controls.re) then startCamOnWeapon(wepObj, Config.distFov or 75.0) end
            if pressed(controls.ranPos) then setRandomCameraAroundWeapon() end
            Wait(0)
        end
        clearCameraPrompts()
        promptThreadActive = false
    end)
end

----------------------------------------
-- NUI
----------------------------------------
local function getUILocales()
    local t = {}
    for _, key in ipairs(UI_LOCALE_KEYS) do t[key] = locale(key) end
    return t
end

local function closeWeaponUI()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
end

local function openWeaponUI(weaponName, wHash, serial, comps)
    local cats = {}
    for cat in pairs(comps) do cats[#cats + 1] = cat end
    table.sort(cats, function(a, b)
        local oa, ob = CATEGORY_ORDER[a] or 999, CATEGORY_ORDER[b] or 999
        if oa == ob then return a < b end
        return oa < ob
    end)

    local formatted = {}
    for _, cat in ipairs(cats) do
        formatted[cat] = {}
        for i, comp in ipairs(comps[cat]) do
            formatted[cat][i] = { name = comp, hash = joaat(comp), label = locale(comp) }
        end
    end

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    SendNUIMessage({
        action = 'open',
        weaponName = locale(weaponName),
        serial = serial or '000000',
        components = formatted,
        prices = Config.price or {},
        savedComponents = selectedCache,
        locales = getUILocales()
    })
end

local function exitCustomisation()
    destroyCamera()
    deleteWeaponObject()
    promptThreadActive = false
    closeWeaponUI()
    setPlayerFrozen(false)
    selectedCache, baselineCache = {}, {}
    currentWeaponData = nil
end

RegisterNetEvent('rsg-weaponcomp:client:ExitCam', exitCustomisation)

RegisterNUICallback('closeUI', function(_, cb)
    cb('ok')
    exitCustomisation()
end)

RegisterNUICallback('notify', function(data, cb)
    cb('ok')
    lib.notify({ title = locale('ui_notify_title'), description = tostring(data.message or ''), type = data.type or 'inform' })
end)

RegisterNUICallback('componentChanged', function(data, cb)
    cb('ok')
    if not currentWeaponData or not wepObj or not DoesEntityExist(wepObj) then return end

    local category, compName = data.category, data.component
    if type(compName) ~= 'string' or not currentWeaponData.comps[category] then return end

    local wHash = currentWeaponData.wHash
    local compHash = joaat(compName)
    loadComponentModel(compHash)

    if selectedCache[category] then
        RemoveWeaponComponentFromWeaponObject(wepObj, joaat(selectedCache[category]))
    end
    GiveWeaponComponentToEntity(wepObj, compHash, wHash, true)

    -- Gripstock parts get cleared when other components on the same part change
    for _, cat in ipairs({ 'GRIPSTOCK_ENGRAVING', 'GRIPSTOCK_TINT' }) do
        if category ~= cat and selectedCache[cat] then
            GiveWeaponComponentToEntity(wepObj, joaat(selectedCache[cat]), wHash, true)
        end
    end

    selectedCache[category] = compName
    SendNUIMessage({ action = 'updatePrice', price = calculatePrice() })
end)

RegisterNUICallback('purchase', function(_, cb)
    cb('ok')
    if not currentWeaponData then return end

    if calculatePrice() <= 0 then
        lib.notify({ title = locale('ui_notify_title'), description = locale('cl_notify_10'), type = 'error' })
        return
    end

    local data = currentWeaponData
    local comps = cloneTable(selectedCache)
    exitCustomisation()
    TriggerServerEvent('rsg-weaponcomp:server:purchase', data.serial, data.wHash, data.weaponName, comps)
end)

RegisterNUICallback('resetWeapon', function(_, cb)
    cb('ok')
    if not currentWeaponData then return end

    local data = currentWeaponData
    exitCustomisation()
    TriggerServerEvent('rsg-weaponcomp:server:reset', data.serial, data.wHash, data.weaponName)
end)

RegisterNUICallback('packup', function(_, cb)
    cb('ok')
    if not currentWeaponData then return end
    local propid = currentWeaponData.propid
    exitCustomisation()
    TriggerEvent('rsg-weaponcomp:client:confirmpackup', propid)
end)

----------------------------------------
-- Customisation
----------------------------------------
--- Puts saved (or factory) components on the display weapon and records them as the baseline.
local function applyComponents(obj, wHash, comps, savedComps)
    for cat, options in pairs(comps) do
        local compToApply = options[1]
        local saved = savedComps[cat]
        if saved then
            for _, valid in ipairs(options) do
                if valid == saved then compToApply = saved break end
            end
        end

        if compToApply then
            local compHash = joaat(compToApply)
            loadComponentModel(compHash)
            GiveWeaponComponentToEntity(obj, compHash, wHash, true)
            selectedCache[cat] = compToApply
        end
    end
    baselineCache = cloneTable(selectedCache)
end

local function startCustomisation(propid, wHash, serial, weaponName)
    if isBusy then return end
    local prop = SpawnedProps[propid]
    if not prop or not DoesEntityExist(prop.obj) then return end
    isBusy = true

    SetCurrentPedWeapon(cache.ped, UNARMED, true)
    setPlayerFrozen(true)

    deleteWeaponObject()
    local coords = GetEntityCoords(prop.obj)
    wepObj = Citizen.InvokeNative(0x9888652B8BA77F73, wHash, 0, coords.x, coords.y, coords.z, false, 1.0) -- CreateWeaponObject
    if not wepObj or not DoesEntityExist(wepObj) then
        setPlayerFrozen(false)
        isBusy = false
        return
    end
    AttachEntityToEntity(wepObj, prop.obj, -1, -0.06, 0.0, 0.28, 0.0, 0.0, 90.0, false, false, false, false, 2, true)

    Wait(500)
    startCamOnWeapon(wepObj, Config.distFov or 75.0)
    startPromptThread()

    local comps = GetAvailableComponents(weaponName, wHash)
    currentWeaponData = { weaponName = weaponName, wHash = wHash, serial = serial, propid = propid, comps = comps }
    selectedCache, baselineCache = {}, {}

    RSGCore.Functions.TriggerCallback('rsg-weaponcomp:server:getPlayerWeaponComponents', function(result)
        if currentWeaponData and wepObj then
            applyComponents(wepObj, wHash, comps, result and result.components or {})
            openWeaponUI(weaponName, wHash, serial, comps)
        end
        isBusy = false
    end, serial, weaponName)
end

local function onUseGunsmith(propid)
    local wHash = GetPedCurrentHeldWeapon(cache.ped)
    if wHash == 0 or wHash == UNARMED then
        return lib.notify({ title = locale('cl_notify_13'), description = locale('cl_no_weapon'), type = 'error' })
    end

    local weaponType = GetWeaponType(wHash)
    local serial = exports['rsg-weapons']:weaponInHands()[wHash]
    if not serial then
        if weaponType ~= 'GROUP_BOW' and weaponType ~= 'MELEE_BLADE' then
            return lib.notify({ title = locale('cl_notify_13'), description = locale('cl_no_serial'), type = 'error' })
        end
        serial = tostring(wHash)
    end

    local weaponName = GetWeaponNameFromHash(wHash)
    for _, restricted in ipairs(Config.WeaponRestriction or {}) do
        if joaat(restricted) == wHash then
            return lib.notify({ title = locale('cl_notify_13'), description = locale('cl_weapon_restricted'), type = 'error' })
        end
    end

    startCustomisation(propid, wHash, serial, weaponName)
end

----------------------------------------
-- Save animation
----------------------------------------
local CLEAN_ANIMS = {
    SHORTARM = { dict = 'mech_inspection@weapons@shortarms@volcanic@base', zoom = 0.85, offset = 0.10 },
    LONGARM = { dict = 'mech_inspection@weapons@longarms@sniper_carcano@base', zoom = 1.5, offset = 0.20 },
    SHOTGUN = { dict = 'mech_inspection@weapons@longarms@shotgun_double_barrel@base', zoom = 1.2, offset = 0.15 },
}

local function startCleaningCam(zoom, offset)
    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    local angle = math.rad(GetEntityHeading(ped))
    camera = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',
        coords.x - zoom * math.sin(angle), coords.y + zoom * math.cos(angle), coords.z + offset + 0.5,
        300.0, 0.0, 0.0, 50.0, false, 0)
    PointCamAtCoord(camera, coords.x, coords.y, coords.z + offset)
    SetCamActive(camera, true)
    RenderScriptCams(true, true, 1000, true, false)
end

RegisterNetEvent('rsg-weaponcomp:client:animationSaved', function(wHash)
    local ped = cache.ped
    if HasPedGotWeapon(ped, wHash, false, false) then
        SetCurrentPedWeapon(ped, wHash, true)
    end

    local anim = CLEAN_ANIMS[GetWeaponType(wHash)]
    if anim then
        startCleaningCam(anim.zoom, anim.offset)
        local cloth = CreateObject(`s_balledragcloth01x`, GetEntityCoords(ped), false, true, false, false, true)
        AttachEntityToEntity(cloth, ped, GetEntityBoneIndexByName(ped, 'SKEL_L_Finger00'), 0.02, -0.035, 0.0, 20.0, -24.0, 165.0, true, false, true, false, 0, true)

        lib.progressBar({
            duration = tonumber(Config.animationSave) or 5000,
            useWhileDead = false,
            canCancel = false,
            disable = { move = true, car = true, combat = true, sprint = true },
            anim = { dict = anim.dict, clip = 'clean_loop', flag = 15 },
            label = locale('cl_lang_1'),
        })

        if DoesEntityExist(cloth) then DeleteEntity(cloth) end
        destroyCamera()
    end

    TriggerEvent('rsg-weaponcomp:client:reloadWeapon')
end)

----------------------------------------
-- Workbench props
----------------------------------------
local function despawnProp(propid)
    local prop = SpawnedProps[propid]
    if not prop then return end
    if DoesEntityExist(prop.obj) then
        exports.ox_target:removeLocalEntity(prop.obj)
        DeleteObject(prop.obj)
    end
    if prop.zone then
        prop.zone:remove()
        if Config.showTextZone then lib.hideTextUI() end
        ingunZone = false
    end
    SpawnedProps[propid] = nil
end

local function spawnProp(v)
    local model = toModelHash(v.propmodel)
    if not loadModel(model, 5000) then return end

    local obj = CreateObject(model, v.x, v.y, v.z, false, true, true)
    SetModelAsNoLongerNeeded(model)
    SetEntityHeading(obj, v.h or 0.0)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)

    local zone
    if Config.gunZoneActive then
        zone = lib.zones.sphere({
            coords = vec3(v.x, v.y, v.z),
            radius = Config.gunZoneSize or 3.0,
            onEnter = function()
                ingunZone = true
                if Config.showTextZone then lib.showTextUI(tostring(v.gunsitename or locale('cl_gunsmith'))) end
            end,
            onExit = function()
                ingunZone = false
                if Config.showTextZone then lib.hideTextUI() end
            end
        })
    end

    exports.ox_target:addLocalEntity(obj, {
        {
            name = 'gunsite_prop_' .. v.propid,
            icon = 'far fa-eye',
            label = locale('cl_lang_14'),
            distance = 2.0,
            onSelect = function() onUseGunsmith(v.propid) end,
        },
    })

    SpawnedProps[v.propid] = { obj = obj, zone = zone }
end

CreateThread(function()
    while true do
        local pos = GetEntityCoords(cache.ped)
        local active = {}

        for _, v in ipairs(Config.PlayerProps) do
            active[v.propid] = true
            local near = #(pos - vector3(v.x, v.y, v.z)) < PROP_RENDER_DISTANCE
            if near and not SpawnedProps[v.propid] then
                spawnProp(v)
            elseif not near and SpawnedProps[v.propid] then
                despawnProp(v.propid)
            end
        end

        -- Remove props that were packed up by their owner
        for propid in pairs(SpawnedProps) do
            if not active[propid] then despawnProp(propid) end
        end

        Wait(1000)
    end
end)

RegisterNetEvent('rsg-weaponcomp:client:updatePropData', function(data)
    Config.PlayerProps = data or {}
end)

local function requestProps()
    RSGCore.Functions.TriggerCallback('rsg-weaponcomp:server:getProps', function(props)
        Config.PlayerProps = props or {}
    end)
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', requestProps)
AddEventHandler('onClientResourceStart', function(resource)
    if resource == GetCurrentResourceName() then requestProps() end
end)

local function canPlaceHere(pos)
    for _, p in ipairs(Config.PlayerProps) do
        if #(pos - vector3(p.x, p.y, p.z)) < (Config.gunZoneSize or 3.0) then return false end
    end
    return true
end

RegisterNetEvent('rsg-weaponcomp:client:setupgunzone', function(coords, heading)
    if isBusy then return end
    local ped = cache.ped

    if #(GetEntityCoords(ped) - coords) > (Config.PlaceDistance or 5.0) then
        return lib.notify({ title = locale('cl_lang_15'), description = locale('cl_lang_16'), type = 'error', duration = 5000 })
    end
    if ingunZone or not canPlaceHere(coords) then
        return lib.notify({ title = locale('cl_lang_19'), description = locale('cl_lang_20'), type = 'error', duration = 7000 })
    end

    RSGCore.Functions.TriggerCallback('rsg-weaponcomp:server:countprop', function(count)
        if count >= (Config.MaxGunsites or 5) then
            return lib.notify({ title = locale('cl_lang_17'), description = locale('cl_lang_18'), type = 'error', duration = 7000 })
        end
        if IsPedInAnyVehicle(ped, false) or isBusy then return end

        isBusy = true
        FreezeEntityPosition(ped, true)
        TaskStartScenarioInPlace(ped, `WORLD_HUMAN_STAND_WAITING`, 0, true)
        Wait(10000)
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)
        TriggerServerEvent('rsg-weaponcomp:server:createnewprop', coords, heading)
        isBusy = false
    end)
end)

RegisterNetEvent('rsg-weaponcomp:client:confirmpackup', function(propid)
    local owner
    for _, p in ipairs(Config.PlayerProps) do
        if p.propid == propid then owner = p.citizenid break end
    end
    if owner ~= RSGCore.Functions.GetPlayerData().citizenid then
        return lib.notify({ title = locale('sv_access_denied'), type = 'error' })
    end

    local input = lib.inputDialog(locale('cl_lang_23'), {
        {
            label = locale('cl_lang_24'),
            description = locale('cl_lang_25'),
            type = 'select',
            options = {
                { value = 'yes', label = locale('cl_lang_26') },
                { value = 'no', label = locale('cl_lang_27') }
            },
            required = true
        },
    })
    if not input or input[1] ~= 'yes' then return end

    LocalPlayer.state:set('inv_busy', true, true)
    local done = lib.progressBar({
        duration = 10000,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        label = locale('cl_lang_28'),
    })
    LocalPlayer.state:set('inv_busy', false, true)

    if done then
        TriggerServerEvent('rsg-weaponcomp:server:removegunsiteprops', propid)
    end
end)

----------------------------------------
-- Cleanup
----------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    exitCustomisation()
    clearCameraPrompts()
    for propid in pairs(SpawnedProps) do despawnProp(propid) end
end)
