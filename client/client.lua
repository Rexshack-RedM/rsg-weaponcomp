local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- State variables (all at top level)
local SpawnedProps = {}
local PackingUpProps = {}
local gunZones = {}
local ingunZone = false
local isBusy = false
local wepObj = nil
local camera = nil
local selectedCache = {}
local selectedLabels = {}
local currentWeaponData = nil  -- Make sure this is at top level

-- Category display order for the menu (related parts grouped together)
local CATEGORY_ORDER = {
    ['BARREL'] = 1,
    ['BARREL_TINT'] = 2,
    ['BARREL_MATERIAL'] = 3,
    ['BARREL_ENGRAVING'] = 4,
    ['BARREL_ENGRAVING_MATERIAL'] = 5,
    ['BARREL_RIFLING'] = 6,
    ['TUBE'] = 10,
    ['MAG'] = 11,
    ['MAGAZINE'] = 12,
    ['CLIP'] = 13,
    ['STOCK'] = 14,
    ['CYLINDER_MATERIAL'] = 20,
    ['CYLINDER_TINT'] = 21,
    ['CYLINDER_ENGRAVING'] = 22,
    ['CYLINDER_ENGRAVING_MATERIAL'] = 23,
    ['FRAME_MATERIAL'] = 30,
    ['FRAME_ENGRAVING'] = 31,
    ['FRAME_ENGRAVING_MATERIAL'] = 32,
    ['HAMMER_MATERIAL'] = 35,
    ['TRIGGER_MATERIAL'] = 40,
    ['TRIGGER_TINT'] = 41,
    ['GRIP'] = 50,
    ['GRIP_TINT'] = 51,
    ['GRIP_MATERIAL'] = 52,
    ['GRIPSTOCK_ENGRAVING'] = 60,
    ['GRIPSTOCK_TINT'] = 61,
    ['SIGHT'] = 70,
    ['SIGHT_MATERIAL'] = 71,
    ['SCOPE'] = 80,
    ['SCOPE_TINT'] = 81,
    ['WRAP'] = 90,
    ['WRAP_TINT'] = 91,
    ['WRAP_MATERIAL'] = 92,
    ['STRAP'] = 100,
    ['STRAP_TINT'] = 101,
    ['MELEE_BLADE_MATERIAL'] = 110,
    ['MELEE_BLADE_ENGRAVING'] = 111,
    ['MELEE_BLADE_ENGRAVING_MATERIAL'] = 112,
    ['TORCH_MATCHSTICK'] = 1000,
}
local promptThreadActive = false
local promptGroup = GetRandomIntInRange(0, 0xffffff)

local c_zoom = 1.5
local c_offset = 0.20

-- Prompt controls
local randomPos = nil
local zoomIn = nil
local zoomOut = nil
local resetCam = nil

----------------------------------------
-- Utility Functions
----------------------------------------
local function FreezePlayer()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
end

local function UnfreezePlayer()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetPedCanRagdoll(ped, true)
end

local WeaponTypeMap = {
    [GetHashKey('GROUP_REPEATER')] = "LONGARM",
    [GetHashKey('GROUP_SHOTGUN')] = "SHOTGUN",
    [GetHashKey('GROUP_PISTOL')] = "SHORTARM",
    [GetHashKey('GROUP_REVOLVER')] = "SHORTARM",
    [GetHashKey('GROUP_RIFLE')] = "LONGARM",
    [GetHashKey('GROUP_SNIPER')] = "LONGARM",
    [GetHashKey('GROUP_MELEE')] = "MELEE_BLADE",
    [GetHashKey('GROUP_BOW')] = "GROUP_BOW",
}

function GetWeaponType(hash)
    return WeaponTypeMap[GetWeapontypeGroup(hash)]
end

