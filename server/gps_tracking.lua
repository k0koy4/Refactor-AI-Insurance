--[[
    gps_tracking.lua (server)
    Real-time GPS tracking for insurance claims.
    Records vehicle location data during and after accidents.
]]

-- Active tracking sessions
local activeTracking = {}

-- Start GPS tracking for a vehicle
function StartGPSTracking(claimId, citizenid, vehiclePlate, trackingType)
    if not claimId or not citizenid then
        return false, 'Missing claim ID or citizen ID'
    end

    local trackingId = claimId .. '_' .. os.time()
    activeTracking[trackingId] = {
        claim_id = claimId,
        citizenid = citizenid,
        vehicle_plate = vehiclePlate,
        tracking_type = trackingType or 'accident',
        start_time = os.time(),
        points = {}
    }

    return true, trackingId
end

-- Record a GPS point
function RecordGPSPoint(trackingId, latitude, longitude, altitude, speed, heading)
    if not activeTracking[trackingId] then
        return false, 'Tracking session not found'
    end

    local tracking = activeTracking[trackingId]
    local point = {
        latitude = latitude,
        longitude = longitude,
        altitude = altitude,
        speed = speed,
        heading = heading,
        timestamp = os.time()
    }

    table.insert(tracking.points, point)

    -- Also save to database immediately for real-time tracking
    MySQL.insert([[
        INSERT INTO insurance_gps_tracking
        (claim_id, citizenid, vehicle_plate, latitude, longitude, altitude, speed, heading, timestamp, tracking_type)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), ?)
    ]], {
        tracking.claim_id,
        tracking.citizenid,
        tracking.vehicle_plate,
        latitude,
        longitude,
        altitude,
        speed,
        heading,
        tracking.tracking_type
    })

    return true, #tracking.points
end

-- Stop GPS tracking
function StopGPSTracking(trackingId)
    if not activeTracking[trackingId] then
        return false, 'Tracking session not found'
    end

    local tracking = activeTracking[trackingId]
    local summary = {
        tracking_id = trackingId,
        claim_id = tracking.claim_id,
        citizenid = tracking.citizenid,
        vehicle_plate = tracking.vehicle_plate,
        tracking_type = tracking.tracking_type,
        start_time = tracking.start_time,
        end_time = os.time(),
        total_points = #tracking.points,
        duration = os.time() - tracking.start_time
    }

    activeTracking[trackingId] = nil
    return true, summary
end

-- Get GPS tracking data for a claim
function GetGPSTrackingData(claimId, cb)
    MySQL.query('SELECT * FROM insurance_gps_tracking WHERE claim_id = ? ORDER BY timestamp ASC', { claimId }, function(rows)
        cb(rows or {})
    end)
end

