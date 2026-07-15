--[[
    main.lua (client)
    Detects meaningful vehicle damage, collects comprehensive evidence,
    lets the player file a claim, and displays the AI adjuster's verdict.

    HOOK: the "GetPlayerStatement" and notify functions are placeholders -
    swap in your phone/UI framework (e.g. NUI callback, ox_lib input dialog, etc.)
]]

local lastEngineHealth = nil
local canFileClaim = false
local lastCrashData = nil
local lastVehicleInfo = nil
local lastAccidentInfo = nil

local function SendClientNotice(title, message)
    local uiConfig = Config and Config.UI or {}

    if type(uiConfig.Notify) == 'function' then
        uiConfig.Notify(title or 'Insurance', message)
        return
    end

    if uiConfig.NotificationMode == 'nui' then
        SendNUIMessage({ type = 'notification', title = title or 'Insurance', message = message })
        return
    end

    TriggerEvent('chat:addMessage', { args = { title or 'Insurance', message } })
end

CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            local health = GetVehicleEngineHealth(veh)

            if lastEngineHealth and (lastEngineHealth - health) > Config.MinDamageThreshold then
                local damagePercent = math.floor((1 - (health / 1000)) * 100)
                local speed = GetEntitySpeed(veh) * 2.236936 -- m/s to mph
                local coords = GetEntityCoords(ped)

                -- Collect comprehensive vehicle information
                local vehicleInfo = CollectVehicleInfo(veh)
                
                -- Collect comprehensive accident information
                local accidentInfo = CollectAccidentInfo(veh, speed)

                lastCrashData = {
                    vehicleModel = vehicleInfo.model,
                    plate = vehicleInfo.plate,
                    damagePercent = damagePercent,
                    impactSpeed = math.floor(speed),
                    location = { x = coords.x, y = coords.y, z = coords.z },
                    -- Expanded accident data
                    vehicleInfo = vehicleInfo,
                    accidentInfo = accidentInfo
                }
                
                lastVehicleInfo = vehicleInfo
                lastAccidentInfo = accidentInfo
                canFileClaim = true

                SendClientNotice('Insurance', 'Significant vehicle damage detected. Use /fileclaim to report it.')
            end

            lastEngineHealth = health
        else
            lastEngineHealth = nil
        end
        Wait(0)
    end
end)

RegisterCommand('fileclaim', function()
    if not canFileClaim or not lastCrashData then
        SendClientNotice('Insurance', 'No recent crash on file.')
        return
    end

    -- Expand crash data with comprehensive information
    local expandedData = {
        -- Original data for backward compatibility
        vehicleModel = lastCrashData.vehicleModel,
        damagePercent = lastCrashData.damagePercent,
        impactSpeed = lastCrashData.impactSpeed,
        location = lastCrashData.location,
        
        -- New comprehensive data
        plate = lastCrashData.plate,
        
        -- Vehicle health details
        engineHealth = lastVehicleInfo.engine_health,
        bodyHealth = lastVehicleInfo.body_health,
        fuelTankHealth = lastVehicleInfo.fuel_tank_health,
        tireCondition = lastVehicleInfo.tire_condition,
        doorDamage = lastVehicleInfo.door_damage,
        windowDamage = lastVehicleInfo.window_damage,
        
        -- Accident details
        streetName = lastAccidentInfo.street_name,
        weather = lastAccidentInfo.weather,
        roadType = lastAccidentInfo.road_type,
        speedBeforeImpact = lastAccidentInfo.speed_before_impact,
        numberOfImpacts = lastAccidentInfo.number_of_impacts,
        impactDirection = lastAccidentInfo.impact_direction,
        impactType = lastAccidentInfo.impact_type,
        impactCategory = lastAccidentInfo.impact_category,
        impactInvolvesPlayer = lastAccidentInfo.impact_involves_player,
        impactInvolvesEntity = lastAccidentInfo.impact_involves_entity,
        impactInvolvesWorldGeometry = lastAccidentInfo.impact_involves_world_geometry,
        impactLivable = lastAccidentInfo.impact_livable,
        impactSeverity = lastAccidentInfo.impact_severity,
        rollovers = lastAccidentInfo.rollovers,
        airbagDeployed = lastAccidentInfo.airbag_deployed,
        vehicleFlipped = lastAccidentInfo.vehicle_flipped,
        engineStalled = lastAccidentInfo.engine_stalled,
        fire = lastAccidentInfo.fire,
        explosion = lastAccidentInfo.explosion,
        occupants = lastAccidentInfo.occupants,
        seatbeltStatus = lastAccidentInfo.seatbelt_status,
        driverEjected = lastAccidentInfo.driver_ejected,
        vehicleDrivable = lastAccidentInfo.vehicle_drivable
    }

    -- HOOK: replace with a proper input dialog (ox_lib:input, NUI form, etc.)
    -- For now this is a stand-in that just files with a generic statement.
    local statement = 'Player did not provide additional details.'

    expandedData.playerStatement = statement
    TriggerServerEvent('ai_insurance_adjuster:submitClaim', expandedData)
    canFileClaim = false

    SendClientNotice('Insurance', 'Claim submitted. Awaiting investigation...')
end, false)

