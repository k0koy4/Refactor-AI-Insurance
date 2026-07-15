--[[
    commercial_features.lua (server)
    Builds a structured portal payload for the player-facing insurance dashboard.
]]

function BuildPortalData(citizenid, cb)
    GetInvestigationHistory(citizenid, function(history)
        GetAdjusterMemory(citizenid, function(memory)
            GetRepairOrders(citizenid, function(orders)
                MySQL.single('SELECT * FROM insurance_driver_profiles WHERE citizenid = ?', { citizenid }, function(profile)
                    MySQL.query('SELECT * FROM insurance_claims_enhanced WHERE citizenid = ? ORDER BY created_at DESC LIMIT 5', { citizenid }, function(claims)
                        cb({
                            history = history or {},
                            memory = memory,
                            repair_orders = orders or {},
                            profile = profile or {},
                            claims = claims or {},
                            summary = {
                                risk_score = profile and profile.risk_score or 0,
                                fraud_suspicion = profile and profile.fraud_suspicion or 0,
                                open_claims = claims and #claims or 0,
                                total_orders = orders and #orders or 0
                            }
                        })
                    end)
                end)
            end)
        end)
    end)
end

exports('BuildPortalData', BuildPortalData)
