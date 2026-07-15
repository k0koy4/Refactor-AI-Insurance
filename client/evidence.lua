--[[
    evidence.lua (client)
    Comprehensive evidence collection on the client side.
    Collects detailed vehicle, accident, and occupant information.
]]

-- Collect comprehensive vehicle information
function CollectVehicleInfo(veh)
    local info = {}
    
    -- Basic vehicle info
    info.model = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
    info.plate = GetVehicleNumberPlateText(veh)
    info.class = GetVehicleClass(veh)
    
    -- Vehicle health
    info.engine_health = GetVehicleEngineHealth(veh)
    info.body_health = GetVehicleBodyHealth(veh)
    info.fuel_tank_health = GetVehiclePetrolTankHealth(veh)
    
    -- Tire condition
    info.tire_condition = {}
    for i = 0, 7 do
        local tireHealth = GetVehicleTyreHealth(veh, i)
        local tireName = GetTyreName(i)
        if tireName then
            info.tire_condition[tireName] = tireHealth
        end
    end
    
    -- Door damage
    info.door_damage = {}
    for i = 0, 5 do
        local doorStatus = IsVehicleDoorDamaged(veh, i)
        local doorName = GetDoorName(i)
        if doorName then
            info.door_damage[doorName] = doorStatus and 0 or 1000
        end
    end
    
    -- Window damage
    info.window_damage = {}
    for i = 0, 7 do
        local windowStatus = IsVehicleWindowIntact(veh, i)
        local windowName = GetWindowName(i)
        if windowName then
            info.window_damage[windowName] = windowStatus and 1000 or 0
        end
    end
    
    -- Vehicle state
    info.is_drivable = IsVehicleDriveable(veh, false)
    
    return info
end

local function DetermineImpactSeverity(speed)
    if speed >= 50 then
        return 'high'
    elseif speed >= 25 then
        return 'moderate'
    end
    return 'low'
end

function DetectImpactContext(veh, impactSpeed)
    local coords = GetEntityCoords(veh)
    local speed = tonumber(impactSpeed or GetEntitySpeed(veh) * 2.236936) or 0
    local involvesPlayer = false
    local involvesEntity = false
    local playerCount = 0
    local playerPed = PlayerPedId()

    for _, playerId in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(playerId)
        if ped and ped ~= playerPed then
            local pedCoords = GetEntityCoords(ped)
            if Vdist(coords.x, coords.y, coords.z, pedCoords.x, pedCoords.y, pedCoords.z) <= 8.0 then
                involvesPlayer = true
                involvesEntity = true
                playerCount = playerCount + 1
            end
        end
    end

    local closestVehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 12.0, 0, 70)
    if closestVehicle and closestVehicle ~= veh then
        local vehicleCoords = GetEntityCoords(closestVehicle)
        if Vdist(coords.x, coords.y, coords.z, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z) <= 10.0 then
            involvesEntity = true
        end
    end

    local impactType = 'unknown'
    if involvesPlayer then
        impactType = 'player'
    elseif involvesEntity then
        impactType = 'entity'
    else
        impactType = 'world'
    end

    local livable = true
    if involvesPlayer then
        livable = false
    elseif speed >= 45 then
        livable = false
    elseif involvesEntity and speed >= 35 then
        livable = false
    end

    return {
        type = impactType,
        category = involvesPlayer and 'player_impact' or (involvesEntity and 'entity_impact' or 'world_geometry'),
        involves_player = involvesPlayer,
        involves_entity = involvesEntity,
        involves_world_geometry = not involvesEntity,
        livable = livable,
        severity = DetermineImpactSeverity(speed),
        nearby_player_count = playerCount
    }
end

