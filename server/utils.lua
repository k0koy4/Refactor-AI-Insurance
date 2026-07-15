--[[
    utils.lua (server)
    Server-side utility functions for the AI Insurance Adjuster system.
]]

local function getFrameworkPlayer(src)
    if not src or src == 0 then
        return nil
    end

    if Config.Framework and Config.Framework.Type == 'esx' and ESX and ESX.GetPlayerFromId then
        return ESX.GetPlayerFromId(src)
    end

    if Config.Framework and Config.Framework.Type == 'qbcore' and QBCore and QBCore.Functions and QBCore.Functions.GetPlayer then
        return QBCore.Functions.GetPlayer(src)
    end

    if Config.Framework and Config.Framework.Type == 'qbox' and QBox and QBox.Functions and QBox.Functions.GetPlayer then
        return QBox.Functions.GetPlayer(src)
    end

    return nil
end

local function getFrameworkIdentifier(src)
    local player = getFrameworkPlayer(src)

    if player then
        if Config.Framework and Config.Framework.Type == 'esx' then
            if player.getIdentifier then
                local identifier = player.getIdentifier()
                if identifier and identifier ~= '' then
                    return identifier
                end
            end
            if player.identifier and player.identifier ~= '' then
                return player.identifier
            end
        elseif Config.Framework and Config.Framework.Type == 'qbcore' then
            if player.PlayerData and player.PlayerData.citizenid and player.PlayerData.citizenid ~= '' then
                return player.PlayerData.citizenid
            end
            if player.PlayerData and player.PlayerData.license and player.PlayerData.license ~= '' then
                return player.PlayerData.license
            end
        elseif Config.Framework and Config.Framework.Type == 'qbox' then
            if player.PlayerData and player.PlayerData.citizenid and player.PlayerData.citizenid ~= '' then
                return player.PlayerData.citizenid
            end
            if player.PlayerData and player.PlayerData.license and player.PlayerData.license ~= '' then
                return player.PlayerData.license
            end
        end
    end

    local identifier = GetPlayerIdentifier(src, 0)
    if identifier and identifier ~= '' then
        return identifier
    end

    return tostring(src)
end

function getCitizenId(src)
    return getFrameworkIdentifier(src)
end

function payoutPlayer(src, amount)
    if not src or not amount or amount <= 0 then
        return false
    end

    local player = getFrameworkPlayer(src)
    if not player then
        print(('[ai_insurance_adjuster] Would pay player %s: $%d'):format(src, amount))
        return true
    end

    if Config.Framework and Config.Framework.Type == 'esx' then
        if player.addMoney then
            player.addMoney('bank', amount)
            return true
        end
        if player.addAccountMoney then
            player.addAccountMoney('bank', amount)
            return true
        end
    elseif Config.Framework and Config.Framework.Type == 'qbcore' then
        if player.Functions and player.Functions.AddMoney then
            player.Functions.AddMoney('bank', amount, 'insurance-claim')
            return true
        end
    elseif Config.Framework and Config.Framework.Type == 'qbox' then
        if player.Functions and player.Functions.AddMoney then
            player.Functions.AddMoney('bank', amount, 'insurance-claim')
            return true
        end
    end

    print(('[ai_insurance_adjuster] Would pay player %s: $%d'):format(src, amount))
    return true
end

function getCharacterName(src)
    local player = getFrameworkPlayer(src)

    if player then
        if Config.Framework and Config.Framework.Type == 'esx' and player.getName then
            local name = player.getName()
            if name and name ~= '' then
                return name
            end
        end

        if player.PlayerData then
            local charinfo = player.PlayerData.charinfo
            if charinfo and charinfo.firstname and charinfo.lastname then
                return (charinfo.firstname .. ' ' .. charinfo.lastname)
            end
            if player.PlayerData.name and player.PlayerData.name ~= '' then
                return player.PlayerData.name
            end
        end

        if player.name and player.name ~= '' then
            return player.name
        end
    end

    local name = GetPlayerName(src)
    if name and name ~= '' then
        return name
    end

    return ('player-' .. tostring(src))
end

-- Get or create vehicle record
function GetOrCreateVehicle(citizenid, plate, model)
    MySQL.single('SELECT id FROM insurance_vehicles WHERE plate = ?', { plate }, function(row)
        if not row then
            local vin = GenerateVIN()
            MySQL.insert([[
                INSERT INTO insurance_vehicles 
                (citizenid, plate, vehicle_model, vehicle_class, vin, policy_tier)
                VALUES (?, ?, ?, ?, ?, 'standard')
            ]], { citizenid, plate, model, 'unknown', vin })
        end
    end)
end

-- Get vehicle information
function GetVehicleInfo(plate, cb)
    MySQL.single('SELECT * FROM insurance_vehicles WHERE plate = ?', { plate }, cb)
end

-- Get driver profile
function GetDriverProfile(citizenid, cb, src)
    MySQL.single('SELECT * FROM insurance_driver_profiles WHERE citizenid = ?', { citizenid }, function(row)
        if not row then
            local characterName = src and getCharacterName(src) or tostring(citizenid or 'unknown')
            -- Create default profile
            MySQL.insert([[
                INSERT INTO insurance_driver_profiles 
                (citizenid, character_name, risk_score)
                VALUES (?, ?, 50)
            ]], { citizenid, characterName }, function(insertId)
                MySQL.single('SELECT * FROM insurance_driver_profiles WHERE id = ?', { insertId }, cb)
            end)
        else
            cb(row)
        end
    end)
end

-- Update driver profile
function UpdateDriverProfile(citizenid, updates)
    local setClause = {}
    local values = {}

    for key, value in pairs(updates) do
        table.insert(setClause, key .. ' = ?')
        table.insert(values, value)
    end

    table.insert(values, citizenid)

    MySQL.query([[
        UPDATE insurance_driver_profiles 
        SET ]] .. table.concat(setClause, ', ') .. [[, last_updated = NOW()
        WHERE citizenid = ?
    ]], values)
end

-- Get policy tier information
function GetPolicyTier(tierName, cb)
    MySQL.single('SELECT * FROM insurance_policy_tiers WHERE tier_name = ?', { tierName }, cb)
end

-- Get fraud score (maintained for backward compatibility)
function GetFraudScore(citizenid, cb)
    MySQL.single('SELECT score, last_updated FROM insurance_fraud_scores WHERE citizenid = ?', { citizenid }, function(row)
        if not row then
            cb(0)
            return
        end
        local daysSince = os.difftime(os.time(), row.last_updated) / 86400
        local decayed = math.max(0, row.score - (daysSince * Config.FraudScoreDecayPerDay))
        cb(math.floor(decayed))
    end)
end

-- Adjust fraud score
function AdjustFraudScore(citizenid, delta)
    MySQL.query([[
        INSERT INTO insurance_fraud_scores (citizenid, score, last_updated)
        VALUES (?, GREATEST(0, LEAST(100, ?)), NOW())
        ON DUPLICATE KEY UPDATE
            score = GREATEST(0, LEAST(100, score + ?)),
            last_updated = NOW()
    ]], { citizenid, delta, delta })
end

-- Export functions for other modules
exports('GetCitizenId', getCitizenId)
exports('PayoutPlayer', payoutPlayer)
exports('GetCharacterName', getCharacterName)