RegisterNetEvent('ai_insurance_adjuster:verdict', function(verdict)
    local decision = verdict.decision or 'unknown'
    local prefix = ({
        approved = '~g~APPROVED~s~',
        denied = '~r~DENIED~s~',
        investigate = '~y~UNDER REVIEW~s~'
    })[decision] or decision:upper()

    -- HOOK: this should render in your phone app / a proper letter-style UI, not chat
    SendClientNotice('Blaine County Mutual', ('[%s] %s'):format(prefix, verdict.reasoning))

    -- Display additional information from new structured format
    if verdict.confidence then
        SendClientNotice('Blaine County Mutual', ('Confidence: %d%%'):format(verdict.confidence))
    end

    if verdict.fraudRisk then
        SendClientNotice('Blaine County Mutual', ('Fraud Risk: %s'):format(string.upper(verdict.fraudRisk)))
    end

    if verdict.repairEstimate then
        SendClientNotice('Blaine County Mutual', ('Repair Estimate: $%d (Parts: $%d, Labor: $%d)'):format(
            verdict.repairEstimate.total or 0,
            verdict.repairEstimate.parts or 0,
            verdict.repairEstimate.labor or 0
        ))
    end

    if decision == 'approved' and verdict.approvedAmount then
        SendClientNotice('Blaine County Mutual', ('Approved Amount: $%d (Deductible: $%d)'):format(
            verdict.approvedAmount,
            verdict.deductible or 0
        ))
    end

    if verdict.flags and #verdict.flags > 0 then
        SendClientNotice('Blaine County Mutual', ('Flags: %s'):format(table.concat(verdict.flags, ', ')))
    end

    if verdict.reconstruction then
        SendClientNotice('Blaine County Mutual', ('Reconstruction: %s'):format(verdict.reconstruction.summary))
        SendClientNotice('Blaine County Mutual', verdict.reconstruction.diagram_ascii or 'Reconstruction diagram unavailable.')
    end
end)

RegisterNetEvent('ai_insurance_adjuster:notify', function(msg)
    SendClientNotice('Insurance', msg)
end)

-- Handle follow-up questions from the AI
RegisterNetEvent('ai_insurance_adjuster:followUpQuestions', function(questions)
    -- HOOK: Replace with proper UI for answering questions
    -- For now, we'll display them in chat and use a command to respond
    
    SendClientNotice('Blaine County Mutual', 'The adjuster has some questions about your claim:')
    
    for i, question in ipairs(questions) do
        SendClientNotice('Blaine County Mutual', string.format('%d. %s', i, question))
    end
    
    SendClientNotice('Blaine County Mutual', 'Please respond to each question using /answerclaim <claim_id> <answer1|answer2|...>')
end)

