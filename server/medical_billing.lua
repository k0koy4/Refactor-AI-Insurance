--[[
    medical_billing.lua (server)
    Medical billing integration for insurance claims.
    Handles medical expense tracking, coverage verification, and payment processing.
]]

-- Medical procedure codes (simplified CPT-like codes)
local procedureCodes = {
    { code = '99281', description = 'Emergency Department Visit - Level 1', base_cost = 150 },
    { code = '99282', description = 'Emergency Department Visit - Level 2', base_cost = 250 },
    { code = '99283', description = 'Emergency Department Visit - Level 3', base_cost = 400 },
    { code = '99284', description = 'Emergency Department Visit - Level 4', base_cost = 600 },
    { code = '99285', description = 'Emergency Department Visit - Level 5', base_cost = 900 },
    { code = '80053', description = 'Comprehensive Metabolic Panel', base_cost = 75 },
    { code = '85025', description = 'Complete Blood Count', base_cost = 50 },
    { code = '71020', description = 'Chest X-Ray', base_cost = 200 },
    { code = '71200', description = 'CT Scan - Chest', base_cost = 800 },
    { code = '72100', description = 'CT Scan - Head', base_cost = 1200 },
    { code = '73700', description = 'CT Scan - Extremity', base_cost = 1000 },
    { code = '26100', description = 'X-Ray - Extremity', base_cost = 150 },
    { code = '27040', description = 'X-Ray - Pelvis', base_cost = 250 },
    { code = '12001', description = 'Simple Repair - Wound', base_cost = 200 },
    { code = '12011', description = 'Intermediate Repair - Wound', base_cost = 350 },
    { code = '12021', description = 'Complex Repair - Wound', base_cost = 500 },
    { code = '99213', description = 'Office Visit - Level 3', base_cost = 100 },
    { code = '99214', description = 'Office Visit - Level 4', base_cost = 150 }
}

-- Provider types
local providerTypes = {
    { id = 'hospital', name = 'Hospital', coverage_multiplier = 1.0 },
    { id = 'urgent_care', name = 'Urgent Care', coverage_multiplier = 0.9 },
    { id = 'clinic', name = 'Medical Clinic', coverage_multiplier = 0.85 },
    { id = 'specialist', name = 'Specialist', coverage_multiplier = 1.1 },
    { id = 'ems', name = 'Emergency Services', coverage_multiplier = 1.0 }
}

-- Calculate medical coverage
function CalculateMedicalCoverage(billedAmount, policyTier, providerType)
    local provider = providerTypes[providerType] or providerTypes[1]
    
    -- Get policy tier details
    GetPolicyTier(policyTier, function(policy)
        if policy and policy.medical_coverage then
            local coverageMultiplier = provider.coverage_multiplier
            local coveredAmount = billedAmount * coverageMultiplier
            
            -- Apply policy limits if any
            if policy.max_payout then
                coveredAmount = math.min(coveredAmount, policy.max_payout * 0.5) -- Medical coverage is typically 50% of max payout
            end
            
            return {
                covered = true,
                billed_amount = billedAmount,
                covered_amount = math.ceil(coveredAmount * 100) / 100,
                patient_responsibility = billedAmount - coveredAmount,
                coverage_percentage = math.floor((coveredAmount / billedAmount) * 100)
            }
        else
            return {
                covered = false,
                billed_amount = billedAmount,
                covered_amount = 0,
                patient_responsibility = billedAmount,
                coverage_percentage = 0
            }
        end
    end)
end

