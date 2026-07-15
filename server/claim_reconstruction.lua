--[[
    claim_reconstruction.lua (server)
    Generates structured crash reconstruction data and ASCII diagrams from the collected evidence.
]]

local function normalizeDirection(direction)
    if not direction or direction == '' then
        return 'unknown'
    end

    local normalized = tostring(direction):lower()
    if normalized:find('front') then
        return 'front impact'
    elseif normalized:find('rear') then
        return 'rear impact'
    elseif normalized:find('side') then
        return 'side impact'
    elseif normalized:find('roll') then
        return 'rollover event'
    end

    return normalized
end

function GenerateDamageReconstruction(evidence, mechanicReport)
    local accident = evidence and evidence.accident or {}
    local vehicle = evidence and evidence.vehicle or {}
    local speed = tonumber(accident.speed_at_impact or accident.speed_before_impact or 0) or 0
    local impactDirection = normalizeDirection(accident.impact_direction or 'unknown')
    local numberOfImpacts = tonumber(accident.number_of_impacts or 1) or 1
    local hasRollover = accident.rollovers == true
    local hasAirbags = accident.airbag_deployed == true
    local vehicleModel = vehicle.model or vehicle.vehicle_model or 'unknown'

    local rotation = math.max(20, math.min(180, math.floor(speed * 0.9 + (hasRollover and 35 or 0) + (numberOfImpacts > 1 and 20 or 0))))
    local travelDistance = math.max(2, math.floor((speed / 8) + (accident.vehicle_flipped and 6 or 0) + (numberOfImpacts > 1 and 3 or 0)))

    local likelyCause = 'Impact with a fixed object at moderate speed.'
    if speed >= 70 then
        likelyCause = 'Loss of traction while cornering at excessive speed.'
    elseif hasRollover then
        likelyCause = 'Vehicle rolled after impact and lost stability.'
    elseif hasAirbags then
        likelyCause = 'High-energy collision caused airbag deployment and significant structural damage.'
    end

    local diagram = {
        nodes = {
            { id = 'vehicle', label = vehicleModel },
            { id = 'impact', label = 'X' },
            { id = 'obstacle', label = 'Obstacle' }
        },
        edges = {
            { from = 'vehicle', to = 'impact' },
            { from = 'impact', to = 'obstacle' }
        }
    }

    local diagramAscii = string.format([[%s
      \
       \
        X
         \
          Obstacle]], vehicleModel)

    local summary = string.format(
        'Collision reconstruction indicates %s. Evidence suggests a %s sequence with %d degrees of rotation and an estimated travel distance of %d meters after impact.',
        likelyCause,
        impactDirection,
        rotation,
        travelDistance
    )

    if mechanicReport and mechanicReport.notes and mechanicReport.notes ~= '' then
        summary = summary .. ' ' .. mechanicReport.notes
    end

    local confidence = math.min(98, 78 + (hasAirbags and 8 or 0) + (numberOfImpacts > 1 and 6 or 0) + (vehicleModel ~= 'unknown' and 3 or 0))

    return {
        impact_speed = speed,
        primary_impact = impactDirection,
        secondary_impact = numberOfImpacts > 1 and 'side contact' or 'stabilization event',
        vehicle_rotation = rotation,
        distance_traveled_after_impact = travelDistance,
        airbags = hasAirbags and 'deployed' or 'not deployed',
        likely_cause = likelyCause,
        sequence = {
            'Primary impact: ' .. tostring(impactDirection),
            'Secondary impact: ' .. (numberOfImpacts > 1 and 'side contact' or 'stabilization event'),
            'Vehicle rotation: ' .. tostring(rotation) .. ' degrees',
            'Estimated distance after impact: ' .. tostring(travelDistance) .. ' meters',
            'Airbags: ' .. (hasAirbags and 'deployed' or 'not deployed')
        },
        diagram = diagram,
        diagram_ascii = diagramAscii,
        summary = summary,
        confidence = confidence
    }
end

exports('GenerateDamageReconstruction', GenerateDamageReconstruction)
