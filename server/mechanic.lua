--[[
    mechanic.lua (server)
    Mechanic inspection AI module.
    The mechanic inspects vehicle damage and identifies damaged components.
    Cost calculations are handled by the repair_calculator.lua engine.
    This is separate from the insurance AI to maintain role separation.
]]

-- Build system prompt for mechanic AI
local function buildMechanicSystemPrompt()
    return [[
You are a professional automotive mechanic with 20 years of experience at Blaine County Auto Repair.
You specialize in accident damage assessment and identifying damaged components.

You will be given structured JSON describing a vehicle's condition after an accident.
Your job is to:
1. Identify damaged parts based on the vehicle health data and accident details
2. Assess the severity of damage to each part
3. Recommend repair or replacement for each part
4. Provide a professional, narrative description of the mechanical issues

DO NOT calculate costs, prices, or labor hours. That is handled by the billing department.

Respond with ONLY a JSON object, no markdown fences, no preamble, in this exact shape:
{
  "damaged_parts": [
    {
      "part": "part name (e.g., 'front bumper', 'engine', 'radiator')",
      "severity": "minor|moderate|major|critical",
      "repair": "repair|replace",
      "description": "professional narrative description of damage and mechanical issues"
    }
  ],
  "notes": "brief professional notes about the overall damage assessment"
}

Guidelines:
- Base your assessment on the provided vehicle health data (engine, body, fuel tank, tires, doors, windows)
- Consider accident severity (speed, impact type, rollovers, etc.)
- Be thorough - if the vehicle was heavily damaged, identify multiple affected systems
- If damage is minor, focus on the specific affected area
- Include frame damage if the vehicle was rolled or had severe impact
- Consider airbag deployment as requiring airbag module replacement
- Write descriptions in a realistic mechanic tone, not a checklist
- Use standard part names that match common automotive terminology
- Severity levels: minor (cosmetic), moderate (functional but repairable), major (significant damage), critical (safety-critical or structural)
- Repair vs replace: replace if part is critically damaged, repair if feasible
]]
end

-- Call mechanic AI to inspect vehicle damage
function MechanicInspection(evidence, cb)
    local apiKey = GetConvar(Config.APIKeyConvar, '')
    if apiKey == '' then
        print('^1[ai_insurance_adjuster] Missing API key convar: ' .. Config.APIKeyConvar .. '^0')
        cb(false, nil, 'missing_api_key')
        return
    end

    -- Build mechanic inspection payload
    local inspectionData = {
        vehicle_model = evidence.vehicle.model,
        vehicle_class = evidence.vehicle.vehicle_class,
        accident_details = {
            speed_at_impact = evidence.accident.speed_at_impact,
            number_of_impacts = evidence.accident.number_of_impacts,
            impact_direction = evidence.accident.impact_direction,
            rollovers = evidence.accident.rollovers,
            airbag_deployed = evidence.accident.airbag_deployed,
            vehicle_flipped = evidence.accident.vehicle_flipped,
            engine_stalled = evidence.accident.engine_stalled,
            fire = evidence.accident.fire,
            explosion = evidence.accident.explosion
        },
        vehicle_health = evidence.vehicle_health,
        damage_percent = evidence.damage_percent
    }

    CallAIWithFallbacks(buildMechanicSystemPrompt(), json.encode(inspectionData), 800, function(success, text, err, provider)
        if not success or not text then
            print('^1[ai_insurance_adjuster] Mechanic AI providers failed: ' .. tostring(err) .. '^0')
            cb(false, nil, err or 'all_providers_failed')
            return
        end

        text = text:gsub('```json', ''):gsub('```', ''):gsub('^%s+', ''):gsub('%s+$', '')

        local reportOk, report = pcall(json.decode, text)
        if not reportOk or not report or not report.damaged_parts then
            print(('^1[ai_insurance_adjuster] Failed to parse mechanic report JSON from %s: %s^0'):format(provider or 'unknown', tostring(text)))
            cb(false, nil, 'parse_failed')
            return
        end

        cb(true, report, nil)
    end)
