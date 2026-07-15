--[[
    risk_engine.lua (server)
    Deterministic driver risk assessment engine.
    Calculates driver risk scores and categories using Lua.
    AI only interprets the calculated risk scores, doesn't calculate them.
]]

-- Risk assessment configuration
RiskConfig = {
    -- Score thresholds
    thresholds = {
        safe = 30,
        average = 50,
        high_risk = 70,
        dangerous = 85
    },
    
    -- Score weights for different factors
    weights = {
        average_speed = 20,
        night_driving = 10,
        rain_driving = 5,
        aggressive_driving = 25,
        police_stops = 15,
        traffic_violations = 20,
        safe_driving_streak = -15,
        accident_frequency = 30,
        claims_per_month = 25,
        dui_count = 35,
        license_points = 20
    },
    
    -- Thresholds for various factors
    speed_thresholds = {
        safe = 55,
        moderate = 75,
        dangerous = 90
    },
    
    night_driving_threshold = {
        start_hour = 20,
        end_hour = 6
    }
}

-- Calculate driver risk score
function CalculateDriverRiskScore(driverProfile, drivingHistory, recentClaims)
    local riskScore = 50 -- Base score
    local riskFactors = {}
    
    -- 1. Average speed analysis
    local speedScore = AnalyzeAverageSpeed(driverProfile.average_speed)
    riskScore = riskScore + speedScore
    table.insert(riskFactors, {
        type = "average_speed",
        score = speedScore,
        value = driverProfile.average_speed or 0,
        description = GetSpeedDescription(driverProfile.average_speed)
    })
    
    -- 2. Night driving frequency
    local nightDrivingScore = AnalyzeNightDriving(driverProfile.night_driving_freq)
    riskScore = riskScore + nightDrivingScore
    table.insert(riskFactors, {
        type = "night_driving",
        score = nightDrivingScore,
        value = driverProfile.night_driving_freq or 0,
        description = "Night driving frequency"
    })
    
    -- 3. Rain driving frequency
    local rainDrivingScore = AnalyzeRainDriving(driverProfile.rain_driving_freq)
    riskScore = riskScore + rainDrivingScore
    table.insert(riskFactors, {
        type = "rain_driving",
        score = rainDrivingScore,
        value = driverProfile.rain_driving_freq or 0,
        description = "Rain driving frequency"
    })
    
    -- 4. Aggressive driving incidents
    local aggressiveScore = AnalyzeAggressiveDriving(driverProfile.aggressive_driving_score)
    riskScore = riskScore + aggressiveScore
    table.insert(riskFactors, {
        type = "aggressive_driving",
        score = aggressiveScore,
        value = driverProfile.aggressive_driving_score or 0,
        description = "Aggressive driving incidents"
    })
    
    -- 5. Police stops
    local policeStopsScore = AnalyzePoliceStops(driverProfile.police_encounters)
    riskScore = riskScore + policeStopsScore
    table.insert(riskFactors, {
        type = "police_stops",
        score = policeStopsScore,
        value = driverProfile.police_encounters or 0,
        description = "Police encounters"
    })
    
    -- 6. Traffic violations
    local violationsScore = AnalyzeTrafficViolations(drivingHistory.traffic_violations)
    riskScore = riskScore + violationsScore
    table.insert(riskFactors, {
        type = "traffic_violations",
        score = violationsScore,
        value = drivingHistory.traffic_violations or 0,
        description = "Traffic violations"
    })
    
    -- 7. Safe driving streak (negative weight - reduces risk)
    local safeStreakScore = AnalyzeSafeDrivingStreak(driverProfile.safe_driving_streak)
    riskScore = riskScore + safeStreakScore
    table.insert(riskFactors, {
        type = "safe_driving_streak",
        score = safeStreakScore,
        value = driverProfile.safe_driving_streak or 0,
        description = "Safe driving streak"
    })
    
    -- 8. Accident frequency
    local accidentScore = AnalyzeAccidentFrequency(drivingHistory.accidents)
    riskScore = riskScore + accidentScore
    table.insert(riskFactors, {
        type = "accident_frequency",
        score = accidentScore,
        value = drivingHistory.accidents or 0,
        description = "Accident frequency"
    })
    
    -- 9. Claims per month
    local claimsScore = AnalyzeClaimsPerMonth(recentClaims)
    riskScore = riskScore + claimsScore
    table.insert(riskFactors, {
        type = "claims_per_month",
        score = claimsScore,
        value = CalculateClaimsPerMonth(recentClaims),
        description = "Claims per month"
    })
    
    -- 10. DUI count
    local duiScore = AnalyzeDUICount(driverProfile.dui_count)
    riskScore = riskScore + duiScore
    table.insert(riskFactors, {
        type = "dui_count",
        score = duiScore,
        value = driverProfile.dui_count or 0,
        description = "DUI incidents"
    })
    
    -- 11. License points
    local licensePointsScore = AnalyzeLicensePoints(drivingHistory.license_points)
    riskScore = riskScore + licensePointsScore
    table.insert(riskFactors, {
        type = "license_points",
        score = licensePointsScore,
        value = drivingHistory.license_points or 0,
        description = "License points"
    })
    
    -- Clamp score between 0 and 100
    riskScore = math.max(0, math.min(100, riskScore))
    
    -- Determine risk category
    local riskCategory = DetermineRiskCategory(riskScore)
    
    return {
        score = riskScore,
        category = riskCategory,
        factors = riskFactors,
        timestamp = os.time()
    }
