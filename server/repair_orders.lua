--[[
    repair_orders.lua (server)
    Repair order lifecycle after an insurance approval.
]]

function CreateRepairOrder(claimId, evidence, verdict)
    local approvedAmount = verdict and verdict.approvedAmount or 0
    local companyName = evidence.company_name or Config.DefaultInsuranceCompany or 'blaine'
    local company = GetInsuranceCompany(companyName)
    local displayName = company and company.name or (Config.Company and Config.Company.Name or 'Blaine County Mutual Insurance')

    MySQL.insert([[
        INSERT INTO insurance_repair_orders
        (claim_id, citizenid, company_name, status, approved_amount, created_at)
        VALUES (?, ?, ?, 'repair_order_generated', ?, NOW())
    ]], {
        claimId,
        evidence.citizenid,
        displayName,
        approvedAmount
    })
end

function GetRepairOrders(citizenid, cb)
    MySQL.query('SELECT * FROM insurance_repair_orders WHERE citizenid = ? ORDER BY created_at DESC LIMIT 5', { citizenid }, function(rows)
        cb(rows or {})
    end)
end

exports('CreateRepairOrder', CreateRepairOrder)
exports('GetRepairOrders', GetRepairOrders)
