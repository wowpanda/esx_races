-- == Language Config == --
local race_started = "~g~You started a race!"
local no_waypoint = "~r~There is no waypoint on the map!"
local race_cancel = "~r~The race has been canceled!"
local race_joined = "~g~You joined the race!"
-- == Language Config == --


-- == ESX STUFF == --
ESX = nil

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
end)
-- == ESX STUFF == --

-- == Don't Touch == --
local RACE_STATE_NONE = 0
local RACE_STATE_JOINED = 1
local RACE_STATE_RACING = 2
local RACE_CHECKPOINT_TYPE = 45
local RACE_CHECKPOINT_FINISH_TYPE = 9

local races = {}
local raceStatus = {
    state = RACE_STATE_NONE,
    index = 0,
    checkpoint = 0
}

local recordedCheckpoints = {

}
-- == Don't Touch == --

-- Main commands for races
RegisterCommand("race", function(source, args)
    if args[1] == "clear" or args[1] == "leave" then
        if raceStatus.state == RACE_STATE_JOINED or raceStatus.state == RACE_STATE_RACING then
            cleanupRace()
            TriggerServerEvent('esx_races:leaveRace', raceStatus.index)
        end
    raceStatus.index = 0
    raceStatus.checkpoint = 0
    raceStatus.state = RACE_STATE_NONE
    elseif args[1] == "start" then
        local amount = tonumber(args[2])
        if amount then
            local startDelay = tonumber(args[3])
            startDelay = config.joinDuration*1000
            local startCoords = GetEntityCoords(GetPlayerPed(-1))
            if IsWaypointActive() then
                local waypointCoords = GetBlipInfoIdCoord(GetFirstBlipInfoId(8))
                local retval, nodeCoords = GetClosestVehicleNode(waypointCoords.x, waypointCoords.y, waypointCoords.z, 1)
                table.insert(recordedCheckpoints, {blip = nil, coords = nodeCoords})
                TriggerServerEvent('esx_races:createRace', amount, startDelay, startCoords, recordedCheckpoints)
                ESX.ShowNotification(race_started)
            else 
            	ESX.ShowNotification(no_waypoint)
            end
            raceStatus.state = RACE_STATE_NONE
        end
    elseif args[1] == "cancel" then
        TriggerServerEvent('esx_races:cancelRace')
		ESX.ShowNotification(race_cancel)
    else
        return
    end
end)

-- Race starting event
RegisterNetEvent("esx_races:createdRace")
AddEventHandler("esx_races:createdRace", function(index, amount, startDelay, startCoords, checkpoints)
    local race = {
        amount = amount,
        started = false,
        startTime = GetGameTimer() + startDelay,
        startCoords = startCoords,
        checkpoints = checkpoints
    }
    races[index] = race
end)

-- Race join event
RegisterNetEvent("esx_races:JoinedRace")
AddEventHandler("esx_races:JoinedRace", function(index)
    raceStatus.index = index
    raceStatus.state = RACE_STATE_JOINED
    local race = races[index]
    local checkpoints = race.checkpoints
	    for index, checkpoint in pairs(checkpoints) do
	        checkpoint.blip = AddBlipForCoord(checkpoint.coords.x, checkpoint.coords.y, checkpoint.coords.z)
	        SetBlipColour(checkpoint.blip, config.checkpointBlipColor)
	        SetBlipAsShortRange(checkpoint.blip, true)
	        ShowNumberOnBlip(checkpoint.blip, index)
	        ESX.ShowNotification(race_joined)
	    end
    SetWaypointOff()
    SetBlipRoute(checkpoints[1].blip, true)
    SetBlipRouteColour(checkpoints[1].blip, config.checkpointBlipColor)
end)

