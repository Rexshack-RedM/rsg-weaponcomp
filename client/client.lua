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
    'ui_no_mods_selected', 'ui_rotate', 'ui_auto_focus', 'ui_on', 'ui_off', 'ui_currency',
    'ui_key_random', 'ui_key_reset', 'ui_notify_title',
}

-- Auto part focus is a per-player preference, remembered between sessions (client KVP)
local FOCUS_KVP = 'rsg-weaponcomp:autoFocus'
local function loadAutoFocus()
    local saved = GetResourceKvpString(FOCUS_KVP)
    if saved == nil then return Config.AutoFocusDefault ~= false end
    return saved == 'true'
end
local autoFocus = loadAutoFocus()

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
--- Hides the player's ped while customising. SetEntityLocallyInvisible doesn't work on
--- your own ped under a scripted camera in RedM, so the ped is made fully invisible.
local function hidePlayerPed(state)
    local ped = cache.ped
    SetEntityVisible(ped, not state)
    if state then
        SetEntityAlpha(ped, 0, false)
    else
        ResetEntityAlpha(ped)
    end
end

local function setPlayerFrozen(state)
    local ped = cache.ped
    if state then
        ClearPedTasksImmediately(ped)
    end
    hidePlayerPed(state)
    LocalPlayer.state:set('inv_busy', state, true) -- blocks inventory/hotbar while customising
    FreezeEntityPosition(ped, state)
    SetEntityInvincible(ped, state)
    SetBlockingOfNonTemporaryEvents(ped, state)
    SetPedCanRagdoll(ped, not state)
end

--- True when a weapon-type (shared) category applies to this weapon (see Config.SharedRequires).
local function sharedCategoryAllowed(cat, weaponName, specific)
    local rule = Config.SharedRequires and Config.SharedRequires[cat]
    if not rule then return true end
    if rule.part and not (specific and specific[rule.part]) then return false end
    if rule.weapon then
        local ok = false
        for _, pattern in ipairs(rule.weapon) do
            if weaponName:find(pattern, 1, true) then ok = true break end
        end
        if not ok then return false end
    end
    return true
end

