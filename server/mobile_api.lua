--[[
    mobile_api.lua (server)
    Mobile app API endpoints for claim status and management.
    Provides REST-like API functionality for external mobile applications.
]]

local activeTokens = {}

-- Generate a secure API token
function GenerateMobileToken(citizenid, deviceId, deviceType, expiresInDays)
    if not citizenid then
        return false, 'Missing citizen ID'
    end

    -- Generate a random token
    local token = string.format('%s_%s_%d', citizenid, deviceId, os.time())
    
    -- Calculate expiration
    local expiresAt = os.time() + (expiresInDays or 30) * 86400

    -- Save to database
    MySQL.insert([[
        INSERT INTO insurance_mobile_tokens
        (citizenid, device_id, device_type, token, expires_at)
        VALUES (?, ?, ?, ?, FROM_UNIXTIME(?))
    ]], {
        citizenid,
        deviceId or 'unknown',
        deviceType or 'mobile',
        token,
        expiresAt
    })

    -- Cache in memory
    activeTokens[token] = {
        citizenid = citizenid,
        device_id = deviceId,
        device_type = deviceType,
        expires_at = expiresAt
    }

    return true, token
end

-- Validate an API token
function ValidateMobileToken(token)
    if not token then
        return false, 'No token provided'
    end

    -- Check memory cache first
    if activeTokens[token] then
        local cached = activeTokens[token]
        if cached.expires_at > os.time() then
            -- Update last used
            MySQL.query('UPDATE insurance_mobile_tokens SET last_used = NOW() WHERE token = ?', { token })
            return true, cached.citizenid
        else
            -- Token expired
            activeTokens[token] = nil
            return false, 'Token expired'
        end
    end

    -- Check database
    MySQL.query('SELECT * FROM insurance_mobile_tokens WHERE token = ?', { token }, function(rows)
        if rows and #rows > 0 then
            local row = rows[1]
            local expiresAt = os.time(row.expires_at)
            
            if expiresAt > os.time() then
                -- Cache it
                activeTokens[token] = {
                    citizenid = row.citizenid,
                    device_id = row.device_id,
                    device_type = row.device_type,
                    expires_at = expiresAt
                }
                
                -- Update last used
                MySQL.query('UPDATE insurance_mobile_tokens SET last_used = NOW() WHERE token = ?', { token })
                return true, row.citizenid
            else
                return false, 'Token expired'
            end
        end
        return false, 'Invalid token'
    end)

    return false, 'Invalid token'
end

-- Revoke a token
function RevokeMobileToken(token)
    if not token then
        return false, 'No token provided'
    end

    -- Remove from cache
    activeTokens[token] = nil

    -- Remove from database
    MySQL.query('DELETE FROM insurance_mobile_tokens WHERE token = ?', { token })
    return true, 'Token revoked'
end

-- Get claim status for mobile app
function GetMobileClaimStatus(citizenid, claimId, cb)
    if not citizenid then
        cb({ error = 'Missing citizen ID' })
        return
    end

    local query = 'SELECT * FROM insurance_claims_enhanced WHERE citizenid = ?'
    local params = { citizenid }

    if claimId then
        query = query .. ' AND id = ?'
        table.insert(params, claimId)
    end

    query = query .. ' ORDER BY created_at DESC LIMIT 10'

    MySQL.query(query, params, function(rows)
        local claims = {}
        
        for _, row in ipairs(rows or {}) do
            local claim = {
                id = row.id,
                claim_number = row.claim_number,
                status = row.investigation_stage,
                decision = row.decision,
                created_at = row.created_at,
                updated_at = row.updated_at,
                
                -- Accident summary
                accident_date = row.accident_date,
                street_name = row.street_name,
                
                -- Vehicle info
                vehicle_model = nil, -- Would need to join with vehicles table
                
                -- Decision info
                confidence = row.confidence,
                fraud_risk = row.fraud_risk,
                approved_amount = row.approved_amount,
                deductible = row.deductible
            }
            
            table.insert(claims, claim)
        end

        cb(claims)
    end)
end