-- Collect comprehensive accident information
function CollectAccidentInfo(veh, impactSpeed)
    local info = {}
    local coords = GetEntityCoords(veh)
    local ped = PlayerPedId()
    
    -- Location
    info.gps_location = {
        x = coords.x,
        y = coords.y,
        z = coords.z
    }
    info.street_name = GetStreetNameFromCoords(coords)
    
    -- Time and date
    local time = GetClockHours()
    info.time = string.format('%02d:%02d', time, GetClockMinutes())
    info.date = os.date('%Y-%m-%d')
    
    -- Weather
    info.weather = GetCurrentWeather()
    
    -- Road type (simplified - could be expanded with zone detection)
    info.road_type = DetectRoadType(coords)
    
    -- Speed data
    local currentSpeed = GetEntitySpeed(veh) * 2.236936 -- m/s to mph
    info.speed_before_impact = currentSpeed
    info.speed_at_impact = impactSpeed or currentSpeed
    
    -- Collision details (these would need to be tracked during the collision event)
    info.number_of_impacts = 1 -- Default, could be tracked
    info.impact_direction = DetectImpactDirection(veh)

    local impactContext = DetectImpactContext(veh, impactSpeed)
    info.impact_context = impactContext
    info.impact_type = impactContext.type
    info.impact_category = impactContext.category
    info.impact_involves_player = impactContext.involves_player
    info.impact_involves_entity = impactContext.involves_entity
    info.impact_involves_world_geometry = impactContext.involves_world_geometry
    info.impact_livable = impactContext.livable
    info.impact_severity = impactContext.severity
    
    -- Vehicle state after accident
    info.rollovers = HasVehicleRolledOver(veh)
    info.airbag_deployed = HasAirbagDeployed() -- This would need to be tracked
    info.vehicle_flipped = IsVehicleUpsideDown(veh)
    info.engine_stalled = info.engine_health < 100
    
    -- Fire/explosion (these would need to be tracked)
    info.fire = false
    info.explosion = false
    
    -- Occupant information
    info.occupants = CountOccupants(veh)
    info.seatbelt_status = IsPedWearingSeatbelt(ped)
    info.driver_ejected = false -- Would need to be tracked
    info.vehicle_drivable = IsVehicleDriveable(veh, false)
    
    return info
end

-- Helper functions

function GetTyreName(index)
    local names = {
        [0] = 'Front Left',
        [1] = 'Front Right',
        [2] = 'Rear Left',
        [3] = 'Rear Right',
        [4] = 'Front Left 2',
        [5] = 'Front Right 2',
        [6] = 'Rear Left 2',
        [7] = 'Rear Right 2'
    }
    return names[index]
end

function GetDoorName(index)
    local names = {
        [0] = 'Driver Door',
        [1] = 'Passenger Door',
        [2] = 'Rear Left Door',
        [3] = 'Rear Right Door',
        [4] = 'Hood',
        [5] = 'Trunk'
    }
    return names[index]
end

function GetWindowName(index)
    local names = {
        [0] = 'Front Left Window',
        [1] = 'Front Right Window',
        [2] = 'Rear Left Window',
        [3] = 'Rear Right Window',
        [4] = 'Front Windshield',
        [5] = 'Rear Windshield'
    }
    return names[index]
end

function GetStreetNameFromCoords(coords)
    local street1, street2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street1Name = GetStreetNameFromHashKey(street1)
    local street2Name = GetStreetNameFromHashKey(street2)
    
    if street2Name and street2Name ~= '' then
        return street1Name .. ' & ' .. street2Name
    end
    return street1Name or 'Unknown Street'
end

function GetCurrentWeather()
    -- This is a simplified version - actual implementation would depend on weather script
    local weathers = {'clear', 'extrasunny', 'clouds', 'overcast', 'rain', 'clearing', 'thunder', 'smog', 'foggy'}
    -- In a real implementation, you'd query your weather system
    return 'clear' -- Placeholder
end

function DetectRoadType(coords)
    -- Simplified road type detection based on zone
    local zone = GetNameOfZone(coords.x, coords.y, coords.z)
    local zoneName = GetLabelText(zone)
    
    if zoneName:find('highway') or zoneName:find('freeway') or zoneName:find('interstate') then
        return 'highway'
    elseif zoneName:find('residential') or zoneName:find('suburban') then
        return 'residential'
    elseif zoneName:find('downtown') or zoneName:find('city') then
        return 'urban'
    elseif zoneName:find('rural') or zoneName:find('country') then
        return 'rural'
    end
    
    return 'unknown'
end

function DetectImpactDirection(veh)
    -- This would need to be calculated based on collision normal
    -- For now, return a placeholder
    return 'front'
end

function HasVehicleRolledOver(veh)
    -- Check if vehicle has rolled over (simplified)
    local rotation = GetEntityRotation(veh)
    return math.abs(rotation.x) > 90 or math.abs(rotation.y) > 90
end

function HasAirbagDeployed()
    -- This would need to be tracked during collision event
    -- For now, return false
    return false
end

function CountOccupants(veh)
    local count = 0
    for i = -1, 6 do
        if IsPedInVehicle(veh, GetPedInVehicleSeat(veh, i), false) then
            count = count + 1
        end
    end
    return count
end

function IsPedWearingSeatbelt(ped)
    -- This would need to be tracked by your vehicle system
    -- For now, return true as a safe default
    return true
end

-- Export functions
exports('CollectVehicleInfo', CollectVehicleInfo)
exports('CollectAccidentInfo', CollectAccidentInfo)
