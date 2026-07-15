--[[
    report.lua (server)
    Professional claim letter/report generator.
    Generates formal insurance reports suitable for RP.
]]

-- Generate a professional insurance claim letter
function GenerateClaimLetter(claimId, verdict, evidence, cb)
    MySQL.single('SELECT * FROM insurance_claims_enhanced WHERE id = ?', { claimId }, function(claim)
        if not claim then
            cb(false, nil, 'claim_not_found')
            return
        end

        -- Build the claim letter
        local letter = {
            company_name = 'Blaine County Mutual Insurance',
            company_address = '120 Route 68, Sandy Shores, Blaine County 92505',
            claim_number = claim.claim_number,
            date = os.date('%B %d, %Y'),
            
            -- Claimant information
            claimant = {
                name = evidence.driver.name,
                citizenid = evidence.citizenid
            },
            
            -- Vehicle information
            vehicle = {
                model = evidence.vehicle.model,
                plate = evidence.vehicle.plate,
                vin = evidence.vehicle.vin,
                policy_tier = evidence.policy.tier
            },
            
            -- Incident summary
            incident = {
                date = claim.accident_date,
                time = os.date('%I:%M %p', os.time(claim.accident_date)),
                location = claim.street_name,
                weather = claim.weather,
                road_type = claim.road_type
            },
            
            -- Evidence reviewed
            evidence_reviewed = {
                mechanic_inspection = claim.mechanic_report ~= nil,
                witness_statements = claim.witness_reports ~= nil,
                police_reports = claim.police_reports ~= nil and #claim.police_reports > 0,
                ems_reports = claim.ems_reports ~= nil and #claim.ems_reports > 0,
                vehicle_telemetry = true,
                driver_history = true
            },
            
            -- Mechanic findings
            mechanic_findings = claim.mechanic_report and json.decode(claim.mechanic_report) or nil,
            
            -- Witness statements summary
            witness_summary = claim.witness_reports and GenerateConsolidatedWitnessSummary(
                json.decode(claim.witness_reports).witnesses
            ) or 'No witnesses present.',
            
            -- Police findings
            police_findings = claim.police_reports or 'No police reports attached.',
            
            -- Decision
            decision = {
                status = claim.decision,
                confidence = claim.confidence,
                fraud_risk = claim.fraud_risk,
                risk_score = claim.risk_score
            },
            
            -- Payment
            payment = {
                approved_amount = claim.approved_amount,
                deductible = claim.deductible,
                total_repair_cost = claim.mechanic_report and json.decode(claim.mechanic_report).total_cost or 0
            },
            
            -- Adjuster notes
            adjuster_notes = claim.adjuster_notes or verdict.adjusterNotes or '',

            -- Reconstruction summary
            reconstruction = verdict and verdict.reconstruction or nil,
            
            -- Reasoning
            reasoning = claim.reasoning or verdict.reasoning or '',
            
            -- Signature
            adjuster_signature = 'Denise Okafor',
            adjuster_title = 'Claims Adjuster II',
            department = 'Claims Department'
        }

        -- Format the letter as text
        local formattedLetter = FormatClaimLetter(letter)

        cb(true, {
            letter = letter,
            formatted = formattedLetter
        }, nil)
    end)
end

