--[[
    adjuster_memory.lua (server)
    Per-player recollection of prior claims for more natural adjuster behaviour.
]]

function SaveAdjusterMemory(citizenid, summary)
    if not citizenid then
        return
    end

    MySQL.single('SELECT * FROM insurance_adjuster_memory WHERE citizenid = ?', { citizenid }, function(memoryRow)
        if not memoryRow then
            MySQL.insert([[
                INSERT INTO insurance_adjuster_memory
                (citizenid, claim_count, summary, last_claim_at)
                VALUES (?, 1, ?, NOW())
            ]], {
                citizenid,
                summary
            })
        else
            local updatedSummary = string.format('%s | %s', memoryRow.summary or '', summary)
            MySQL.query([[
                UPDATE insurance_adjuster_memory
                SET claim_count = claim_count + 1,
                    summary = ?,
                    last_claim_at = NOW()
                WHERE citizenid = ?
            ]], { updatedSummary, citizenid })
        end
    end)
end

function GetAdjusterMemory(citizenid, cb)
    MySQL.single('SELECT * FROM insurance_adjuster_memory WHERE citizenid = ?', { citizenid }, function(row)
        if row then
            cb(row)
        else
            cb(nil)
        end
    end)
end

exports('SaveAdjusterMemory', SaveAdjusterMemory)
exports('GetAdjusterMemory', GetAdjusterMemory)
