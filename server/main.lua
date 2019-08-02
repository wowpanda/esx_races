local races = {}

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)
        for index, race in pairs(races) do
            local time = GetGameTimer()
            local players = race.players
            if (time > race.startTime) and (#players == 0) then
                table.remove(races, index)
                TriggerClientEvent("esx_races:removeRace", -1, index)
            elseif (race.finishTime ~= 0) and (time > race.finishTime + race.finishTimeout) then
                for _, player in pairs(players) do
                    notifyPlayer(player, "DNF (timeout)")
                end
                table.remove(races, index)
                TriggerClientEvent("esx_races:removeRace", -1, index)
            end
        end
    end
end)

-- Race creating event
RegisterNetEvent("esx_races:createRace")
AddEventHandler("esx_races:createRace", function(amount, startDelay, startCoords, checkpoints, finishTimeout)
    local race = {
        owner = source,
        amount = amount,
        startTime = GetGameTimer() + startDelay,
        startCoords = startCoords,
        checkpoints = checkpoints,
        finishTimeout = config.delete_race*1000,
        players = {},
        prize = 0,
        finishTime = 0
    }
    table.insert(races, race)
    local index = #races
    TriggerClientEvent("esx_races:createdRace", -1, index, amount, startDelay, startCoords, checkpoints)
end)

-- Race cancel event
RegisterNetEvent("esx_races:cancelRace")
AddEventHandler("esx_races:cancelRace", function()
    for index, race in pairs(races) do
        local time = GetGameTimer()
        if source == race.owner and time < race.startTime then
            for _, player in pairs(race.players) do
                addMoney(player, race.amount)
                race.prize = race.prize - race.amount
                exports['mythic_notify']:DoHudText('inform', 'Võidusõit tühistati')
            end
            table.remove(races, index)
            TriggerClientEvent("esx_races:removeRace", -1, index)
        end
    end
end)

-- Race Join Event
RegisterNetEvent("esx_races:JoinRace")
AddEventHandler("esx_races:JoinRace", function(index)
    local race = races[index]
    local amount = race.amount
    local playerMoney = getMoney(source)
    if playerMoney >= amount then
        removeMoney(source, amount)
        race.prize = race.prize + amount
        table.insert(races[index].players, source)
        TriggerClientEvent("esx_races:JoinedRace", source, index)
    else
		exports['mythic_notify']:DoHudText('error', 'Sul ei ole piisavalt raha, et ühineda')
    end
end)

-- Race leaving event
RegisterNetEvent("esx_races:leaveRace")
AddEventHandler("esx_races:leaveRace", function(index)
    local race = races[index]
    local players = race.players
    for index, player in pairs(players) do
        if source == player then
            table.remove(players, index)
            break
        end
    end
end)

-- Race finish event
RegisterNetEvent("esx_races:finishedRace")
AddEventHandler("esx_races:finishedRace", function(index, time)
    local race = races[index]
    local players = race.players
    for index, player in pairs(players) do
        if source == player then 
            local time = GetGameTimer()
            local timeSeconds = (time - race.startTime)/1000.0
            local timeMinutes = math.floor(timeSeconds/60.0)
            timeSeconds = timeSeconds - 60.0*timeMinutes
	            if race.finishTime == 0 then
	                race.finishTime = time
	                addMoney(source, race.prize)
                for _, pSource in pairs(players) do
                    if pSource == source then
                        local msg = ("You won! Time: [%02d:%06.3f]"):format(timeMinutes, timeSeconds)
                        notifyPlayer(pSource, msg)
                    elseif config.notifyOfWinner then
                        local msg = ("%s won! Time: [%02d:%06.3f]"):format(getName(source), timeMinutes, timeSeconds)
                        notifyPlayer(pSource, msg)
                    end
                end
            else
                local msg = ("You lost! Time: [%02d:%06.3f]"):format(timeMinutes, timeSeconds)
                notifyPlayer(source, msg)
            end
            table.remove(players, index)
            break
        end
    end
end)