-- Analyze GPS data for accident reconstruction
function AnalyzeGPSData(claimId, cb)
    GetGPSTrackingData(claimId, function(gpsData)
        if #gpsData == 0 then
            cb({ has_data = false })

            return
        end

        local analysis = {
            has_data = true,
            total_points = #gpsData,
            start_time = gpsData[1].timestamp,
            end_time = gpsData[#gpsData].timestamp,
            duration_seconds = os.difftime(gpsData[#gpsData].timestamp, gpsData[1].timestamp),
            
            -- Speed analysis
            max_speed = 0,
            average_speed = 0,
            speed_samples = {},
            
            -- Location analysis
            start_location = { lat = gpsData[1].latitude, lon = gpsData[1].longitude, alt = gpsData[1].altitude },
            end_location = { lat = gpsData[#gpsData].latitude, lon = gpsData[#gpsData].longitude, alt = gpsData[#gpsData].altitude },
            
            -- Path analysis
            total_distance = 0,
            heading_changes = 0,
            
            -- Events
            sudden_stops = 0,
            rapid_accelerations = 0,
            sharp_turns = 0
        }

        -- Calculate statistics
        local totalSpeed = 0
        local lastSpeed = nil
        local lastHeading = nil
        local lastLocation = nil

        for i, point in ipairs(gpsData) do
            local speed = point.speed or 0
            totalSpeed = totalSpeed + speed
            
            if speed > analysis.max_speed then
                analysis.max_speed = speed
            end

            -- Detect sudden stops
            if lastSpeed and (lastSpeed - speed) > 20 then
                analysis.sudden_stops = analysis.sudden_stops + 1
            end

            -- Detect rapid acceleration
            if lastSpeed and (speed - lastSpeed) > 15 then
                analysis.rapid_accelerations = analysis.rapid_accelerations + 1
            end

            -- Detect sharp turns
            if lastHeading then
                local headingDiff = math.abs(point.heading - lastHeading)
                if headingDiff > 45 then
                    analysis.sharp_turns = analysis.sharp_turns + 1
                end
            end

            -- Calculate distance
            if lastLocation then
                local distance = CalculateDistance(
                    lastLocation.lat, lastLocation.lon,
                    point.latitude, point.longitude
                )
                analysis.total_distance = analysis.total_distance + distance
            end

            lastSpeed = speed
            lastHeading = point.heading
            lastLocation = { lat = point.latitude, lon = point.longitude }
        end

        analysis.average_speed = totalSpeed / #gpsData

        -- Generate insights
        analysis.insights = {}
        if analysis.sudden_stops > 0 then
            table.insert(analysis.insights, string.format('%d sudden stop(s) detected', analysis.sudden_stops))
        end
        if analysis.rapid_accelerations > 0 then
            table.insert(analysis.insights, string.format('%d rapid acceleration event(s) detected', analysis.rapid_accelerations))
        end
        if analysis.sharp_turns > 0 then
            table.insert(analysis.insights, string.format('%d sharp turn(s) detected', analysis.sharp_turns))
        end
        if analysis.max_speed > 80 then
            table.insert(analysis.insights, string.format('High speed detected: %.1f mph', analysis.max_speed))
        end

        cb(analysis)
    end)
end

-- Helper function to calculate distance between two points (Haversine formula)
function CalculateDistance(lat1, lon1, lat2, lon2)
    local R = 3959 -- Earth's radius in miles
    local dLat = math.rad(lat2 - lat1)
    local dLon = math.rad(lon2 - lon1)
    local a = math.sin(dLat / 2) * math.sin(dLat / 2) +
              math.cos(math.rad(lat1)) * math.cos(math.rad(lat2)) *
              math.sin(dLon / 2) * math.sin(dLon / 2)
    local c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c
end

-- Event handlers
RegisterNetEvent('ai_insurance_adjuster:startGPSTracking', function(claimId, vehiclePlate, trackingType)
    local src = source
    local citizenid = GetPlayerIdentifier(src, 0) or tostring(src)
    local ok, result = StartGPSTracking(claimId, citizenid, vehiclePlate, trackingType)
    if ok then
        TriggerClientEvent('ai_insurance_adjuster:notify', src, 'GPS tracking started.')
        TriggerClientEvent('ai_insurance_adjuster:gpsTrackingStarted', src, result)
    else
        TriggerClientEvent('ai_insurance_adjuster:notify', src, result or 'Could not start GPS tracking.')
    end
end)

RegisterNetEvent('ai_insurance_adjuster:recordGPSPoint', function(trackingId, latitude, longitude, altitude, speed, heading)
    local src = source
    local ok, result = RecordGPSPoint(trackingId, latitude, longitude, altitude, speed, heading)
    if ok then
        -- Silent success, don't spam notifications
    else
        TriggerClientEvent('ai_insurance_adjuster:notify', src, result or 'Could not record GPS point.')
    end
end)

RegisterNetEvent('ai_insurance_adjuster:stopGPSTracking', function(trackingId)
    local src = source
    local ok, summary = StopGPSTracking(trackingId)
    if ok then
        TriggerClientEvent('ai_insurance_adjuster:notify', src, string.format('GPS tracking stopped. %d points recorded.', summary.total_points))
        TriggerClientEvent('ai_insurance_adjuster:gpsTrackingStopped', src, summary)
    else
        TriggerClientEvent('ai_insurance_adjuster:notify', src, summary or 'Could not stop GPS tracking.')
    end
end)

RegisterNetEvent('ai_insurance_adjuster:requestGPSAnalysis', function(claimId)
    local src = source
    AnalyzeGPSData(claimId, function(analysis)
        TriggerClientEvent('ai_insurance_adjuster:gpsAnalysis', src, analysis)
    end)
end)

-- Exports
exports('StartGPSTracking', StartGPSTracking)
exports('RecordGPSPoint', RecordGPSPoint)
exports('StopGPSTracking', StopGPSTracking)
exports('GetGPSTrackingData', GetGPSTrackingData)
exports('AnalyzeGPSData', AnalyzeGPSData)
