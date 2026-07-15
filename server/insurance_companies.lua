--[[
    insurance_companies.lua (server)
    Insurance company selection and policy styling.
]]

function SelectInsuranceCompany(policyTier, damagePercent)
    local companies = Config.InsuranceCompanies or {}
    local candidates = {}
    for _, company in pairs(companies) do
        table.insert(candidates, company)
    end

    table.sort(candidates, function(a, b)
        return (a.id or '') < (b.id or '')
    end)

    if #candidates == 0 then
        return Config.DefaultInsuranceCompany or 'blaine'
    end

    local index = 1
    if policyTier == 'elite' then
        index = 4
    elseif policyTier == 'premium' then
        index = 3
    elseif damagePercent and damagePercent > 60 then
        index = 2
    end

    return candidates[math.min(index, #candidates)].id
end

function GetInsuranceCompany(companyName)
    local company = Config.InsuranceCompanies and Config.InsuranceCompanies[companyName]
    if company then
        return company
    end

    return Config.InsuranceCompanies and Config.InsuranceCompanies[Config.DefaultInsuranceCompany or 'blaine'] or {
        id = 'blaine',
        name = Config.Company and Config.Company.Name or 'Blaine County Mutual Insurance',
        adjuster_style = 'pragmatic',
        payout_modifier = 1.0,
        deductible_modifier = 1.0
    }
end

exports('GetInsuranceCompany', GetInsuranceCompany)
exports('SelectInsuranceCompany', SelectInsuranceCompany)
