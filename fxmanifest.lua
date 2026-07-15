fx_version 'cerulean'
game 'gta5'

author 'you'
description 'AI Insurance Adjuster - investigates vehicle crash claims and pays out (or doesn\'t)'
version '1.0.0'

ui_page 'html/dashboard.html'

files {
    'html/dashboard.html',
    'html/dashboard.css',
    'html/dashboard.js'
}

shared_script 'config.lua'
shared_script 'shared/utils.lua'
shared_script 'shared/vehicle_parts.lua'

client_scripts {
    'client/main.lua',
    'client/evidence.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'shared/database.lua',
    'server/logger.lua',
    'server/utils.lua',
    'server/repair_calculator.lua',
    'server/fraud_engine.lua',
    'server/risk_engine.lua',
    'server/confidence_engine.lua',
    'server/policy_engine.lua',
    'server/evidence.lua',
    'server/witness.lua',
    'server/mechanic.lua',
    'server/ai.lua',
    'server/investigation.lua',
    'server/report.lua',
    'server/insurance_companies.lua',
    'server/claim_history.lua',
    'server/repair_orders.lua',
    'server/adjuster_memory.lua',
    'server/claim_reconstruction.lua',
    'server/player_portal.lua',
    'server/photo_evidence.lua',
    'server/dashcam.lua',
    'server/gps_tracking.lua',
    'server/mobile_api.lua',
    'server/towing.lua',
    'server/rental_cars.lua',
    'server/medical_billing.lua',
    'server/admin_tools.lua',
    'server/main.lua'
}

-- This resource assumes oxmysql is started before it.
-- Add 'ai_insurance_adjuster' to your server.cfg ensure list after oxmysql and your core framework.