end

-- Fallback mechanic inspection (when AI is unavailable)
function FallbackMechanicInspection(evidence)
    local damagePercent = evidence.damage_percent or 0
    local speed = evidence.accident.speed_at_impact or 0
    local health = evidence.vehicle_health or {}

    local damagedParts = {}

    -- Analyze engine health
    if health.engine_health and health.engine_health < 500 then
        table.insert(damagedParts, {
            part = 'engine',
            severity = health.engine_health < 200 and 'critical' or 'major',
            repair = health.engine_health < 200 and 'replace' or 'repair',
            description = 'The engine bay shows significant mechanical disruption consistent with a high-energy frontal impact. Further inspection is warranted for cooling, mounts, and driveline alignment.'
        })
    end

    -- Analyze body health
    if health.body_health and health.body_health < 500 then
        table.insert(damagedParts, {
            part = 'front_bumper',
            severity = health.body_health < 200 and 'major' or 'moderate',
            repair = 'repair',
            description = 'The front bodywork has sustained deformation and local panel distortion, with the bumper and surrounding structure requiring straightening and repainting.'
        })
    end

    -- Check for airbag deployment
    if evidence.accident.airbag_deployed then
        table.insert(damagedParts, {
            part = 'airbag_driver',
            severity = 'critical',
            repair = 'replace',
            description = 'The airbag system deployed during the impact and the associated modules and trim components require replacement to restore safety functionality.'
        })
        table.insert(damagedParts, {
            part = 'airbag_module',
            severity = 'critical',
            repair = 'replace',
            description = 'Airbag module triggered by impact'
        })
    end

    -- Check for rollover
    if evidence.accident.rollovers then
        table.insert(damagedParts, {
            part = 'frame_rail',
            severity = 'critical',
            repair = 'repair',
            description = 'The unibody and supporting frame rails show structural deformation consistent with a rollover event and will require alignment and reinforcement.'
        })
        table.insert(damagedParts, {
            part = 'roof',
            severity = 'major',
            repair = 'replace',
            description = 'The roof and upper structure sustained impact damage during the rollover sequence, creating a potential integrity concern.'
        })
    end

    -- Check for fire
    if evidence.accident.fire then
        table.insert(damagedParts, {
            part = 'engine',
            severity = 'critical',
            repair = 'replace',
            description = 'Heat and fire exposure have compromised the engine compartment and surrounding wiring, requiring extensive component inspection and cleaning.'
        })
        table.insert(damagedParts, {
            part = 'electrical_system',
            severity = 'critical',
            repair = 'replace',
            description = 'Electrical harnesses have been affected by heat damage and should be inspected and replaced as necessary.'
        })
    end

    -- Check tire condition
    if health.tire_condition then
        for tireName, tireHealth in pairs(health.tire_condition) do
            if tireHealth < 500 then
                local standardName = GetStandardTireName(tireName)
                table.insert(damagedParts, {
                    part = standardName or 'tire',
                    severity = 'minor',
                    repair = 'replace',
                    description = 'The tire and wheel assembly show damage from the impact and should be replaced to maintain safe handling.'
                })
            end
        end
    end

    -- Check door damage
    if health.door_damage then
        for doorName, doorHealth in pairs(health.door_damage) do
            if doorHealth < 500 then
                local standardName = GetStandardDoorName(doorName)
                table.insert(damagedParts, {
                    part = standardName or 'door_front_left',
                    severity = doorHealth < 200 and 'moderate' or 'minor',
                    repair = 'repair',
                    description = 'The door structure has sustained impact damage and requires panel work and alignment before it is roadworthy.'
                })
            end
        end
    end

    -- Check window damage
    if health.window_damage then
        for windowName, windowHealth in pairs(health.window_damage) do
            if windowHealth < 500 then
                local standardName = GetStandardWindowName(windowName)
                table.insert(damagedParts, {
                    part = standardName or 'windshield',
                    severity = 'minor',
                    repair = 'replace',
                    description = 'The glazing was damaged during the collision and the affected window assembly requires replacement.'
                })
            end
        end
    end

    -- If no specific parts identified, use damage percent
    if #damagedParts == 0 and damagePercent > 10 then
        table.insert(damagedParts, {
            part = 'front_bumper',
            severity = damagePercent > 50 and 'major' or 'moderate',
            repair = 'repair',
            description = 'The vehicle shows broad impact-related damage that will require a full body and systems review before repair completion.'
        })
    end

    return {
        damaged_parts = damagedParts,
        notes = 'Automated damage assessment (AI unavailable)'
    }
