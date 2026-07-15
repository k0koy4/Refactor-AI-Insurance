--[[
    vehicle_parts.lua (shared)
    Configurable vehicle parts database for repair cost calculations.
    This database is used by the repair cost calculation engine to determine
    replacement costs, repair costs, labor hours, and repair difficulty.
    
    All costs are in USD. Labor hours are estimated.
    Repair difficulty affects labor cost multiplier.
]]

VehiclePartsDatabase = {
    -- Engine Components
    engine = {
        replacement_cost = 4500,
        repair_cost = 2500,
        labor_hours = 12,
        repair_difficulty = "high",
        repairable = true,
        replace_only = false,
        category = "powertrain"
    },
    
    transmission = {
        replacement_cost = 3500,
        repair_cost = 2000,
        labor_hours = 10,
        repair_difficulty = "high",
        repairable = true,
        replace_only = false,
        category = "powertrain"
    },
    
    radiator = {
        replacement_cost = 400,
        repair_cost = 200,
        labor_hours = 2,
        repair_difficulty = "medium",
        repairable = true,
        replace_only = false,
        category = "cooling"
    },
    
    -- Body Components
    front_bumper = {
        replacement_cost = 500,
        repair_cost = 250,
        labor_hours = 3,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "exterior"
    },
    
    rear_bumper = {
        replacement_cost = 450,
        repair_cost = 225,
        labor_hours = 3,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "exterior"
    },
    
    hood = {
        replacement_cost = 600,
        repair_cost = 300,
        labor_hours = 2,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "exterior"
    },
    
    trunk = {
        replacement_cost = 550,
        repair_cost = 275,
        labor_hours = 2,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "exterior"
    },
    
    fender_front_left = {
        replacement_cost = 350,
        repair_cost = 175,
        labor_hours = 2,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "exterior"
    },
    
    fender_front_right = {
        replacement_cost = 350,
        repair_cost = 175,
        labor_hours = 2,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "exterior"
    },
    
    fender_rear_left = {
        replacement_cost = 300,
        repair_cost = 150,
        labor_hours = 2,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "exterior"
    },
    
    fender_rear_right = {
        replacement_cost = 300,
        repair_cost = 150,
        labor_hours = 2,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "exterior"
    },
    
    -- Doors
    door_front_left = {
        replacement_cost = 600,
        repair_cost = 300,
        labor_hours = 3,
        repair_difficulty = "medium",
        repairable = true,
        replace_only = false,
        category = "exterior"
    },
    
    door_front_right = {
        replacement_cost = 600,
        repair_cost = 300,
        labor_hours = 3,
        repair_difficulty = "medium",
        repairable = true,
        replace_only = false,
        category = "exterior"
    },
    
    door_rear_left = {
        replacement_cost = 550,
        repair_cost = 275,
        labor_hours = 3,
        repair_difficulty = "medium",
        repairable = true,
        replace_only = false,
        category = "exterior"
    },
    
    door_rear_right = {
        replacement_cost = 550,
        repair_cost = 275,
        labor_hours = 3,
        repair_difficulty = "medium",
        repairable = true,
        replace_only = false,
        category = "exterior"
    },
    
    -- Windows
    windshield = {
        replacement_cost = 300,
        repair_cost = 100,
        labor_hours = 1,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "glass"
    },
    
    window_front_left = {
        replacement_cost = 200,
        repair_cost = 75,
        labor_hours = 1,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "glass"
    },
    
    window_front_right = {
        replacement_cost = 200,
        repair_cost = 75,
        labor_hours = 1,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "glass"
    },
    
    window_rear_left = {
        replacement_cost = 200,
        repair_cost = 75,
        labor_hours = 1,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "glass"
    },
    
    window_rear_right = {
        replacement_cost = 200,
        repair_cost = 75,
        labor_hours = 1,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "glass"
    },
    
    window_rear = {
        replacement_cost = 250,
        repair_cost = 100,
        labor_hours = 1,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "glass"
    },
    
    -- Suspension
    suspension_front = {
        replacement_cost = 800,
        repair_cost = 400,
        labor_hours = 4,
        repair_difficulty = "medium",
        repairable = true,
        replace_only = false,
        category = "suspension"
    },
    
    suspension_rear = {
        replacement_cost = 700,
        repair_cost = 350,
        labor_hours = 4,
        repair_difficulty = "medium",
        repairable = true,
        replace_only = false,
        category = "suspension"
    },
    
    shock_absorbers = {
        replacement_cost = 400,
        repair_cost = 200,
        labor_hours = 2,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "suspension"
    },
    
    struts = {
        replacement_cost = 500,
        repair_cost = 250,
        labor_hours = 3,
        repair_difficulty = "medium",
        repairable = true,
        replace_only = false,
        category = "suspension"
    },
    
    -- Wheels and Brakes
    wheel = {
        replacement_cost = 150,
        repair_cost = 50,
        labor_hours = 0.5,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "wheels"
    },
    
    tire = {
        replacement_cost = 120,
        repair_cost = 0,
        labor_hours = 0.5,
        repair_difficulty = "low",
        repairable = false,
        replace_only = true,
        category = "wheels"
    },
    
    brake_calipers = {
        replacement_cost = 200,
        repair_cost = 100,
        labor_hours = 1,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "brakes"
    },
    
    brake_rotors = {
        replacement_cost = 150,
        repair_cost = 75,
        labor_hours = 1,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "brakes"
    },
    
    brake_pads = {
        replacement_cost = 80,
        repair_cost = 40,
        labor_hours = 0.5,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "brakes"
    },
    
    -- Fuel System
    fuel_tank = {
        replacement_cost = 400,
        repair_cost = 200,
        labor_hours = 3,
        repair_difficulty = "medium",
        repairable = true,
        replace_only = false,
        category = "fuel"
    },
    
    fuel_pump = {
        replacement_cost = 300,
        repair_cost = 150,
        labor_hours = 2,
        repair_difficulty = "medium",
        repairable = true,
        replace_only = false,
        category = "fuel"
    },
    
    -- Electrical
    battery = {
        replacement_cost = 150,
        repair_cost = 0,
        labor_hours = 0.5,
        repair_difficulty = "low",
        repairable = false,
        replace_only = true,
        category = "electrical"
    },
    
    alternator = {
        replacement_cost = 400,
        repair_cost = 200,
        labor_hours = 2,
        repair_difficulty = "medium",
        repairable = true,
        replace_only = false,
        category = "electrical"
    },
    
    starter = {
        replacement_cost = 350,
        repair_cost = 175,
        labor_hours = 2,
        repair_difficulty = "medium",
        repairable = true,
        replace_only = false,
        category = "electrical"
    },
    
    -- Lighting
    headlight_left = {
        replacement_cost = 200,
        repair_cost = 100,
        labor_hours = 0.5,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "lighting"
    },
    
    headlight_right = {
        replacement_cost = 200,
        repair_cost = 100,
        labor_hours = 0.5,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "lighting"
    },
    
    taillight_left = {
        replacement_cost = 150,
        repair_cost = 75,
        labor_hours = 0.5,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "lighting"
    },
    
    taillight_right = {
        replacement_cost = 150,
        repair_cost = 75,
        labor_hours = 0.5,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "lighting"
    },
    
    -- Safety Systems
    airbag_module = {
        replacement_cost = 800,
        repair_cost = 0,
        labor_hours = 4,
        repair_difficulty = "high",
        repairable = false,
        replace_only = true,
        category = "safety"
    },
    
    airbag_driver = {
        replacement_cost = 400,
        repair_cost = 0,
        labor_hours = 2,
        repair_difficulty = "high",
        repairable = false,
        replace_only = true,
        category = "safety"
    },
    
    airbag_passenger = {
        replacement_cost = 400,
        repair_cost = 0,
        labor_hours = 2,
        repair_difficulty = "high",
        repairable = false,
        replace_only = true,
        category = "safety"
    },
    
    seatbelt = {
        replacement_cost = 250,
        repair_cost = 100,
        labor_hours = 2,
        repair_difficulty = "medium",
        repairable = true,
        replace_only = false,
        category = "safety"
    },
    
    -- Frame and Structure
    frame_rail = {
        replacement_cost = 2000,
        repair_cost = 1000,
        labor_hours = 15,
        repair_difficulty = "high",
        repairable = true,
        replace_only = false,
        category = "structure"
    },
    
    unibody = {
        replacement_cost = 5000,
        repair_cost = 2500,
        labor_hours = 25,
        repair_difficulty = "critical",
        repairable = true,
        replace_only = false,
        category = "structure"
    },
    
    -- Interior
    dashboard = {
        replacement_cost = 800,
        repair_cost = 400,
        labor_hours = 4,
        repair_difficulty = "medium",
        repairable = true,
        replace_only = false,
        category = "interior"
    },
    
    seats = {
        replacement_cost = 400,
        repair_cost = 200,
        labor_hours = 2,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "interior"
    },
    
    steering_wheel = {
        replacement_cost = 300,
        repair_cost = 150,
        labor_hours = 1,
        repair_difficulty = "low",
        repairable = true,
        replace_only = false,
        category = "interior"
    }
}

-- Labor cost per hour based on difficulty
LaborRates = {
    low = 75,
    medium = 100,
    high = 125,
    critical = 150
}

-- Helper function to get part information
function GetPartInfo(partName)
    return VehiclePartsDatabase[partName]
end

-- Helper function to get labor rate for difficulty
function GetLaborRate(difficulty)
    return LaborRates[difficulty] or LaborRates.medium
end

-- Helper function to get all parts in a category
function GetPartsByCategory(category)
    local parts = {}
    for partName, partData in pairs(VehiclePartsDatabase) do
        if partData.category == category then
            parts[partName] = partData
        end
    end
    return parts
end

-- Helper function to check if part exists
function PartExists(partName)
    return VehiclePartsDatabase[partName] ~= nil
end