-- Handle claim letter display
RegisterNetEvent('ai_insurance_adjuster:claimLetter', function(letterData)
    -- HOOK: Replace with proper UI for displaying the letter
    -- For now, we'll display it in chat
    
    SendClientNotice('Blaine County Mutual', '=== CLAIM LETTER ===')
    
    -- Split the formatted letter into lines and display them
    for line in letterData.formatted:gmatch('[^\r\n]+') do
        SendClientNotice('Blaine County Mutual', line)
    end
    
    SendClientNotice('Blaine County Mutual', '=== END LETTER ===')
end)

-- Command to answer follow-up questions (placeholder)
RegisterCommand('claimportal', function()
    TriggerServerEvent('ai_insurance_adjuster:requestPortalData')
end, false)

RegisterCommand('claimdashboard', function()
    TriggerServerEvent('ai_insurance_adjuster:requestDashboard')
end, false)

RegisterCommand('uploadphoto', function(source, args)
    local photoUrl = args[1]
    local caption = table.concat(args, ' ', 2)
    if not photoUrl then
        TriggerEvent('chat:addMessage', { args = { 'Insurance', 'Usage: /uploadphoto <url> [caption]' } })
        return
    end

    TriggerServerEvent('ai_insurance_adjuster:submitPhotoEvidence', tonumber(args[2]) or 0, photoUrl, caption)
end, false)

RegisterNetEvent('ai_insurance_adjuster:dashboardData', function(dashboardData)
    SendNUIMessage({
        type = 'dashboard:update',
        activeClaims = dashboardData.activeClaims or {},
        previousClaims = dashboardData.previousClaims or {},
        riskScore = dashboardData.riskScore or 0,
        fraudScore = dashboardData.fraudScore or 0,
        repairOrders = dashboardData.repairOrders or {},
        progress = dashboardData.progress or {},
        timeline = dashboardData.timeline or {},
        evidence = dashboardData.evidence or {}
    })
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'dashboard:show' })
end)

RegisterNUICallback('closeDashboard', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNetEvent('ai_insurance_adjuster:portalData', function(portalData)
    TriggerEvent('chat:addMessage', { args = { 'Insurance', '=== CLAIM PORTAL ===' } })

    if portalData and portalData.memory then
        TriggerEvent('chat:addMessage', {
            args = { 'Insurance', ('Adjuster memory: %s'):format(portalData.memory.summary or 'No prior activity recorded.') }
        })
    end

    if portalData and portalData.history and #portalData.history > 0 then
        TriggerEvent('chat:addMessage', { args = { 'Insurance', 'Recent claim history:' } })
        for _, entry in ipairs(portalData.history) do
            TriggerEvent('chat:addMessage', {
                args = { 'Insurance', string.format('%s | %s | $%s', entry.claim_number or entry.id, entry.decision or 'unknown', entry.approved_amount or 0) }
            })
        end
    else
        TriggerEvent('chat:addMessage', { args = { 'Insurance', 'No prior claims recorded.' } })
    end

    if portalData and portalData.repair_orders and #portalData.repair_orders > 0 then
        TriggerEvent('chat:addMessage', { args = { 'Insurance', 'Active repair orders:' } })
        for _, order in ipairs(portalData.repair_orders) do
            TriggerEvent('chat:addMessage', {
                args = { 'Insurance', string.format('Order %s | %s | $%s', order.id, order.status or 'pending', order.approved_amount or 0) }
            })
        end
    end

    TriggerEvent('chat:addMessage', { args = { 'Insurance', '=== END PORTAL ===' } })
end)

RegisterCommand('answerclaim', function(source, args)
    -- HOOK: This should be replaced with proper UI
    -- args[1] = claim_id, args[2] = answers separated by |
    
    if #args < 2 then
        TriggerEvent('chat:addMessage', {
            args = { 'Insurance', 'Usage: /answerclaim <claim_id> <answer1|answer2|...>' }
        })
        return
    end
    
    local claimId = tonumber(args[1])
    local answersString = args[2]
    local answers = {}
    
    for answer in answersString:gmatch('([^|]+)') do
        table.insert(answers, answer)
    end
    
    TriggerServerEvent('ai_insurance_adjuster:submitFollowUpAnswers', claimId, answers)
end, false)
