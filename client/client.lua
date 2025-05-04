local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local SpawnedProps   = {}
local PackingUpProps = {}
local gunZones       = {}
local ingunZone      = false
local isBusy         = false
local wepObj         = nil
local camera         = nil
local selectedCache  = {}
local selectedLabels  = {}

----------------------------------------
-- Basics
----------------------------------------
local WeaponTypeMap = {
    [GetHashKey('GROUP_REPEATER')] = "LONGARM",
    [GetHashKey('GROUP_SHOTGUN'  )] = "SHOTGUN",
    [GetHashKey('GROUP_PISTOL'   )] = "SHORTARM",
    [GetHashKey('GROUP_REVOLVER')] = "SHORTARM",
    [GetHashKey('GROUP_RIFLE'    )] = "LONGARM",
    [GetHashKey('GROUP_SNIPER'   )] = "LONGARM",
    [GetHashKey('GROUP_MELEE'    )] = "MELEE_BLADE",
    [GetHashKey('GROUP_BOW'      )] = "GROUP_BOW",
}

function GetWeaponType(hash)
    return WeaponTypeMap[GetWeapontypeGroup(hash)]
end

-- Merge components from source into merged
local function mergeComponents(merged, source)
    for cat, list in pairs(source) do
        merged[cat] = merged[cat] or {}
        for _, comp in ipairs(list) do
            merged[cat][#merged[cat]+1] = comp
        end
    end
end

-- Build specific + shared merged table
local function GetAvailableComponents(weaponName, wHash)
    local specific = Config.Specific[weaponName] or {}
    local merged   = {}
    local group    = GetWeaponType(wHash)

    if group and Config.Shared[group] then    -- Shared (group) components
        mergeComponents(merged, Config.Shared[group])
    end

    mergeComponents(merged, specific)    -- Specific components
    return merged
end

local function CalculatePrice(selection)
    local total = 0
    for cat, _ in pairs(selection) do
        total = total + (Config.price[cat] or 0)
    end
    return total
end

local function CanPlacePropHere(pos)
    for _,p in ipairs(Config.PlayerProps) do
        if #(pos - vector3(p.x,p.y,p.z)) < 1.3 then return false end
    end
    return true
end

-- Spawn weapon on the prop
local function spawnWeaponOnProp(propObj, spawnPos, wHash)
    if wepObj ~= nil and DoesEntityExist(wepObj) then
        DeleteObject(wepObj)
        wepObj = nil
    end
    -- create new
    wepObj = Citizen.InvokeNative(0x9888652B8BA77F73, wHash, 0, spawnPos.x, spawnPos.y, spawnPos.z, false, 1.0)
    -- place weapon
    if wepObj and DoesEntityExist(wepObj) then
        AttachEntityToEntity(wepObj, propObj, -1, -0.06, 0.0, 0.28, 0.0, 0.0, 90.0, false, false, false, false, 2, true)
        FreezeEntityPosition(wepObj, true)
    end
end

----------------------------------------
-- cameras
----------------------------------------
local function StartCamOnWeapon(obj, fov)
    if not (obj and DoesEntityExist(obj)) then return end
    local forward, right, up, origin = table.unpack({ GetEntityMatrix(obj) })

    local distBack = Config.distBack
    local distSide = Config.distSide
    local distUp   = Config.distUp

    local camPos = vector3(
        origin.x - forward.x * distBack + right.x * distSide + up.x * distUp,
        origin.y - forward.y * distBack + right.y * distSide + up.y * distUp,
        origin.z - forward.z * distBack + right.z * distSide + up.z * distUp
    )

    if camera then DestroyCam(camera, true) end
    camera = CreateCamWithParams(
        "DEFAULT_SCRIPTED_CAMERA",
        camPos.x, camPos.y, camPos.z,
        0, 0, 0,    -- rotación; la fijamos con PointCamAtCoord
        fov or 75.0,
        false, 0
    )

    SetCamActive(camera, true)
    RenderScriptCams(true, true, 2000, true, true)
    PointCamAtCoord(camera, origin.x, origin.y, origin.z + 0.1)
end

local c_zoom = 1.5
local c_offset = 0.20

local function StartCamClean(zoom, offset)
    local zoomOffset = tonumber(zoom)
    local coords = GetEntityCoords(cache.ped)
    local playerHeading = GetEntityHeading(cache.ped)
    local angle
    if playerHeading == nil then
        angle = playerHeading * math.pi / 180.0
    else
        angle = playerHeading * math.pi / 180.0
    end

    local pos = {
        x = coords.x - tonumber(zoomOffset * math.sin(angle)),
        y = coords.y + tonumber(zoomOffset * math.cos(angle)),
        z = coords.z + offset
    }

    local camera_pos = GetObjectOffsetFromCoords(pos.x, pos.y, pos.z, 0.0, 1.0, 1.0, 1.0)

    camera = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", pos.x, pos.y, pos.z + 0.5, 300.00, 0.00, 0.00, 50.00, false, 0)
    local pCoords = GetEntityCoords(cache.ped)
    PointCamAtCoord(camera, pCoords.x, pCoords.y, pCoords.z + offset)

    SetCamActive(camera, true)
    RenderScriptCams(true, true, 1000, true, true)
end

RegisterNetEvent("rsg-weaponcomp:client:animationSaved")
AddEventHandler("rsg-weaponcomp:client:animationSaved", function(objecthash, serial)
    SetCurrentPedWeapon(cache.ped, objecthash, true)
    if camera then DestroyCam(camera,true) end
    camera = nil

    if wepObj ~= nil and DoesEntityExist(wepObj) then
        SetEntityAsMissionEntity(wepObj, false)
        FreezeEntityPosition(wepObj, false)
        DeleteObject(wepObj)
    end

    local weapon_type = GetWeaponType(objecthash)
    local boneIndex2 = GetEntityBoneIndexByName(cache.ped, "SKEL_L_Finger00")
    local Cloth = CreateObject(GetHashKey('s_balledragcloth01x'), GetEntityCoords(cache.ped), false, true, false, false, true)
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
        AttachEntityToEntity(Cloth, cache.ped, boneIndex2, 0.02, -0.035, 0.00, 20.0, -24.0, 165.0, true, false, true, false, 0, true)

        lib.progressBar({
            duration = tonumber(Config.animationSave),
            useWhileDead = false,
            canCancel = false,
            disable = { move = true, car = true, combat= true, mouse= false, sprint = true, },
            anim = { dict = animDict, clip = animName, flag = 15, },
            label = locale('cl_lang_1'),
        })

        if Cloth ~= nil and DoesEntityExist(Cloth) then
            SetEntityAsNoLongerNeeded(Cloth)
            DeleteEntity(Cloth)
        end
    end

    TriggerServerEvent("rsg-weaponcomp:server:check_comps")
    TriggerEvent('rsg-weaponcomp:client:ExitCam')
end)

RegisterNetEvent('rsg-weaponcomp:client:ExitCam')
AddEventHandler('rsg-weaponcomp:client:ExitCam', function()
    RenderScriptCams(false, true, 2000, true, false)
    if camera then DestroyCam(camera,true) end
    camera = nil
    DestroyAllCams(true)

    if wepObj ~= nil and DoesEntityExist(wepObj) then
        SetEntityAsMissionEntity(wepObj, false)
        FreezeEntityPosition(wepObj, false)
        DeleteObject(wepObj)
    end
    selectedCache  = {}
    MenuData.CloseAll()
end)

----------------------------------------
-- for change camera WIP
----------------------------------------
--[[ 

local targetCoords   = nil
local function Lerp(a,b,t) return a + (b-a)*t end
local function FocusCam(obj)
    if not(obj and camera and DoesEntityExist(obj)) then return end
    local pos = GetEntityCoords(obj)
    local rot = GetEntityRotation(obj,2)
    if not targetCoords or vector3(pos.x,pos.y,pos.z) ~= targetCoords then
        targetCoords = vector3(pos.x,pos.y,pos.z)
        local cx,cy,cz = table.unpack(GetCamCoord(camera))
        for t=0,1,0.05 do
            StartCam(Lerp(cx,pos.x,t), Lerp(cy,pos.y,t), Lerp(cz,pos.z+0.5,t), 75.0)
            Wait(30)
        end
    else
        StartCam(pos.x,pos.y,pos.z+0.5,75.0)
    end
    SetCamRot(camera, rot.x,rot.y,rot.z,2)
end ]]

----------------------------------------
-- aply menu
----------------------------------------
local function applyWeaponComponent(obj, prevComp, nextComp, wHash)
    local mdl = GetWeaponComponentTypeModel(nextComp)
    if mdl and mdl ~= 0 then
        RequestModel(mdl)
        while not HasModelLoaded(mdl) do Wait(50) end
    end
    if prevComp then RemoveWeaponComponentFromWeaponObject(obj, prevComp) end
    GiveWeaponComponentToEntity(obj, nextComp, wHash, true)
end

-- Initialize first set comp
local function applyDefaults(obj, wHash)
    local name = Citizen.InvokeNative(0x89CF5FF3D363311E, wHash, Citizen.ResultAsString())
    local comps = GetAvailableComponents(name, wHash)
    local listcomps = { 'BARREL', 'GRIP' }
    -- local listcomps = { 'BARREL','GRIP','SIGHT','CLIP','MAG','STOCK','TUBE','TORCH_MATCHSTICK','GRIPSTOCK' }
    for _, cat in ipairs(listcomps) do
        local options = comps[cat]
        if options and #options > 0 then
            local defaultComp = options[1]                     -- nombre del componente
            local compHash    = GetHashKey(defaultComp)       -- su hash
            applyWeaponComponent(obj, nil, compHash, wHash)   -- lo aplicas
            selectedCache[cat] = defaultComp                  -- y lo guardas en la caché
        end
    end
end

----------------------------------------
-- Menu
----------------------------------------
MenuData = {}
TriggerEvent('rsg-menubase:getData', function(call)
    MenuData = call
end)

local function OpenComponentMenu(wname, wHash, serial, propid)
    local comps = Config.Specific[wname] or {}
    local elements = {}
    local a = 1

    for cat, list in pairs(comps) do
        local hashes, labels, labelsSends = {}, {}, {}
        for i, comp in ipairs(list) do
            hashes[i], labels[i], labelsSends[i] = GetHashKey(comp), comp, locale(comp)            -- labels[i] = comp
        end
        elements[#elements+1] = {
            label  = locale(cat),
            type   = "slider",
            name   = cat,
            min    = 1,
            max    = #list,
            value  = selectedCache[cat] and (function()
                for idx,v in ipairs(list) do if v==selectedCache[cat] then return idx end end
                return 1
            end)() or 1,
            hashes = hashes,
            labels = labels,
            labelsSends = labelsSends,
            id = a
        }
    end

    MenuData.Open("default", GetCurrentResourceName(), "weapon_specific_menu", {
        title    = locale('cl_lang_2') ..  ":",
        align    = "top-left",
        elements = elements,
    }, function(data, menu)
        local sel = data.current
        if sel.hashes then
            local prev = selectedCache[sel.name] and GetHashKey(selectedCache[sel.name]) or nil
            local nxt  = sel.hashes[sel.value]
            applyWeaponComponent(wepObj, prev, nxt, wHash)
            selectedCache[sel.name] = sel.labels[sel.value]
            selectedLabels[sel.name] = sel.labelsSends[sel.value]  -- Almacena el label
            -- FocusCam(wepObj)
        end
    end, function(_, menu)
        menu.close()
        MainWeaponMenu(wname, wHash, serial, propid)
    end)
end

-- Menu MATERIAL (not _ENGRAVING_MATERIAL)
local function OpenMaterialMenu(wname, wHash, serial, propid)
    local comps = GetAvailableComponents(wname, wHash)
    local elements = {}
    local a = 1
    for cat, items in pairs(comps) do
      if cat:find('_MATERIAL$') and not cat:find('_ENGRAVING_MATERIAL$') then
        local hashes, labels, labelsSends = {}, {}, {}
        for i, comp in ipairs(items) do
            hashes[i], labels[i], labelsSends[i] = GetHashKey(comp), comp, locale(comp)
        end
        table.insert(elements, {
          label  = locale(cat),
          type   = 'slider',
          name   = cat,
          min    = 1,
          max    = #items,
          value  = selectedCache[cat] and (function()
            for idx,v in ipairs(items) do if v==selectedCache[cat] then return idx end end
            return 1
          end)() or 1,
          hashes = hashes,
          labels = labels,
          labelsSends = labelsSends,
          id = a
        })
      end
    end

    if #elements == 0 then
        lib.notify({ title = locale('cl_notify_1'), description = locale('cl_notify_2'), type='error' })
        return
    end

    MenuData.Open('default', GetCurrentResourceName(), 'weapon_mat_menu', {
      title    = locale('cl_lang_3') .. ':',
      align    = 'top-left',
      elements = elements,
    }, function(data, menu)
        local sel = data.current
        if sel.hashes then
            local prev = selectedCache[sel.name] and GetHashKey(selectedCache[sel.name]) or nil
            local nxt  = sel.hashes[sel.value]
            applyWeaponComponent(wepObj, prev, nxt, wHash)
            selectedCache[sel.name] = sel.labels[sel.value]
            selectedLabels[sel.name] = sel.labelsSends[sel.value]  -- Almacena el label
            -- FocusCam(wepObj)
        end
    end, function(_, menu)
        menu.close()
        MainWeaponMenu(wname, wHash, serial, propid)
    end)
end

  -- Menu ENGRAVING (add _ENGRAVING y _ENGRAVING_MATERIAL)
local function OpenEngravingMenu(wname, wHash, serial, propid)
    local comps = GetAvailableComponents(wname, wHash)
    local elements = {}
    local a = 1

    for cat, items in pairs(comps) do
      if cat:find('_ENGRAVING') then
        local hashes, labels, labelsSends = {}, {}, {}
        for i, comp in ipairs(items) do
            hashes[i], labels[i], labelsSends[i] = GetHashKey(comp), comp, locale(comp)
        end
        table.insert(elements, {
          label  = locale(cat),
          type   = 'slider',
          name   = cat,
          min    = 1,
          max    = #items,
          value  = selectedCache[cat] and (function()
            for idx,v in ipairs(items) do if v==selectedCache[cat] then return idx end end
            return 1
          end)() or 1,
          hashes = hashes,
          labels = labels,
          labelsSends = labelsSends,
          id = a
        })
      end
    end

    if #elements == 0 then
        lib.notify({ title=locale('cl_notify_3'), description=locale('cl_notify_4'), type='error' })
        return
    end

    MenuData.Open('default', GetCurrentResourceName(), 'weapon_eng_menu', {
      title    = locale('cl_lang_4') ..':',
      align    = 'top-left',
      elements = elements,
    }, function(data, menu)
        local sel = data.current
        if sel.hashes then
            local prev = selectedCache[sel.name] and GetHashKey(selectedCache[sel.name]) or nil
            local nxt  = sel.hashes[sel.value]
            applyWeaponComponent(wepObj, prev, nxt, wHash)
            selectedCache[sel.name] = sel.labels[sel.value]
            selectedLabels[sel.name] = sel.labelsSends[sel.value]  -- Almacena el label
        end
    end, function(_, menu)
        menu.close()
        MainWeaponMenu(wname, wHash, serial, propid)
    end)
end

-- Menu TINTS
local function OpenTintsMenu(wname, wHash, serial, propid)
    local comps    = GetAvailableComponents(wname, wHash)
    local elements = {}

    -- Recolectamos solo categorías _TINT
    for cat, items in pairs(comps) do
        if cat:find('_TINT$') then
            local hashes, labels, labelsSends = {}, {}, {}
            for i, comp in ipairs(items) do
                hashes[i], labels[i], labelsSends[i] = GetHashKey(comp), comp, locale(comp)
            end
            table.insert(elements, {
                label  = locale(cat),
                type   = 'slider',
                name   = cat,
                min    = 1,
                max    = #items,
                value  = selectedCache[cat] and (function()
                    for idx, v in ipairs(items) do
                        if v == selectedCache[cat] then return idx end
                    end
                    return 1
                end)() or 1,
                hashes = hashes,
                labels = labels,
                labelsSends = labelsSends,
                id     = #elements + 1
            })
        end
    end

    if #elements == 0 then
        lib.notify({ title = locale('cl_notify_7'), description = locale('cl_notify_8'), type = 'error' })
        return
    end

    -- Aquí cambio el ID a 'weapon_tint_menu'
    MenuData.Open('default', GetCurrentResourceName(), 'weapon_tint_menu', {
        title    = locale('cl_lang_5') .. ':',
        align    = 'top-left',
        elements = elements,
    }, function(data, menu)
        local sel = data.current
        if sel.hashes then
            local prev = selectedCache[sel.name] and GetHashKey(selectedCache[sel.name]) or nil
            local nxt  = sel.hashes[sel.value]
            -- local tintIndex = sel.value - 1  -- native usa 0-7
            -- applyWeaponTint(cache.ped, wHash, tintIndex)
            applyWeaponComponent(wepObj, prev, nxt, wHash)
            selectedCache[sel.name] = sel.labels[sel.value]
            selectedLabels[sel.name] = sel.labelsSends[sel.value]  -- Almacena el label
        end
    end, function(_, menu)
        menu.close()
        MainWeaponMenu(wname, wHash, serial, propid)
    end)
end

-- In MainWeaponMenu you call like this:
function MainWeaponMenu(wname, wHash, serial, propid)
    MenuData.CloseAll()

    for cat, compName in pairs(selectedCache) do
        local compHash = GetHashKey(compName)
        applyWeaponComponent(wepObj, nil, compHash, wHash)
    end

    local el = {
        { label=locale('cl_lang_6'),  value='specific' },
        { label=locale('cl_lang_7'),  value='material' },
        { label=locale('cl_lang_8'),  value='engraving' },
        { label=locale('cl_lang_9'),  value='tints' },
        { label=locale('cl_lang_10'), value='buy' },
        { label=locale('cl_lang_11'), value='reset' },
        { label=locale('cl_lang_12'), value='packup' },
    }
    MenuData.Open('default', GetCurrentResourceName(), 'main_weapon_menu', {
        title    = locale('cl_lang_13'),
        align    = 'top-left',
        elements = el,
    }, function(data, menu)
        if data.current.value == 'specific' then
            OpenComponentMenu(wname, wHash, serial)

        elseif data.current.value == 'material' then
            OpenMaterialMenu(wname, wHash, serial)

        elseif data.current.value == 'engraving' then
            OpenEngravingMenu(wname, wHash, serial)

        elseif data.current.value == 'tints' then
            OpenTintsMenu(wname, wHash, serial)

        elseif data.current.value == 'buy' then
            local price = CalculatePrice(selectedCache)
            if price > 0 then
                TriggerServerEvent('rsg-weaponcomp:server:price',
                    price, wHash, serial, selectedCache, selectedLabels
                )
                lib.notify({ title=locale('cl_notify_9'), description="$"..price, type="success" })
                menu.close()
                -- Ojo: si quieres que la próxima vez empiece limpio,
                selectedCache = {}
            else
                lib.notify({ title=locale('cl_notify_10'), type="error" })
            end
        elseif data.current.value == 'reset' then
            RSGCore.Functions.TriggerCallback('rsg-weaponcomp:server:getPlayerWeaponComponents', function(d)
                local dbComps = d.components or nil
                local price   = CalculatePrice(dbComps) * Config.RemovePrice

                if price > 0 then
                    TriggerServerEvent('rsg-weaponcomp:server:price',
                        price, wHash, serial, nil, nil
                    )
                    lib.notify({ title=locale('cl_notify_11'), description="$"..price, type="success" })
                    selectedCache = {}
                    selectedLabels = {}
                    menu.close()
                else
                    lib.notify({ title=locale('cl_notify_12'), type="error" })
                end
            end, serial)

        elseif data.current.value == 'packup' then
            TriggerEvent('rsg-weaponcomp:client:confirmpackup', propid)
            menu.close()
        end
    end, function(_, menu)
        TriggerEvent('rsg-weaponcomp:client:ExitCam')
        menu.close()
    end)
end

----------------------------------------
-- START CUSTOM EVENT
----------------------------------------
RegisterNetEvent('rsg-weaponcomp:client:startcustom', function(propid, wHash, serial, weaponName)
    if isBusy then return end
    isBusy = true

    local propData = SpawnedProps[propid]
    if not propData then return end
    local propObj = propData.obj
    local coords = GetEntityCoords(propObj)
    spawnWeaponOnProp(propObj, coords, wHash)

    Wait(500)
    StartCamOnWeapon(wepObj, Config.distFov)
    MainWeaponMenu(weaponName, wHash, serial, propid)
    applyDefaults(wepObj, wHash)
    isBusy = false
end)

--------------------------
-- Spawn & track existing props + zones + targets
----------------------------
Citizen.CreateThread(function()
    while true do
        Wait(150)
        local ped = cache.ped or PlayerPedId()
        local pos = GetEntityCoords(ped)
        local inRange = false
        if not Config.PlayerProps then return end
        for k, v in ipairs(Config.PlayerProps) do
            if #(pos - vector3(v.x,v.y,v.z)) < 50.0 then
                inRange = true
                if not SpawnedProps[v.propid] and not PackingUpProps[v.propid] then
                    -- Modelo y objeto
                    local m = joaat(v.propmodel)
                    RequestModel(m)
                    while not HasModelLoaded(m) do Wait(1) end
                    local obj = CreateObject(m, v.x, v.y, v.z, false, true, true)
                    SetEntityHeading(obj, v.h)
                    FreezeEntityPosition(obj, true)

                    -- Zona de interacción
                    local propConfig = Config.PlayerProps[k]
                    gunZones[v.propid] = lib.zones.sphere({
                        coords = vec3(propConfig.x, propConfig.y, propConfig.z),
                        radius = Config.gunZoneSize,
                        debug = false,
                        onEnter = function()
                            ingunZone = true
                            if propConfig.item == Config.Gunsmithitem then
                                gunsitename = tostring(propConfig.gunsitename)
                                lib.showTextUI(gunsitename)
                            end
                        end,
                        onExit = function()
                            ingunZone = false
                            lib.hideTextUI()
                        end
                    })

                    -- Target para menú
                    exports.ox_target:addLocalEntity(obj, {
                        {
                            name     = 'gunsite_prop',
                            icon     = 'far fa-eye',
                            label    = locale('cl_lang_14'),
                            onSelect = function()
                                local wHash = GetPedCurrentHeldWeapon(PlayerPedId())
                                local serial = exports['rsg-weapons']:weaponInHands()[wHash]
                                local weaponName = Citizen.InvokeNative(0x89CF5FF3D363311E, wHash, Citizen.ResultAsString())
                                if not serial then -- or wHash == -1569615261 or not isWeaponOneHanded
                                    return lib.notify({ title = locale('cl_notify_13'), description=locale('cl_notify_14'), type='error' })
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

        if not inRange then Wait(5000) end
    end
end)

-- update props
RegisterNetEvent('rsg-weaponcomp:client:updatePropData')
AddEventHandler('rsg-weaponcomp:client:updatePropData', function(data)
    Config.PlayerProps = data
end)

-- setup new gunsite
RegisterNetEvent('rsg-weaponcomp:client:setupgunzone')
AddEventHandler('rsg-weaponcomp:client:setupgunzone', function(propmodel, item, coords, heading)
    RSGCore.Functions.TriggerCallback('rsg-weaponcomp:server:countprop', function(result)
        -- distance check
        local playercoords = GetEntityCoords(cache.ped)
        if #(playercoords - coords) > Config.PlaceDistance then
            lib.notify({ title = locale('cl_lang_15'), description = locale('cl_lang_16'), type = 'error', duration = 5000 })
            return
        end
        -- check gunsites
        if result >= Config.MaxGunsites then
            lib.notify({ title = locale('cl_lang_17'), description = locale('cl_lang_18'), type = 'error', duration = 7000 })
            return
        end
        -- check guning zone
        if ingunZone then
            lib.notify({ title = locale('cl_lang_19'), description = locale('cl_lang_20'), type = 'error', duration = 7000 })
            return
        end
        -- check not in town and other props
        if not CanPlacePropHere(coords) then
            lib.notify({ title = locale('cl_lang_21'), description = locale('cl_lang_22'), type = 'error', duration = 7000 })
            return
        end
        if not IsPedInAnyVehicle(cache.ped, false) and not isBusy then
            isBusy = true
            local anim1 = `WORLD_HUMAN_STAND_WAITING`
            FreezeEntityPosition(cache.ped, true)
            TaskStartScenarioInPlace(cache.ped, anim1, 0, true)
            Wait(10000)
            ClearPedTasks(cache.ped)
            FreezeEntityPosition(cache.ped, false)
            TriggerServerEvent('rsg-weaponcomp:server:createnewprop', propmodel, item, coords, heading)
            isBusy = false
            return
        end
    end, item)
end)

-- confirm gunsite packup
RegisterNetEvent('rsg-weaponcomp:client:confirmpackup', function(propid)
    local input = lib.inputDialog(locale('cl_lang_23'), {
        {
            label = locale('cl_lang_24'),
            description = locale('cl_lang_25'),
            type = 'select',
            options = {
                { value = 'yes', label = locale('cl_lang_26') },
                { value = 'no',  label = locale('cl_lang_27') }
            },
            required = true
        },
    })

    if not input or input[1] == 'no' then return end

    TriggerEvent('rsg-weaponcomp:client:ExitCam')

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
        label = locale('cl_lang_28'),
    })

    LocalPlayer.state:set('inv_busy', false, true)
    TriggerEvent('rsg-weaponcomp:client:packupgunsite', propid)
end)

-- packup gunsite
RegisterNetEvent('rsg-weaponcomp:client:packupgunsite', function(propid)

    TriggerServerEvent('rsg-weaponcomp:server:removegunsiteprops', propid)

    PackingUpProps[propid] = true
    local propData = SpawnedProps[propid]
    if propData and DoesEntityExist(propData.obj) then
        SetEntityAsMissionEntity(propData.obj, true, true)
        DeleteObject(propData.obj)
        Wait(100)
    end
    SpawnedProps[propid] = nil

    if gunZones[propid] then
        gunZones[propid]:remove()
        gunZones[propid] = nil
    end

    lib.hideTextUI()
    ingunZone = false
    PackingUpProps[propid] = false
    TriggerServerEvent('rsg-weaponcomp:server:additem', Config.Gunsmithitem, 1)
end)

---------------------------------------------
-- clean up
---------------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    DestroyAllCams(true)
    if camera then DestroyCam(camera,true) end
    MenuData.CloseAll()

    if wepObj ~= nil and DoesEntityExist(wepObj) then
        SetEntityAsMissionEntity(wepObj, false)
        FreezeEntityPosition(wepObj, false)
        DeleteObject(wepObj)
    end

    for k, v in pairs(SpawnedProps) do
        local props = SpawnedProps[k].obj
        SetEntityAsMissionEntity(props, false)
        FreezeEntityPosition(props, false)
        DeleteObject(props)
    end

    SpawnedProps   = {}        -- [propid] = { obj }
    PackingUpProps = {}
    ingunZone      = false
    lib.hideTextUI()
    gunZones       = {}

    isBusy         = false
    camera         = nil

    selectedCache  = {}
    selectedLabels = {}
end)