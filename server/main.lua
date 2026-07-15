--[[
    main.lua (server)
    Wires together: claim submission -> multi-stage investigation -> payout -> logging.

    Integration points your main coder will need to hook up (marked with -- HOOK):
    - Giving the player money (framework-specific: QBCore/ESX/etc.)
    - Sending the verdict to the player's phone UI instead of a plain notification
    - Police/EMS report integration (framework-specific)
]]

local claimCooldowns = {} -- [citizenid] = os.time() of last claim

-- Note: Database tables are now created in shared/database.lua
-- This maintains backward compatibility with the original tables

-- Shared framework adapters are defined in server/utils.lua and exposed globally.

RegisterNetEvent('ai_insurance_adjuster:submitClaim', function(crashData)
    local src = source
    local citizenid = getCitizenId(src)

    -- Cooldown check
    local last = claimCooldowns[citizenid]
    if last and (os.time() - last) < Config.ClaimCooldown then
        TriggerClientEvent('ai_insurance_adjuster:notify', src,
            'You already have a claim being processed. Try again later.')
        return
    end

    -- Basic sanity checks server-side (never trust client telemetry blindly)
    if not crashData or not crashData.damagePercent or crashData.damagePercent < 0 or crashData.damagePercent > 100 then
        return
    end
    if crashData.damagePercent * 10 < Config.MinDamageThreshold then
        TriggerClientEvent('ai_insurance_adjuster:notify', src, 'Damage too minor to file a claim.')
        return
    end

    claimCooldowns[citizenid] = os.time()

    -- Start the multi-stage investigation
    print('[ai_insurance_adjuster] Starting multi-stage investigation for claim from', citizenid)
    StartInvestigation(crashData, src, function(success, result, err)
        if not success then
            TriggerClientEvent('ai_insurance_adjuster:notify', src,
                'Claims system is down. Try again later. (' .. tostring(err) .. ')')
            return
        end

        if result.status == 'awaiting_response' then
            -- AI has follow-up questions
            TriggerClientEvent('ai_insurance_adjuster:followUpQuestions', src, result.follow_up_questions)
            TriggerClientEvent('ai_insurance_adjuster:notify', src,
                'The adjuster has some questions about your claim. Please respond to continue.')
        elseif result.status == 'completed' then
            -- Investigation complete, process verdict
            local verdict = result.verdict
            
            -- Send verdict to client
            TriggerClientEvent('ai_insurance_adjuster:verdict', src, verdict)
            
            -- Process payout if approved
            if verdict.decision == 'approved' and verdict.approvedAmount and verdict.approvedAmount > 0 then
                payoutPlayer(src, verdict.approvedAmount)
            end
            
            -- Send claim letter
            SendClaimLetterToClient(src, result.claim_id)
        end
    end)
end)

RegisterNetEvent('ai_insurance_adjuster:requestPortalData', function()
    local src = source
    local citizenid = getCitizenId(src)
    BuildPortalData(citizenid, function(portalData)
        TriggerClientEvent('ai_insurance_adjuster:portalData', src, portalData)
    end)
end)

RegisterNetEvent('ai_insurance_adjuster:requestDashboard', function()
    local src = source
    local citizenid = getCitizenId(src)
    BuildDashboardData(citizenid, function(dashboardData)
        TriggerClientEvent('ai_insurance_adjuster:dashboardData', src, dashboardData)
    end)
end)
