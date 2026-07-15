--[[
    policy_engine.lua (server)
    Deterministic policy validation engine.
    Validates insurance policies, coverage, and claim eligibility using Lua.
    AI receives the validated policy information, doesn't calculate it.
]]

-- Policy configuration database
PolicyDatabase = {
    none = {
        display_name = "No Insurance",
        max_payout = 0,
        deductible = 0,
        luxury_coverage = false,
        roadside_assistance = false,
        rental_reimbursement = false,
        medical_coverage = false,
        approval_priority = 999,
        covered_vehicles = {},
        monthly_premium = 0,
        description = "No insurance coverage"
    },
    
    basic = {
        display_name = "Basic Coverage",
        max_payout = 5000,
        deductible = 1000,
        luxury_coverage = false,
        roadside_assistance = false,
        rental_reimbursement = false,
        medical_coverage = false,
        approval_priority = 10,
        covered_vehicles = {"compact", "sedan", "suv", "utility", "van"},
        monthly_premium = 50,
        description = "Entry-level coverage for standard vehicles"
    },
    
    standard = {
        display_name = "Standard Coverage",
        max_payout = 15000,
        deductible = 500,
        luxury_coverage = false,
        roadside_assistance = true,
        rental_reimbursement = false,
        medical_coverage = false,
        approval_priority = 5,
        covered_vehicles = {"compact", "sedan", "suv", "utility", "van", "muscle", "offroad"},
        monthly_premium = 100,
        description = "Standard coverage with roadside assistance"
    },
    
    premium = {
        display_name = "Premium Coverage",
        max_payout = 35000,
        deductible = 250,
        luxury_coverage = true,
        roadside_assistance = true,
        rental_reimbursement = true,
        medical_coverage = true,
        approval_priority = 3,
        covered_vehicles = {"compact", "sedan", "suv", "utility", "van", "muscle", "offroad", "sports", "sports_classic"},
        monthly_premium = 200,
        description = "Premium coverage including luxury vehicles and medical"
    },
    
    elite = {
        display_name = "Elite Coverage",
        max_payout = 100000,
        deductible = 100,
        luxury_coverage = true,
        roadside_assistance = true,
        rental_reimbursement = true,
        medical_coverage = true,
        approval_priority = 1,
        covered_vehicles = {"all"},
        monthly_premium = 500,
        description = "Elite coverage with full replacement and priority investigation"
    }
}

-- Vehicle class categorization
VehicleClasses = {
    -- Economy
    compact = "economy",
    sedan = "economy",
    cycle = "economy",
    
    -- Standard
    suv = "standard",
    utility = "standard",
    van = "standard",
    
    -- Performance
    sports = "performance",
    muscle = "performance",
    sports_classic = "performance",
    
    -- Luxury
    super = "luxury",
    coupe = "luxury",
    
    -- Specialty
    offroad = "specialty",
    industrial = "specialty",
    commercial = "specialty",
    
    -- Emergency/Service
    emergency = "service",
    service = "service",
    military = "service",
    
    -- Water/Air
    boat = "marine",
    helicopter = "aviation",
    plane = "aviation"
}