-- Main thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local player = GetPlayerPed(-1)

        if IsPedInAnyVehicle(player, false) then
            local position = GetEntityCoords(player)
            local vehicle = GetVehiclePedIsIn(player, false)

            if raceStatus.state == RACE_STATE_RACING then
                local race = races[raceStatus.index]
	                if raceStatus.checkpoint == 0 then
	                    raceStatus.checkpoint = 1
				 local checkpoint = race.checkpoints[raceStatus.checkpoint]

	                    if 25 > 0 then
	                        local checkpointType = raceStatus.checkpoint < #race.checkpoints and RACE_CHECKPOINT_TYPE or RACE_CHECKPOINT_FINISH_TYPE
	                        checkpoint.checkpoint = CreateCheckpoint(checkpointType, checkpoint.coords.x,  checkpoint.coords.y, checkpoint.coords.z, 0, 0, 0, 25.0, 255, 255, 0, 127, 0)
	                        SetCheckpointCylinderHeight(checkpoint.checkpoint, 10.0, 10.0, 25.0)
	                    end
                    SetBlipRoute(checkpoint.blip, true)
                    SetBlipRouteColour(checkpoint.blip, config.checkpointBlipColor)
                else
                    local checkpoint = race.checkpoints[raceStatus.checkpoint]
	                    if GetDistanceBetweenCoords(position.x, position.y, position.z, checkpoint.coords.x, checkpoint.coords.y, 0, false) < 25.0 then
	                        RemoveBlip(checkpoint.blip)
	                        if 25 > 0 then
	                            DeleteCheckpoint(checkpoint.checkpoint)
	                        end   
		                        if raceStatus.checkpoint == #(race.checkpoints) then
		                            PlaySoundFrontend(-1, "RACE_PLACED", "HUD_AWARDS")
		                            local currentTime = (GetGameTimer() - race.startTime)
		                            TriggerServerEvent('esx_races:finishedRace', raceStatus.index, currentTime) 
                            raceStatus.index = 0
                            raceStatus.state = RACE_STATE_NONE
                        else
                            raceStatus.checkpoint = raceStatus.checkpoint + 1
                            local nextCheckpoint = race.checkpoints[raceStatus.checkpoint]
                                if config_cl.checkpointRadius > 0 then
                                    local checkpointType = raceStatus.checkpoint < #race.checkpoints and RACE_CHECKPOINT_TYPE or RACE_CHECKPOINT_FINISH_TYPE
                                    nextCheckpoint.checkpoint = CreateCheckpoint(checkpointType, nextCheckpoint.coords.x,  nextCheckpoint.coords.y, nextCheckpoint.coords.z, 0, 0, 0, config_cl.checkpointRadius, 255, 255, 0, 127, 0)
                                    SetCheckpointCylinderHeight(nextCheckpoint.checkpoint, config_cl.checkpointHeight, config_cl.checkpointHeight, config_cl.checkpointRadius)
                                end
                            SetBlipRoute(nextCheckpoint.blip, true)
                            SetBlipRouteColour(nextCheckpoint.blip, config_cl.checkpointBlipColor)
                        end
                    end
                end

                if config.hudEnabled then
                    Draw2DText(config.hudPosition.x, config.hudPosition.y, ("RACE IN PROGRESS"):format(timeMinutes, timeSeconds), 0.7)
                    local checkpoint = race.checkpoints[raceStatus.checkpoint]
                    local checkpointDist = math.floor(GetDistanceBetweenCoords(position.x, position.y, position.z, checkpoint.coords.x, checkpoint.coords.y, 0, false))
                    Draw2DText(config.hudPosition.x, config.hudPosition.y + 0.04, ("~y~FINISH %d/%d (%dm)"):format(raceStatus.checkpoint, #race.checkpoints, checkpointDist), 0.5)
                end
            elseif raceStatus.state == RACE_STATE_JOINED then
                local race = races[raceStatus.index]
                local currentTime = GetGameTimer()
                local count = race.startTime - currentTime
                if count <= 0 then
                    raceStatus.state = RACE_STATE_RACING
                    raceStatus.checkpoint = 0
                    FreezeEntityPosition(vehicle, false)
                elseif count <= config.freezeDuration*1000 then
                    Draw2DText(0.5, 0.4, ("~y~%d"):format(math.ceil(count/1000.0)), 3.0)
                    FreezeEntityPosition(vehicle, true)
                else
                    local temp, zCoord = GetGroundZFor_3dCoord(race.startCoords.x, race.startCoords.y, 9999.9, 1)
                    Draw3DText(race.startCoords.x, race.startCoords.y, zCoord+1.0, ("Võidusõit osalustasuga ~g~$%d~w~ algab: ~y~%d~w~s pärast."):format(race.amount, math.ceil(count/1000.0)))
                    Draw3DText(race.startCoords.x, race.startCoords.y, zCoord+0.80, "Joined")
                end
            else
                for index, race in pairs(races) do
                    local currentTime = GetGameTimer()
                    local proximity = GetDistanceBetweenCoords(position.x, position.y, position.z, race.startCoords.x, race.startCoords.y, race.startCoords.z, true)
	                    if proximity < 5 and currentTime < race.startTime then
	                        local count = math.ceil((race.startTime - currentTime)/1000.0)
	                        local temp, zCoord = GetGroundZFor_3dCoord(race.startCoords.x, race.startCoords.y, 9999.9, 0)
	                        Draw3DText(race.startCoords.x, race.startCoords.y, zCoord+1.0, ("Võidusõit osalustasuga ~g~$%d~w~ algab: ~y~%d~w~s pärast."):format(race.amount, count))
	                        Draw3DText(race.startCoords.x, race.startCoords.y, zCoord+0.80, "Vajuta [~g~E~w~] et ühineda")
                        if IsControlJustReleased(1, 51) then
                            TriggerServerEvent('esx_races:JoinRace', index)
                            break
                        end
                    end
                end
            end  
        end
    end
end)

-- Making sure not to use any other checkpoints but the waypoint
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)
        if raceStatus.state == RACE_STATE_RECORDING then
            if IsWaypointActive() then
                local waypointCoords = GetBlipInfoIdCoord(GetFirstBlipInfoId(8))
                local retval, coords = GetClosestVehicleNode(waypointCoords.x, waypointCoords.y, waypointCoords.z, 1)
                SetWaypointOff()
                    for index, checkpoint in pairs(recordedCheckpoints) do
                        if GetDistanceBetweenCoords(coords.x, coords.y, coords.z, checkpoint.coords.x, checkpoint.coords.y, checkpoint.coords.z, false) < 1.0 then
                            RemoveBlip(checkpoint.blip)
                            table.remove(recordedCheckpoints, index)
                            coords = nil
                            for i = index, #recordedCheckpoints do
                                ShowNumberOnBlip(recordedCheckpoints[i].blip, i)
                            end
                            break
                        end
                    end
                if (coords ~= nil) then
                    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
                    SetBlipColour(blip, config_cl.checkpointBlipColor)
                    SetBlipAsShortRange(blip, true)
                    ShowNumberOnBlip(blip, #recordedCheckpoints+1)
                    table.insert(recordedCheckpoints, {blip = blip, coords = coords})
                end
            end
        else
            cleanupRecording()
        end
    end
end)

