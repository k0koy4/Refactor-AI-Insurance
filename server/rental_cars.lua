--[[
    rental_cars.lua (server)
    Rental car coordination for insurance claims.
    Handles rental car booking, coverage verification, and cost management.
]]

-- Available rental companies
local rentalCompanies = {
    { id = 'budget', name = 'Budget Rentals', base_rate = 35, luxury_rate = 75, suv_rate = 55, phone = '555-0201' },
    { id = 'enterprise', name = 'Enterprise Rent-A-Car', base_rate = 40, luxury_rate = 85, suv_rate = 60, phone = '555-0202' },
    { id = 'hertz', name = 'Hertz', base_rate = 45, luxury_rate = 95, suv_rate = 65, phone = '555-0203' },
    { id = 'avis', name = 'Avis', base_rate = 42, luxury_rate = 90, suv_rate = 62, phone = '555-0204' }
}

-- Coverage types
local coverageTypes = {
    { id = 'basic', name = 'Basic Coverage', daily_multiplier = 1.0, deductible = 500 },
    { id = 'standard', name = 'Standard Coverage', daily_multiplier = 1.2, deductible = 250 },
    { id = 'premium', name = 'Premium Coverage', daily_multiplier = 1.5, deductible = 0 }
}

-- Calculate rental cost
function CalculateRentalCost(pickupDate, returnDate, vehicleType, coverageType, companyId)
    local company = rentalCompanies[companyId] or rentalCompanies[1]
    local coverage = coverageTypes[coverageType] or coverageTypes[1]

    -- Calculate number of days
    local pickupTime = os.time(pickupDate)
    local returnTime = os.time(returnDate)
    local days = math.ceil(os.difftime(returnTime, pickupTime) / 86400)
    
    if days < 1 then
        days = 1
    end

    -- Get daily rate based on vehicle type
    local dailyRate = company.base_rate
    if vehicleType == 'luxury' then
        dailyRate = company.luxury_rate
    elseif vehicleType == 'suv' then
        dailyRate = company.suv_rate
    end

    -- Apply coverage multiplier
    local adjustedRate = dailyRate * coverage.daily_multiplier
    local totalCost = adjustedRate * days

    return {
        company = company,
        coverage = coverage,
        vehicle_type = vehicleType,
        daily_rate = dailyRate,
        adjusted_rate = adjustedRate,
        days = days,
        total_cost = math.ceil(totalCost * 100) / 100,
        deductible = coverage.deductible
    }
end

-- Check if rental is covered by policy
function CheckRentalCoverage(policyTier, cb)
    -- Get policy tier details
    GetPolicyTier(policyTier, function(policy)
        if policy then
            cb({
                covered = policy.rental_reimbursement or false,
                max_daily_rate = policy.rental_reimbursement and 50 or 0,
                max_days = policy.rental_reimbursement and 7 or 0
            })
        else
            cb({ covered = false, max_daily_rate = 0, max_days = 0 })
        end
    end)
end

