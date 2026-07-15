--[[
    fraud_engine.lua (server)
    Deterministic fraud detection engine.
    Calculates fraud scores and detects suspicious patterns using Lua.
    AI only interprets the calculated fraud scores, doesn't calculate them.
]]

-- Fraud detection configuration
FraudConfig = {
    -- Score thresholds
    thresholds = {
        low = 20,
        medium = 40,
        high = 60,
        critical = 80
    },
    
    -- Score weights for different factors
    weights = {
        claim_frequency = 15,
        claim_location_repeat = 20,
        rapid_claims = 25,
        vehicle_resale = 30,
        new_policy = 20,
        police_citations = 10,
        vehicle_theft = 35,
        disconnect_investigation = 15,
        repeated_passengers = 10,
        speed_damage_mismatch = 25,
        witness_conflict = 20,
        statement_conflict = 30,
        pattern_anomaly = 15
    },
    
    -- Time windows (in seconds)
    time_windows = {
        rapid_claim = 86400,        -- 24 hours
        frequent_claim = 604800,     -- 7 days
        new_policy = 1209600,       -- 14 days
        location_repeat = 2592000   -- 30 days
    }
}

-- Calculate fraud score for a claim
function CalculateFraudScore(citizenid, claimData, driverProfile, recentClaims)
    local fraudScore = 0
    local fraudIndicators = {}
    
    -- 1. Claim frequency analysis
    local claimFrequencyScore = AnalyzeClaimFrequency(recentClaims)
    if claimFrequencyScore > 0 then
        fraudScore = fraudScore + claimFrequencyScore
        table.insert(fraudIndicators, {
            type = "claim_frequency",
            score = claimFrequencyScore,
            description = "High claim frequency detected"
        })
    end
    
    -- 2. Location repeat analysis
    local locationScore = AnalyzeLocationRepeat(recentClaims, claimData.accident.gps_location)
    if locationScore > 0 then
        fraudScore = fraudScore + locationScore
        table.insert(fraudIndicators, {
            type = "location_repeat",
            score = locationScore,
            description = "Repeated claims at same location"
        })
    end
    
    -- 3. Rapid claims analysis
    local rapidClaimsScore = AnalyzeRapidClaims(recentClaims)
    if rapidClaimsScore > 0 then
        fraudScore = fraudScore + rapidClaimsScore
        table.insert(fraudIndicators, {
            type = "rapid_claims",
            score = rapidClaimsScore,
            description = "Multiple claims in short time period"
        })
    end
    
    -- 4. Vehicle resale analysis
    local resaleScore = AnalyzeVehicleResale(citizenid, claimData.vehicle.plate)
    if resaleScore > 0 then
        fraudScore = fraudScore + resaleScore
        table.insert(fraudIndicators, {
            type = "vehicle_resale",
            score = resaleScore,
            description = "Vehicle sold shortly after claim"
        })
    end
    
    -- 5. New policy analysis
    local newPolicyScore = AnalyzeNewPolicy(driverProfile.policy_start_date)
    if newPolicyScore > 0 then
        fraudScore = fraudScore + newPolicyScore
        table.insert(fraudIndicators, {
            type = "new_policy",
            score = newPolicyScore,
            description = "Claim filed shortly after policy activation"
        })
    end
    
    -- 6. Police citations analysis
    local citationsScore = AnalyzePoliceCitations(driverProfile.police_citations)
    if citationsScore > 0 then
        fraudScore = fraudScore + citationsScore
        table.insert(fraudIndicators, {
            type = "police_citations",
            score = citationsScore,
            description = "Recent police citations"
        })
    end
    
    -- 7. Vehicle theft analysis
    local theftScore = AnalyzeVehicleTheft(claimData.vehicle.plate)
    if theftScore > 0 then
        fraudScore = fraudScore + theftScore
        table.insert(fraudIndicators, {
            type = "vehicle_theft",
            score = theftScore,
            description = "Vehicle reported stolen"
        })
    end
    
    -- 8. Disconnect during investigation
    local disconnectScore = AnalyzeDisconnectPattern(citizenid)
    if disconnectScore > 0 then
        fraudScore = fraudScore + disconnectScore
        table.insert(fraudIndicators, {
            type = "disconnect_investigation",
            score = disconnectScore,
            description = "Pattern of disconnecting during investigations"
        })
    end
    
    -- 9. Repeated passengers analysis
    local passengerScore = AnalyzeRepeatedPassengers(recentClaims, claimData.accident.occupants)
    if passengerScore > 0 then
        fraudScore = fraudScore + passengerScore
        table.insert(fraudIndicators, {
            type = "repeated_passengers",
            score = passengerScore,
            description = "Same passengers in multiple claims"
        })
    end
    
    -- 10. Speed vs damage mismatch
    local mismatchScore = AnalyzeSpeedDamageMismatch(claimData.accident.speed_at_impact, 
                                                    claimData.damage_percent)
    if mismatchScore > 0 then
        fraudScore = fraudScore + mismatchScore
        table.insert(fraudIndicators, {
            type = "speed_damage_mismatch",
            score = mismatchScore,
            description = "Speed inconsistent with damage"
        })
    end
    
    -- 11. Witness conflict analysis
    local witnessConflictScore = AnalyzeWitnessConflict(claimData.witness_reports, 
                                                       claimData.player_statement)
    if witnessConflictScore > 0 then
        fraudScore = fraudScore + witnessConflictScore
        table.insert(fraudIndicators, {
            type = "witness_conflict",
            score = witnessConflictScore,
            description = "Witness statements conflict with claim"
        })
    end
    
    -- 12. Statement conflict analysis
    local statementConflictScore = AnalyzeStatementConflict(claimData.accident, 
                                                             claimData.player_statement)
    if statementConflictScore > 0 then
        fraudScore = fraudScore + statementConflictScore
        table.insert(fraudIndicators, {
            type = "statement_conflict",
            score = statementConflictScore,
            description = "Player statement inconsistent with evidence"
        })
    end
    
    -- 13. Pattern anomaly analysis
    local anomalyScore = AnalyzePatternAnomaly(recentClaims, driverProfile)
    if anomalyScore > 0 then
        fraudScore = fraudScore + anomalyScore
        table.insert(fraudIndicators, {
            type = "pattern_anomaly",
            score = anomalyScore,
            description = "Unusual claim pattern detected"
        })
    end
    
    -- Clamp score between 0 and 100
    fraudScore = math.max(0, math.min(100, fraudScore))
    
    -- Determine fraud level
    local fraudLevel = DetermineFraudLevel(fraudScore)
    
    return {
        score = fraudScore,
        level = fraudLevel,
        indicators = fraudIndicators,
        timestamp = os.time()
    }
