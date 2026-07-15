--[[
    photo_evidence.lua (server)
    Enhanced photo evidence system with validation, metadata, and AI analysis integration.
    Stores uploaded crash photos with comprehensive metadata for claim review.
]]

local function sanitizePhotoInput(photoUrl, caption)
    local normalizedUrl = tostring(photoUrl or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local normalizedCaption = tostring(caption or 'Uploaded photo'):gsub('^%s+', ''):gsub('%s+$', '')

    if normalizedUrl == '' then
        return nil, nil
    end

    return normalizedUrl, normalizedCaption
end

local function validatePhotoUrl(photoUrl)
    -- Basic URL validation
    if not photoUrl or photoUrl == '' then
        return false, 'Invalid URL'
    end

    -- Check for common image extensions
    local validExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'}
    local lowerUrl = photoUrl:lower()
    local hasValidExtension = false
    
    for _, ext in ipairs(validExtensions) do
        if lowerUrl:find(ext, 1, true) then
            hasValidExtension = true
            break
        end
    end

    -- Also allow data URLs and common image hosting services
    if photoUrl:find('^data:image/') or 
       photoUrl:find('imgur%.com') or 
       photoUrl:find('discord%.com') or 
       photoUrl:find('discordapp%.com') or
       photoUrl:find('prnt%.sc') then
        hasValidExtension = true
    end

    if not hasValidExtension then
        return false, 'Invalid image format. Use JPG, PNG, GIF, or WebP.'
    end

    return true, nil
end

function SavePhotoEvidence(claimId, citizenid, photoUrl, caption, metadata)
    if not claimId or not citizenid then
        return false, 'Missing claim ID or citizen ID'
    end

    local normalizedUrl, normalizedCaption = sanitizePhotoInput(photoUrl, caption)
    if not normalizedUrl then
        return false, 'Invalid photo URL'
    end

    local valid, err = validatePhotoUrl(normalizedUrl)
    if not valid then
        return false, err
    end

    -- Parse metadata if provided
    local photoMetadata = metadata or {}
    photoMetadata.uploaded_at = os.time()
    photoMetadata.file_size = photoMetadata.file_size or 0
    photoMetadata.resolution = photoMetadata.resolution or 'unknown'
    photoMetadata.location = photoMetadata.location or {}

    MySQL.insert([[
        INSERT INTO insurance_evidence_photos
        (claim_id, citizenid, photo_url, caption, photo_type, damage_area, metadata, uploaded_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
    ]], {
        claimId,
        citizenid,
        normalizedUrl,
        normalizedCaption,
        photoMetadata.photo_type or 'general',
        photoMetadata.damage_area or 'unspecified',
        json.encode(photoMetadata)
    })

    return true, 'Photo evidence uploaded successfully'
end

function GetPhotoEvidence(claimId, cb)
    MySQL.query('SELECT * FROM insurance_evidence_photos WHERE claim_id = ? ORDER BY uploaded_at DESC', { claimId }, function(rows)
        -- Parse JSON metadata for each photo
        for _, row in ipairs(rows or {}) do
            if row.metadata then
                local success, decoded = pcall(json.decode, row.metadata)
                if success then
                    row.metadata = decoded
                end
            end
        end
        cb(rows or {})
    end)
end

function ListPhotoEvidence(citizenid, limit, cb)
    local count = tonumber(limit) or 5
    MySQL.query('SELECT * FROM insurance_evidence_photos WHERE citizenid = ? ORDER BY uploaded_at DESC LIMIT ?', { citizenid, count }, function(rows)
        -- Parse JSON metadata for each photo
        for _, row in ipairs(rows or {}) do
            if row.metadata then
                local success, decoded = pcall(json.decode, row.metadata)
                if success then
                    row.metadata = decoded
                end
            end
        end
        cb(rows or {})
    end)
end

function AnalyzePhotoEvidence(claimId, cb)
    -- Get all photos for the claim
    GetPhotoEvidence(claimId, function(photos)
        if #photos == 0 then
            cb({ has_photos = false, analysis = 'No photos available for analysis' })
            return
        end

        -- Build analysis summary
        local analysis = {
            has_photos = true,
            total_photos = #photos,
            photo_types = {},
            damage_areas = {},
            quality_score = 0,
            recommendations = {}
        }

        for _, photo in ipairs(photos) do
            -- Collect photo types
            if photo.photo_type then
                analysis.photo_types[photo.photo_type] = (analysis.photo_types[photo.photo_type] or 0) + 1
            end

            -- Collect damage areas
            if photo.damage_area then
                analysis.damage_areas[photo.damage_area] = (analysis.damage_areas[photo.damage_area] or 0) + 1
            end

            -- Simple quality assessment based on metadata
            if photo.metadata and photo.metadata.resolution then
                local width, height = photo.metadata.resolution:match('(%d+)x(%d+)')
                if width and height then
                    local pixels = tonumber(width) * tonumber(height)
                    if pixels > 2000000 then -- 2MP
                        analysis.quality_score = analysis.quality_score + 1
                    end
                end
            end
        end

        -- Generate recommendations
        if not analysis.photo_types.front then
            table.insert(analysis.recommendations, 'Consider adding front-view photos')
        end
        if not analysis.photo_types.rear then
            table.insert(analysis.recommendations, 'Consider adding rear-view photos')
        end
        if not analysis.photo_types.interior then
            table.insert(analysis.recommendations, 'Consider adding interior photos')
        end

        cb(analysis)
    end)
end

function DeletePhotoEvidence(photoId, citizenid, cb)
    MySQL.query('DELETE FROM insurance_evidence_photos WHERE id = ? AND citizenid = ?', { photoId, citizenid }, function(result)
        cb(result.affectedRows > 0)
    end)
end

RegisterNetEvent('ai_insurance_adjuster:submitPhotoEvidence', function(claimId, photoUrl, caption, metadata)
    local src = source
    local citizenid = GetPlayerIdentifier(src, 0) or tostring(src)
    local ok, msg = SavePhotoEvidence(claimId, citizenid, photoUrl, caption, metadata)
    if ok then
        TriggerClientEvent('ai_insurance_adjuster:notify', src, msg or 'Photo evidence uploaded and attached to the claim.')
    else
        TriggerClientEvent('ai_insurance_adjuster:notify', src, msg or 'Photo evidence could not be attached.')
    end
end)

RegisterNetEvent('ai_insurance_adjuster:requestPhotoAnalysis', function(claimId)
    local src = source
    AnalyzePhotoEvidence(claimId, function(analysis)
        TriggerClientEvent('ai_insurance_adjuster:photoAnalysis', src, analysis)
    end)
end)

RegisterNetEvent('ai_insurance_adjuster:deletePhotoEvidence', function(photoId)
    local src = source
    local citizenid = GetPlayerIdentifier(src, 0) or tostring(src)
    DeletePhotoEvidence(photoId, citizenid, function(success)
        if success then
            TriggerClientEvent('ai_insurance_adjuster:notify', src, 'Photo evidence deleted.')
        else
            TriggerClientEvent('ai_insurance_adjuster:notify', src, 'Could not delete photo evidence.')
        end
    end)
end)

exports('SavePhotoEvidence', SavePhotoEvidence)
exports('GetPhotoEvidence', GetPhotoEvidence)
exports('ListPhotoEvidence', ListPhotoEvidence)
exports('AnalyzePhotoEvidence', AnalyzePhotoEvidence)
exports('DeletePhotoEvidence', DeletePhotoEvidence)