-- Request rental car
function RequestRentalCar(claimId, citizenid, pickupDate, returnDate, vehicleType, coverageType, companyId)
    if not claimId or not citizenid then
        return false, 'Missing claim ID or citizen ID'
    end

    if not pickupDate or not returnDate then
        return false, 'Invalid rental dates'
    end

    -- Calculate cost
    local cost = CalculateRentalCost(pickupDate, returnDate, vehicleType, coverageType, companyId)

    -- Save to database
    local requestId = MySQL.insert([[
        INSERT INTO insurance_rental_cars
        (claim_id, citizenid, rental_company, vehicle_model, pickup_date, return_date,
         daily_rate, total_cost, coverage_type, status, requested_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', NOW())
    ]], {
        claimId,
        citizenid,
        cost.company.name,
        vehicleType,
        pickupDate,
        returnDate,
        cost.adjusted_rate,
        cost.total_cost,
        coverageType
    })

    return true, { request_id = requestId, cost = cost }
end

-- Get rental request status
function GetRentalStatus(requestId, cb)
    MySQL.query('SELECT * FROM insurance_rental_cars WHERE id = ?', { requestId }, function(rows)
        if rows and #rows > 0 then
            local request = rows[1]
            cb({
                id = request.id,
                claim_id = request.claim_id,
                rental_company = request.rental_company,
                vehicle_model = request.vehicle_model,
                pickup_date = request.pickup_date,
                return_date = request.return_date,
                daily_rate = request.daily_rate,
                total_cost = request.total_cost,
                coverage_type = request.coverage_type,
                status = request.status,
                confirmation_number = request.confirmation_number,
                requested_at = request.requested_at,
                confirmed_at = request.confirmed_at
            })
        else
            cb(nil)
        end
    end)
end

-- Update rental request status
function UpdateRentalStatus(requestId, status, confirmationNumber)
    local values = { status, requestId }

    if confirmationNumber then
        MySQL.query('UPDATE insurance_rental_cars SET confirmation_number = ? WHERE id = ?', { confirmationNumber, requestId })
    end

    if status == 'confirmed' then
        MySQL.query('UPDATE insurance_rental_cars SET confirmed_at = NOW() WHERE id = ?', { requestId })
    end

    MySQL.query('UPDATE insurance_rental_cars SET status = ? WHERE id = ?', values)
    return true
end

-- Get rental companies
function GetRentalCompanies()
    return rentalCompanies
end

-- Get coverage types
function GetCoverageTypes()
    return coverageTypes
end

-- Get rental history for a citizen
function GetRentalHistory(citizenid, limit, cb)
    local count = tonumber(limit) or 10
    MySQL.query('SELECT * FROM insurance_rental_cars WHERE citizenid = ? ORDER BY requested_at DESC LIMIT ?', { citizenid, count }, function(rows)
        cb(rows or {})
    end)
end

-- Event handlers
RegisterNetEvent('ai_insurance_adjuster:requestRentalCar', function(claimId, pickupDate, returnDate, vehicleType, coverageType, companyId)
    local src = source
    local citizenid = GetPlayerIdentifier(src, 0) or tostring(src)
    local ok, result = RequestRentalCar(claimId, citizenid, pickupDate, returnDate, vehicleType, coverageType, companyId)
    if ok then
        TriggerClientEvent('ai_insurance_adjuster:notify', src, string.format('Rental car requested. Estimated cost: $%.2f', result.cost.total_cost))
        TriggerClientEvent('ai_insurance_adjuster:rentalRequested', src, result)
    else
        TriggerClientEvent('ai_insurance_adjuster:notify', src, result or 'Could not request rental car.')
    end
end)

RegisterNetEvent('ai_insurance_adjuster:getRentalStatus', function(requestId)
    local src = source
    GetRentalStatus(requestId, function(status)
        TriggerClientEvent('ai_insurance_adjuster:rentalStatus', src, status)
    end)
end)

RegisterNetEvent('ai_insurance_adjuster:getRentalCompanies', function()
    local src = source
    TriggerClientEvent('ai_insurance_adjuster:rentalCompanies', src, GetRentalCompanies())
end)

RegisterNetEvent('ai_insurance_adjuster:getCoverageTypes', function()
    local src = source
    TriggerClientEvent('ai_insurance_adjuster:coverageTypes', src, GetCoverageTypes())
end)

RegisterNetEvent('ai_insurance_adjuster:getRentalHistory', function(limit)
    local src = source
    local citizenid = GetPlayerIdentifier(src, 0) or tostring(src)
    GetRentalHistory(citizenid, limit, function(history)
        TriggerClientEvent('ai_insurance_adjuster:rentalHistory', src, history)
    end)
end)

RegisterNetEvent('ai_insurance_adjuster:checkRentalCoverage', function(policyTier)
    local src = source
    CheckRentalCoverage(policyTier, function(coverage)
        TriggerClientEvent('ai_insurance_adjuster:rentalCoverage', src, coverage)
    end)
end)

-- Admin event to update rental status
RegisterNetEvent('ai_insurance_adjuster:updateRentalStatus', function(requestId, status, confirmationNumber)
    local src = source
    -- HOOK: Add admin permission check here
    UpdateRentalStatus(requestId, status, confirmationNumber)
    TriggerClientEvent('ai_insurance_adjuster:notify', src, string.format('Rental request %s.', status))
end)

-- Exports
exports('RequestRentalCar', RequestRentalCar)
exports('GetRentalStatus', GetRentalStatus)
exports('UpdateRentalStatus', UpdateRentalStatus)
exports('GetRentalCompanies', GetRentalCompanies)
exports('GetCoverageTypes', GetCoverageTypes)
exports('GetRentalHistory', GetRentalHistory)
exports('CheckRentalCoverage', CheckRentalCoverage)
