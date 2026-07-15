--[[
    investigation.lua (server)
    Multi-stage investigation workflow orchestrator.
    Coordinates evidence collection, mechanic inspection, witness review, police/EMS review, and AI analysis.
]]

-- Investigation stages
local STAGES = {
    EVIDENCE_COLLECTION = 'evidence_collection',
    MECHANIC_INSPECTION = 'mechanic_inspection',
    WITNESS_REVIEW = 'witness_review',
    POLICE_REVIEW = 'police_review',
    EMS_REVIEW = 'ems_review',
    AI_ANALYSIS = 'ai_analysis',
    COMPLETED = 'completed'
}

-- Start a new investigation
function StartInvestigation(crashData, src, cb)
    local citizenid = getCitizenId(src)
    
    -- Stage 1: Evidence Collection
    print('[ai_insurance_adjuster] Starting investigation - Stage 1: Evidence Collection')
    CollectEvidence(crashData, src, function(success, evidence, err)
        if not success then
            cb(false, nil, err)
            return
        end

        -- Create initial claim record
        MySQL.insert([[
            INSERT INTO insurance_claims_enhanced 
            (claim_number, citizenid, policy_tier, investigation_stage, accident_date, gps_x, gps_y, gps_z,
             street_name, weather, road_type, speed_before_impact, speed_at_impact, number_of_impacts,
             impact_direction, rollovers, airbag_deployed, vehicle_flipped, engine_stalled, fire, explosion,
             occupants, seatbelt_status, driver_ejected, vehicle_drivable, engine_health, body_health,
             fuel_tank_health, tire_condition, door_damage, window_damage, damage_percent)
            VALUES (?, ?, ?, ?, NOW(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            evidence.claim_number,
            evidence.citizenid,
            evidence.policy.tier,
            STAGES.EVIDENCE_COLLECTION,
            evidence.accident.gps_location.x,
            evidence.accident.gps_location.y,
            evidence.accident.gps_location.z,
            evidence.accident.street_name,
            evidence.accident.weather,
            evidence.accident.road_type,
            evidence.accident.speed_before_impact,
            evidence.accident.speed_at_impact,
            evidence.accident.number_of_impacts,
            evidence.accident.impact_direction,
            evidence.accident.rollovers and 1 or 0,
            evidence.accident.airbag_deployed and 1 or 0,
            evidence.accident.vehicle_flipped and 1 or 0,
            evidence.accident.engine_stalled and 1 or 0,
            evidence.accident.fire and 1 or 0,
            evidence.accident.explosion and 1 or 0,
            evidence.accident.occupants,
            evidence.accident.seatbelt_status and 1 or 0,
            evidence.accident.driver_ejected and 1 or 0,
            evidence.accident.vehicle_drivable and 1 or 0,
            evidence.vehicle_health.engine_health,
            evidence.vehicle_health.body_health,
            evidence.vehicle_health.fuel_tank_health,
            json.encode(evidence.vehicle_health.tire_condition),
            json.encode(evidence.vehicle_health.door_damage),
            json.encode(evidence.vehicle_health.window_damage),
            evidence.damage_percent
        }, function(claimId)
            evidence.claim_id = claimId

            -- Stage 2: Mechanic Inspection
            print('[ai_insurance_adjuster] Stage 2: Mechanic Inspection')
            MechanicInspection(evidence, function(mechanicSuccess, mechanicReport, mechanicErr)
                if not mechanicSuccess then
                    print('[ai_insurance_adjuster] Mechanic inspection failed, using fallback: ' .. tostring(mechanicErr))
                    mechanicReport = FallbackMechanicInspection(evidence)
                end

                -- Save mechanic report
                SaveMechanicReport(claimId, mechanicReport, 'AI Mechanic')
                evidence.mechanic_report = mechanicReport

                -- Update investigation stage
                UpdateInvestigationStage(claimId, STAGES.MECHANIC_INSPECTION)

                -- Stage 3: Witness Review
                print('[ai_insurance_adjuster] Stage 3: Witness Review')
                DetectWitnesses(src, evidence.accident.gps_location, function(witnesses)
                    GenerateWitnessSummaries(witnesses, evidence.accident, function(summaries)
                        -- Save witness reports
                        SaveWitnessReports(claimId, witnesses, summaries)
                        evidence.witness_reports = {
                            witnesses = witnesses,
                            summaries = summaries
                        }

                        -- Update investigation stage
                        UpdateInvestigationStage(claimId, STAGES.WITNESS_REVIEW)

                        -- Stage 4: Police Review (if applicable)
                        print('[ai_insurance_adjuster] Stage 4: Police Review')
                        AttachPoliceReports(claimId, citizenid, function(policeReports)
                            evidence.police_reports = policeReports

                            -- Update investigation stage
                            UpdateInvestigationStage(claimId, STAGES.POLICE_REVIEW)

                            -- Stage 5: EMS Review (if applicable)
                            print('[ai_insurance_adjuster] Stage 5: EMS Review')
                            AttachEMSReports(claimId, citizenid, function(emsReports)
                                evidence.ems_reports = emsReports

                                -- Update investigation stage
                                UpdateInvestigationStage(claimId, STAGES.EMS_REVIEW)

                                -- Stage 6: AI Analysis
                                print('[ai_insurance_adjuster] Stage 6: AI Analysis')
                                GetAdjusterMemory(evidence.citizenid, function(memory)
                                    evidence.adjuster_memory = memory and memory.summary or 'No prior claim history available.'
                                    evidence.company_name = evidence.company_name or SelectInsuranceCompany(evidence.policy and evidence.policy.tier or 'standard', evidence.damage_percent or 0)
                                    PerformAIAnalysis(evidence, claimId, function(aiSuccess, verdict, aiErr)
                                        if not aiSuccess then
                                            cb(false, nil, aiErr)
                                            return
                                        end

                                        -- Update investigation stage
                                        UpdateInvestigationStage(claimId, STAGES.AI_ANALYSIS)

                                        -- Add reconstruction and commercial context
                                        local reconstruction = GenerateDamageReconstruction(evidence, evidence.mechanic_report)
                                        verdict.reconstruction = reconstruction
                                        verdict.company = evidence.company_name or Config.DefaultInsuranceCompany or 'blaine'
                                        verdict.companyName = GetInsuranceCompany(verdict.company) and GetInsuranceCompany(verdict.company).name or Config.Company.Name
                                        verdict.dashboard = {
                                            reconstruction = reconstruction,
                                            claim_history = {},
                                            repair_orders = {}
                                        }

                                        -- Persist history, repair order, and memory
                                        SaveClaimHistoryEntry(claimId, evidence, verdict, verdict.companyName, reconstruction)
                                        CreateRepairOrder(claimId, evidence, verdict)

                                        -- Check investigation status
                                        if verdict.decision == 'investigate' and verdict.followUpQuestions then
                                            -- Need follow-up questions
                                            UpdateInvestigationStage(claimId, 'awaiting_response')
                                            SaveFollowUpQuestions(claimId, verdict.followUpQuestions)
                                            cb(true, {
                                                claim_id = claimId,
                                                claim_number = evidence.claim_number,
                                                status = 'awaiting_response',
                                                follow_up_questions = verdict.followUpQuestions,
                                                evidence = evidence
                                            }, nil)
                                        else
                                            -- Investigation complete
                                            CompleteInvestigation(claimId, verdict, evidence, function(completeSuccess, completeErr)
                                                if completeSuccess then
                                                    cb(true, {
                                                        claim_id = claimId,
                                                        claim_number = evidence.claim_number,
                                                        status = 'completed',
                                                        verdict = verdict,
                                                        evidence = evidence
                                                    }, nil)
                                                else
                                                    cb(false, nil, completeErr)
                                                end
                                            end)
                                        end
                                    end)
                                end)
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end)
end

-- Attach police reports if available (framework-specific hook)
function AttachPoliceReports(claimId, citizenid, cb)
    -- This is a framework-specific integration point
    -- For now, we'll return empty reports
    -- In a real implementation, you would query your police MDT or citation system
    
    -- Example implementation:
    -- MySQL.query('SELECT * FROM police_citations WHERE citizenid = ? ORDER BY date DESC LIMIT 5', 
    --     { citizenid }, function(reports)
    --         if reports and #reports > 0 then
    --             for _, report in ipairs(reports) do
    --                 MySQL.insert([[
    --                     INSERT INTO insurance_police_reports 
    --                     (claim_id, report_number, officer_name, citation_type, description, fine_amount, report_date)
    --                     VALUES (?, ?, ?, ?, ?, ?, ?)
    --                 ]], { claimId, report.id, report.officer, report.type, report.description, report.fine, report.date })
    --             end
    --         end
    --         cb(reports or {})
    --     end)
    
    cb({})
end

-- Attach EMS reports if available (framework-specific hook)
function AttachEMSReports(claimId, citizenid, cb)
    -- This is a framework-specific integration point
    -- For now, we'll return empty reports
    -- In a real implementation, you would query your EMS system
    
    -- Example implementation:
    -- MySQL.query('SELECT * FROM ems_reports WHERE citizenid = ? ORDER BY date DESC LIMIT 5', 
    --     { citizenid }, function(reports)
    --         if reports and #reports > 0 then
    --             for _, report in ipairs(reports) do
    --                 MySQL.insert([[
    --                     INSERT INTO insurance_ems_reports 
    --                     (claim_id, paramedic_name, injury_severity, injuries, treatment, unconscious, passengers, transported, hospital_name, report_date)
    --                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    --                 ]], { claimId, report.paramedic, report.severity, json.encode(report.injuries), report.treatment, 
    --                      report.unconscious and 1 or 0, report.passengers, report.transported and 1 or 0, report.hospital, report.date })
    --             end
    --         end
    --         cb(reports or {})
    --     end)
    
    cb({})
end

-- Perform AI analysis with all collected evidence
function PerformAIAnalysis(evidence, claimId, cb)
    GetPhotoEvidence(claimId, function(photos)
    -- Step 1: Calculate repair costs from mechanic parts identification
    local repairEstimate = CalculateRepairEstimate(evidence.mechanic_report, evidence.vehicle)
    
    -- Step 2: Calculate fraud score
    local fraudAssessment = CalculateFraudScore(
        evidence.citizenid,
        evidence,
        evidence.driver,
        evidence.driver.recent_claims or {}
    )
    
    -- Step 3: Calculate risk score
    local riskAssessment = CalculateDriverRiskScore(
        evidence.driver,
        evidence.driver.driving_history or {},
        evidence.driver.recent_claims or {}
    )
    
    -- Step 4: Calculate confidence score
    local confidenceAssessment = CalculateInvestigationConfidence({
        vehicle = evidence.vehicle,
        witness_reports = evidence.witness_reports,
        police_reports = evidence.police_reports,
        mechanic_report = evidence.mechanic_report,
        player_statement = evidence.player_statement,
        ems_reports = evidence.ems_reports
    })
    
    -- Step 5: Validate policy and coverage
    local policyValidation = ValidatePolicy(
        evidence.policy.tier,
        evidence.vehicle.vehicle_class,
        evidence
    )
    
    local coverageLimits = CalculateCoverageLimits(
        evidence.policy.tier,
        evidence.vehicle.vehicle_class,
        repairEstimate.total_cost
    )
    
    local claimEligibility = CalculateClaimEligibility(
        policyValidation,
        coverageLimits,
        evidence.driver
    )
    
    -- Step 6: Calculate final approved amount and deductible
    local deductible = CalculateDeductible(
        evidence.policy.tier,
        evidence.accident.accident_type or "collision",
        nil -- driver at fault not determined yet
    )
    
    local approvedAmount = CalculateApprovedAmount(
        repairEstimate.total_cost,
        deductible,
        coverageLimits.effective_max_payout,
        coverageLimits
    )
    
    local photoSummary = {}
    for _, photo in ipairs(photos or {}) do
        table.insert(photoSummary, string.format('%s: %s', photo.caption or 'photo', photo.photo_url or ''))
    end

    -- Build comprehensive analysis payload with pre-calculated values
    local analysisPayload = {
        claim_number = evidence.claim_number,
        
        -- Vehicle information
        vehicle = evidence.vehicle,
        
        -- Driver information
        driver = evidence.driver,
        
        -- Accident details
        accident = evidence.accident,
        
        -- Vehicle health
        vehicle_health = evidence.vehicle_health,
        
        -- Damage
        damage_percent = evidence.damage_percent,
        
        -- Player statement
        player_statement = evidence.player_statement,
        
        -- Mechanic report (parts only - no costs)
        mechanic_report = {
            damaged_parts = evidence.mechanic_report.damaged_parts,
            notes = evidence.mechanic_report.notes
        },
        
        -- Pre-calculated repair estimate
        repair_estimate = {
            parts = repairEstimate.parts_cost,
            labor = repairEstimate.labor_cost,
            total = repairEstimate.total_cost,
            labor_hours = repairEstimate.labor_hours,
            itemized_costs = repairEstimate.itemized_costs
        },
        
        -- Pre-calculated fraud assessment
        fraud_assessment = {
            score = fraudAssessment.score,
            level = fraudAssessment.level,
            indicators = fraudAssessment.indicators
        },
        
        -- Pre-calculated risk assessment
        risk_assessment = {
            score = riskAssessment.score,
            category = riskAssessment.category,
            factors = riskAssessment.factors
        },
        
        -- Pre-calculated confidence assessment
        confidence_assessment = {
            score = confidenceAssessment.score,
            level = confidenceAssessment.level,
            evidence_quality = confidenceAssessment.evidence_quality
        },
        
        -- Pre-calculated policy validation
        policy_validation = {
            is_valid = policyValidation.is_valid,
            policy_tier = policyValidation.policy_tier,
            coverage_details = policyValidation.coverage_details,
            restrictions = policyValidation.restrictions,
            benefits = policyValidation.benefits
        },
        
        -- Pre-calculated coverage limits
        coverage_limits = {
            max_payout = coverageLimits.effective_max_payout,
            deductible = deductible,
            covered_amount = coverageLimits.covered_amount,
            exceeds_limit = coverageLimits.exceeds_limit
        },
        
        -- Pre-calculated approved amount
        approved_amount = approvedAmount,

        -- Commercial context
        adjuster_memory = evidence.adjuster_memory or 'No prior claim history available.',
        company_name = evidence.company_name or Config.DefaultInsuranceCompany or 'blaine',
        reconstruction = GenerateDamageReconstruction(evidence, evidence.mechanic_report),
        
        -- Witness summary
        witness_summary = GenerateConsolidatedWitnessSummary(evidence.witness_reports.witnesses),
        
        -- Police reports
        police_reports = evidence.police_reports or [],
        
        -- EMS reports
        ems_reports = evidence.ems_reports or [],
        
        -- Policy information
        policy = evidence.policy,

        -- Photo evidence
        photo_evidence = photoSummary,
        photo_evidence_summary = table.concat(photoSummary, ' | ')
    }

    -- Call insurance AI with pre-calculated values
    InvestigateClaim(analysisPayload, claimId, function(success, verdict, err)
        if not success then
            cb(false, nil, err)
            return
        }

        -- Ensure AI uses our pre-calculated values
        verdict.confidence = confidenceAssessment.score
        verdict.fraudRisk = fraudAssessment.level
        verdict.riskScore = riskAssessment.score
        verdict.approvedAmount = approvedAmount
        verdict.deductible = deductible
        verdict.promptVersion = verdict.promptVersion or (Config.AIPromptVersion or 'v1')
        verdict.provider = verdict.provider or 'unknown'
        
        cb(true, verdict, nil)
    end)
    end)
end

-- Update investigation stage
function UpdateInvestigationStage(claimId, stage)
    MySQL.query('UPDATE insurance_claims_enhanced SET investigation_stage = ? WHERE id = ?', { stage, claimId })
end

-- Save follow-up questions
function SaveFollowUpQuestions(claimId, questions)
    MySQL.query('UPDATE insurance_claims_enhanced SET follow_up_questions = ? WHERE id = ?', 
        { json.encode(questions), claimId })
end

-- Process player answers to follow-up questions
function ProcessFollowUpAnswers(claimId, answers, cb)
    MySQL.single('SELECT * FROM insurance_claims_enhanced WHERE id = ?', { claimId }, function(claim)
        if not claim then
            cb(false, 'claim_not_found')
            return
        end

        -- Save answers
        MySQL.query('UPDATE insurance_claims_enhanced SET player_answers = ? WHERE id = ?', 
            { json.encode(answers), claimId })

        -- Re-run AI analysis with new information
        local evidence = json.decode(json.encode(claim)) -- Deep copy
        evidence.player_answers = answers

        PerformAIAnalysis(evidence, claimId, function(success, verdict, err)
            if not success then
                cb(false, err)
                return
            end

            -- Check if still investigating
            if verdict.decision == 'investigate' and verdict.followUpQuestions then
                -- More questions needed
                SaveFollowUpQuestions(claimId, verdict.followUpQuestions)
                cb(true, {
                    status = 'awaiting_response',
                    follow_up_questions = verdict.followUpQuestions
                })
            else
                -- Investigation complete
                CompleteInvestigation(claimId, verdict, evidence, function(completeSuccess, completeErr)
                    if completeSuccess then
                        cb(true, { status = 'completed', verdict = verdict })
                    else
                        cb(false, completeErr)
                    end
                end)
            end
        end)
    end)
end

-- Complete investigation and save final verdict
function CompleteInvestigation(claimId, verdict, evidence, cb)
    -- Get policy tier for deductible
    GetPolicyTier(evidence.policy.tier, function(policyTier)
        local deductible = policyTier and policyTier.deductible or 500
        local approvedAmount = 0

        if verdict.decision == 'approved' then
            approvedAmount = math.max(0, (verdict.approvedAmount or verdict.repairEstimate.total) - deductible)
        end

        -- Update claim with final verdict
        local premiumMultiplier = CalculatePremiumAdjustment(
            policyTier and policyTier.monthly_premium or 100,
            verdict.riskScore or 50,
            { recent_claims_count = evidence.recent_claims_count or 0 }
        )

        MySQL.query([[
            UPDATE insurance_claims_enhanced 
            SET investigation_stage = 'completed',
                decision = ?,
                prompt_version = ?,
                ai_provider = ?,
                confidence = ?,
                fraud_risk = ?,
                risk_score = ?,
                approved_amount = ?,
                deductible = ?,
                mechanic_report = ?,
                witness_reports = ?,
                police_reports = ?,
                ems_reports = ?,
                reasoning = ?,
                flags = ?,
                next_action = ?,
                adjuster_notes = ?,
                mechanic_summary = ?,
                investigation_summary = ?,
                follow_up_questions = ?,
                completed_at = NOW()
            WHERE id = ?
        ]], {
            verdict.decision,
            verdict.promptVersion or (Config.AIPromptVersion or 'v1'),
            verdict.provider or 'unknown',
            verdict.confidence or 50,
            verdict.fraudRisk or 'medium',
            verdict.riskScore or 50,
            approvedAmount,
            deductible,
            json.encode(evidence.mechanic_report),
            json.encode(evidence.witness_reports),
            json.encode(evidence.police_reports),
            json.encode(evidence.ems_reports),
            verdict.reasoning,
            json.encode(verdict.flags or {}),
            verdict.nextAction or '',
            verdict.adjusterNotes or '',
            verdict.mechanicSummary or '',
            verdict.investigationSummary or '',
            json.encode(verdict.followUpQuestions or {}),
            claimId
        })

        -- Persist commercial context to the claim record
        local reconstructionPayload = verdict.reconstruction or {}
        MySQL.query([[
            UPDATE insurance_claims_enhanced
            SET investigation_summary = ?,
                mechanic_summary = ?
            WHERE id = ?
        ]], {
            verdict.investigationSummary or (reconstructionPayload.summary or ''),
            verdict.mechanicSummary or (reconstructionPayload.summary or ''),
            claimId
        })

        -- Also update driver premium profile
        UpdateDriverProfile(evidence.citizenid, {
            risk_score = verdict.riskScore or 50,
            premium_multiplier = premiumMultiplier / 100
        })

        -- Also update legacy table for backward compatibility
        MySQL.insert([[
            INSERT INTO insurance_claims 
            (citizenid, vehicle_model, damage_percent, impact_speed, decision, payout, suspicion_score, reasoning, flags)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            evidence.citizenid,
            evidence.vehicle.model,
            evidence.damage_percent,
            evidence.accident.speed_at_impact,
            verdict.decision,
            approvedAmount,
            evidence.driver.fraud_score,
            verdict.reasoning,
            json.encode(verdict.flags or {})
        })

        -- Update driver statistics
        UpdateDriverStatistics(evidence.citizenid, evidence.accident, verdict.decision)

        -- Adjust fraud score if denied
        if verdict.decision == 'denied' then
            AdjustFraudScore(evidence.citizenid, 5)
        elseif verdict.decision == 'approved' then
            AdjustFraudScore(evidence.citizenid, -1) -- Small reward for legitimate claim
        end

        cb(true, nil)
    end)
end

-- Get investigation status
function GetInvestigationStatus(claimId, cb)
    MySQL.single('SELECT * FROM insurance_claims_enhanced WHERE id = ?', { claimId }, cb)
end

-- Register event for follow-up answers
RegisterNetEvent('ai_insurance_adjuster:submitFollowUpAnswers', function(claimId, answers)
    local src = source
    ProcessFollowUpAnswers(claimId, answers, function(success, result, err)
        if not success then
            TriggerClientEvent('ai_insurance_adjuster:notify', src, 'Error processing answers: ' .. tostring(err))
            return
        end

        if result.status == 'awaiting_response' then
            TriggerClientEvent('ai_insurance_adjuster:followUpQuestions', src, result.follow_up_questions)
        elseif result.status == 'completed' then
            TriggerClientEvent('ai_insurance_adjuster:verdict', src, result.verdict)
            
            -- Process payout if approved
            if result.verdict.decision == 'approved' and result.verdict.approvedAmount > 0 then
                payoutPlayer(src, result.verdict.approvedAmount)
            end
        end
    end)
end)
