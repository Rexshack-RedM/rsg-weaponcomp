lib.locale()

local PromptPlacerGroup = GetRandomIntInRange(0, 0xffffff)
local SetPrompt, CancelPrompt
local isPlacing = false
local ghostProp
local ROTATE_SPEED = 60.0 -- degrees per second

local CONTROL_SET = 0xC7B5340A
local CONTROL_CANCEL = 0xF84FA74F
local CONTROL_ROTATE_LEFT = 0xA65EBAB4
local CONTROL_ROTATE_RIGHT = 0xDEB34313

local function createPrompt(control, textKey, hold)
    local prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, control)
    PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', locale(textKey)))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    if hold then PromptSetHoldMode(prompt, true) else PromptSetStandardMode(prompt, true) end
    PromptSetGroup(prompt, PromptPlacerGroup)
    PromptRegisterEnd(prompt)
    return prompt
end

CreateThread(function()
    SetPrompt = createPrompt(CONTROL_SET, 'cl_promp_2', true)
    CancelPrompt = createPrompt(CONTROL_CANCEL, 'cl_promp_1', true)
    createPrompt(CONTROL_ROTATE_LEFT, 'cl_promp_3')
    createPrompt(CONTROL_ROTATE_RIGHT, 'cl_promp_4')
end)

local function rotationToDirection(rot)
    local x, z = math.rad(rot.x), math.rad(rot.z)
    return vector3(-math.sin(z) * math.abs(math.cos(x)), math.cos(z) * math.abs(math.cos(x)), math.sin(x))
end

local function raycastFromCamera(distance)
    local camCoord = GetGameplayCamCoord()
    local dest = camCoord + rotationToDirection(GetGameplayCamRot()) * distance
    local _, hit, coords = GetShapeTestResult(StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z, dest.x, dest.y, dest.z, -1, cache.ped, 0))
    return hit == 1, coords
end

local function drawPropAxes(prop)
    local forward, right, up, pos = GetEntityMatrix(prop)
    local origin = pos + vector3(0.0, 0.0, 0.1)
    local x, y, z = pos + right * 0.2, pos + forward * 0.2, pos + up * 0.2
    DrawLine(origin.x, origin.y, origin.z, x.x, x.y, x.z, 255, 0, 0, 255)
    DrawLine(origin.x, origin.y, origin.z, y.x, y.y, y.z, 0, 255, 0, 255)
    DrawLine(origin.x, origin.y, origin.z, z.x, z.y, z.z, 0, 0, 255, 255)
end

local function placeProp(propmodel)
    if isPlacing then return end
    local model = type(propmodel) == 'number' and propmodel or joaat(propmodel)
    if not pcall(lib.requestModel, model, 5000) then return end
    isPlacing = true

    local heading = 0.0
    local _, coords = raycastFromCamera(20.0)
    local prop = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    ghostProp = prop
    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(prop, true)
    SetEntityCollision(prop, false, false)
    SetEntityAlpha(prop, 150, false)

    local groupLabel = CreateVarString(10, 'LITERAL_STRING', locale('cl_promp_5'))

    CreateThread(function()
        while true do
            local hit, hitCoords = raycastFromCamera(20.0)
            if hit then coords = hitCoords end

            SetEntityCoordsNoOffset(prop, coords.x, coords.y, coords.z, false, false, false)
            drawPropAxes(prop)

            -- ghost goes faint when out of range so players know before they try to place
            local inRange = #(GetEntityCoords(cache.ped) - coords) <= (Config.PlaceDistance or 5.0)
            SetEntityAlpha(prop, inRange and 150 or 60, false)
            PromptSetActiveGroupThisFrame(PromptPlacerGroup, groupLabel)

            local step = ROTATE_SPEED * GetFrameTime()
            if IsControlPressed(1, CONTROL_ROTATE_LEFT) then
                heading = (heading + step) % 360.0
            elseif IsControlPressed(1, CONTROL_ROTATE_RIGHT) then
                heading = (heading - step) % 360.0
            end
            SetEntityHeading(prop, heading)

            if PromptHasHoldModeCompleted(SetPrompt) then
                DeleteObject(prop)
                TriggerEvent('rsg-weaponcomp:client:setupgunzone', coords, heading)
                break
            end

            if PromptHasHoldModeCompleted(CancelPrompt) then
                DeleteObject(prop)
                break
            end

            Wait(0)
        end
        ghostProp = nil
        isPlacing = false
    end)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if ghostProp and DoesEntityExist(ghostProp) then DeleteObject(ghostProp) end
end)

RegisterNetEvent('rsg-weaponcomp:client:createprop', function(data)
    placeProp(data.propmodel)
end)