-- Validate policy for a claim
function ValidatePolicy(policyTier, vehicleClass, claimData)
    local policy = PolicyDatabase[policyTier] or PolicyDatabase.none
    
    local validation = {
        is_valid = true,
        policy_tier = policyTier,
        policy_details = policy,
        coverage_details = {},
        restrictions = {},
        benefits = {}
    }
    
    -- Check if vehicle class is covered
    local vehicleCoverage = ValidateVehicleCoverage(policy, vehicleClass)
    validation.coverage_details.vehicle_covered = vehicleCoverage.covered
    validation.coverage_details.vehicle_class = vehicleClass
    validation.coverage_details.vehicle_category = VehicleClasses[vehicleClass] or "unknown"
    
    if not vehicleCoverage.covered then
        validation.is_valid = false
        table.insert(validation.restrictions, {
            type = "vehicle_not_covered",
            reason = vehicleCoverage.reason
        })
    end
    
    -- Check luxury vehicle coverage
    local isLuxury = IsLuxuryVehicle(vehicleClass)
    validation.coverage_details.is_luxury = isLuxury
    
    if isLuxury and not policy.luxury_coverage then
        validation.is_valid = false
        table.insert(validation.restrictions, {
            type = "luxury_not_covered",
            reason = "Policy does not cover luxury vehicles"
        })
    end
    
    -- Check marine/aviation coverage
    local isSpecialty = IsSpecialtyVehicle(vehicleClass)
    validation.coverage_details.is_specialty = isSpecialty
    
    if isSpecialty and policyTier ~= "elite" then
        validation.is_valid = false
        table.insert(validation.restrictions, {
            type = "specialty_not_covered",
            reason = "Policy does not cover specialty vehicles"
        })
    end
    
    -- Check policy status
    local policyStatus = ValidatePolicyStatus(claimData.policy_start_date, claimData.policy_active)
    validation.coverage_details.policy_active = policyStatus.active
    validation.coverage_details.policy_days_active = policyStatus.days_active
    
    if not policyStatus.active then
        validation.is_valid = false
        table.insert(validation.restrictions, {
            type = "policy_inactive",
            reason = policyStatus.reason
        })
    end
    
    -- Compile benefits
    if policy.roadside_assistance then
        table.insert(validation.benefits, "roadside_assistance")
    end
    if policy.rental_reimbursement then
        table.insert(validation.benefits, "rental_reimbursement")
    end
    if policy.medical_coverage then
        table.insert(validation.benefits, "medical_coverage")
    end
    if policy.luxury_coverage then
        table.insert(validation.benefits, "luxury_coverage")
    end
    
    return validation
end

-- Validate vehicle coverage
function ValidateVehicleCoverage(policy, vehicleClass)
    local coveredVehicles = policy.covered_vehicles
    
    -- Check if "all" is covered
    for _, vehicle in ipairs(coveredVehicles) do
        if vehicle == "all" then
            return { covered = true, reason = nil }
        end
    end
    
    -- Check specific vehicle class
    for _, vehicle in ipairs(coveredVehicles) do
        if vehicle == vehicleClass then
            return { covered = true, reason = nil }
        end
    end
    
    return { covered = false, reason = "Vehicle class not covered by policy" }
end

-- Check if vehicle is luxury
function IsLuxuryVehicle(vehicleClass)
    local luxuryClasses = {
        "super", "coupe", "sports_classic"
    }
    
    for _, class in ipairs(luxuryClasses) do
        if vehicleClass == class then
            return true
        end
    end
    
    return false
end

-- Check if vehicle is specialty
function IsSpecialtyVehicle(vehicleClass)
    local specialtyClasses = {
        "boat", "helicopter", "plane", "industrial", "commercial"
    }
    
    for _, class in ipairs(specialtyClasses) do
        if vehicleClass == class then
            return true
        end
    end
    
    return false
end

-- Validate policy status
function ValidatePolicyStatus(policyStartDate, policyActive)
    if not policyActive then
        return { active = false, reason = "Policy is inactive", days_active = 0 }
    end
    
    if not policyStartDate then
        return { active = true, reason = nil, days_active = 0 }
    end
    
    local daysActive = math.floor((os.time() - policyStartDate) / 86400)
    
    -- Check if policy is too new (less than 1 day)
    if daysActive < 1 then
        return { active = false, reason = "Policy too recently activated", days_active = daysActive }
    end
    
    return { active = true, reason = nil, days_active = daysActive }
end

-- Calculate coverage limits
function CalculateCoverageLimits(policyTier, vehicleClass, repairCost)
    local policy = PolicyDatabase[policyTier] or PolicyDatabase.none
    local isLuxury = IsLuxuryVehicle(vehicleClass)
    
    local limits = {
        max_payout = policy.max_payout,
        deductible = policy.deductible,
        luxury_multiplier = 1.0,
        effective_max_payout = policy.max_payout,
        covered_amount = 0,
        exceeds_limit = false
    }
    
    -- Apply luxury multiplier for premium/elite
    if isLuxury and (policyTier == "premium" or policyTier == "elite") then
        limits.luxury_multiplier = 1.5
        limits.effective_max_payout = math.floor(policy.max_payout * limits.luxury_multiplier)
    end
    
    -- Check if repair cost exceeds limit
    if repairCost > limits.effective_max_payout then
        limits.exceeds_limit = true
        limits.covered_amount = limits.effective_max_payout
    else
        limits.covered_amount = repairCost
    end
    
    return limits