end

-- Analyze average speed
function AnalyzeAverageSpeed(averageSpeed)
    if not averageSpeed then
        return 0
    end
    
    local thresholds = RiskConfig.speed_thresholds
    local weight = RiskConfig.weights.average_speed
    
    if averageSpeed >= thresholds.dangerous then
        return weight
    elseif averageSpeed >= thresholds.moderate then
        return weight * 0.6
    elseif averageSpeed >= thresholds.safe then
        return weight * 0.3
    else
        return 0
    end
end

-- Get speed description
function GetSpeedDescription(speed)
    if not speed then
        return "No data"
    end
    
    if speed >= RiskConfig.speed_thresholds.dangerous then
        return "Dangerous"
    elseif speed >= RiskConfig.speed_thresholds.moderate then
        return "Above limit"
    elseif speed >= RiskConfig.speed_thresholds.safe then
        return "Moderate"
    else
        return "Safe"
    end
end

-- Analyze night driving
function AnalyzeNightDriving(nightDrivingFreq)
    if not nightDrivingFreq then
        return 0
    end
    
    local weight = RiskConfig.weights.night_driving
    
    -- nightDrivingFreq is percentage (0-100)
    if nightDrivingFreq > 50 then
        return weight
    elseif nightDrivingFreq > 30 then
        return weight * 0.6
    elseif nightDrivingFreq > 15 then
        return weight * 0.3
    else
        return 0
    end
end

-- Analyze rain driving
function AnalyzeRainDriving(rainDrivingFreq)
    if not rainDrivingFreq then
        return 0
    end
    
    local weight = RiskConfig.weights.rain_driving
    
    -- rainDrivingFreq is percentage (0-100)
    if rainDrivingFreq > 40 then
        return weight
    elseif rainDrivingFreq > 25 then
        return weight * 0.6
    elseif rainDrivingFreq > 10 then
        return weight * 0.3
    else
        return 0
    end
end

-- Analyze aggressive driving
function AnalyzeAggressiveDriving(aggressiveScore)
    if not aggressiveScore then
        return 0
    end
    
    local weight = RiskConfig.weights.aggressive_driving
    
    if aggressiveScore >= 10 then
        return weight
    elseif aggressiveScore >= 5 then
        return weight * 0.6
    elseif aggressiveScore >= 2 then
        return weight * 0.3
    else
        return 0
    end
end

-- Analyze police stops
function AnalyzePoliceStops(policeEncounters)
    if not policeEncounters then
        return 0
    end
    
    local weight = RiskConfig.weights.police_stops
    
    if policeEncounters >= 5 then
        return weight
    elseif policeEncounters >= 3 then
        return weight * 0.6
    elseif policeEncounters >= 1 then
        return weight * 0.3
    else
        return 0
    end
end

