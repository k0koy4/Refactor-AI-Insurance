--[[
    confidence_engine.lua (server)
    Deterministic confidence calculation engine.
    Calculates investigation confidence based on evidence completeness.
    AI receives the calculated confidence value, doesn't calculate it.
]]

-- Confidence calculation configuration
ConfidenceConfig = {
    -- Evidence weights (must sum to 100)
    evidence_weights = {
        vehicle_data = 25,
        witnesses = 20,
        police_report = 20,
        mechanic_inspection = 20,
        driver_statement = 10,
        ems_report = 5
    },
    
    -- Quality multipliers for evidence
    quality_multipliers = {
        complete = 1.0,
        partial = 0.5,
        minimal = 0.2,
        none = 0.0
    }
}

-- Calculate investigation confidence score
function CalculateInvestigationConfidence(evidence)
    local confidenceScore = 0
    local evidenceQuality = {}
    
    -- 1. Vehicle data quality
    local vehicleQuality = AssessVehicleDataQuality(evidence.vehicle)
    local vehicleScore = ConfidenceConfig.evidence_weights.vehicle_data * vehicleQuality
    confidenceScore = confidenceScore + vehicleScore
    table.insert(evidenceQuality, {
        type = "vehicle_data",
        weight = ConfidenceConfig.evidence_weights.vehicle_data,
        quality = vehicleQuality,
        score = vehicleScore,
        description = GetVehicleDataDescription(evidence.vehicle)
    })
    
    -- 2. Witness evidence quality
    local witnessQuality = AssessWitnessQuality(evidence.witness_reports)
    local witnessScore = ConfidenceConfig.evidence_weights.witnesses * witnessQuality
    confidenceScore = confidenceScore + witnessScore
    table.insert(evidenceQuality, {
        type = "witnesses",
        weight = ConfidenceConfig.evidence_weights.witnesses,
        quality = witnessQuality,
        score = witnessScore,
        description = GetWitnessDescription(evidence.witness_reports)
    })
    
    -- 3. Police report quality
    local policeQuality = AssessPoliceReportQuality(evidence.police_reports)
    local policeScore = ConfidenceConfig.evidence_weights.police_report * policeQuality
    confidenceScore = confidenceScore + policeScore
    table.insert(evidenceQuality, {
        type = "police_report",
        weight = ConfidenceConfig.evidence_weights.police_report,
        quality = policeQuality,
        score = policeScore,
        description = GetPoliceReportDescription(evidence.police_reports)
    })
    
    -- 4. Mechanic inspection quality
    local mechanicQuality = AssessMechanicInspectionQuality(evidence.mechanic_report)
    local mechanicScore = ConfidenceConfig.evidence_weights.mechanic_inspection * mechanicQuality
    confidenceScore = confidenceScore + mechanicScore
    table.insert(evidenceQuality, {
        type = "mechanic_inspection",
        weight = ConfidenceConfig.evidence_weights.mechanic_inspection,
        quality = mechanicQuality,
        score = mechanicScore,
        description = GetMechanicInspectionDescription(evidence.mechanic_report)
    })
    
    -- 5. Driver statement quality
    local statementQuality = AssessDriverStatementQuality(evidence.player_statement)
    local statementScore = ConfidenceConfig.evidence_weights.driver_statement * statementQuality
    confidenceScore = confidenceScore + statementScore
    table.insert(evidenceQuality, {
        type = "driver_statement",
        weight = ConfidenceConfig.evidence_weights.driver_statement,
        quality = statementQuality,
        score = statementScore,
        description = GetDriverStatementDescription(evidence.player_statement)
    })
    
    -- 6. EMS report quality
    local emsQuality = AssessEMSReportQuality(evidence.ems_reports)
    local emsScore = ConfidenceConfig.evidence_weights.ems_report * emsQuality
    confidenceScore = confidenceScore + emsScore
    table.insert(evidenceQuality, {
        type = "ems_report",
        weight = ConfidenceConfig.evidence_weights.ems_report,
        quality = emsQuality,
        score = emsScore,
        description = GetEMSReportDescription(evidence.ems_reports)
    })
    
    -- Clamp score between 0 and 100
    confidenceScore = math.max(0, math.min(100, math.floor(confidenceScore)))
    
    -- Determine confidence level
    local confidenceLevel = DetermineConfidenceLevel(confidenceScore)
    
    return {
        score = confidenceScore,
        level = confidenceLevel,
        evidence_quality = evidenceQuality,
        timestamp = os.time()
    }
