--[[
    towing.lua (server)
    Towing service integration for insurance claims.
    Handles tow truck dispatch, coordination, and cost management.
]]

-- Available towing companies
local towingCompanies = {
    { id = 'sandy', name = 'Sandy Shores Towing', base_rate = 150, per_mile_rate = 3.5, phone = '555-0101' },
    { id = 'paleto', name = 'Paleto Bay Towing', base_rate = 200, per_mile_rate = 4.0, phone = '555-0102' },
    { id = 'city', name = 'Los Santos Customs Towing', base_rate = 175, per_mile_rate = 3.0, phone = '555-0103' },
    { id = 'blaine', name = 'Blaine County Roadside', base_rate = 125, per_mile_rate = 2.5, phone = '555-0104' }
}

-- Active towing requests
local activeRequests = {}

-- Calculate towing cost based on distance
function CalculateTowingCost(pickupX, pickupY, dropoffX, dropoffY, companyId)
    local company = towingCompanies[companyId] or towingCompanies[1]
    
    -- Calculate distance (simple Euclidean for now, could use road distance)
    local distance = math.sqrt((dropoffX - pickupX)^2 + (dropoffY - pickupY)^2)
    local distanceMiles = distance / 1000 -- Convert game units to approximate miles
    
    local totalCost = company.base_rate + (distanceMiles * company.per_mile_rate)
    
    return {
        base_rate = company.base_rate,
        distance_miles = distanceMiles,
        per_mile_rate = company.per_mile_rate,
        total_cost = math.ceil(totalCost * 100) / 100, -- Round to 2 decimal places
        company = company
    }
end

-- Request towing service
function RequestTowing(claimId, citizenid, vehiclePlate, pickupLocation, dropoffLocation, companyId)
    if not claimId or not citizenid then
        return false, 'Missing claim ID or citizen ID'
    end

    if not pickupLocation or not pickupLocation.x or not pickupLocation.y then
        return false, 'Invalid pickup location'
    end

    -- Default dropoff to pickup if not specified
    if not dropoffLocation then
        dropoffLocation = pickupLocation
    end

    -- Calculate estimated cost
    local cost = CalculateTowingCost(
        pickupLocation.x, pickupLocation.y,
        dropoffLocation.x, dropoffLocation.y,
        companyId
    )

    -- Save to database
    local requestId = MySQL.insert([[
        INSERT INTO insurance_towing_requests
        (claim_id, citizenid, vehicle_plate, pickup_location_x, pickup_location_y, pickup_location_z,
         dropoff_location_x, dropoff_location_y, dropoff_location_z,
         tow_company, status, estimated_cost, requested_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, NOW())
    ]], {
        claimId,
        citizenid,
        vehiclePlate or 'UNKNOWN',
        pickupLocation.x,
        pickupLocation.y,
        pickupLocation.z or 0,
        dropoffLocation.x,
        dropoffLocation.y,
        dropoffLocation.z or 0,
        cost.company.name,
        cost.total_cost
    })

    -- Cache in memory
    activeRequests[requestId] = {
        id = requestId,
        claim_id = claimId,
        citizenid = citizenid,
        vehicle_plate = vehiclePlate,
        status = 'pending',
        estimated_cost = cost.total_cost
    }

    return true, { request_id = requestId, cost = cost }
end

-- Get towing request status
function GetTowingStatus(requestId, cb)
    MySQL.query('SELECT * FROM insurance_towing_requests WHERE id = ?', { requestId }, function(rows)
        if rows and #rows > 0 then
            local request = rows[1]
            cb({
                id = request.id,
                claim_id = request.claim_id,
                vehicle_plate = request.vehicle_plate,
                status = request.status,
                tow_company = request.tow_company,
                driver_name = request.driver_name,
                estimated_cost = request.estimated_cost,
                actual_cost = request.actual_cost,
                requested_at = request.requested_at,
                completed_at = request.completed_at
            })
        else
            cb(nil)
        end
    end)
end

-- Update towing request status
function UpdateTowingStatus(requestId, status, driverName, actualCost)
    local updates = { status = status }
    local values = { status, requestId }

    if driverName then
        MySQL.query('UPDATE insurance_towing_requests SET driver_name = ? WHERE id = ?', { driverName, requestId })
    end

    if actualCost then
        MySQL.query('UPDATE insurance_towing_requests SET actual_cost = ? WHERE id = ?', { actualCost, requestId })
    end

    if status == 'completed' then
        MySQL.query('UPDATE insurance_towing_requests SET completed_at = NOW() WHERE id = ?', { requestId })
    end

    MySQL.query('UPDATE insurance_towing_requests SET status = ? WHERE id = ?', values)

    -- Update cache
    if activeRequests[requestId] then
        activeRequests[requestId].status = status
    end

    return true
end

-- Get available towing companies
function GetTowingCompanies()
    return towingCompanies
end

-- Get towing history for a citizen
function GetTowingHistory(citizenid, limit, cb)
    local count = tonumber(limit) or 10
    MySQL.query('SELECT * FROM insurance_towing_requests WHERE citizenid = ? ORDER BY requested_at DESC LIMIT ?', { citizenid, count }, function(rows)
        cb(rows or {})
    end)
end

-- Event handlers
RegisterNetEvent('ai_insurance_adjuster:requestTowing', function(claimId, vehiclePlate, pickupLocation, dropoffLocation, companyId)
    local src = source
    local citizenid = GetPlayerIdentifier(src, 0) or tostring(src)
    local ok, result = RequestTowing(claimId, citizenid, vehiclePlate, pickupLocation, dropoffLocation, companyId)
    if ok then
        TriggerClientEvent('ai_insurance_adjuster:notify', src, string.format('Towing requested. Estimated cost: $%.2f', result.cost.total_cost))
        TriggerClientEvent('ai_insurance_adjuster:towingRequested', src, result)
    else
        TriggerClientEvent('ai_insurance_adjuster:notify', src, result or 'Could not request towing.')
    end
end)

RegisterNetEvent('ai_insurance_adjuster:getTowingStatus', function(requestId)
    local src = source
    GetTowingStatus(requestId, function(status)
        TriggerClientEvent('ai_insurance_adjuster:towingStatus', src, status)
    end)
end)

RegisterNetEvent('ai_insurance_adjuster:getTowingCompanies', function()
    local src = source
    TriggerClientEvent('ai_insurance_adjuster:towingCompanies', src, GetTowingCompanies())
end)

RegisterNetEvent('ai_insurance_adjuster:getTowingHistory', function(limit)
    local src = source
    local citizenid = GetPlayerIdentifier(src, 0) or tostring(src)
    GetTowingHistory(citizenid, limit, function(history)
        TriggerClientEvent('ai_insurance_adjuster:towingHistory', src, history)
    end)
end)

-- Admin event to update towing status (would be called by tow truck job)
RegisterNetEvent('ai_insurance_adjuster:updateTowingStatus', function(requestId, status, driverName, actualCost)
    local src = source
    -- HOOK: Add admin permission check here
    UpdateTowingStatus(requestId, status, driverName, actualCost)
    TriggerClientEvent('ai_insurance_adjuster:notify', src, string.format('Towing request %s.', status))
end)

-- Exports
exports('RequestTowing', RequestTowing)
exports('GetTowingStatus', GetTowingStatus)
exports('UpdateTowingStatus', UpdateTowingStatus)
exports('GetTowingCompanies', GetTowingCompanies)
exports('GetTowingHistory', GetTowingHistory)
