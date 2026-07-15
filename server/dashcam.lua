--[[
    dashcam.lua (server)
    Dashcam footage integration for insurance claims.
    Handles video evidence upload, validation, and analysis.
]]

local function validateFootageUrl(footageUrl)
    -- Basic URL validation for video files
    if not footageUrl or footageUrl == '' then
        return false, 'Invalid URL'
    end

    -- Check for common video extensions
    local validExtensions = {'.mp4', '.webm', '.mov', '.avi', '.mkv'}
    local lowerUrl = footageUrl:lower()
    local hasValidExtension = false
    
    for _, ext in ipairs(validExtensions) do
        if lowerUrl:find(ext, 1, true) then
            hasValidExtension = true
            break
        end
    end

    -- Also allow data URLs and common video hosting services
    if footageUrl:find('^data:video/') or 
       footageUrl:find('youtube%.com') or 
       footageUrl:find('youtu%.be') or 
       footageUrl:find('vimeo%.com') or
       footageUrl:find('discord%.com') then
        hasValidExtension = true
    end

    if not hasValidExtension then
        return false, 'Invalid video format. Use MP4, WebM, MOV, or AVI.'
    end

    return true, nil
end

function SaveDashcamFootage(claimId, citizenid, footageUrl, metadata)
    if not claimId or not citizenid then
        return false, 'Missing claim ID or citizen ID'
    end

    local valid, err = validateFootageUrl(footageUrl)
    if not valid then
        return false, err
    end

    -- Parse metadata
    local videoMetadata = metadata or {}
    videoMetadata.uploaded_at = os.time()
    videoMetadata.file_size = videoMetadata.file_size or 0
    videoMetadata.resolution = videoMetadata.resolution or 'unknown'
    videoMetadata.frame_rate = videoMetadata.frame_rate or 30
    videoMetadata.bitrate = videoMetadata.bitrate or 0

    MySQL.insert([[
        INSERT INTO insurance_dashcam_footage
        (claim_id, citizenid, footage_url, duration_seconds, start_time, end_time, file_size, resolution, metadata, uploaded_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
    ]], {
        claimId,
        citizenid,
        footageUrl,
        videoMetadata.duration_seconds or 0,
        videoMetadata.start_time or nil,
        videoMetadata.end_time or nil,
        videoMetadata.file_size,
        videoMetadata.resolution,
        json.encode(videoMetadata)
    })

    return true, 'Dashcam footage uploaded successfully'
end

function GetDashcamFootage(claimId, cb)
    MySQL.query('SELECT * FROM insurance_dashcam_footage WHERE claim_id = ? ORDER BY uploaded_at DESC', { claimId }, function(rows)
        -- Parse JSON metadata for each footage
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

function ListDashcamFootage(citizenid, limit, cb)
    local count = tonumber(limit) or 5
    MySQL.query('SELECT * FROM insurance_dashcam_footage WHERE citizenid = ? ORDER BY uploaded_at DESC LIMIT ?', { citizenid, count }, function(rows)
        -- Parse JSON metadata for each footage
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

function AnalyzeDashcamFootage(claimId, cb)
    -- Get all footage for the claim
    GetDashcamFootage(claimId, function(footageList)
        if #footageList == 0 then
            cb({ has_footage = false, analysis = 'No dashcam footage available for analysis' })
            return
        end

        -- Build analysis summary
        local analysis = {
            has_footage = true,
            total_footage = #footageList,
            total_duration = 0,
            resolutions = {},
            quality_score = 0,
            coverage_analysis = {},
            recommendations = {}
        }

        for _, footage in ipairs(footageList) do
            -- Sum total duration
            analysis.total_duration = analysis.total_duration + (footage.duration_seconds or 0)

            -- Collect resolutions
            if footage.resolution then
                analysis.resolutions[footage.resolution] = (analysis.resolutions[footage.resolution] or 0) + 1
            end

            -- Quality assessment
            if footage.metadata and footage.metadata.resolution then
                local width, height = footage.metadata.resolution:match('(%d+)x(%d+)')
                if width and height then
                    local pixels = tonumber(width) * tonumber(height)
                    if pixels > 1280000 then -- 720p
                        analysis.quality_score = analysis.quality_score + 1
                    end
                end
            end

            -- Coverage analysis based on timestamps
            if footage.start_time and footage.end_time then
                table.insert(analysis.coverage_analysis, {
                    start = footage.start_time,
                    end = footage.end_time,
                    duration = footage.duration_seconds
                })
            end
        end

        -- Generate recommendations
        if analysis.total_duration < 60 then
            table.insert(analysis.recommendations, 'Footage duration is short. Consider uploading longer clips for better context.')
        end
        if analysis.quality_score < #footageList then
            table.insert(analysis.recommendations, 'Some footage appears to be low quality. Higher resolution footage is preferred.')
        end

        cb(analysis)
    end)
end

function DeleteDashcamFootage(footageId, citizenid, cb)
    MySQL.query('DELETE FROM insurance_dashcam_footage WHERE id = ? AND citizenid = ?', { footageId, citizenid }, function(result)
        cb(result.affectedRows > 0)
    end)
end

-- Event handlers
RegisterNetEvent('ai_insurance_adjuster:submitDashcamFootage', function(claimId, footageUrl, metadata)
    local src = source
    local citizenid = GetPlayerIdentifier(src, 0) or tostring(src)
    local ok, msg = SaveDashcamFootage(claimId, citizenid, footageUrl, metadata)
    if ok then
        TriggerClientEvent('ai_insurance_adjuster:notify', src, msg or 'Dashcam footage uploaded successfully.')
    else
        TriggerClientEvent('ai_insurance_adjuster:notify', src, msg or 'Could not upload dashcam footage.')
    end
end)

RegisterNetEvent('ai_insurance_adjuster:requestDashcamAnalysis', function(claimId)
    local src = source
    AnalyzeDashcamFootage(claimId, function(analysis)
        TriggerClientEvent('ai_insurance_adjuster:dashcamAnalysis', src, analysis)
    end)
end)

RegisterNetEvent('ai_insurance_adjuster:deleteDashcamFootage', function(footageId)
    local src = source
    local citizenid = GetPlayerIdentifier(src, 0) or tostring(src)
    DeleteDashcamFootage(footageId, citizenid, function(success)
        if success then
            TriggerClientEvent('ai_insurance_adjuster:notify', src, 'Dashcam footage deleted.')
        else
            TriggerClientEvent('ai_insurance_adjuster:notify', src, 'Could not delete dashcam footage.')
        end
    end)
end)

-- Exports
exports('SaveDashcamFootage', SaveDashcamFootage)
exports('GetDashcamFootage', GetDashcamFootage)
exports('ListDashcamFootage', ListDashcamFootage)
exports('AnalyzeDashcamFootage', AnalyzeDashcamFootage)
exports('DeleteDashcamFootage', DeleteDashcamFootage)
