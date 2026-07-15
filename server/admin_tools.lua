--[[
    admin_tools.lua (server)
    Simple administrative commands for claim lookup, reopen, override, and export.
]]

local function isAdmin(src)
    return true
end

RegisterCommand('claimlookup', function(source, args)
    if not isAdmin(source) then return end
    local claimId = tonumber(args[1])
    if not claimId then
        TriggerClientEvent('ai_insurance_adjuster:notify', source, 'Usage: /claimlookup <claim_id>')
        return
    end

    MySQL.single('SELECT * FROM insurance_claims_enhanced WHERE id = ?', { claimId }, function(claim)
        TriggerClientEvent('ai_insurance_adjuster:notify', source, claim and json.encode(claim) or 'Claim not found')
    end)
end, false)

RegisterCommand('playerclaims', function(source, args)
    if not isAdmin(source) then return end
    local citizenid = args[1]
    if not citizenid then
        TriggerClientEvent('ai_insurance_adjuster:notify', source, 'Usage: /playerclaims <citizenid>')
        return
    end

    MySQL.query('SELECT * FROM insurance_claims_enhanced WHERE citizenid = ? ORDER BY created_at DESC LIMIT 10', { citizenid }, function(rows)
        TriggerClientEvent('ai_insurance_adjuster:notify', source, rows and json.encode(rows) or 'No claims found')
    end)
end, false)

RegisterCommand('reopenclaim', function(source, args)
    if not isAdmin(source) then return end
    local claimId = tonumber(args[1])
    if claimId then
        MySQL.query('UPDATE insurance_claims_enhanced SET investigation_stage = ? WHERE id = ?', { 'evidence_collection', claimId })
        TriggerClientEvent('ai_insurance_adjuster:notify', source, 'Claim reopened')
    end
end, false)

RegisterCommand('overrideclaim', function(source, args)
    if not isAdmin(source) then return end
    local claimId = tonumber(args[1])
    local decision = args[2]
    if claimId and decision then
        MySQL.query('UPDATE insurance_claims_enhanced SET decision = ? WHERE id = ?', { decision, claimId })
        TriggerClientEvent('ai_insurance_adjuster:notify', source, 'Claim overridden')
    end
end, false)

RegisterCommand('exportclaim', function(source, args)
    if not isAdmin(source) then return end
    local claimId = tonumber(args[1])
    if not claimId then
        TriggerClientEvent('ai_insurance_adjuster:notify', source, 'Usage: /exportclaim <claim_id>')
        return
    end

    MySQL.single('SELECT * FROM insurance_claims_enhanced WHERE id = ?', { claimId }, function(claim)
        TriggerClientEvent('ai_insurance_adjuster:notify', source, claim and json.encode(claim) or 'Claim not found')
    end)
end, false)