-- Analyze traffic violations
function AnalyzeTrafficViolations(violations)
    if not violations then
        return 0
    end
    
    local weight = RiskConfig.weights.traffic_violations
    
    if violations >= 10 then
        return weight
    elseif violations >= 5 then
        return weight * 0.6
    elseif violations >= 2 then
        return weight * 0.3
    else
        return 0
    end
end

-- Analyze safe driving streak
function AnalyzeSafeDrivingStreak(streakDays)
    if not streakDays then
        return 0
    end
    
    local weight = RiskConfig.weights.safe_driving_streak -- Negative weight
    
    if streakDays >= 90 then
        return weight -- -15 points
    elseif streakDays >= 60 then
        return weight * 0.6 -- -9 points
    elseif streakDays >= 30 then
        return weight * 0.3 -- -4.5 points
    else
        return 0
    end
end

-- Analyze accident frequency
function AnalyzeAccidentFrequency(accidents)
    if not accidents then
        return 0
    end
    
    local weight = RiskConfig.weights.accident_frequency
    
    if accidents >= 5 then
        return weight
    elseif accidents >= 3 then
        return weight * 0.6
    elseif accidents >= 1 then
        return weight * 0.3
    else
        return 0
    end
end

-- Calculate claims per month
function CalculateClaimsPerMonth(recentClaims)
    if not recentClaims or #recentClaims == 0 then
        return 0
    end
    
    local thirtyDaysAgo = os.time() - (30 * 86400)
    local recentClaimCount = 0
    
    for _, claim in ipairs(recentClaims) do
        if claim.created_at and claim.created_at >= thirtyDaysAgo then
            recentClaimCount = recentClaimCount + 1
        end
    end
    
    return recentClaimCount
end

-- Analyze claims per month
function AnalyzeClaimsPerMonth(recentClaims)
    local claimsPerMonth = CalculateClaimsPerMonth(recentClaims)
    local weight = RiskConfig.weights.claims_per_month
    
    if claimsPerMonth >= 3 then
        return weight
    elseif claimsPerMonth >= 2 then
        return weight * 0.6
    elseif claimsPerMonth >= 1 then
        return weight * 0.3
    else
        return 0
    end
end

-- Analyze DUI count
function AnalyzeDUICount(duiCount)
    if not duiCount then
        return 0
    end
    
    local weight = RiskConfig.weights.dui_count
    
    if duiCount >= 2 then
        return weight
    elseif duiCount >= 1 then
        return weight * 0.6
    else
        return 0
    end
end

-- Analyze license points
function AnalyzeLicensePoints(licensePoints)
    if not licensePoints then
        return 0
    end
    
    local weight = RiskConfig.weights.license_points
    
    if licensePoints >= 12 then
        return weight
    elseif licensePoints >= 8 then
        return weight * 0.6
    elseif licensePoints >= 4 then
        return weight * 0.3
    else
        return 0
    end
end

-- Determine risk category from score
function DetermineRiskCategory(score)
    if score >= RiskConfig.thresholds.dangerous then
        return "dangerous"
    elseif score >= RiskConfig.thresholds.high_risk then
        return "high_risk"
    elseif score >= RiskConfig.thresholds.average then
        return "average"
    elseif score >= RiskConfig.thresholds.safe then
        return "safe"
    else
        return "very_safe"
    end
end

-- Update driver risk profile in database
function UpdateDriverRiskProfile(citizenid, riskAssessment)
    MySQL.query([[
        UPDATE insurance_driver_profiles 
        SET risk_score = ?,
            last_updated = NOW()
        WHERE citizenid = ?
    ]], { riskAssessment.score, citizenid })
end

-- Get risk score history
function GetRiskScoreHistory(citizenid, days, cb)
    local cutoffTime = os.time() - (days * 86400)
    
    MySQL.query([[
        SELECT risk_score, last_updated 
        FROM insurance_driver_profiles_history
        WHERE citizenid = ? AND last_updated >= ?
        ORDER BY last_updated DESC
    ]], { citizenid, cutoffTime }, cb)
end

-- Export functions
exports('CalculateDriverRiskScore', CalculateDriverRiskScore)
exports('DetermineRiskCategory', DetermineRiskCategory)
exports('UpdateDriverRiskProfile', UpdateDriverRiskProfile)
exports('GetRiskScoreHistory', GetRiskScoreHistory)