local function mergeComponents(merged, source)
    for cat, list in pairs(source) do
        merged[cat] = merged[cat] or {}
        for _, comp in ipairs(list) do
            merged[cat][#merged[cat]+1] = comp
        end
    end
end

local function GetAvailableComponents(weaponName, wHash)
    local specific = Config.Specific and Config.Specific[weaponName] or {}
    local merged = {}
    local group = GetWeaponType(wHash)

    if group and Config.Shared and Config.Shared[group] then
        mergeComponents(merged, Config.Shared[group])
    end

    mergeComponents(merged, specific)
    return merged
end

local function CalculatePrice(selection)
    local total = 0
    if not selection then return 0 end
    for cat, _ in pairs(selection) do
        total = total + (Config.price and Config.price[cat] or 0)
    end
    return total
end

local function CanPlacePropHere(pos)
    if not Config.PlayerProps then return true end
    for _, p in ipairs(Config.PlayerProps) do
        if #(pos - vector3(p.x, p.y, p.z)) < 1.3 then return false end
    end
    return true
end

----------------------------------------
-- Weapon Object Management
----------------------------------------
local function spawnWeaponOnProp(propObj, spawnPos, wHash)
    if wepObj ~= nil and DoesEntityExist(wepObj) then
        DeleteObject(wepObj)
        wepObj = nil
    end
    
    wepObj = Citizen.InvokeNative(0x9888652B8BA77F73, wHash, 0, spawnPos.x, spawnPos.y, spawnPos.z, false, 1.0)
    
    if wepObj and DoesEntityExist(wepObj) then
        AttachEntityToEntity(wepObj, propObj, -1, -0.06, 0.0, 0.28, 0.0, 0.0, 90.0, false, false, false, false, 2, true)
        FreezeEntityPosition(wepObj, true)
    end
end

----------------------------------------
-- Camera System
----------------------------------------
local function StartCamOnWeapon(obj, fov)
    if not (obj and DoesEntityExist(obj)) then return end
    ClearFocus()
    local forward, right, up, origin = table.unpack({ GetEntityMatrix(obj) })

    local distBack = Config.distBack or 0.8
    local distSide = Config.distSide or 0.3
    local distUp = Config.distUp or 0.2

    local camPos = vector3(
        origin.x - forward.x * distBack + right.x * distSide + up.x * distUp,
        origin.y - forward.y * distBack + right.y * distSide + up.y * distUp,
        origin.z - forward.z * distBack + right.z * distSide + up.z * distUp
    )

    if camera then DestroyCam(camera, true) end
    camera = CreateCamWithParams(
        "DEFAULT_SCRIPTED_CAMERA",
        camPos.x, camPos.y, camPos.z,
        0, 0, 0,
        fov or 75.0,
        false, 0
    )

    SetCamActive(camera, true)
    RenderScriptCams(true, true, 1000, true, false)
    PointCamAtCoord(camera, origin.x, origin.y, origin.z + 0.1)
end

local function SetRandomCameraAroundWeapon()
    if not camera or not wepObj then return end

    local wepCoords = GetEntityCoords(wepObj)
    local radius = 0.50

    local angleDeg = math.random(1, 360)
    local pitchDeg = math.random(-10, 50)

    local angleRad = math.rad(angleDeg)
    local pitchRad = math.rad(pitchDeg)

    local xOffset = radius * math.cos(angleRad) * math.cos(pitchRad)
    local yOffset = radius * math.sin(angleRad) * math.cos(pitchRad)
    local zOffset = radius * math.sin(pitchRad)

    local camX = wepCoords.x + xOffset
    local camY = wepCoords.y + yOffset
    local camZ = wepCoords.z + zOffset

    SetCamCoord(camera, camX, camY, camZ)
    PointCamAtCoord(camera, wepCoords.x, wepCoords.y, wepCoords.z)
end

local function smoothZoom(cam, fromFov, toFov, duration)
    local startTime = GetGameTimer()
    while true do
        local now = GetGameTimer()
        local elapsed = now - startTime
        if elapsed >= duration then break end

        local progress = elapsed / duration
        local currentFov = fromFov + (toFov - fromFov) * progress
        SetCamFov(cam, currentFov)
        Wait(0)
    end
    SetCamFov(cam, toFov)
end

local function AdjustZoom(increase)
    if not camera or not wepObj then return end
    local currentFov = GetCamFov(camera)
    local targetFov = increase and (currentFov - 5.0) or (currentFov + 5.0)
    targetFov = math.max(15.0, math.min(90.0, targetFov))

    CreateThread(function()
        smoothZoom(camera, currentFov, targetFov, 150)
    end)
end

local function ResetCameraToDefault()
    if not camera or not wepObj then return end
    StartCamOnWeapon(wepObj, Config.distFov or 75.0)
end

----------------------------------------
-- NUI Functions
----------------------------------------
local function CloseWeaponUI()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
end

local function OpenWeaponUI(weaponName, wHash, serial, propid, savedComps)
    local comps = GetAvailableComponents(weaponName, wHash)
    
    -- Collect and sort categories by display order, filtering out FRAME_VERTDATA
    local cats = {}
    for cat, _ in pairs(comps) do
        if cat ~= 'FRAME_VERTDATA' then
            cats[#cats+1] = cat
        end
    end
    table.sort(cats, function(a, b)
        local oa = CATEGORY_ORDER[a] or 999
        local ob = CATEGORY_ORDER[b] or 999
        if oa == ob then return a < b end
        return oa < ob
    end)
    
    -- Format components for UI in the sorted order
    local formattedComps = {}
    for _, cat in ipairs(cats) do
        local list = comps[cat]
        formattedComps[cat] = {}
        for i, comp in ipairs(list) do
            formattedComps[cat][i] = {
                name = comp,
                hash = GetHashKey(comp),
                label = locale(comp) or comp
            }
        end
    end
    
    -- Strip FRAME_VERTDATA from saved components
    local cleanSaved = {}
    if savedComps then
        for k, v in pairs(savedComps) do
            if k ~= 'FRAME_VERTDATA' then
                cleanSaved[k] = v
            end
        end
    end
    
    -- Set current weapon data BEFORE opening UI (already set in startcustom, but ensure it's there)
    currentWeaponData = {
        weaponName = weaponName,
        wHash = wHash,
        serial = serial,
        propid = propid
    }
    
    -- If we have saved components, use them for UI selections
    -- If not, reset selections
    if next(cleanSaved) then
        -- selectedCache is already populated by applyComponents
    else
        selectedCache = {}
        selectedLabels = {}
    end
    
    -- Enable NUI focus but keep game input working for camera controls
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    
    -- Send saved components to UI for proper slider positions
    SendNUIMessage({
        action = 'open',
        weaponName = locale(weaponName) or weaponName,
        serial = serial or '000000',
        components = formattedComps,
        prices = Config.price or {},
        savedComponents = cleanSaved or {}
    })
end

----------------------------------------
-- NUI Callbacks
----------------------------------------
RegisterNUICallback('closeUI', function(data, cb)
    cb('ok')
    TriggerEvent('rsg-weaponcomp:client:ExitCam')
end)

RegisterNUICallback('notify', function(data, cb)
    lib.notify({ title = 'Weapon Comp', description = data.message or '', type = data.type or 'info' })
    cb('ok')
end)

RegisterNUICallback('componentChanged', function(data, cb)
    cb('ok')
    
    if not wepObj or not DoesEntityExist(wepObj) then 
       
        return 
    end
    
    if not currentWeaponData then
        
        return
    end
    
    local wHash = currentWeaponData.wHash
    local compHash = data.hash
    local category = data.category
    local compName = data.component
    
    if not compHash or compHash == 0 then
       
        return
    end
    
    -- Get previous component
    local prevComp = nil
    if selectedCache[category] then
        prevComp = GetHashKey(selectedCache[category])
    end
    
    -- Load model if needed
    local mdl = GetWeaponComponentTypeModel(compHash)
    if mdl and mdl ~= 0 then
        RequestModel(mdl)
        local timeout = 0
        while not HasModelLoaded(mdl) and timeout < 50 do 
            Wait(50) 
            timeout = timeout + 1
        end
    end
    
    -- Remove old component
    if prevComp then 
        RemoveWeaponComponentFromWeaponObject(wepObj, prevComp) 
    end
    
    -- Add new component
    GiveWeaponComponentToEntity(wepObj, compHash, wHash, true)
    
    -- Re-apply GRIPSTOCK components (they get cleared when other components are changed on the same weapon part)
    if category ~= 'GRIPSTOCK_ENGRAVING' and selectedCache['GRIPSTOCK_ENGRAVING'] then
        GiveWeaponComponentToEntity(wepObj, GetHashKey(selectedCache['GRIPSTOCK_ENGRAVING']), wHash, true)
    end
    if category ~= 'GRIPSTOCK_TINT' and selectedCache['GRIPSTOCK_TINT'] then
        GiveWeaponComponentToEntity(wepObj, GetHashKey(selectedCache['GRIPSTOCK_TINT']), wHash, true)
    end
    
    -- Store selection
    selectedCache[category] = compName
    selectedLabels[category] = locale(compName) or compName
    
    -- Update price
    local price = CalculatePrice(selectedCache)
    SendNUIMessage({
        action = 'updatePrice',
        price = price
    })
    
   
end)

RegisterNUICallback('purchase', function(data, cb)
    cb('ok')
    
    if not currentWeaponData then
        lib.notify({ title = 'Weapon Comp', description = 'No weapon selected!', type = 'error' })
        return
    end
    
    local price = CalculatePrice(selectedCache)
    
    if price <= 0 or not next(selectedCache) then
        lib.notify({ title = 'Weapon Comp', description = locale('cl_notify_10') or 'No modifications selected!', type = 'error' })
        return
    end
    
    -- Store data before clearing
    local weaponHash = currentWeaponData.wHash
    local serial = currentWeaponData.serial
    local weaponName = currentWeaponData.weaponName
    local cacheToSend = {}
    local labelsToSend = {}
    
    for k, v in pairs(selectedCache) do
        cacheToSend[k] = v
    end
    for k, v in pairs(selectedLabels) do
        labelsToSend[k] = v
    end
    
   
    
    TriggerEvent('rsg-weaponcomp:client:ExitCam')
    
    TriggerServerEvent('rsg-weaponcomp:server:price',
        price, weaponHash, serial,
        cacheToSend, labelsToSend, weaponHash, weaponName
    )
    
    lib.notify({ title = 'Weapon Comp', description = (locale('cl_notify_9') or 'Purchased!') .. ' $' .. price, type = 'success' })
end)

RegisterNUICallback('resetWeapon', function(data, cb)
    cb('ok')
    
    if not currentWeaponData then
        lib.notify({ title = 'Weapon Comp', description = 'No weapon selected!', type = 'error' })
        return
    end
    
    local serial = currentWeaponData.serial
    local wHash = currentWeaponData.wHash
    
    if not serial or (type(serial) == 'string' and tonumber(serial) and tonumber(serial) < 100000) then
        lib.notify({ title = 'Weapon Comp', description = locale('cl_notify_12') or 'Cannot reset this weapon!', type = 'error' })
        return
    end
    
    RSGCore.Functions.TriggerCallback('rsg-weaponcomp:server:getItemBySerial', function(comp)
        if not comp then
            TriggerEvent('rsg-weaponcomp:client:ExitCam')
            return
        end
        
        local totalComps = comp.components or {}
        local price = CalculatePrice(totalComps) * (Config.RemovePrice or 0.5)
        
        if price > 0 then
            TriggerEvent('rsg-weaponcomp:client:ExitCam')
            TriggerServerEvent('rsg-weaponcomp:server:price',
                price, wHash, serial, nil, nil, wHash
            )
            lib.notify({ title = 'Weapon Comp', description = (locale('cl_notify_11') or 'Reset!') .. ' $' .. price, type = 'success' })
        else
            lib.notify({ title = 'Weapon Comp', description = locale('cl_notify_12') or 'No modifications to remove!', type = 'error' })
        end
    end, serial)
end)

RegisterNUICallback('packup', function(data, cb)
    cb('ok')
    
    if not currentWeaponData then
      
        return
    end
    
    local propid = currentWeaponData.propid
    
    TriggerEvent('rsg-weaponcomp:client:ExitCam')
    TriggerEvent('rsg-weaponcomp:client:confirmpackup', propid)
end)

----------------------------------------
-- Exit Camera Event
----------------------------------------
RegisterNetEvent('rsg-weaponcomp:client:ExitCam')
AddEventHandler('rsg-weaponcomp:client:ExitCam', function()
    ClearFocus()
    RenderScriptCams(false, false, 0, true, false)
    if camera then DestroyCam(camera, true) end
    camera = nil
    DestroyAllCams(true)

    if wepObj ~= nil and DoesEntityExist(wepObj) then
        SetEntityAsMissionEntity(wepObj, true, true)
        FreezeEntityPosition(wepObj, false)
        SetEntityVelocity(wepObj, 0, 0, 0)
        DeleteObject(wepObj)
        wepObj = nil
    end
    
    ClearCameraPrompts()
    promptThreadActive = false
    CloseWeaponUI()
    TriggerEvent('HideAllUI')
    UnfreezePlayer()
    
    -- Clear state
    selectedCache = {}
    selectedLabels = {}
    currentWeaponData = nil
    
   
end)

----------------------------------------
-- Prompts
----------------------------------------
function ClearCameraPrompts()
    randomPos = nil
    zoomIn = nil
    zoomOut = nil
    resetCam = nil
end

local function RegisterPrompt(control, textKey, group, hold)
    local txt = locale(textKey) or textKey
    local p = PromptRegisterBegin()
    PromptSetControlAction(p, control)
    PromptSetText(p, CreateVarString(10, 'LITERAL_STRING', txt))
    PromptSetEnabled(p, true)
    PromptSetVisible(p, true)
    if hold then 
        PromptSetHoldMode(p, true) 
    else 
        PromptSetStandardMode(p, true) 
    end
    PromptSetGroup(p, group)
    Citizen.InvokeNative(0xC5F428EE08FA7F2C, p, true)
    PromptRegisterEnd(p)
    return p
end

local function RegisterCameraPrompts()
    if Config.prompts then
        randomPos = RegisterPrompt(Config.prompts.ranPos, 'weapon_cam_rand', promptGroup, false)
        zoomIn = RegisterPrompt(Config.prompts.zoIn, 'zoom', promptGroup, false)
        zoomOut = RegisterPrompt(Config.prompts.zoOut, 'zoom', promptGroup, false)
        resetCam = RegisterPrompt(Config.prompts.re, 'weapon_cam_reset', promptGroup, true)
    end
end

local function StartPromptThread()
    if promptThreadActive then return end
    promptThreadActive = true
    CreateThread(function()
        RegisterCameraPrompts()
        while promptThreadActive do
            local sleep = 1000
            if camera and Config.prompts then
                local promptText = CreateVarString(10, 'LITERAL_STRING', 'Camera Controls')
                PromptSetActiveGroupThisFrame(promptGroup, promptText)
                
                sleep = 0
                
                
                DisableControlAction(0, 0xCEFD9220, true) -- INPUT_CURSOR_ACCEPT
                DisableControlAction(0, 0x156F7119, true) -- INPUT_CURSOR_CANCEL
                
                
                local zoomInPressed = IsControlJustPressed(2, Config.prompts.zoIn) or IsDisabledControlJustPressed(2, Config.prompts.zoIn)
                local zoomOutPressed = IsControlJustPressed(2, Config.prompts.zoOut) or IsDisabledControlJustPressed(2, Config.prompts.zoOut)
                local resetPressed = IsControlJustPressed(2, Config.prompts.re) or IsDisabledControlJustPressed(2, Config.prompts.re)
                local randomPressed = IsControlJustPressed(2, Config.prompts.ranPos) or IsDisabledControlJustPressed(2, Config.prompts.ranPos)
                
                if zoomInPressed then AdjustZoom(true) end
                if zoomOutPressed then AdjustZoom(false) end
                if resetPressed then ResetCameraToDefault() end
                if randomPressed then SetRandomCameraAroundWeapon() end
            end
            Wait(sleep)
        end
    end)
end

-- Apply components (saved or defaults)
local function applyComponents(obj, wHash, savedComps)
    local name = Citizen.InvokeNative(0x89CF5FF3D363311E, wHash, Citizen.ResultAsString())
    local availableComps = GetAvailableComponents(name, wHash)
    
    for cat, options in pairs(availableComps) do
        if options and #options > 0 then
            -- Skip FRAME_VERTDATA (removed from menu, conflicts with other component visuals)
            if cat == 'FRAME_VERTDATA' then
                goto continue
            end
            
            local compToApply = nil
            
            -- Check if we have a saved component for this category
            if savedComps and savedComps[cat] and savedComps[cat] ~= "" then
                local savedComp = savedComps[cat]
                for _, validComp in ipairs(options) do
                    if validComp == savedComp then
                        compToApply = savedComp
                        break
                    end
                end
            end
            
            if not compToApply then
                compToApply = options[1]
            end
            
            if compToApply then
                local compHash = GetHashKey(compToApply)
                local mdl = GetWeaponComponentTypeModel(compHash)
                if mdl and mdl ~= 0 then
                    RequestModel(mdl)
                    local timeout = 0
                    while not HasModelLoaded(mdl) and timeout < 50 do 
                        Wait(50) 
                        timeout = timeout + 1
                    end
                end
                GiveWeaponComponentToEntity(obj, compHash, wHash, true)
                ApplyShopItemToPed(PlayerPedId(), compHash, true, true, true)
                selectedCache[cat] = compToApply
            end
            ::continue::
        end
    end
end

----------------------------------------
-- Start Customization Event
----------------------------------------
RegisterNetEvent('rsg-weaponcomp:client:startcustom', function(propid, wHash, serial, weaponName)
    if isBusy then 
        return 
    end
    isBusy = true

    local propData = SpawnedProps[propid]
    if not propData then 
        isBusy = false
        return 
    end
    
    local propObj = propData.obj
    if not propObj or not DoesEntityExist(propObj) then
        isBusy = false
        return
    end
    
    local coords = GetEntityCoords(propObj)
    spawnWeaponOnProp(propObj, coords, wHash)
    
    local ped = PlayerPedId()
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    FreezePlayer()
    
    Wait(500)
    StartCamOnWeapon(wepObj, Config.distFov or 75.0)
    StartPromptThread()

    currentWeaponData = {
        weaponName = weaponName,
        wHash = wHash,
        serial = serial,
        propid = propid
    }
    
    selectedCache = {}
    selectedLabels = {}
    
    RSGCore.Functions.TriggerCallback('rsg-weaponcomp:server:getPlayerWeaponComponents', function(result)
        local savedComps = result and result.components or {}
        
        -- Strip FRAME_VERTDATA from saved data (removed from menu, conflicts with other visuals)
        savedComps['FRAME_VERTDATA'] = nil
        
        applyComponents(wepObj, wHash, savedComps)
        OpenWeaponUI(weaponName, wHash, serial, propid, savedComps)
        
        isBusy = false
    end, serial)
end)


local function StartCamClean(zoom, offset)
    ClearFocus()
    local ped = PlayerPedId()
    local zoomOffset = tonumber(zoom)
    local coords = GetEntityCoords(ped)
    local playerHeading = GetEntityHeading(ped)
    local angle = playerHeading * math.pi / 180.0

    local pos = {
        x = coords.x - (zoomOffset * math.sin(angle)),
        y = coords.y + (zoomOffset * math.cos(angle)),
        z = coords.z + offset
    }

    camera = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", pos.x, pos.y, pos.z + 0.5, 300.00, 0.00, 0.00, 50.00, false, 0)
    local pCoords = GetEntityCoords(ped)
    PointCamAtCoord(camera, pCoords.x, pCoords.y, pCoords.z + offset)

    SetCamActive(camera, true)
    RenderScriptCams(true, true, 1000, true, false)
end

RegisterNetEvent("rsg-weaponcomp:client:animationSaved")
AddEventHandler("rsg-weaponcomp:client:animationSaved", function(objecthash, serial)
    local ped = PlayerPedId()
    SetCurrentPedWeapon(ped, objecthash, true)

    if camera then DestroyCam(camera, true) end
    camera = nil

    if wepObj ~= nil and DoesEntityExist(wepObj) then
        SetEntityAsMissionEntity(wepObj, false)
        FreezeEntityPosition(wepObj, false)
        DeleteObject(wepObj)
        wepObj = nil
    end

    local weapon_type = GetWeaponType(objecthash)
    local boneIndex2 = GetEntityBoneIndexByName(ped, "SKEL_L_Finger00")
    local Cloth = CreateObject(GetHashKey('s_balledragcloth01x'), GetEntityCoords(ped), false, true, false, false, true)
    local animDict = nil
    local animName = nil

    if weapon_type == 'SHORTARM' then
        animDict = "mech_inspection@weapons@shortarms@volcanic@base"
        animName = "clean_loop"
        c_zoom = 0.85
        c_offset = 0.10
    elseif weapon_type == 'LONGARM' then
        animDict = "mech_inspection@weapons@longarms@sniper_carcano@base"
        animName = "clean_loop"
        c_zoom = 1.5
        c_offset = 0.20
    elseif weapon_type == 'SHOTGUN' then
        animDict = "mech_inspection@weapons@longarms@shotgun_double_barrel@base"
        animName = "clean_loop"
        c_zoom = 1.2
        c_offset = 0.15
    elseif weapon_type == 'GROUP_BOW' then
        c_zoom = 1.5
        c_offset = 0.15
    elseif weapon_type == 'MELEE_BLADE' then
        c_zoom = 1.2
        c_offset = 0.15
    end

    StartCamClean(c_zoom, c_offset)
    Wait(100)

    if animDict ~= nil and animName ~= nil then
        AttachEntityToEntity(Cloth, ped, boneIndex2, 0.02, -0.035, 0.00, 20.0, -24.0, 165.0, true, false, true, false, 0, true)

        lib.progressBar({
            duration = tonumber(Config.animationSave) or 5000,
            useWhileDead = false,
            canCancel = false,
            disable = { move = true, car = true, combat = true, mouse = false, sprint = true },
            anim = { dict = animDict, clip = animName, flag = 15 },
            label = locale('cl_lang_1') or 'Applying modifications...',
        })

        if Cloth ~= nil and DoesEntityExist(Cloth) then
            SetEntityAsNoLongerNeeded(Cloth)
            DeleteEntity(Cloth)
        end
    end

    TriggerServerEvent("rsg-weaponcomp:server:check_comps")
    TriggerEvent('rsg-weaponcomp:client:ExitCam')
end)

----------------------------------------
-- Prop Spawning & Zone Management
----------------------------------------
CreateThread(function()
    Wait(2000) -- Wait for config to load
    
    while true do
        Wait(150)
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local inRange = false
        
        if not Config.PlayerProps or #Config.PlayerProps == 0 then 
            Wait(5000)
            goto continue 
        end
        
        for k, v in ipairs(Config.PlayerProps) do
            local propPos = vector3(v.x, v.y, v.z)
            local dist = #(pos - propPos)
            
            if dist < 50.0 then
                inRange = true
                
                if not SpawnedProps[v.propid] and not PackingUpProps[v.propid] then
                    local m = joaat(v.propmodel)
                    RequestModel(m)
                    local timeout = 0
                    while not HasModelLoaded(m) and timeout < 100 do 
                        Wait(10) 
                        timeout = timeout + 1
                    end
                    
                    if HasModelLoaded(m) then
                        local obj = CreateObject(m, v.x, v.y, v.z, false, true, true)
                        SetEntityHeading(obj, v.h or 0.0)
                        FreezeEntityPosition(obj, true)
                        PlaceObjectOnGroundProperly(obj)
                        
                        if Config.gunZoneActive then
                            gunZones[v.propid] = lib.zones.sphere({
                                coords = vec3(v.x, v.y, v.z),
                                radius = Config.gunZoneSize or 3.0,
                                debug = false,
                                onEnter = function()
                                    ingunZone = true
                                    if v.item == Config.Gunsmithitem and Config.showTextZone then
                                        lib.showTextUI(tostring(v.gunsitename or 'Gunsmith'))
                                    end
                                end,
                                onExit = function()
                                    ingunZone = false
                                    if Config.showTextZone then
                                        lib.hideTextUI()
                                    end
                                end
                            })
                        end

                        exports.ox_target:addLocalEntity(obj, {
                            {
                                name = 'gunsite_prop_' .. v.propid,
                                icon = 'far fa-eye',
                                label = locale('cl_lang_14') or 'Use Gunsmith',
                                onSelect = function()
                                    local wHash = GetPedCurrentHeldWeapon(PlayerPedId())
                                    local serial = exports['rsg-weapons']:weaponInHands()[wHash]
                                    local weaponName = Citizen.InvokeNative(0x89CF5FF3D363311E, wHash, Citizen.ResultAsString())
                                    local weaponType = GetWeaponType(wHash)
                                    
                                    if wHash == -1569615261 or wHash == GetHashKey('WEAPON_UNARMED') then
                                        return lib.notify({ 
                                            title = locale('cl_notify_13') or 'Error', 
                                            description = locale('cl_no_weapon') or 'No weapon equipped', 
                                            type = 'error' 
                                        })
                                    end
                                    if not serial and weaponType ~= 'GROUP_BOW' and weaponType ~= 'MELEE_BLADE' then
                                        return lib.notify({ 
                                            title = locale('cl_notify_13') or 'Error', 
                                            description = locale('cl_notify_14') or 'Weapon has no serial', 
                                            type = 'error' 
                                        })
                                    end
                                    if not serial and (weaponType == 'GROUP_BOW' or weaponType == 'MELEE_BLADE') then
                                        serial = tostring(wHash)
                                    end
                                    TriggerEvent('rsg-weaponcomp:client:startcustom', v.propid, wHash, serial, weaponName)
                                end,
                                distance = 2.0
                            },
                        })

                        SpawnedProps[v.propid] = { obj = obj }
                        
                    end
                end
            end
        end

        ::continue::
        if not inRange then Wait(5000) end
    end
end)

----------------------------------------
-- Event Handlers
----------------------------------------
RegisterNetEvent('rsg-weaponcomp:client:updatePropData')
AddEventHandler('rsg-weaponcomp:client:updatePropData', function(data)
    Config.PlayerProps = data or {}
end)

RegisterNetEvent('rsg-weaponcomp:client:setupgunzone')
AddEventHandler('rsg-weaponcomp:client:setupgunzone', function(propmodel, item, coords, heading)
    RSGCore.Functions.TriggerCallback('rsg-weaponcomp:server:countprop', function(result)
        local ped = PlayerPedId()
        local playercoords = GetEntityCoords(ped)
        if #(playercoords - coords) > (Config.PlaceDistance or 5.0) then
            lib.notify({ 
                title = locale('cl_lang_15') or 'Error', 
                description = locale('cl_lang_16') or 'Too far away', 
                type = 'error', 
                duration = 5000 
            })
            return
        end
        if result >= (Config.MaxGunsites or 5) then
            lib.notify({ 
                title = locale('cl_lang_17') or 'Error', 
                description = locale('cl_lang_18') or 'Max gunsites reached', 
                type = 'error', 
                duration = 7000 
            })
            return
        end
        if ingunZone then
            lib.notify({ 
                title = locale('cl_lang_19') or 'Error', 
                description = locale('cl_lang_20') or 'Already in gunsite zone', 
                type = 'error', 
                duration = 7000 
            })
            return
        end
        if not CanPlacePropHere(coords) then
            lib.notify({ 
                title = locale('cl_lang_21') or 'Error', 
                description = locale('cl_lang_22') or 'Cannot place here', 
                type = 'error', 
                duration = 7000 
            })
            return
        end
        if not IsPedInAnyVehicle(ped, false) and not isBusy then
            isBusy = true
            local anim1 = `WORLD_HUMAN_STAND_WAITING`
            FreezeEntityPosition(ped, true)
            TaskStartScenarioInPlace(ped, anim1, 0, true)
            Wait(10000)
            ClearPedTasks(ped)
            FreezeEntityPosition(ped, false)
            TriggerServerEvent('rsg-weaponcomp:server:createnewprop', propmodel, item, coords, heading)
            isBusy = false
        end
    end, item)
end)

RegisterNetEvent('rsg-weaponcomp:client:confirmpackup', function(propid)
    local input = lib.inputDialog(locale('cl_lang_23') or 'Pack Up', {
        {
            label = locale('cl_lang_24') or 'Confirm',
            description = locale('cl_lang_25') or 'Are you sure?',
            type = 'select',
            options = {
                { value = 'yes', label = locale('cl_lang_26') or 'Yes' },
                { value = 'no', label = locale('cl_lang_27') or 'No' }
            },
            required = true
        },
    })
    if not input or input[1] == 'no' then return end

    LocalPlayer.state:set('inv_busy', true, true)
    lib.progressBar({
        duration = 10000,
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disableControl = true,
        disable = {
            move = true,
            mouse = false,
        },
        label = locale('cl_lang_28') or 'Packing up...',
    })

    LocalPlayer.state:set('inv_busy', false, true)
    TriggerEvent('rsg-weaponcomp:client:packupgunsite', propid)
end)

RegisterNetEvent('rsg-weaponcomp:client:packupgunsite', function(propid)
    TriggerServerEvent('rsg-weaponcomp:server:removegunsiteprops', propid)

    PackingUpProps[propid] = true
    local propData = SpawnedProps[propid]
    if propData and propData.obj and DoesEntityExist(propData.obj) then
        exports.ox_target:removeLocalEntity(propData.obj)
        SetEntityAsMissionEntity(propData.obj, true, true)
        DeleteObject(propData.obj)
        Wait(100)
    end
    SpawnedProps[propid] = nil
    
    if Config.gunZoneActive and gunZones[propid] then
        gunZones[propid]:remove()
        gunZones[propid] = nil
        if Config.showTextZone then
            lib.hideTextUI()
        end
        ingunZone = false
    end
    
    PackingUpProps[propid] = false
    TriggerServerEvent('rsg-weaponcomp:server:additem', Config.Gunsmithitem, 1)
end)

----------------------------------------
-- Cleanup
----------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    DestroyAllCams(true)
    if camera then DestroyCam(camera, true) end
    CloseWeaponUI()

    if wepObj ~= nil and DoesEntityExist(wepObj) then
        SetEntityAsMissionEntity(wepObj, false)
        FreezeEntityPosition(wepObj, false)
        DeleteObject(wepObj)
    end

    for k, v in pairs(SpawnedProps) do
        if v.obj and DoesEntityExist(v.obj) then
            exports.ox_target:removeLocalEntity(v.obj)
            SetEntityAsMissionEntity(v.obj, false)
            FreezeEntityPosition(v.obj, false)
            DeleteObject(v.obj)
        end
    end

    SpawnedProps = {}
    PackingUpProps = {}

    if Config.gunZoneActive then
        for _, zone in pairs(gunZones) do
            if zone and zone.remove then
                zone:remove()
            end
        end
        ingunZone = false
        gunZones = {}
        if Config.showTextZone then lib.hideTextUI() end
    end

    promptThreadActive = false
    ClearCameraPrompts()
    isBusy = false
    camera = nil
    currentWeaponData = nil
    selectedCache = {}
    selectedLabels = {}
end)