end

-- Calculate claim eligibility
function CalculateClaimEligibility(policyValidation, coverageLimits, driverProfile)
    local eligibility = {
        eligible = true,
        reasons = {},
        warnings = {}
    }
    
    -- Check policy validity
    if not policyValidation.is_valid then
        eligibility.eligible = false
        for _, restriction in ipairs(policyValidation.restrictions) do
            table.insert(eligibility.reasons, restriction.reason)
        end
    end
    
    -- Check coverage limits
    if coverageLimits.exceeds_limit then
        table.insert(eligibility.warnings, string.format(
            "Repair cost exceeds policy maximum by $%d",
            coverageLimits.covered_amount - coverageLimits.effective_max_payout
        ))
    end
    
    -- Check driver eligibility
    if driverProfile.license_suspended then
        eligibility.eligible = false
        table.insert(eligibility.reasons, "Driver license is suspended")
    end
    
    if driverProfile.age < 18 then
        eligibility.eligible = false
        table.insert(eligibility.reasons, "Driver is under 18")
    end
    
    return eligibility
end

-- Calculate premium adjustment based on risk
function CalculatePremiumAdjustment(basePremium, riskScore, claimHistory)
    local adjustment = 1.0
    
    -- Risk score adjustment
    if riskScore > 70 then
        adjustment = adjustment * 1.5
    elseif riskScore > 50 then
        adjustment = adjustment * 1.2
    elseif riskScore > 30 then
        adjustment = adjustment * 1.0
    else
        adjustment = adjustment * 0.9 -- Safe driver discount
    end
    
    -- Claim history adjustment
    local recentClaims = claimHistory.recent_claims_count or 0
    if recentClaims >= 3 then
        adjustment = adjustment * 1.3
    elseif recentClaims >= 1 then
        adjustment = adjustment * 1.1
    end
    
    return math.floor(basePremium * adjustment)
end

-- Generate policy summary for AI
function GeneratePolicySummary(policyValidation, coverageLimits)
    local policy = policyValidation.policy_details
    local summary = {}
    
    table.insert(summary, string.format("Policy: %s", policy.display_name))
    table.insert(summary, string.format("Maximum Payout: $%d", coverageLimits.effective_max_payout))
    table.insert(summary, string.format("Deductible: $%d", policy.deductible))
    
    if #policyValidation.benefits > 0 then
        table.insert(summary, "Benefits:")
        for _, benefit in ipairs(policyValidation.benefits) do
            table.insert(summary, string.format("- %s", benefit:gsub("_", " "):gsub("^%l", string.upper)))
        end
    end
    
    if not policyValidation.is_valid then
        table.insert(summary, "RESTRICTIONS:")
        for _, restriction in ipairs(policyValidation.restrictions) do
            table.insert(summary, string.format("- %s", restriction.reason))
        end
    end
    
    return table.concat(summary, "\n")
end

-- Get policy information
function GetPolicyInfo(tierName)
    return PolicyDatabase[tierName]
end

-- Get all available policies
function GetAllPolicies()
    return PolicyDatabase
end

-- Check if policy exists
function PolicyExists(tierName)
    return PolicyDatabase[tierName] ~= nil
end

-- Export functions
exports('ValidatePolicy', ValidatePolicy)
exports('CalculateCoverageLimits', CalculateCoverageLimits)
exports('CalculateClaimEligibility', CalculateClaimEligibility)
exports('CalculatePremiumAdjustment', CalculatePremiumAdjustment)
exports('GeneratePolicySummary', GeneratePolicySummary)
exports('GetPolicyInfo', GetPolicyInfo)
exports('GetAllPolicies', GetAllPolicies)
exports('PolicyExists', PolicyExists)
