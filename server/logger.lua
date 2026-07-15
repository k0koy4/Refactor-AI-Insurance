--[[
    logger.lua (server)
    Centralized logging helper for the insurance module.
]]

local LEVELS = {
    DEBUG = 1,
    INFO = 2,
    WARNING = 3,
    ERROR = 4
}

local function shouldLog(level)
    local loggingConfig = Config and Config.Logging or {}
    if loggingConfig.Enabled ~= false then
        local configuredLevel = string.upper(loggingConfig.Level or 'INFO')
        local currentLevel = LEVELS[configuredLevel] or LEVELS.INFO
        local targetLevel = LEVELS[level] or LEVELS.INFO
        return targetLevel >= currentLevel
    end
    return false
end

local function formatMessage(level, message, detail)
    local prefix = '[ai_insurance_adjuster]'
    local output = prefix .. ' [' .. tostring(level) .. '] ' .. tostring(message)
    if detail ~= nil and detail ~= '' then
        output = output .. ' ' .. tostring(detail)
    end
    return output
end

local function log(level, message, detail)
    if not shouldLog(level) then
        return
    end

    print(formatMessage(level, message, detail))
end

Logger = {
    Debug = function(message, detail) log('DEBUG', message, detail) end,
    Info = function(message, detail) log('INFO', message, detail) end,
    Warning = function(message, detail) log('WARNING', message, detail) end,
    Error = function(message, detail) log('ERROR', message, detail) end
}

exports('Logger', Logger)
