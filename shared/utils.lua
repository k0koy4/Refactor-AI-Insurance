--[[
    utils.lua (shared)
    Shared utility functions for the AI Insurance Adjuster system.
]]

-- Generate a unique claim number
function GenerateClaimNumber()
    local timestamp = os.time()
    local random = math.random(1000, 9999)
    return string.format('BCMI-%d-%d', timestamp, random)
end

-- Generate a VIN if one doesn't exist
function GenerateVIN()
    local chars = 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789'
    local vin = ''
    for i = 1, 17 do
        local pos = math.random(1, #chars)
        vin = vin .. string.sub(chars, pos, pos)
    end
    return vin
end

-- Calculate risk score based on multiple factors
function CalculateRiskScore(profile)
    if not profile then return 50 end
    
    local risk = 50 -- Base risk score
    
    -- Adjust based on claim history
    local claimRatio = profile.total_claims > 0 and (profile.denied_claims / profile.total_claims) or 0
    risk = risk + (claimRatio * 30)
    
    -- Adjust based on average speed (assuming 60mph is baseline)
    if profile.average_speed then
        local speedFactor = math.max(0, (profile.average_speed - 60) / 2)
        risk = risk + speedFactor
    end
    
    -- Adjust based on police encounters
    risk = risk + (profile.police_encounters * 5)
    
    -- Adjust based on DUI count
    risk = risk + (profile.dui_count * 20)
    
    -- Adjust based on fraud suspicion
    risk = risk + profile.fraud_suspicion
    
    -- Adjust based on aggressive driving
    risk = risk + (profile.aggressive_driving_score / 2)
    
    -- Reduce risk based on safe driving streak
    risk = risk - math.min(20, profile.safe_driving_streak / 10)
    
    -- Clamp between 0 and 100
    return math.max(0, math.min(100, math.floor(risk)))
end

-- Validate vehicle health values
function ValidateVehicleHealth(health)
    return health and health >= 0 and health <= 1000
end

-- Validate speed values
function ValidateSpeed(speed)
    return speed and speed >= 0 and speed <= 300
end

-- Format currency
function FormatCurrency(amount)
    return string.format('$%s', tostring(amount):reverse():gsub("%d%d%d", "%s,"):reverse():gsub("^,", ""))
end

-- Get weather from game (client-side)
function GetGameWeather()
    -- This would be implemented client-side
    -- Returns current weather condition
    return 'clear' -- Placeholder
end

-- Get street name from coordinates (client-side)
function GetStreetNameFromCoords(coords)
    -- This would be implemented client-side using GetStreetNameAtCoord
    return 'Unknown Street' -- Placeholder
end

-- Calculate distance between two points
function CalculateDistance(x1, y1, z1, x2, y2, z2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2 + (z2 - z1)^2)
end

-- Deep copy a table
function DeepCopy(original)
    local copy
    if type(original) == 'table' then
        copy = {}
        for key, value in next, original, nil do
            copy[DeepCopy(key)] = DeepCopy(value)
        end
        setmetatable(copy, DeepCopy(getmetatable(original)))
    else
        copy = original
    end
    return copy
end

-- Safe JSON encode with error handling
function SafeJSONEncode(data)
    local ok, result = pcall(json.encode, data)
    if ok then
        return result
    else
        print('[ai_insurance_adjuster] JSON encode error:', result)
        return json.encode({})
    end
end

-- Safe JSON decode with error handling
function SafeJSONDecode(str)
    local ok, result = pcall(json.decode, str)
    if ok then
        return result
    else
        print('[ai_insurance_adjuster] JSON decode error:', result)
        return nil
    end
end
