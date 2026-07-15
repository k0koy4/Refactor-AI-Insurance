--[[
    repair_calculator.lua (server)
    Deterministic repair cost calculation engine.
    Calculates repair costs based on vehicle parts database and damage assessment.
    All calculations are done in Lua - AI only identifies damaged parts.
]]

-- Calculate repair cost for a single part
function CalculatePartRepairCost(partName, severity, action)
    local partInfo = GetPartInfo(partName)
    if not partInfo then
        return {
            part = partName,
            cost = 0,
            labor_cost = 0,
            total_cost = 0,
            error = "part_not_found"
        }
    end

    -- Determine if repair or replacement based on action and part properties
    local isReplacement = action == "replace" or partInfo.replace_only
    
    -- Base cost
    local baseCost = isReplacement and partInfo.replacement_cost or partInfo.repair_cost
    
    -- Severity multiplier
    local severityMultiplier = 1.0
    if severity == "minor" then
        severityMultiplier = 0.5
    elseif severity == "moderate" then
        severityMultiplier = 1.0
    elseif severity == "major" then
        severityMultiplier = 1.5
    elseif severity == "critical" then
        severityMultiplier = 2.0
    end
    
    -- Apply severity multiplier to repair cost (not replacement)
    if not isReplacement then
        baseCost = baseCost * severityMultiplier
    end
    
    -- Calculate labor cost
    local laborRate = GetLaborRate(partInfo.repair_difficulty)
    local laborHours = partInfo.labor_hours * severityMultiplier
    local laborCost = laborRate * laborHours
    
    -- Total cost
    local totalCost = baseCost + laborCost
    
    return {
        part = partName,
        action = isReplacement and "replace" or "repair",
        severity = severity,
        parts_cost = math.floor(baseCost),
        labor_cost = math.floor(laborCost),
        labor_hours = math.floor(laborHours * 10) / 10,
        total_cost = math.floor(totalCost),
        category = partInfo.category
    }
end

function ApplyEconomicBalancing(repairEstimate, vehicleData)
    if not repairEstimate then
        return repairEstimate
    end

    local modifier = 1.0
    local ageYears = tonumber(vehicleData and vehicleData.age_years) or 0
    local mileage = tonumber(vehicleData and vehicleData.mileage) or 0
    local previousRepairs = tonumber(vehicleData and vehicleData.previous_repairs) or 0
    local vehicleValue = tonumber(vehicleData and vehicleData.vehicle_value) or 0

    if ageYears > 8 then
        modifier = modifier * 0.88
    elseif ageYears > 4 then
        modifier = modifier * 0.93
    end

    if mileage > 120000 then
        modifier = modifier * 0.9
    elseif mileage > 60000 then
        modifier = modifier * 0.95
    end

    if previousRepairs > 2 then
        modifier = modifier * 0.92
    elseif previousRepairs > 0 then
        modifier = modifier * 0.96
    end

    if vehicleValue > 0 and repairEstimate.total_cost > vehicleValue * 0.75 then
        modifier = modifier * 0.9
    end

    repairEstimate.parts_cost = math.floor(repairEstimate.parts_cost * modifier)
    repairEstimate.labor_cost = math.floor(repairEstimate.labor_cost * modifier)
    repairEstimate.labor_hours = math.floor(repairEstimate.labor_hours * 10) / 10
    repairEstimate.shop_fee = math.floor(repairEstimate.shop_fee * modifier)
    repairEstimate.environmental_fee = repairEstimate.environmental_fee
    repairEstimate.tax = math.floor((repairEstimate.parts_cost + repairEstimate.labor_cost + repairEstimate.shop_fee + repairEstimate.environmental_fee) * 0.08)
    repairEstimate.subtotal = repairEstimate.parts_cost + repairEstimate.labor_cost + repairEstimate.shop_fee
    repairEstimate.total_cost = repairEstimate.subtotal + repairEstimate.tax + repairEstimate.environmental_fee
    repairEstimate.economic_modifier = modifier

    return repairEstimate
end