end

-- Analyze claim frequency
function AnalyzeClaimFrequency(recentClaims)
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
    
    -- Score based on claim frequency
    if recentClaimCount >= 5 then
        return FraudConfig.weights.claim_frequency
    elseif recentClaimCount >= 3 then
        return FraudConfig.weights.claim_frequency * 0.75
    elseif recentClaimCount >= 2 then
        return FraudConfig.weights.claim_frequency * 0.5
    elseif recentClaimCount >= 1 then
        return FraudConfig.weights.claim_frequency * 0.25
    end
    
    return 0
end

-- Analyze location repeat
function AnalyzeLocationRepeat(recentClaims, currentLocation)
    if not recentClaims or #recentClaims == 0 or not currentLocation then
        return 0
    end
    
    local locationThreshold = 50.0 -- 50 meters
    local repeatCount = 0
    
    for _, claim in ipairs(recentClaims) do
        if claim.gps_x and claim.gps_y then
            local distance = math.sqrt(
                (claim.gps_x - currentLocation.x)^2 + 
                (claim.gps_y - currentLocation.y)^2
            )
            if distance < locationThreshold then
                repeatCount = repeatCount + 1
            end
        end
    end
    
    if repeatCount >= 3 then
        return FraudConfig.weights.claim_location_repeat
    elseif repeatCount >= 2 then
        return FraudConfig.weights.claim_location_repeat * 0.6
    elseif repeatCount >= 1 then
        return FraudConfig.weights.claim_location_repeat * 0.3
    end
    
    return 0
end

-- Analyze rapid claims
function AnalyzeRapidClaims(recentClaims)
    if not recentClaims or #recentClaims < 2 then
        return 0
    end
    
    local rapidWindow = FraudConfig.time_windows.rapid_claim
    local rapidCount = 0
    
    for i = 1, #recentClaims - 1 do
        local timeDiff = recentClaims[i].created_at - recentClaims[i + 1].created_at
        if timeDiff < rapidWindow then
            rapidCount = rapidCount + 1
        end
    end
    
    if rapidCount >= 2 then
        return FraudConfig.weights.rapid_claims
    elseif rapidCount >= 1 then
        return FraudConfig.weights.rapid_claims * 0.5
    end
    
    return 0
end

-- Analyze vehicle resale
function AnalyzeVehicleResale(citizenid, plate)
    -- Check if vehicle was sold within 30 days of a claim
    -- This would need database integration
    -- For now, return 0 as placeholder
    return 0
end