-- Format the claim letter as readable text
function FormatClaimLetter(letter)
    local lines = {}
    
    -- Header
    table.insert(lines, letter.company_name)
    table.insert(lines, letter.company_address)
    table.insert(lines, '')
    table.insert(lines, string.format('Date: %s', letter.date))
    table.insert(lines, '')
    table.insert(lines, string.format('Claim Number: %s', letter.claim_number))
    table.insert(lines, string.format('Claimant: %s', letter.claimant.name))
    table.insert(lines, '')
    
    -- Vehicle Information
    table.insert(lines, 'VEHICLE INFORMATION')
    table.insert(lines, string.format('Model: %s', letter.vehicle.model))
    table.insert(lines, string.format('License Plate: %s', letter.vehicle.plate))
    table.insert(lines, string.format('VIN: %s', letter.vehicle.vin))
    table.insert(lines, string.format('Policy Tier: %s', string.upper(letter.vehicle.policy_tier)))
    table.insert(lines, '')
    
    -- Incident Summary
    table.insert(lines, 'INCIDENT SUMMARY')
    table.insert(lines, string.format('Date: %s', letter.incident.date))
    table.insert(lines, string.format('Time: %s', letter.incident.time))
    table.insert(lines, string.format('Location: %s', letter.incident.location))
    table.insert(lines, string.format('Weather: %s', letter.incident.weather))
    table.insert(lines, string.format('Road Type: %s', letter.incident.road_type))
    table.insert(lines, '')
    
    -- Evidence Reviewed
    table.insert(lines, 'EVIDENCE REVIEWED')
    local evidenceItems = {
        {letter.evidence_reviewed.mechanic_inspection, 'Mechanic Inspection'},
        {letter.evidence_reviewed.witness_statements, 'Witness Statements'},
        {letter.evidence_reviewed.police_reports, 'Police Reports'},
        {letter.evidence_reviewed.ems_reports, 'EMS Reports'},
        {letter.evidence_reviewed.vehicle_telemetry, 'Vehicle Telemetry'},
        {letter.evidence_reviewed.driver_history, 'Driver History'}
    }
    
    for _, item in ipairs(evidenceItems) do
        local status = item[1] and '[X]' or '[ ]'
        table.insert(lines, string.format('%s %s', status, item[2]))
    end
    table.insert(lines, '')
    
    -- Mechanic Findings
    table.insert(lines, 'MECHANIC FINDINGS')
    if letter.mechanic_findings then
        table.insert(lines, string.format('Total Repair Cost: $%d', letter.mechanic_findings.total_cost or 0))
        table.insert(lines, string.format('Parts Cost: $%d', letter.mechanic_findings.parts_cost or 0))
        table.insert(lines, string.format('Labor Cost: $%d', letter.mechanic_findings.labor_cost or 0))
        table.insert(lines, string.format('Repair Time: %.1f hours', letter.mechanic_findings.repair_time_hours or 0))
        
        if letter.mechanic_findings.damaged_parts and #letter.mechanic_findings.damaged_parts > 0 then
            table.insert(lines, 'Damaged Parts:')
            for _, part in ipairs(letter.mechanic_findings.damaged_parts) do
                table.insert(lines, string.format('  - %s (%s): %s', part.part, part.severity, part.description))
            end
        end
    else
        table.insert(lines, 'No mechanic inspection available.')
    end
    table.insert(lines, '')
    
    -- Witness Statements
    table.insert(lines, 'WITNESS STATEMENTS')
    table.insert(lines, letter.witness_summary)
    table.insert(lines, '')
    
    -- Police Findings
    table.insert(lines, 'POLICE FINDINGS')
    if type(letter.police_findings) == 'table' and #letter.police_findings > 0 then
        for _, report in ipairs(letter.police_findings) do
            table.insert(lines, string.format('- %s: %s', report.citation_type or 'Report', report.description or 'No details'))
        end
    else
        table.insert(lines, letter.police_findings)
    end
    table.insert(lines, '')
    
    -- Decision
    table.insert(lines, 'CLAIM DECISION')
    local decisionUpper = string.upper(letter.decision.status)
    table.insert(lines, string.format('Status: %s', decisionUpper))
    table.insert(lines, string.format('Confidence: %d%%', letter.decision.confidence or 0))
    table.insert(lines, string.format('Fraud Risk: %s', string.upper(letter.decision.fraud_risk or 'unknown')))
    table.insert(lines, string.format('Risk Score: %d/100', letter.decision.risk_score or 0))
    table.insert(lines, '')
    
    -- Payment
    table.insert(lines, 'PAYMENT INFORMATION')
    if letter.decision.status == 'approved' then
        table.insert(lines, string.format('Approved Amount: $%d', letter.payment.approved_amount or 0))
        table.insert(lines, string.format('Deductible: $%d', letter.payment.deductible or 0))
        table.insert(lines, string.format('Total Repair Cost: $%d', letter.payment.total_repair_cost or 0))
    else
        table.insert(lines, 'No payment approved.')
    end
    table.insert(lines, '')
    
    -- Reconstruction
    if letter.reconstruction then
        table.insert(lines, 'CRASH RECONSTRUCTION')
        table.insert(lines, string.format('Impact Speed: %d mph', letter.reconstruction.impact_speed or 0))
        table.insert(lines, string.format('Primary Impact: %s', letter.reconstruction.primary_impact or 'unknown'))
        table.insert(lines, string.format('Vehicle Rotation: %d°', letter.reconstruction.vehicle_rotation or 0))
        table.insert(lines, string.format('Likely Cause: %s', letter.reconstruction.likely_cause or 'unknown'))
        table.insert(lines, '')
    end

    -- Adjuster Notes
    if letter.adjuster_notes and letter.adjuster_notes ~= '' then
        table.insert(lines, 'ADJUSTER NOTES')
        table.insert(lines, letter.adjuster_notes)
        table.insert(lines, '')
    end
    
    -- Reasoning
    table.insert(lines, 'DECISION REASONING')
    table.insert(lines, letter.reasoning)
    table.insert(lines, '')
    
    -- Signature
    table.insert(lines, string.format('Sincerely,'))
    table.insert(lines, string.format('%s', letter.adjuster_signature))
    table.insert(lines, string.format('%s', letter.adjuster_title))
    table.insert(lines, string.format('%s', letter.department))
    table.insert(lines, string.format('%s', letter.company_name))
    
    return table.concat(lines, '\n')
end

-- Save claim letter to database (optional)
function SaveClaimLetter(claimId, letterData)
    MySQL.query([[
        UPDATE insurance_claims_enhanced 
        SET claim_letter = ?
        WHERE id = ?
    ]], { json.encode(letterData), claimId })
end

-- Send claim letter to client
function SendClaimLetterToClient(src, claimId)
    GenerateClaimLetter(claimId, {}, {}, function(success, result, err)
        if not success then
            print('[ai_insurance_adjuster] Failed to generate claim letter:', err)
            return
        end

        -- Save to database
        SaveClaimLetter(claimId, result.letter)

        -- Send to client
        TriggerClientEvent('ai_insurance_adjuster:claimLetter', src, {
            formatted = result.formatted,
            data = result.letter
        })
    end)
end

-- Register event to request claim letter
RegisterNetEvent('ai_insurance_adjuster:requestClaimLetter', function(claimId)
    local src = source
    SendClaimLetterToClient(src, claimId)
end)
