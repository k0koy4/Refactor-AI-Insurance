--[[
    player_portal.lua (server)
    Aggregates data for the insurance dashboard/NUI panel with a coherent summary payload.
]]

function BuildDashboardData(citizenid, cb)
    GetInvestigationHistory(citizenid, function(history)
        GetAdjusterMemory(citizenid, function(memory)
            GetRepairOrders(citizenid, function(orders)
                MySQL.single('SELECT * FROM insurance_driver_profiles WHERE citizenid = ?', { citizenid }, function(profile)
                    MySQL.query('SELECT * FROM insurance_claims_enhanced WHERE citizenid = ? ORDER BY created_at DESC LIMIT 5', { citizenid }, function(activeClaims)
                        ListPhotoEvidence(citizenid, 5, function(photos)
                            local timeline = {}
                            for _, entry in ipairs(history or {}) do
                                table.insert(timeline, string.format('%s | %s | $%s', entry.claim_number or entry.id, entry.decision or 'unknown', entry.approved_amount or 0))
                            end

                            local evidenceItems = {}
                            for _, photo in ipairs(photos or {}) do
                                table.insert(evidenceItems, string.format('%s - %s', photo.caption or 'Photo', photo.photo_url or ''))
                            end

                            local progress = {}
                            for _, claim in ipairs(activeClaims or {}) do
                                table.insert(progress, string.format('%s: %s', claim.claim_number or claim.id, claim.investigation_stage or 'unknown'))
                            end

                            local activeClaimItems = {}
                            for _, claim in ipairs(activeClaims or {}) do
                                table.insert(activeClaimItems, string.format('%s | %s', claim.claim_number or claim.id, claim.decision or claim.investigation_stage or 'pending'))
                            end

                            local previousClaimItems = {}
                            for _, entry in ipairs(history or {}) do
                                table.insert(previousClaimItems, string.format('%s | %s', entry.claim_number or entry.id, entry.decision or 'unknown'))
                            end

                            local repairOrderItems = {}
                            for _, order in ipairs(orders or {}) do
                                table.insert(repairOrderItems, string.format('%s | %s | $%s', order.id, order.status or 'pending', order.approved_amount or 0))
                            end

                            cb({
                                activeClaims = activeClaimItems,
                                previousClaims = previousClaimItems,
                                riskScore = profile and (profile.risk_score or 0) or 0,
                                fraudScore = profile and (profile.fraud_suspicion or 0) or 0,
                                repairOrders = repairOrderItems,
                                progress = progress,
                                timeline = timeline,
                                evidence = evidenceItems,
                                memory = memory and memory.summary or 'No previous activity recorded.'
                            })
                        end)
                    end)
                end)
            end)
        end)
    end)
end

exports('BuildDashboardData', BuildDashboardData)