-- Calculate total repair estimate from mechanic assessment
function CalculateRepairEstimate(mechanicAssessment, vehicleData)
    local damagedParts = mechanicAssessment.damagedParts or {}
    local totalPartsCost = 0
    local totalLaborCost = 0
    local totalLaborHours = 0
    local itemizedCosts = {}
    
    for _, partAssessment in ipairs(damagedParts) do
        local partName = partAssessment.part
        local severity = partAssessment.severity or "moderate"
        local action = partAssessment.repair or "repair"
        
        local costCalculation = CalculatePartRepairCost(partName, severity, action)
        
        if costCalculation.error then
            print('[repair_calculator] Warning: ' .. costCalculation.error .. ' for part: ' .. partName)
        else
            totalPartsCost = totalPartsCost + costCalculation.parts_cost
            totalLaborCost = totalLaborCost + costCalculation.labor_cost
            totalLaborHours = totalLaborHours + costCalculation.labor_hours
            table.insert(itemizedCosts, costCalculation)
        end
    end
    
    -- Calculate total
    local totalCost = totalPartsCost + totalLaborCost
    
    -- Add shop fee (typically 10-15% of labor cost)
    local shopFee = math.floor(totalLaborCost * 0.10)
    
    -- Add environmental fee
    local environmentalFee = 25
    
    -- Add tax (8%)
    local tax = math.floor((totalCost + shopFee + environmentalFee) * 0.08)
    
    local grandTotal = totalCost + shopFee + environmentalFee + tax

    local estimate = {
        itemized_costs = itemizedCosts,
        parts_cost = totalPartsCost,
        labor_cost = totalLaborCost,
        labor_hours = math.floor(totalLaborHours * 10) / 10,
        shop_fee = shopFee,
        environmental_fee = environmentalFee,
        tax = tax,
        subtotal = totalCost,
        total_cost = grandTotal,
        damaged_parts_count = #itemizedCosts
    }

    return ApplyEconomicBalancing(estimate, vehicleData)
end

-- Calculate vehicle value for total loss determination
function CalculateVehicleValue(vehicleModel, vehicleClass, mileage, condition)
    -- Base values by vehicle class
    local baseValues = {
        compact = 15000,
        sedan = 20000,
        suv = 35000,
        sports = 45000,
        sports_classic = 55000,
        super = 150000,
        motorcycle = 12000,
        muscle = 35000,
        offroad = 40000,
        industrial = 60000,
        utility = 30000,
        van = 28000,
        cycle = 5000,
        boat = 75000,
        helicopter = 250000,
        plane = 500000,
        service = 25000,
        emergency = 45000,
        military = 80000,
        commercial = 70000,
        train = 200000
    }
    
    local baseValue = baseValues[vehicleClass] or 25000
    
    -- Mileage depreciation (0.5% per 1000 miles over 10000)
    local mileageDepreciation = 0
    if mileage > 10000 then
        mileageDepreciation = math.floor((mileage - 10000) / 1000) * 0.005
    end
    
    -- Condition multiplier
    local conditionMultiplier = 1.0
    if condition == "excellent" then
        conditionMultiplier = 1.1
    elseif condition == "good" then
        conditionMultiplier = 1.0
    elseif condition == "fair" then
        conditionMultiplier = 0.85
    elseif condition == "poor" then
        conditionMultiplier = 0.7
    end
    
    -- Calculate final value
    local depreciation = math.min(mileageDepreciation, 0.5) -- Max 50% depreciation
    local value = baseValue * (1 - depreciation) * conditionMultiplier
    
    return math.floor(value)
end

-- Determine if vehicle is total loss
function IsTotalLoss(repairCost, vehicleValue)
    -- Vehicle is total loss if repair cost exceeds 75% of vehicle value
    local threshold = vehicleValue * 0.75
    return repairCost > threshold, threshold
end

-- Calculate deductible based on policy
function CalculateDeductible(policyTier, accidentType, driverAtFault)
    local deductibles = {
        none = { standard = 0, at_fault = 0, not_at_fault = 0 },
        basic = { standard = 1000, at_fault = 1000, not_at_fault = 500 },
        standard = { standard = 500, at_fault = 500, not_at_fault = 250 },
        premium = { standard = 250, at_fault = 250, not_at_fault = 100 },
        elite = { standard = 100, at_fault = 100, not_at_fault = 0 }
    }
    
    local tierDeductibles = deductibles[policyTier] or deductibles.standard
    
    if driverAtFault == nil then
        return tierDeductibles.standard
    elseif driverAtFault then
        return tierDeductibles.at_fault
    else
        return tierDeductibles.not_at_fault
    end