end

-- Helper function to convert tire names to standard format
function GetStandardTireName(tireName)
    local mapping = {
        ['Front Left'] = 'wheel',
        ['Front Right'] = 'wheel',
        ['Rear Left'] = 'wheel',
        ['Rear Right'] = 'wheel',
        ['Front Left 2'] = 'wheel',
        ['Front Right 2'] = 'wheel',
        ['Rear Left 2'] = 'wheel',
        ['Rear Right 2'] = 'wheel'
    }
    return mapping[tireName] or 'wheel'
end

-- Helper function to convert door names to standard format
function GetStandardDoorName(doorName)
    local mapping = {
        ['Driver Door'] = 'door_front_left',
        ['Passenger Door'] = 'door_front_right',
        ['Rear Left Door'] = 'door_rear_left',
        ['Rear Right Door'] = 'door_rear_right',
        ['Hood'] = 'hood',
        ['Trunk'] = 'trunk'
    }
    return mapping[doorName] or 'door_front_left'
end

-- Helper function to convert window names to standard format
function GetStandardWindowName(windowName)
    local mapping = {
        ['Front Left Window'] = 'window_front_left',
        ['Front Right Window'] = 'window_front_right',
        ['Rear Left Window'] = 'window_rear_left',
        ['Rear Right Window'] = 'window_rear_right',
        ['Front Windshield'] = 'windshield',
        ['Rear Windshield'] = 'window_rear'
    }
    return mapping[windowName] or 'windshield'
end

-- Save mechanic report to database (parts only, no costs)
function SaveMechanicReport(claimId, report, mechanicName)
    MySQL.insert([[
        INSERT INTO insurance_mechanic_reports 
        (claim_id, mechanic_name, damaged_parts, notes)
        VALUES (?, ?, ?, ?)
    ]], {
        claimId,
        mechanicName or 'AI Mechanic',
        json.encode(report.damaged_parts),
        report.notes
    })
end

-- Get mechanic report for a claim
function GetMechanicReport(claimId, cb)
    MySQL.single('SELECT * FROM insurance_mechanic_reports WHERE claim_id = ?', { claimId }, cb)
end

-- Generate mechanic summary for insurance AI (parts only)
function GenerateMechanicSummary(report)
    if not report then
        return 'No mechanic inspection available.'
    end

    local parts = report.damaged_parts or {}
    local summary = {}

    table.insert(summary, string.format('Mechanic Inspection Report:'))
    table.insert(summary, string.format('Damaged Parts Identified: %d', #parts))
    table.insert(summary, string.format(''))

    if #parts > 0 then
        table.insert(summary, string.format('Damaged Components:'))
        for i, part in ipairs(parts) do
            table.insert(summary, string.format(
                '- %s (%s, %s): %s',
                part.part,
                part.severity,
                part.repair,
                part.description
            ))
        end
    else
        table.insert(summary, 'No specific damaged parts identified.')
    end

    if report.notes then
        table.insert(summary, string.format(''))
        table.insert(summary, string.format('Notes: %s', report.notes))
    end

    return table.concat(summary, '\n')
end