-- Submit medical bill
function SubmitMedicalBill(claimId, citizenid, providerName, providerType, treatmentDate, serviceType, diagnosis, procedureCodesList, billedAmount)
    if not claimId or not citizenid then
        return false, 'Missing claim ID or citizen ID'
    end

    if not providerName or not treatmentDate then
        return false, 'Missing provider information or treatment date'
    end

    -- Calculate coverage
    local coverage = CalculateMedicalCoverage(billedAmount, 'standard', providerType)

    -- Save to database
    local billId = MySQL.insert([[
        INSERT INTO insurance_medical_billing
        (claim_id, citizenid, provider_name, provider_type, treatment_date, service_type,
         diagnosis, procedure_codes, billed_amount, covered_amount, patient_responsibility, status, submitted_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', NOW())
    ]], {
        claimId,
        citizenid,
        providerName,
        providerType,
        treatmentDate,
        serviceType or 'general',
        diagnosis or 'Not specified',
        json.encode(procedureCodesList or {}),
        billedAmount,
        coverage.covered_amount,
        coverage.patient_responsibility
    })

    return true, { bill_id = billId, coverage = coverage }
end

-- Get medical bill status
function GetMedicalBillStatus(billId, cb)
    MySQL.query('SELECT * FROM insurance_medical_billing WHERE id = ?', { billId }, function(rows)
        if rows and #rows > 0 then
            local bill = rows[1]
            -- Parse procedure codes
            local codes = {}
            if bill.procedure_codes then
                local success, decoded = pcall(json.decode, bill.procedure_codes)
                if success then
                    codes = decoded
                end
            end
            
            cb({
                id = bill.id,
                claim_id = bill.claim_id,
                provider_name = bill.provider_name,
                provider_type = bill.provider_type,
                treatment_date = bill.treatment_date,
                service_type = bill.service_type,
                diagnosis = bill.diagnosis,
                procedure_codes = codes,
                billed_amount = bill.billed_amount,
                covered_amount = bill.covered_amount,
                patient_responsibility = bill.patient_responsibility,
                status = bill.status,
                invoice_number = bill.invoice_number,
                submitted_at = bill.submitted_at,
                processed_at = bill.processed_at
            })
        else
            cb(nil)
        end
    end)
end

-- Process medical bill payment
function ProcessMedicalBill(billId, status, invoiceNumber)
    local values = { status, billId }

    if invoiceNumber then
        MySQL.query('UPDATE insurance_medical_billing SET invoice_number = ? WHERE id = ?', { invoiceNumber, billId })
    end

    if status == 'approved' or status == 'paid' then
        MySQL.query('UPDATE insurance_medical_billing SET processed_at = NOW() WHERE id = ?', { billId })
    end

    MySQL.query('UPDATE insurance_medical_billing SET status = ? WHERE id = ?', values)
    return true
end

-- Get medical bills for a claim
function GetClaimMedicalBills(claimId, cb)
    MySQL.query('SELECT * FROM insurance_medical_billing WHERE claim_id = ? ORDER BY submitted_at DESC', { claimId }, function(rows)
        local bills = {}
        for _, row in ipairs(rows or {}) do
            local codes = {}
            if row.procedure_codes then
                local success, decoded = pcall(json.decode, row.procedure_codes)
                if success then
                    codes = decoded
                end
            end
            
            table.insert(bills, {
                id = row.id,
                provider_name = row.provider_name,
                provider_type = row.provider_type,
                treatment_date = row.treatment_date,
                service_type = row.service_type,
                diagnosis = row.diagnosis,
                procedure_codes = codes,
                billed_amount = row.billed_amount,
                covered_amount = row.covered_amount,
                patient_responsibility = row.patient_responsibility,
                status = row.status
            })
        end
        cb(bills)
    end)
end

-- Get medical billing history for a citizen
function GetMedicalBillingHistory(citizenid, limit, cb)
    local count = tonumber(limit) or 10
    MySQL.query('SELECT * FROM insurance_medical_billing WHERE citizenid = ? ORDER BY submitted_at DESC LIMIT ?', { citizenid, count }, function(rows)
        cb(rows or {})
    end)
end

-- Get procedure codes
function GetProcedureCodes()
    return procedureCodes
end

-- Get provider types
function GetProviderTypes()
    return providerTypes
end

-- Event handlers
RegisterNetEvent('ai_insurance_adjuster:submitMedicalBill', function(claimId, providerName, providerType, treatmentDate, serviceType, diagnosis, procedureCodesList, billedAmount)
    local src = source
    local citizenid = GetPlayerIdentifier(src, 0) or tostring(src)
    local ok, result = SubmitMedicalBill(claimId, citizenid, providerName, providerType, treatmentDate, serviceType, diagnosis, procedureCodesList, billedAmount)
    if ok then
        TriggerClientEvent('ai_insurance_adjuster:notify', src, string.format('Medical bill submitted. Covered amount: $%.2f', result.coverage.covered_amount))
        TriggerClientEvent('ai_insurance_adjuster:medicalBillSubmitted', src, result)
    else
        TriggerClientEvent('ai_insurance_adjuster:notify', src, result or 'Could not submit medical bill.')
    end
end)

RegisterNetEvent('ai_insurance_adjuster:getMedicalBillStatus', function(billId)
    local src = source
    GetMedicalBillStatus(billId, function(status)
        TriggerClientEvent('ai_insurance_adjuster:medicalBillStatus', src, status)
    end)
end)

RegisterNetEvent('ai_insurance_adjuster:getClaimMedicalBills', function(claimId)
    local src = source
    GetClaimMedicalBills(claimId, function(bills)
        TriggerClientEvent('ai_insurance_adjuster:claimMedicalBills', src, bills)
    end)
end)

RegisterNetEvent('ai_insurance_adjuster:getMedicalBillingHistory', function(limit)
    local src = source
    local citizenid = GetPlayerIdentifier(src, 0) or tostring(src)
    GetMedicalBillingHistory(citizenid, limit, function(history)
        TriggerClientEvent('ai_insurance_adjuster:medicalBillingHistory', src, history)
    end)
end)

RegisterNetEvent('ai_insurance_adjuster:getProcedureCodes', function()
    local src = source
    TriggerClientEvent('ai_insurance_adjuster:procedureCodes', src, GetProcedureCodes())
end)

RegisterNetEvent('ai_insurance_adjuster:getProviderTypes', function()
    local src = source
    TriggerClientEvent('ai_insurance_adjuster:providerTypes', src, GetProviderTypes())
end)

-- Admin event to process medical bill
RegisterNetEvent('ai_insurance_adjuster:processMedicalBill', function(billId, status, invoiceNumber)
    local src = source
    -- HOOK: Add admin permission check here
    ProcessMedicalBill(billId, status, invoiceNumber)
    TriggerClientEvent('ai_insurance_adjuster:notify', src, string.format('Medical bill %s.', status))
end)

-- Exports
exports('SubmitMedicalBill', SubmitMedicalBill)
exports('GetMedicalBillStatus', GetMedicalBillStatus)
exports('ProcessMedicalBill', ProcessMedicalBill)
exports('GetClaimMedicalBills', GetClaimMedicalBills)
exports('GetMedicalBillingHistory', GetMedicalBillingHistory)
exports('GetProcedureCodes', GetProcedureCodes)
exports('GetProviderTypes', GetProviderTypes)
