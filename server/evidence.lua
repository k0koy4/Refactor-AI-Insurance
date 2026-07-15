--[[
    evidence.lua (server)
    Server-side evidence collection with validation.
    Never trust client values - validate everything server-side.
]]

-- Validate client-reported crash data
function ValidateCrashData(crashData, src)
    if not crashData then
        return false, 'No crash data provided'
    end

    -- Validate damage percentage
    if not crashData.damagePercent or crashData.damagePercent < 0 or crashData.damagePercent > 100 then
        return false, 'Invalid damage percentage'
    end

    -- Validate speed
    if not ValidateSpeed(crashData.impactSpeed) then
        return false, 'Invalid impact speed'
    end

    -- Validate coordinates
    if not crashData.location or not crashData.location.x or not crashData.location.y or not crashData.location.z then
        return false, 'Invalid coordinates'
    end

    -- Validate vehicle model
    if not crashData.vehicleModel or crashData.vehicleModel == '' then
        return false, 'Invalid vehicle model'
    end

    -- Server-side verification: check if player actually owns this vehicle
    -- This is a framework-specific check that needs to be hooked up
    -- local citizenid = getCitizenId(src)
    -- if not VerifyVehicleOwnership(citizenid, crashData.plate) then
    --     return false, 'Vehicle ownership verification failed'
    -- end

    return true, nil
end

-- Collect comprehensive evidence from client report and server validation
function CollectEvidence(crashData, src, cb)
    local citizenid = getCitizenId(src)
    local characterName = getCharacterName(src)

    -- Validate client data first
    local valid, err = ValidateCrashData(crashData, src)
    if not valid then
        cb(false, nil, err)
        return
    end

    -- Get vehicle information
    GetVehicleInfo(crashData.plate or 'UNKNOWN', function(vehicleInfo)
        -- Get driver profile
        GetDriverProfile(citizenid, function(driverProfile)
            -- Get fraud score (backward compatibility)
            GetFraudScore(citizenid, function(fraudScore)
                -- Get recent claims
                MySQL.query('SELECT decision, created_at FROM insurance_claims WHERE citizenid = ? ORDER BY created_at DESC LIMIT 5',
                    { citizenid }, function(recentClaims)

                    -- Build comprehensive evidence package
                    local evidence = {
                        -- Claim metadata
                        claim_number = GenerateClaimNumber(),
                        citizenid = citizenid,
                        character_name = characterName,
                        submitted_at = os.time(),

                        -- Vehicle information
                        vehicle = {
                            model = crashData.vehicleModel,
                            plate = crashData.plate or 'UNKNOWN',
                            vehicle_class = vehicleInfo and vehicleInfo.vehicle_class or 'unknown',
                            vin = vehicleInfo and vehicleInfo.vin or GenerateVIN(),
                            mileage = vehicleInfo and vehicleInfo.mileage or 0,
                            vehicle_value = vehicleInfo and vehicleInfo.vehicle_value or 0,
                            policy_tier = vehicleInfo and vehicleInfo.policy_tier or 'standard'
                        },

                        -- Driver information
                        driver = {
                            name = characterName,
                            citizenid = citizenid,
                            fraud_score = fraudScore,
                            risk_score = driverProfile and CalculateRiskScore(driverProfile) or 50,
                            total_claims = driverProfile and driverProfile.total_claims or 0,
                            approved_claims = driverProfile and driverProfile.approved_claims or 0,
                            denied_claims = driverProfile and driverProfile.denied_claims or 0,
                            average_speed = driverProfile and driverProfile.average_speed or 0,
                            police_encounters = driverProfile and driverProfile.police_encounters or 0,
                            dui_count = driverProfile and driverProfile.dui_count or 0,
                            fraud_suspicion = driverProfile and driverProfile.fraud_suspicion or 0,
                            aggressive_driving_score = driverProfile and driverProfile.aggressive_driving_score or 0,
                            safe_driving_streak = driverProfile and driverProfile.safe_driving_streak or 0
                        },

                        -- Accident information
                        accident = {
                            date = os.date('%Y-%m-%d'),
                            time = os.date('%H:%M:%S'),
                            gps_location = {
                                x = crashData.location.x,
                                y = crashData.location.y,
                                z = crashData.location.z
                            },
                            street_name = crashData.streetName or 'Unknown',
                            weather = crashData.weather or 'clear',
                            road_type = crashData.roadType or 'unknown',
                            speed_before_impact = crashData.speedBeforeImpact or crashData.impactSpeed,
                            speed_at_impact = crashData.impactSpeed,
                            number_of_impacts = crashData.numberOfImpacts or 1,
                            impact_direction = crashData.impactDirection or 'unknown',
                            impact_type = crashData.impactType or 'unknown',
                            impact_category = crashData.impactCategory or 'unknown',
                            impact_involves_player = crashData.impactInvolvesPlayer or false,
                            impact_involves_entity = crashData.impactInvolvesEntity or false,
                            impact_involves_world_geometry = crashData.impactInvolvesWorldGeometry or false,
                            impact_livable = crashData.impactLivable ~= false,
                            impact_severity = crashData.impactSeverity or 'unknown',
                            rollovers = crashData.rollovers or false,
                            airbag_deployed = crashData.airbagDeployed or false,
                            vehicle_flipped = crashData.vehicleFlipped or false,
                            engine_stalled = crashData.engineStalled or false,
                            fire = crashData.fire or false,
                            explosion = crashData.explosion or false,
                            occupants = crashData.occupants or 1,
                            seatbelt_status = crashData.seatbeltStatus,
                            driver_ejected = crashData.driverEjected or false,
                            vehicle_drivable = crashData.vehicleDrivable or false
                        },

                        -- Vehicle health at time of accident
                        vehicle_health = {
                            engine_health = crashData.engineHealth or 0,
                            body_health = crashData.bodyHealth or 0,
                            fuel_tank_health = crashData.fuelTankHealth or 0,
                            tire_condition = crashData.tireCondition or {},
                            door_damage = crashData.doorDamage or {},
                            window_damage = crashData.windowDamage or {}
                        },

                        -- Damage calculation
                        damage_percent = crashData.damagePercent,

                        -- Player statement
                        player_statement = crashData.playerStatement or '(no statement provided)',

                        -- Claim history
                        recent_claims = recentClaims or {},
                        recent_claims_count = #recentClaims,

                        -- Policy information
                        policy = {
                            tier = vehicleInfo and vehicleInfo.policy_tier or 'standard'
                        }
                    }

                    -- Get policy tier details
                    GetPolicyTier(evidence.policy.tier, function(policyTier)
                        if policyTier then
                            evidence.policy.details = policyTier
                        end

                        cb(true, evidence, nil)
                    end)
                end)
            end)
        end)
    end)
