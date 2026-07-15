--[[
    claim_history.lua (server)
    Persistent claim history storage for each player.
]]

function SaveClaimHistoryEntry(claimId, evidence, verdict, companyName, reconstruction)
    local historySummary = string.format(
        'Claim %s for %s. Decision: %s. Amount: $%d. Company: %s.',
        evidence.claim_number or claimId,
        evidence.vehicle and evidence.vehicle.model or 'unknown vehicle',
        verdict and verdict.decision or 'unknown',
        verdict and verdict.approvedAmount or 0,
        companyName or 'unknown'
    )

    MySQL.insert([[
        INSERT INTO insurance_claim_history
        (claim_id, claim_number, citizenid, company_name, decision, approved_amount, summary, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
    ]], {
        claimId,
        evidence.claim_number,
        evidence.citizenid,
        companyName or 'unknown',
        verdict and verdict.decision or 'unknown',
        verdict and verdict.approvedAmount or 0,
        historySummary
    })

    SaveAdjusterMemory(evidence.citizenid, historySummary)
end

function GetInvestigationHistory(citizenid, cb)
    MySQL.query('SELECT * FROM insurance_claim_history WHERE citizenid = ? ORDER BY created_at DESC LIMIT 10', { citizenid }, function(rows)
        cb(rows or {})
    end)
end

exports('SaveClaimHistoryEntry', SaveClaimHistoryEntry)
exports('GetInvestigationHistory', GetInvestigationHistory)