-- Helper functions
function cleanupRace()
    if raceStatus.index ~= 0 then
        local race = races[raceStatus.index]
        local checkpoints = race.checkpoints
        for _, checkpoint in pairs(checkpoints) do
            if checkpoint.blip then
                RemoveBlip(checkpoint.blip)
            end
            if checkpoint.checkpoint then
                DeleteCheckpoint(checkpoint.checkpoint)
            end
        end
	        if raceStatus.state == RACE_STATE_RACING then
	            local lastCheckpoint = checkpoints[#checkpoints]
	            SetNewWaypoint(lastCheckpoint.coords.x, lastCheckpoint.coords.y)
	        end
        local vehicle = GetVehiclePedIsIn(GetPlayerPed(-1), false)
        FreezeEntityPosition(vehicle, false)
    end
end

function cleanupRecording()
    for _, checkpoint in pairs(recordedCheckpoints) do
        RemoveBlip(checkpoint.blip)
        checkpoint.blip = nil
    end
    recordedCheckpoints = {}
end

function Draw3DText(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        local dist = GetDistanceBetweenCoords(GetGameplayCamCoords(), x, y, z, 1)
        local scale = 1.8*(1/dist)*(1/GetGameplayCamFov())*100
        SetTextScale(scale, scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 255)
        SetTextDropShadow(0, 0, 0, 0,255)
        SetTextDropShadow()
        SetTextEdge(4, 0, 0, 0, 255)
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

function Draw2DText(x, y, text, scale)
    SetTextFont(4)
    SetTextProportional(7)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextDropShadow(0, 0, 0, 0,255)
    SetTextDropShadow()
    SetTextEdge(4, 0, 0, 0, 255)
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

-- Add helper comments to the chat command
Citizen.CreateThread(function()
	TriggerEvent('chat:addSuggestion', '/race start', ('Create a race!'), { { name = ('price'), help = ('Make sure you have a waypoint set!') } } )
end)