end

-- Assess vehicle data quality
function AssessVehicleDataQuality(vehicleData)
    if not vehicleData then
        return ConfidenceConfig.quality_multipliers.none
    end
    
    local requiredFields = {
        "model", "plate", "engine_health", "body_health", "fuel_tank_health"
    }
    
    local presentFields = 0
    for _, field in ipairs(requiredFields) do
        if vehicleData[field] ~= nil then
            presentFields = presentFields + 1
        end
    end
    
    local completeness = presentFields / #requiredFields
    
    if completeness >= 0.9 then
        return ConfidenceConfig.quality_multipliers.complete
    elseif completeness >= 0.6 then
        return ConfidenceConfig.quality_multipliers.partial
    elseif completeness >= 0.3 then
        return ConfidenceConfig.quality_multipliers.minimal
    else
        return ConfidenceConfig.quality_multipliers.none
    end
end

-- Assess witness quality
function AssessWitnessQuality(witnessReports)
    if not witnessReports or #witnessReports == 0 then
        return ConfidenceConfig.quality_multipliers.none
    end
    
    local credibleWitnesses = 0
    for _, witness in ipairs(witnessReports) do
        if witness.likely_witness and witness.line_of_sight then
            credibleWitnesses = credibleWitnesses + 1
        end
    end
    
    if credibleWitnesses >= 2 then
        return ConfidenceConfig.quality_multipliers.complete
    elseif credibleWitnesses >= 1 then
        return ConfidenceConfig.quality_multipliers.partial
    else
        return ConfidenceConfig.quality_multipliers.minimal
    end
end

-- Assess police report quality
function AssessPoliceReportQuality(policeReports)
    if not policeReports or #policeReports == 0 then
        return ConfidenceConfig.quality_multipliers.none
    end
    
    local relevantReports = 0
    for _, report in ipairs(policeReports) do
        if report.citation_type and report.citation_type ~= "" then
            relevantReports = relevantReports + 1
        end
    end
    
    if relevantReports >= 2 then
        return ConfidenceConfig.quality_multipliers.complete
    elseif relevantReports >= 1 then
        return ConfidenceConfig.quality_multipliers.partial
    else
        return ConfidenceConfig.quality_multipliers.minimal
    end
end

-- Assess mechanic inspection quality
function AssessMechanicInspectionQuality(mechanicReport)
    if not mechanicReport then
        return ConfidenceConfig.quality_multipliers.none
    end
    
    local damagedParts = mechanicReport.damaged_parts or {}
    
    if #damagedParts >= 5 then
        return ConfidenceConfig.quality_multipliers.complete
    elseif #damagedParts >= 2 then
        return ConfidenceConfig.quality_multipliers.partial
    elseif #damagedParts >= 1 then
        return ConfidenceConfig.quality_multipliers.minimal
    else
        return ConfidenceConfig.quality_multipliers.none
    end
end

-- Assess driver statement quality
function AssessDriverStatementQuality(statement)
    if not statement or statement == "" or statement == "(no statement provided)" then
        return ConfidenceConfig.quality_multipliers.none
    end
    
    local wordCount = #string.split(statement, " ")
    
    if wordCount >= 20 then
        return ConfidenceConfig.quality_multipliers.complete
    elseif wordCount >= 10 then
        return ConfidenceConfig.quality_multipliers.partial
    elseif wordCount >= 5 then
        return ConfidenceConfig.quality_multipliers.minimal
    else
        return ConfidenceConfig.quality_multipliers.none
    end
end