-- Analyze new policy
function AnalyzeNewPolicy(policyStartDate)
    if not policyStartDate then
        return 0
    end
    
    local timeSincePolicy = os.time() - policyStartDate
    local newPolicyWindow = FraudConfig.time_windows.new_policy
    
    if timeSincePolicy < newPolicyWindow then
        return FraudConfig.weights.new_policy
    end
    
    return 0
end

-- Analyze police citations
function AnalyzePoliceCitations(citations)
    if not citations or citations == 0 then
        return 0
    end
    
    local score = 0
    if citations >= 5 then
        score = FraudConfig.weights.police_citations
    elseif citations >= 3 then
        score = FraudConfig.weights.police_citations * 0.6
    elseif citations >= 1 then
        score = FraudConfig.weights.police_citations * 0.3
    end
    
    return score
end

-- Analyze vehicle theft
function AnalyzeVehicleTheft(plate)
    -- Check if vehicle was reported stolen
    -- This would need database integration with police system
    -- For now, return 0 as placeholder
    return 0
end

-- Analyze disconnect pattern
function AnalyzeDisconnectPattern(citizenid)
    -- Check if player has pattern of disconnecting during investigations
    -- This would need tracking system
    -- For now, return 0 as placeholder
    return 0
end

-- Analyze repeated passengers
function AnalyzeRepeatedPassengers(recentClaims, currentOccupants)
    if not recentClaims or #recentClaims == 0 or not currentOccupants then
        return 0
    end
    
    -- Check if same passengers appear in multiple claims
    -- This would need passenger tracking
    -- For now, return 0 as placeholder
    return 0
end

-- Analyze speed vs damage mismatch
function AnalyzeSpeedDamageMismatch(speed, damagePercent)
    if not speed or not damagePercent then
        return 0
    end
    
    -- Expected damage based on speed (rough approximation)
    local expectedDamage = math.min(100, speed * 0.8)
    local damageDiff = math.abs(expectedDamage - damagePercent)
    
    -- If speed is high but damage is low, or vice versa
    if speed > 60 and damagePercent < 20 then
        return FraudConfig.weights.speed_damage_mismatch
    elseif speed < 20 and damagePercent > 50 then
        return FraudConfig.weights.speed_damage_mismatch * 0.7
    elseif damageDiff > 40 then
        return FraudConfig.weights.speed_damage_mismatch * 0.5
    end
    
    return 0
end

-- Analyze witness conflict
function AnalyzeWitnessConflict(witnessReports, playerStatement)
    if not witnessReports or #witnessReports == 0 then
        return 0
    end
    
    -- Check if witness reports conflict with player statement
    -- This would need NLP or keyword matching
    -- For now, return 0 as placeholder
    return 0
end

-- Analyze statement conflict
function AnalyzeStatementConflict(accidentData, playerStatement)
    if not accidentData or not playerStatement then
        return 0
    end
    
    -- Check if player statement conflicts with telemetry
    -- Example: player says "parked" but speed was 60 mph
    -- This would need keyword analysis
    -- For now, return 0 as placeholder
    return 0
end

-- Analyze pattern anomaly
function AnalyzePatternAnomaly(recentClaims, driverProfile)
    if not recentClaims or #recentClaims < 3 then
        return 0
    end
    
    -- Check for unusual patterns in claim timing, amounts, etc.
    -- This would need statistical analysis
    -- For now, return 0 as placeholder
    return 0
end

-- Determine fraud level from score
function DetermineFraudLevel(score)
    if score >= FraudConfig.thresholds.critical then
        return "critical"
    elseif score >= FraudConfig.thresholds.high then
        return "high"
    elseif score >= FraudConfig.thresholds.medium then
        return "medium"
    elseif score >= FraudConfig.thresholds.low then
        return "low"
    else
        return "none"
    end
end

-- Update fraud score in database
function UpdateFraudScoreDB(citizenid, fraudScore)
    MySQL.query([[
        INSERT INTO insurance_fraud_scores (citizenid, score, last_updated)
        VALUES (?, ?, NOW())
        ON DUPLICATE KEY UPDATE
            score = ?,
            last_updated = NOW()
    ]], { citizenid, fraudScore, fraudScore })
end

-- Get fraud score history for analysis
function GetFraudScoreHistory(citizenid, days, cb)
    local cutoffTime = os.time() - (days * 86400)
    
    MySQL.query([[
        SELECT score, last_updated 
        FROM insurance_fraud_scores_history
        WHERE citizenid = ? AND last_updated >= ?
        ORDER BY last_updated DESC
    ]], { citizenid, cutoffTime }, cb)
end

-- Export functions
exports('CalculateFraudScore', CalculateFraudScore)
exports('DetermineFraudLevel', DetermineFraudLevel)
exports('UpdateFraudScoreDB', UpdateFraudScoreDB)
exports('GetFraudScoreHistory', GetFraudScoreHistory)