end

-- Server-side verification of vehicle state (to be called after evidence collection)
function VerifyVehicleState(vehNetId, evidence)
    -- This would verify the actual vehicle state on the server
    -- For now, we trust the validated client data but this could be expanded
    -- to actually check the vehicle entity on the server
    
    -- Future implementation:
    -- local veh = GetNetVehicle(vehNetId)
    -- if not veh then return false end
    -- evidence.vehicle_health.server_verified = {
    --     engine_health = GetVehicleEngineHealth(veh),
    --     body_health = GetVehicleBodyHealth(veh),
    --     fuel_tank_health = GetVehiclePetrolTankHealth(veh)
    -- }
    
    return true
end

-- Update driver statistics after a claim
function UpdateDriverStatistics(citizenid, crashData, decision)
    local updates = {
        total_claims = 'total_claims + 1'
    }

    if decision == 'approve' then
        updates.approved_claims = 'approved_claims + 1'
    elseif decision == 'deny' then
        updates.denied_claims = 'denied_claims + 1'
    end

    -- Update average speed
    if crashData.impactSpeed then
        MySQL.query([[
            UPDATE insurance_driver_profiles 
            SET average_speed = (average_speed * total_claims + ?) / (total_claims + 1)
            WHERE citizenid = ?
        ]], { crashData.impactSpeed, citizenid })
    end

    -- Apply other updates
    local setClause = {}
    local values = {}
    for key, value in pairs(updates) do
        if type(value) == 'string' and value:find('+') then
            table.insert(setClause, key .. ' = ' .. value)
        else
            table.insert(setClause, key .. ' = ?')
            table.insert(values, value)
        end
    end
    table.insert(values, citizenid)

    MySQL.query([[
        UPDATE insurance_driver_profiles 
        SET ]] .. table.concat(setClause, ', ') .. [[, last_updated = NOW()
        WHERE citizenid = ?
    ]], values)
end