-- Assess EMS report quality
function AssessEMSReportQuality(emsReports)
    if not emsReports or #emsReports == 0 then
        return ConfidenceConfig.quality_multipliers.none
    end
    
    local detailedReports = 0
    for _, report in ipairs(emsReports) do
        if report.injury_severity and report.treatment then
            detailedReports = detailedReports + 1
        end
    end
    
    if detailedReports >= 1 then
        return ConfidenceConfig.quality_multipliers.complete
    else
        return ConfidenceConfig.quality_multipliers.partial
    end
end

-- Get vehicle data description
function GetVehicleDataDescription(vehicleData)
    if not vehicleData then
        return "No vehicle data available"
    end
    
    local fields = {}
    if vehicleData.model then table.insert(fields, "model") end
    if vehicleData.plate then table.insert(fields, "plate") end
    if vehicleData.engine_health then table.insert(fields, "engine health") end
    if vehicleData.body_health then table.insert(fields, "body health") end
    if vehicleData.fuel_tank_health then table.insert(fields, "fuel tank health") end
    
    return "Vehicle data: " .. table.concat(fields, ", ")
end

-- Get witness description
function GetWitnessDescription(witnessReports)
    if not witnessReports or #witnessReports == 0 then
        return "No witnesses"
    end
    
    local credibleCount = 0
    for _, witness in ipairs(witnessReports) do
        if witness.likely_witness then
            credibleCount = credibleCount + 1
        end
    end
    
    return string.format("%d witness(es), %d credible", #witnessReports, credibleCount)
end

-- Get police report description
function GetPoliceReportDescription(policeReports)
    if not policeReports or #policeReports == 0 then
        return "No police reports"
    end
    
    return string.format("%d police report(s)", #policeReports)
end

-- Get mechanic inspection description
function GetMechanicInspectionDescription(mechanicReport)
    if not mechanicReport then
        return "No mechanic inspection"
    end
    
    local damagedParts = mechanicReport.damaged_parts or {}
    return string.format("%d damaged part(s) identified", #damagedParts)
end

-- Get driver statement description
function GetDriverStatementDescription(statement)
    if not statement or statement == "" then
        return "No statement provided"
    end
    
    local wordCount = #string.split(statement, " ")
    return string.format("Statement: %d words", wordCount)
end

-- Get EMS report description
function GetEMSReportDescription(emsReports)
    if not emsReports or #emsReports == 0 then
        return "No EMS reports"
    end
    
    return string.format("%d EMS report(s)", #emsReports)
end

-- Determine confidence level from score
function DetermineConfidenceLevel(score)
    if score >= 80 then
        return "high"
    elseif score >= 60 then
        return "medium"
    elseif score >= 40 then
        return "low"
    else
        return "very_low"
    end
end

-- Check if confidence is sufficient for decision
function IsConfidenceSufficient(confidenceScore, decisionType)
    local thresholds = {
        approve = 70,
        deny = 60,
        investigate = 40
    }
    
    local threshold = thresholds[decisionType] or 50
    return confidenceScore >= threshold
end

-- Generate confidence summary for AI
function GenerateConfidenceSummary(confidenceAssessment)
    local summary = {}
    
    table.insert(summary, string.format("Overall Confidence: %d%% (%s)", 
        confidenceAssessment.score, confidenceAssessment.level))
    
    table.insert(summary, "Evidence Quality Breakdown:")
    
    for _, evidence in ipairs(confidenceAssessment.evidence_quality) do
        local qualityPercent = evidence.quality * 100
        table.insert(summary, string.format("- %s: %d%% (weight: %d%%, score: %d)", 
            evidence.type, qualityPercent, evidence.weight, evidence.score))
    end
    
    return table.concat(summary, "\n")
end

-- Export functions
exports('CalculateInvestigationConfidence', CalculateInvestigationConfidence)
exports('DetermineConfidenceLevel', DetermineConfidenceLevel)
exports('IsConfidenceSufficient', IsConfidenceSufficient)
exports('GenerateConfidenceSummary', GenerateConfidenceSummary)