-- Get claim timeline for mobile app
function GetMobileClaimTimeline(claimId, cb)
    if not claimId then
        cb({ error = 'Missing claim ID' })
        return
    end

    -- Get claim details
    MySQL.query('SELECT * FROM insurance_claims_enhanced WHERE id = ?', { claimId }, function(claimRows)
        if not claimRows or #claimRows == 0 then
            cb({ error = 'Claim not found' })
            return
        end

        local claim = claimRows[1]
        local timeline = {}

        -- Add claim creation
        table.insert(timeline, {
            event = 'Claim Submitted',
            timestamp = claim.created_at,
            description = 'Initial claim submitted by policyholder'
        })

        -- Add investigation stages
        if claim.investigation_stage ~= 'evidence_collection' then
            table.insert(timeline, {
                event = 'Evidence Collection',
                timestamp = claim.created_at,
                description = 'Evidence collection completed'
            })
        end

        -- Add decision if available
        if claim.decision then
            table.insert(timeline, {
                event = 'Decision Reached',
                timestamp = claim.updated_at,
                description = string.format('Claim %s', claim.decision)
            })
        end

        -- Get photo evidence
        MySQL.query('SELECT * FROM insurance_evidence_photos WHERE claim_id = ? ORDER BY uploaded_at', { claimId }, function(photoRows)
            for _, photo in ipairs(photoRows or {}) do
                table.insert(timeline, {
                    event = 'Photo Evidence Added',
                    timestamp = photo.uploaded_at,
                    description = photo.caption or 'Photo uploaded'
                })
            end

            -- Get dashcam footage
            MySQL.query('SELECT * FROM insurance_dashcam_footage WHERE claim_id = ? ORDER BY uploaded_at', { claimId }, function(footageRows)
                for _, footage in ipairs(footageRows or {}) do
                    table.insert(timeline, {
                        event = 'Dashcam Footage Added',
                        timestamp = footage.uploaded_at,
                        description = string.format('Video footage (%d seconds)', footage.duration_seconds or 0)
                    })
                end

                -- Sort timeline by timestamp
                table.sort(timeline, function(a, b)
                    return a.timestamp < b.timestamp
                end)

                cb({
                    claim_id = claimId,
                    claim_number = claim.claim_number,
                    timeline = timeline
                })
            end)
        end)
    end)
end

-- Get user profile for mobile app
function GetMobileUserProfile(citizenid, cb)
    if not citizenid then
        cb({ error = 'Missing citizen ID' })
        return
    end

    -- Get driver profile
    MySQL.query('SELECT * FROM insurance_driver_profiles WHERE citizenid = ?', { citizenid }, function(profileRows)
        local profile = profileRows and profileRows[1] or {}
        
        -- Get recent claims count
        MySQL.query('SELECT COUNT(*) as total FROM insurance_claims_enhanced WHERE citizenid = ?', { citizenid }, function(countRows)
            local stats = {
                citizenid = citizenid,
                character_name = profile.character_name,
                risk_score = profile.risk_score or 50,
                total_claims = countRows and countRows[1] and countRows[1].total or 0,
                approved_claims = profile.approved_claims or 0,
                denied_claims = profile.denied_claims or 0,
                safe_driving_streak = profile.safe_driving_streak or 0
            }

            cb(stats)
        end)
    end)
end

-- Event handlers for mobile API
RegisterNetEvent('ai_insurance_adjuster:mobileGenerateToken', function(deviceId, deviceType)
    local src = source
    local citizenid = GetPlayerIdentifier(src, 0) or tostring(src)
    local ok, result = GenerateMobileToken(citizenid, deviceId, deviceType, 30)
    if ok then
        TriggerClientEvent('ai_insurance_adjuster:mobileTokenGenerated', src, result)
    else
        TriggerClientEvent('ai_insurance_adjuster:notify', src, result or 'Could not generate token.')
    end
end)

RegisterNetEvent('ai_insurance_adjuster:mobileGetClaims', function(claimId)
    local src = source
    local citizenid = GetPlayerIdentifier(src, 0) or tostring(src)
    GetMobileClaimStatus(citizenid, claimId, function(claims)
        TriggerClientEvent('ai_insurance_adjuster:mobileClaimsData', src, claims)
    end)
end)

RegisterNetEvent('ai_insurance_adjuster:mobileGetTimeline', function(claimId)
    local src = source
    GetMobileClaimTimeline(claimId, function(timeline)
        TriggerClientEvent('ai_insurance_adjuster:mobileTimelineData', src, timeline)
    end)
end)

RegisterNetEvent('ai_insurance_adjuster:mobileGetProfile', function()
    local src = source
    local citizenid = GetPlayerIdentifier(src, 0) or tostring(src)
    GetMobileUserProfile(citizenid, function(profile)
        TriggerClientEvent('ai_insurance_adjuster:mobileProfileData', src, profile)
    end)
end)

-- Exports
exports('GenerateMobileToken', GenerateMobileToken)
exports('ValidateMobileToken', ValidateMobileToken)
exports('RevokeMobileToken', RevokeMobileToken)
exports('GetMobileClaimStatus', GetMobileClaimStatus)
exports('GetMobileClaimTimeline', GetMobileClaimTimeline)
exports('GetMobileUserProfile', GetMobileUserProfile)