local function copyList(list)
    local out, seen = {}, {}
    for _, comp in ipairs(list or {}) do
        if not seen[comp] then
            seen[comp] = true
            out[#out + 1] = comp
        end
    end
    return out
end

--- Builds the options for one weapon: its own (Config.Specific) categories first, then the
--- weapon-type (Config.Shared) categories it doesn't already define and that fit it.
--- Returns the component table plus an ordered list of categories ({ cat, specific }).
function GetAvailableComponents(weaponName, wHash)
    local merged, order = {}, {}
    weaponName = (weaponName or ''):upper()
    local specific = Config.Specific and Config.Specific[weaponName]
    local group = GetWeaponType(wHash)
    local shared = group and Config.Shared and Config.Shared[group]

    for cat, list in pairs(specific or {}) do
        if cat ~= 'FRAME_VERTDATA' and #list > 0 then -- FRAME_VERTDATA conflicts with other visuals
            merged[cat] = copyList(list)
            order[#order + 1] = { cat = cat, specific = true }
        end
    end
    for cat, list in pairs(shared or {}) do
        if not merged[cat] and cat ~= 'FRAME_VERTDATA' and #list > 0 and sharedCategoryAllowed(cat, weaponName, specific) then
            merged[cat] = copyList(list)
            order[#order + 1] = { cat = cat, specific = false }
        end
    end
    return merged, order
end

--- Price/changed state versus what the weapon had when the menu opened (mirrors the server).
local function calculatePrice()
    return WeaponComp.ChangePrice(baselineCache, selectedCache)
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
-- Orbit camera: always looks at the centre of the weapon model and circles around it
local orbit = { yaw = 0.0, pitch = 10.0, radius = 0.8, target = nil }

--- Centre of the weapon's bounding box in world space (the entity origin sits at the grip).
local function getWeaponCentre(obj)
    local min, max = GetModelDimensions(GetEntityModel(obj))
    local mid = (min + max) / 2
    return GetOffsetFromEntityInWorldCoords(obj, mid.x, mid.y, mid.z), #(max - min)
end

local function updateOrbitCam()
    if not camera or not orbit.target then return end
    local yaw, pitch = math.rad(orbit.yaw), math.rad(orbit.pitch)
    local t, r = orbit.target, orbit.radius
    SetCamCoord(camera,
        t.x + r * math.cos(pitch) * math.sin(yaw),
        t.y - r * math.cos(pitch) * math.cos(yaw),
        t.z + r * math.sin(pitch))
    PointCamAtCoord(camera, t.x, t.y, t.z)
end

--- Default view: side-on to the weapon, slightly above, framed by its length.
local function resetOrbit(obj)
    local centre, size = getWeaponCentre(obj)
    orbit.target = centre
    orbit.radius = math.max(0.5, size * (Config.distBack or 0.7) + 0.2)
    orbit.pitch = 10.0
    orbit.yaw = GetEntityHeading(obj) + 90.0
end

local function startCamOnWeapon(obj, fov)
    if not (obj and DoesEntityExist(obj)) then return end
    ClearFocus()
    resetOrbit(obj)

    if not camera then
        camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamFov(camera, fov or 60.0)
        updateOrbitCam()
        SetCamActive(camera, true)
        RenderScriptCams(true, true, 1000, true, false)
    else
        SetCamFov(camera, fov or 60.0)
        updateOrbitCam()
    end
end

local function rotateCamera(degrees)
    orbit.yaw = (orbit.yaw + degrees) % 360.0
    updateOrbitCam()
end

--- Point along the weapon's length for a part. 0.0 = rear (stock/grip end),
--- 1.0 = muzzle. The muzzle is the end of the longest axis furthest from the entity origin.
local function getPartPosition(obj, fraction)
    local min, max = GetModelDimensions(GetEntityModel(obj))
    local mid = (min + max) / 2
    local size = max - min
    local axis = 'x'
    if size.y > size[axis] then axis = 'y' end
    if size.z > size[axis] then axis = 'z' end

    local rearV, muzzleV = min[axis], max[axis]
    if math.abs(min[axis]) > math.abs(max[axis]) then rearV, muzzleV = max[axis], min[axis] end

    local offset = { x = mid.x, y = mid.y, z = mid.z }
    offset[axis] = rearV + (muzzleV - rearV) * fraction
    return GetOffsetFromEntityInWorldCoords(obj, offset.x, offset.y, offset.z), #size
end

local focusToken = 0

--- Smoothly moves the orbit target/radius to a new point.
local function animateOrbitTo(target, radius, duration)
    focusToken = focusToken + 1
    local token = focusToken
    local fromT, fromR = orbit.target, orbit.radius
    if not fromT then orbit.target, orbit.radius = target, radius updateOrbitCam() return end

    CreateThread(function()
        local start = GetGameTimer()
        duration = duration or 400
        while token == focusToken and camera do
            local p = math.min(1.0, (GetGameTimer() - start) / duration)
            local e = p * p * (3 - 2 * p) -- smoothstep
            orbit.target = fromT + (target - fromT) * e
            orbit.radius = fromR + (radius - fromR) * e
            updateOrbitCam()
            if p >= 1.0 then break end
            Wait(0)
        end
    end)
end

--- Finds the focus settings for a category (exact name first, then the first matching prefix).
local function getFocusFor(category)
    local focus = Config.PartFocus or {}
    if focus[category] then return focus[category] end
    local best, bestLen
    for key, v in pairs(focus) do
        if category:sub(1, #key) == key and (not bestLen or #key > bestLen) then best, bestLen = v, #key end
    end
    return best
end

--- Moves the camera to the part of the weapon that a category changes.
local function focusOnCategory(category)
    if not autoFocus or not camera or not wepObj or not DoesEntityExist(wepObj) then return end
    local focus = getFocusFor(category)
    if not focus then return end
    local pos, size = getPartPosition(wepObj, focus.at)
    animateOrbitTo(pos, math.max(0.25, size * (focus.zoom or 0.35)), 400)
end

local function setRandomCameraAroundWeapon()
    if not camera or not wepObj then return end
    orbit.yaw = math.random(0, 359) + 0.0
    orbit.pitch = math.random(-10, 45) + 0.0
    updateOrbitCam()
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

local function registerPrompt(control, textKey, hold, control2)
    local p = PromptRegisterBegin()
    PromptSetControlAction(p, control)
    if control2 then PromptSetControlAction(p, control2) end
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
        registerPrompt(controls.rotLeft, 'weapon_cam_rotate', false, controls.rotRight),
        registerPrompt(controls.ranPos, 'weapon_cam_rand'),
        registerPrompt(controls.zoIn, 'zoom_in'),
        registerPrompt(controls.zoOut, 'zoom_out'),
        registerPrompt(controls.re, 'weapon_cam_reset', true),
    }

    local function pressed(control)
        return IsControlJustPressed(2, control) or IsDisabledControlJustPressed(2, control)
    end

    local function held(control)
        return IsDisabledControlPressed(0, control) or IsControlPressed(0, control)
            or IsDisabledControlPressed(2, control) or IsControlPressed(2, control)
    end

    local rotateSpeed = Config.camRotateSpeed or 90.0 -- degrees per second

    CreateThread(function()
        local groupLabel = CreateVarString(10, 'LITERAL_STRING', locale('cl_camera_controls'))
        while promptThreadActive and camera do
            PromptSetActiveGroupThisFrame(promptGroup, groupLabel)
            -- block every player action (move, attack, weapon wheel, horse whistle, emotes...)
            -- and re-enable only the camera prompt keys
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            for _, control in pairs(controls) do EnableControlAction(0, control, true) end

            if pressed(controls.zoIn) then adjustZoom(true) end
            if pressed(controls.zoOut) then adjustZoom(false) end
            if pressed(controls.re) then focusToken = focusToken + 1 startCamOnWeapon(wepObj, Config.distFov or 75.0) end
            if pressed(controls.ranPos) then setRandomCameraAroundWeapon() end

            -- hold left/right to orbit around the weapon
            local step = rotateSpeed * GetFrameTime()
            if held(controls.rotLeft) then rotateCamera(-step) end
            if held(controls.rotRight) then rotateCamera(step) end
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

--- Weapon display name: the item label from rsg-core (already in the server's language).
local function getWeaponLabel(weaponName)
    local item = weaponName and RSGCore.Shared.Items[weaponName:lower()]
    return item and item.label or locale('ui_unknown_weapon')
end

local function openWeaponUI(weaponName, wHash, serial, comps, order)
    -- Weapon-specific categories first, then weapon-type categories, each group in CATEGORY_ORDER
    local cats = {}
    for _, entry in ipairs(order or {}) do cats[#cats + 1] = entry end
    table.sort(cats, function(a, b)
        if a.specific ~= b.specific then return a.specific end
        local oa, ob = CATEGORY_ORDER[a.cat] or 999, CATEGORY_ORDER[b.cat] or 999
        if oa == ob then return a.cat < b.cat end
        return oa < ob
    end)
    for i, entry in ipairs(cats) do cats[i] = entry.cat end

    -- Sent as an ordered array: JSON objects don't keep key order in the UI
    local formatted = {}
    for _, cat in ipairs(cats) do
        local items = {}
        if not WeaponComp.IsFactoryCategory(cat) then
            items[1] = { name = '', hash = 0, label = locale('ui_factory') }
        end
        for _, comp in ipairs(comps[cat]) do
            items[#items + 1] = { name = comp, hash = joaat(comp), label = locale(comp) }
        end
        formatted[#formatted + 1] = { category = cat, label = locale(cat), items = items }
    end

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    SendNUIMessage({
        action = 'open',
        weaponName = getWeaponLabel(weaponName),
        serial = serial or '000000',
        components = formatted,
        prices = Config.price or {},
        savedComponents = selectedCache,
        autoFocus = autoFocus,
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

RegisterNUICallback('setAutoFocus', function(data, cb)
    cb('ok')
    autoFocus = data.enabled == true
    SetResourceKvp(FOCUS_KVP, tostring(autoFocus))
    if not autoFocus and wepObj and DoesEntityExist(wepObj) then
        -- back to the whole-weapon view
        focusToken = focusToken + 1
        startCamOnWeapon(wepObj, Config.distFov or 60.0)
    end
end)

RegisterNUICallback('notify', function(data, cb)
    cb('ok')
    lib.notify({ title = locale('ui_notify_title'), description = tostring(data.message or ''), type = data.type or 'inform' })
end)

local function isValidOption(category, compName)
    local list = currentWeaponData.comps[category]
    if not list then return false end
    if compName == '' then return not WeaponComp.IsFactoryCategory(category) end
    for _, comp in ipairs(list) do
        if comp == compName then return true end
    end
    return false
end

--- Re-applies every finish (tint/material/engraving/wrap) on top of the current parts.
--- Swapping the wood stock/grip model resets its finish, so this keeps the preview honest.
local function reapplyFinishes(wHash)
    for _, cat in ipairs(WeaponComp.SortedKeys(selectedCache)) do
        if WeaponComp.Priority(cat) >= 20 then
            GiveWeaponComponentToEntity(wepObj, joaat(selectedCache[cat]), wHash, true)
        end
    end
end

RegisterNUICallback('componentChanged', function(data, cb)
    cb('ok')
    if not currentWeaponData or not wepObj or not DoesEntityExist(wepObj) then return end

    local category, compName = data.category, data.component
    if type(category) ~= 'string' or type(compName) ~= 'string' or not isValidOption(category, compName) then return end

    local wHash = currentWeaponData.wHash
    local list = currentWeaponData.comps[category]
    local isFactoryPart = WeaponComp.IsFactoryCategory(category) and compName == list[1]
    local previous = selectedCache[category] or (WeaponComp.IsFactoryCategory(category) and list[1])
    if previous then
        RemoveWeaponComponentFromWeaponObject(wepObj, joaat(previous))
    end

    if compName == '' then
        selectedCache[category] = nil -- back to factory finish
    else
        local compHash = joaat(compName)
        loadComponentModel(compHash)
        GiveWeaponComponentToEntity(wepObj, compHash, wHash, true)
        selectedCache[category] = not isFactoryPart and compName or nil
    end

    if WeaponComp.Priority(category) < 20 or compName == '' then
        reapplyFinishes(wHash)
    end

    focusOnCategory(category)

    local price, changed = calculatePrice()
    SendNUIMessage({ action = 'updatePrice', price = price, changed = changed })
end)

RegisterNUICallback('purchase', function(_, cb)
    cb('ok')
    if not currentWeaponData then return end

    local _, changed = calculatePrice()
    if not changed then
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
--- Puts the saved modifications on the display weapon and records them as the baseline.
--- Only real modifications go into the cache; factory parts are shown but never stored,
--- otherwise every purchase would also save the first tint/engraving/material of every list.
local function applyComponents(obj, wHash, comps, savedComps)
    local display = {}
    for cat, options in pairs(comps) do
        local saved = savedComps[cat]
        for _, valid in ipairs(options) do
            if saved and valid == saved then
                selectedCache[cat] = saved
                display[cat] = saved
                break
            end
        end
        if not display[cat] and WeaponComp.IsFactoryCategory(cat) then
            display[cat] = options[1]
        end
    end

    for _, cat in ipairs(WeaponComp.SortedKeys(display)) do
        local compHash = joaat(display[cat])
        loadComponentModel(compHash)
        GiveWeaponComponentToEntity(obj, compHash, wHash, true)
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

    local comps, order = GetAvailableComponents(weaponName, wHash)
    currentWeaponData = { weaponName = weaponName, wHash = wHash, serial = serial, propid = propid, comps = comps }
    selectedCache, baselineCache = {}, {}

    RSGCore.Functions.TriggerCallback('rsg-weaponcomp:server:getPlayerWeaponComponents', function(result)
        if currentWeaponData and wepObj then
            applyComponents(wepObj, wHash, comps, result and result.components or {})
            openWeaponUI(weaponName, wHash, serial, comps, order)
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

    TriggerEvent('rsg-weaponcomp:client:reloadWeapon', true)
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
        TaskStartScenarioInPlace(ped, `WORLD_HUMAN_STAND_WAITING`, 0, true)
        local done = lib.progressBar({
            duration = Config.SetupTime or 10000,
            label = locale('cl_setting_up'),
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true, combat = true, mouse = false },
        })
        ClearPedTasks(ped)
        if done then
            TriggerServerEvent('rsg-weaponcomp:server:createnewprop', coords, heading)
        end
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