end

-- Calculate maximum payout based on policy
function CalculateMaximumPayout(policyTier, vehicleClass, isLuxury)
    local maxPayouts = {
        none = 0,
        basic = 5000,
        standard = 15000,
        premium = 35000,
        elite = 100000
    }
    
    local baseMax = maxPayouts[policyTier] or maxPayouts.standard
    
    -- Basic tier doesn't cover luxury vehicles
    if policyTier == "basic" and isLuxury then
        return 0
    end
    
    -- Premium and elite have higher limits for luxury
    if (policyTier == "premium" or policyTier == "elite") and isLuxury then
        baseMax = baseMax * 1.5
    end
    
    return math.floor(baseMax)
end

-- Calculate coverage validation
function ValidateCoverage(policyTier, vehicleClass, repairCost, vehicleValue)
    local isLuxury = (vehicleClass == "sports" or vehicleClass == "sports_classic" or 
                     vehicleClass == "super" or vehicleClass == "luxury")
    
    local maxPayout = CalculateMaximumPayout(policyTier, vehicleClass, isLuxury)
    local isTotalLoss, totalLossThreshold = IsTotalLoss(repairCost, vehicleValue)
    
    local coverage = {
        is_covered = true,
        max_payout = maxPayout,
        is_total_loss = isTotalLoss,
        total_loss_threshold = totalLossThreshold,
        luxury_excluded = (policyTier == "basic" and isLuxury),
        exceeds_max_payout = repairCost > maxPayout,
        covered_amount = math.min(repairCost, maxPayout)
    }
    
    -- Determine if covered
    if coverage.luxury_excluded then
        coverage.is_covered = false
        coverage.rejection_reason = "luxury_vehicle_not_covered"
    elseif coverage.exceeds_max_payout then
        coverage.is_covered = false
        coverage.rejection_reason = "exceeds_policy_maximum"
    end
    
    return coverage
end

-- Calculate approved amount
function CalculateApprovedAmount(repairCost, deductible, maxPayout, coverageValidation)
    if not coverageValidation.is_covered then
        return 0
    end
    
    local approvedAmount = repairCost - deductible
    
    -- Apply maximum payout limit
    approvedAmount = math.min(approvedAmount, maxPayout)
    
    -- Ensure non-negative
    approvedAmount = math.max(0, approvedAmount)
    
    return math.floor(approvedAmount)
end

-- Generate repair summary for AI
function GenerateRepairSummary(repairEstimate, coverageValidation)
    local summary = {}
    
    table.insert(summary, string.format("Total Repair Cost: $%d", repairEstimate.total_cost))
    table.insert(summary, string.format("Parts Cost: $%d", repairEstimate.parts_cost))
    table.insert(summary, string.format("Labor Cost: $%d (%.1f hours)", repairEstimate.labor_cost, repairEstimate.labor_hours))
    table.insert(summary, string.format("Damaged Parts: %d", repairEstimate.damaged_parts_count))
    
    if coverageValidation.is_total_loss then
        table.insert(summary, string.format("TOTAL LOSS - Repair cost exceeds %.0f%% of vehicle value", 
            coverageValidation.total_loss_threshold / coverageValidation.vehicle_value * 100))
    end
    
    if not coverageValidation.is_covered then
        table.insert(summary, string.format("NOT COVERED: %s", coverageValidation.rejection_reason))
    end
    
    return table.concat(summary, "\n")
end

-- Export functions
exports('CalculatePartRepairCost', CalculatePartRepairCost)
exports('CalculateRepairEstimate', CalculateRepairEstimate)
exports('CalculateVehicleValue', CalculateVehicleValue)
exports('IsTotalLoss', IsTotalLoss)
exports('CalculateDeductible', CalculateDeductible)
exports('CalculateMaximumPayout', CalculateMaximumPayout)
exports('ValidateCoverage', ValidateCoverage)
exports('CalculateApprovedAmount', CalculateApprovedAmount)
exports('GenerateRepairSummary', GenerateRepairSummary)
