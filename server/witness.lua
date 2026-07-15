--[[
    witness.lua (server)
    Witness detection and summary system.
    Automatically searches for nearby players and generates witness statements.
]]

-- Detect nearby witnesses to an accident
function DetectWitnesses(src, accidentLocation, cb)
    local witnesses = {}
    local accidentCoords = vector3(accidentLocation.x, accidentLocation.y, accidentLocation.z)
    local searchRadius = 100.0 -- 100 meters

    -- Get all players
    local players = GetPlayers()
    
    for _, playerId in ipairs(players) do
        local pedId = GetPlayerPed(playerId)
        if pedId and tonumber(playerId) ~= tonumber(src) then -- Exclude the claimant
            local pedCoords = GetEntityCoords(pedId)
            local distance = #(accidentCoords - pedCoords)
            
            if distance <= searchRadius then
                -- Check if the witness has line of sight to the accident location
                local hasLineOfSight = CheckLineOfSight(pedCoords, accidentCoords)
                
                -- Determine if they likely witnessed the collision
                local likelyWitness = distance <= 50.0 and hasLineOfSight
                
                table.insert(witnesses, {
                    id = playerId,
                    citizenid = getCitizenId(playerId),
                    name = getCharacterName(playerId),
                    distance = distance,
                    position = {
                        x = pedCoords.x,
                        y = pedCoords.y,
                        z = pedCoords.z
                    },
                    line_of_sight = hasLineOfSight,
                    likely_witness = likelyWitness
                })
            end
        end
    end

    cb(witnesses)
end

-- Check line of sight between two points
function CheckLineOfSight(from, to)
    -- This is a simplified check. In a full implementation, you would use
    -- StartShapeTestRay to check for obstacles between the points
    -- For now, we'll assume line of sight if within reasonable distance
    local distance = #(from - to)
    return distance < 75.0 -- Assume line of sight within 75 meters
end

-- Generate witness summaries using AI
function GenerateWitnessSummaries(witnesses, accidentData, cb)
    if #witnesses == 0 then
        cb({})
        return
    end

    -- Build prompt for AI to generate witness summaries
    local witnessPrompt = [[
You are generating witness summaries for an insurance investigation.
For each witness, generate a brief, factual statement about what they likely observed.

Witness data: ]] .. json.encode(witnesses) .. [[

Accident details: ]] .. json.encode(accidentData) .. [[

Generate a summary for each witness in this JSON format:
{
  "witness_summaries": [
    {
      "witness_id": 1,
      "summary": "Brief statement about what this witness likely observed",
      "credibility": "high|medium|low"
    }
  ]
}

Consider:
- Distance from accident
- Line of sight
- Number of witnesses (corroboration)
- Accident circumstances

Keep summaries factual and brief. Do not hallucinate details.
]]

    -- Call AI to generate summaries
    local apiKey = GetConvar(Config.APIKeyConvar, '')
    if apiKey == '' then
        -- Fallback: generate simple summaries without AI
        local summaries = {}
        for i, witness in ipairs(witnesses) do
            local summary
            if witness.likely_witness then
                summary = string.format('Witness #%d was approximately %.1f meters from the incident with clear line of sight.', i, witness.distance)
            else
                summary = string.format('Witness #%d was approximately %.1f meters away but likely did not have a clear view.', i, witness.distance)
            end
            table.insert(summaries, {
                witness_id = i,
                summary = summary,
                credibility = witness.likely_witness and 'medium' or 'low'
            })
        end
        cb(summaries)
        return
    end

    -- Use AI to generate more sophisticated summaries
    CallAIWithFallbacks(Config.AdjusterPersona, witnessPrompt, 1000, function(success, text, err)
        if not success or not text then
            -- Fallback to simple summaries
            local summaries = {}
            for i, witness in ipairs(witnesses) do
                local summary = string.format('Witness #%d was %.1f meters away.', i, witness.distance)
                table.insert(summaries, {
                    witness_id = i,
                    summary = summary,
                    credibility = 'low'
                })
            end
            cb(summaries)
            return
        end

        text = text:gsub('```json', ''):gsub('```', ''):gsub('^%s+', ''):gsub('%s+$', '')

        local summaryOk, summaryData = pcall(json.decode, text)
        if not summaryOk or not summaryData or not summaryData.witness_summaries then
            cb({})
            return
        end

        cb(summaryData.witness_summaries)
    end)
end

-- Save witness reports to database
function SaveWitnessReports(claimId, witnesses, summaries)
    for i, witness in ipairs(witnesses) do
        local summary = summaries[i] and summaries[i].summary or 'No summary available'
        local credibility = summaries[i] and summaries[i].credibility or 'low'

        MySQL.insert([[
            INSERT INTO insurance_witnesses 
            (claim_id, witness_citizenid, witness_name, distance, position_x, position_y, position_z,
             line_of_sight, likely_witness, statement, summary)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            claimId,
            witness.citizenid,
            witness.name,
            witness.distance,
            witness.position.x,
            witness.position.y,
            witness.position.z,
            witness.line_of_sight,
            witness.likely_witness,
            'Witness statement pending',
            summary
        })
    end
end

-- Get witness reports for a claim
function GetWitnessReports(claimId, cb)
    MySQL.query('SELECT * FROM insurance_witnesses WHERE claim_id = ?', { claimId }, cb)
end

-- Generate a consolidated witness summary for the AI investigation
function GenerateConsolidatedWitnessSummary(witnessReports)
    if not witnessReports or #witnessReports == 0 then
        return 'No witnesses were present at the scene.'
    end

    local summary = {}
    local credibleCount = 0
    local totalWitnesses = #witnessReports

    for i, report in ipairs(witnessReports) do
        local credibility = report.credibility or 'low'
        if credibility == 'high' or credibility == 'medium' then
            credibleCount = credibleCount + 1
        end
        
        table.insert(summary, string.format(
            'Witness #%d: %s (Distance: %.1fm, Line of Sight: %s, Credibility: %s)',
            i,
            report.summary or 'No statement available',
            report.distance,
            report.line_of_sight and 'Yes' or 'No',
            credibility
        ))
    end

    local header = string.format(
        '%d witness(es) identified at the scene. %d credible witness(es).\n',
        totalWitnesses,
        credibleCount
    )

    return header .. table.concat(summary, '\n')
end
