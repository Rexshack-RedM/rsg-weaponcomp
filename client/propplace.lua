local confirmed
local heading
local PromptPlacerGroup = GetRandomIntInRange(0, 0xffffff)
lib.locale()

-- prompt controls
CreateThread(function()
    Set()
    Del()
    RotateLeft()
    RotateRight()
end)

function Del()
    CreateThread(function()
        local str = locale('cl_promp_1')
        CancelPrompt = PromptRegisterBegin()
        PromptSetControlAction(CancelPrompt, 0xF84FA74F)
        str = CreateVarString(10, 'LITERAL_STRING', str)
        PromptSetText(CancelPrompt, str)
        PromptSetEnabled(CancelPrompt, true)
        PromptSetVisible(CancelPrompt, true)
        PromptSetHoldMode(CancelPrompt, true)
        PromptSetGroup(CancelPrompt, PromptPlacerGroup)
        PromptRegisterEnd(CancelPrompt)
    end)
end

function Set()
    CreateThread(function()
        local str = locale('cl_promp_2')
        SetPrompt = PromptRegisterBegin()
        PromptSetControlAction(SetPrompt, 0xC7B5340A)
        str = CreateVarString(10, 'LITERAL_STRING', str)
        PromptSetText(SetPrompt, str)
        PromptSetEnabled(SetPrompt, true)
        PromptSetVisible(SetPrompt, true)
        PromptSetHoldMode(SetPrompt, true)
        PromptSetGroup(SetPrompt, PromptPlacerGroup)
        PromptRegisterEnd(SetPrompt)
    end)
end

function RotateLeft()
    CreateThread(function()
        local str = locale('cl_promp_3')
        RotateLeftPrompt = PromptRegisterBegin()
        PromptSetControlAction(RotateLeftPrompt, 0xA65EBAB4)
        str = CreateVarString(10, 'LITERAL_STRING', str)
        PromptSetText(RotateLeftPrompt, str)
        PromptSetEnabled(RotateLeftPrompt, true)
        PromptSetVisible(RotateLeftPrompt, true)
        PromptSetStandardMode(RotateLeftPrompt, true)
        PromptSetGroup(RotateLeftPrompt, PromptPlacerGroup)
        PromptRegisterEnd(RotateLeftPrompt)
    end)
end

function RotateRight()
    CreateThread(function()
        local str = locale('cl_promp_4')
        RotateRightPrompt = PromptRegisterBegin()
        PromptSetControlAction(RotateRightPrompt, 0xDEB34313)
        str = CreateVarString(10, 'LITERAL_STRING', str)
        PromptSetText(RotateRightPrompt, str)
        PromptSetEnabled(RotateRightPrompt, true)
        PromptSetVisible(RotateRightPrompt, true)
        PromptSetStandardMode(RotateRightPrompt, true)
        PromptSetGroup(RotateRightPrompt, PromptPlacerGroup)
        PromptRegisterEnd(RotateRightPrompt)
    end)
end

function RotationToDirection(rotation)
    local adjustedRotation =
    {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z
    }
    local direction =
    {
        x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        z = math.sin(adjustedRotation.x)
    }
    return direction
end

function DrawPropAxes(prop)
    local propForward, propRight, propUp, propCoords = GetEntityMatrix(prop)

    local propXAxisEnd = propCoords + propRight * 0.20
    local propYAxisEnd = propCoords + propForward * 0.20
    local propZAxisEnd = propCoords + propUp * 0.20

    DrawLine(propCoords.x, propCoords.y, propCoords.z + 0.1, propXAxisEnd.x, propXAxisEnd.y, propXAxisEnd.z, 255, 0, 0, 255)
    DrawLine(propCoords.x, propCoords.y, propCoords.z + 0.1, propYAxisEnd.x, propYAxisEnd.y, propYAxisEnd.z, 0, 255, 0, 255)
    DrawLine(propCoords.x, propCoords.y, propCoords.z + 0.1, propZAxisEnd.x, propZAxisEnd.y, propZAxisEnd.z, 0, 0, 255, 255)
end

function RayCastGamePlayCamera(distance)
    local cameraRotation = GetGameplayCamRot()
    local cameraCoord = GetGameplayCamCoord()
    local direction = RotationToDirection(cameraRotation)
    local destination =
    {
        x = cameraCoord.x + direction.x * distance,
        y = cameraCoord.y + direction.y * distance,
        z = cameraCoord.z + direction.z * distance
    }
    local a, b, c, d, e = GetShapeTestResult(StartShapeTestRay(cameraCoord.x, cameraCoord.y, cameraCoord.z, destination.x, destination.y, destination.z, -1, PlayerPedId(), 0))
    return b, c, e
end

local function placeProp(propmodel, item, gunsitename, gunsiteid)
    prop = joaat(propmodel)
    heading = 0.0
    confirmed = false

    RequestModel(prop)
    while not HasModelLoaded(prop) do
        Wait(0)
    end

    local hit, coords, entity

    while not hit do
        hit, coords, entity = RayCastGamePlayCamera(1000.0)
        Wait(0)
    end

    prop = CreateObject(prop, coords.x, coords.y, coords.z, true, false, true)

    CreateThread(function()
        while not confirmed do
            hit, coords, entity = RayCastGamePlayCamera(1000.0)

            SetEntityCoordsNoOffset(prop, coords.x, coords.y, coords.z, false, false, false, true)
            FreezeEntityPosition(prop, true)
            SetEntityCollision(prop, false, false)
            SetEntityAlpha(prop, 150, false)
            DrawPropAxes(prop)
            Wait(0)

            local PropPlacerGroupName  = CreateVarString(10, 'LITERAL_STRING', locale('cl_promp_5'))
            PromptSetActiveGroupThisFrame(PromptPlacerGroup, PropPlacerGroupName)

            if IsControlPressed(1, 0xA65EBAB4) then -- Left arrow key
                heading = heading + 1.0
            elseif IsControlPressed(1, 0xDEB34313) then -- Right arrow key
                heading = heading - 1.0
            end

            if heading > 360.0 then
                heading = 0.0
            elseif heading < 0.0 then
                heading = 360.0
            end

            SetEntityHeading(prop, heading)

            if PromptHasHoldModeCompleted(SetPrompt) then
                confirmed = true
                SetEntityAlpha(prop, 255, false)
                SetEntityCollision(prop, true, true)
                DeleteObject(prop)
                if item == Config.Gunsmithitem then
                    TriggerEvent('rsg-weaponcomp:client:setupgunzone', propmodel, item, coords, heading)
                else
                    TriggerEvent('rsg-weaponcomp:client:placegunsiteitem', propmodel, item, gunsiteid, coords, heading)
                end
            end

            if PromptHasHoldModeCompleted(CancelPrompt) then
                DeleteObject(prop)
                SetModelAsNoLongerNeeded(prop)
                break
            end

        end
    end)
end

RegisterNetEvent('rsg-weaponcomp:client:createprop', function(data)
    placeProp(data.propmodel, data.item, data.gunsitename, data.gunsiteid)
end)
