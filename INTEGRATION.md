# AI Insurance Adjuster - Integration Guide

## Overview

The AI Insurance Adjuster system has been transformed from a simple payout script into a comprehensive insurance investigation platform. The system now uses a multi-stage investigation workflow with evidence collection, mechanic inspection, witness detection, and AI analysis before making claim decisions.

## New Architecture

### Directory Structure

```
ai_insurance_adjuster/
├── fxmanifest.lua
├── config.lua
├── README.md
├── INTEGRATION.md
├── shared/
│   ├── database.lua      # Database schema initialization
│   └── utils.lua         # Shared utility functions
├── client/
│   ├── main.lua          # Main client logic
│   └── evidence.lua      # Evidence collection
└── server/
    ├── main.lua          # Main server logic
    ├── utils.lua         # Server utilities
    ├── evidence.lua      # Evidence collection & validation
    ├── witness.lua       # Witness detection system
    ├── mechanic.lua      # Mechanic inspection AI
    ├── ai.lua            # Insurance decision AI
    ├── investigation.lua # Multi-stage investigation workflow
    └── report.lua        # Claim letter generation
```

### Investigation Stages

1. **Evidence Collection** - Comprehensive data collection from client and server validation
2. **Mechanic Inspection** - AI mechanic analyzes damage and estimates repair costs
3. **Witness Review** - Detect nearby players and generate witness summaries
4. **Police Review** - Attach police reports (framework integration required)
5. **EMS Review** - Attach EMS reports (framework integration required)
6. **AI Analysis** - Insurance AI reviews all evidence and makes decision
7. **Follow-up Questions** - Request additional information if needed
8. **Decision** - Final claim decision with professional report

## Framework Integration

### Required Hooks

You must integrate the following functions in `server/utils.lua`:

#### 1. Player Identifier

```lua
local function getCitizenId(src)
    -- QBCore Example:
    local Player = QBCore.Functions.GetPlayer(src)
    return Player.PlayerData.citizenid
    
    -- ESX Example:
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer.identifier
end
```

#### 2. Money Payout

```lua
local function payoutPlayer(src, amount)
    -- QBCore Example:
    local Player = QBCore.Functions.GetPlayer(src)
    Player.Functions.AddMoney('bank', amount, 'insurance-claim')
    
    -- ESX Example:
    local xPlayer = ESX.GetPlayerFromId(src)
    xPlayer.addAccountMoney('bank', amount, 'Insurance Claim Payout')
end
```

#### 3. Character Name

```lua
local function getCharacterName(src)
    -- QBCore Example:
    local Player = QBCore.Functions.GetPlayer(src)
    return Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    -- ESX Example:
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer.getName()
end
```

### Optional Framework Integrations

#### Police Reports

Edit `server/investigation.lua` in the `AttachPoliceReports` function:

```lua
function AttachPoliceReports(claimId, citizenid, cb)
    -- Example for MDT integration:
    MySQL.query('SELECT * FROM police_mdt_citations WHERE suspect_id = ? ORDER BY date DESC LIMIT 5', 
        { citizenid }, function(reports)
        if reports and #reports > 0 then
            for _, report in ipairs(reports) do
                MySQL.insert([[
                    INSERT INTO insurance_police_reports 
                    (claim_id, report_number, officer_name, citation_type, description, fine_amount, report_date)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ]], { claimId, report.id, report.officer_name, report.charge, report.description, report.fine, report.date })
            end
        end
        cb(reports or {})
    end)
end
```

#### EMS Reports

Edit `server/investigation.lua` in the `AttachEMSReports` function:

```lua
function AttachEMSReports(claimId, citizenid, cb)
    -- Example for EMS system integration:
    MySQL.query('SELECT * FROM ems_medical_records WHERE patient_id = ? ORDER BY date DESC LIMIT 5', 
        { citizenid }, function(reports)
        if reports and #reports > 0 then
            for _, report in ipairs(reports) do
                MySQL.insert([[
                    INSERT INTO insurance_ems_reports 
                    (claim_id, paramedic_name, injury_severity, injuries, treatment, unconscious, passengers, transported, hospital_name, report_date)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ]], { claimId, report.paramedic, report.severity, json.encode(report.injuries), report.treatment, 
                     report.unconscious and 1 or 0, report.passengers, report.transported and 1 or 0, report.hospital, report.date })
            end
        end
        cb(reports or {})
    end)
end
```

#### Vehicle Ownership Verification

Edit `server/evidence.lua` in the `ValidateCrashData` function:

```lua
function ValidateCrashData(crashData, src)
    -- ... existing validation ...
    
    -- Add vehicle ownership verification
    local citizenid = getCitizenId(src)
    
    -- QBCore Example:
    local Player = QBCore.Functions.GetPlayer(src)
    local vehicle = Player.PlayerData.vehicles[crashData.plate]
    if not vehicle then
        return false, 'Vehicle ownership verification failed'
    end
    
    -- ESX Example:
    -- Check your vehicle ownership system
    
    return true, nil
end
```

## Database Schema

### New Tables

The system creates the following new tables automatically:

- `insurance_vehicles` - Vehicle information and policy tiers
- `insurance_vehicle_repairs` - Vehicle repair history
- `insurance_driver_profiles` - Driver risk profiles
- `insurance_policy_tiers` - Policy tier configurations
- `insurance_claims_enhanced` - Enhanced claims with investigation data
- `insurance_witnesses` - Witness statements
- `insurance_police_reports` - Police report attachments
- `insurance_ems_reports` - EMS report attachments
- `insurance_mechanic_reports` - Mechanic inspection reports

### Legacy Tables (Maintained for Backward Compatibility)

- `insurance_claims` - Original claims table
- `insurance_fraud_scores` - Original fraud scores table

## Configuration

### New Config Options

```lua
Config.Investigation = {
    WitnessSearchRadius = 100.0,      -- Meters
    MaxFollowUpRounds = 2,            -- Max question rounds before auto-deny
    UseAIForWitnessSummaries = true,  -- Use AI for witness summaries
    UseAIForMechanicInspection = true, -- Use AI for mechanic inspection
    DefaultPolicyTier = 'standard'     -- Default policy for new vehicles
}

Config.RiskProfile = {
    FastDrivingThreshold = 75,        -- MPH threshold
    NightStartHour = 20,              -- 24-hour format
    NightEndHour = 6,
    RiskWeights = {
        ClaimFrequency = 10,
        DeniedClaims = 15,
        PoliceEncounters = 5,
        DUI = 25,
        FraudSuspicion = 20,
        AggressiveDriving = 10,
        Speeding = 0.5,
        SafeDrivingBonus = -1
    }
}

Config.Company = {
    Name = 'Blaine County Mutual Insurance',
    Address = '120 Route 68, Sandy Shores, Blaine County 92505',
    Phone = '(555) 123-4567',
    Website = 'www.blainecountymutual.ins'
}
```

## API Changes

### Client Events

#### New Events

- `ai_insurance_adjuster:followUpQuestions` - AI requests additional information
- `ai_insurance_adjuster:claimLetter` - Professional claim letter received

#### Modified Events

- `ai_insurance_adjuster:verdict` - Now includes structured JSON with:
  - `decision` (approved/denied/investigate)
  - `confidence` (0-100)
  - `fraudRisk` (low/medium/high)
  - `riskScore` (0-100)
  - `repairEstimate` (parts, labor, total)
  - `approvedAmount` (final payout)
  - `deductible` (policy deductible)
  - `flags` (array of warning flags)
  - `reasoning` (AI explanation)
  - `adjusterNotes` (professional notes)
  - `mechanicSummary` (mechanic findings)
  - `investigationSummary` (evidence reviewed)

### Server Events

#### New Events

- `ai_insurance_adjuster:submitFollowUpAnswers` - Submit answers to AI questions
- `ai_insurance_adjuster:requestClaimLetter` - Request claim letter for a claim

### Client Commands

#### New Commands

- `/answerclaim <claim_id> <answer1|answer2|...>` - Answer follow-up questions

## Backward Compatibility

### Maintained Compatibility

1. **Original API** - The original `ai_insurance_adjuster:submitClaim` event still works
2. **Original Tables** - Legacy database tables are maintained and updated
3. **Original Config** - Original config options remain functional
4. **Original Events** - Original client events are maintained

### Migration Path

For existing installations:

1. **Backup your database** - Before updating
2. **Update the resource** - Replace files with new version
3. **Restart the resource** - New tables will be created automatically
4. **Test with existing claims** - Legacy claims remain accessible
5. **Integrate framework hooks** - Update the HOOK comments in code
6. **Configure new options** - Adjust config.lua as needed

### Data Migration

The system automatically:
- Creates new tables on first start
- Maintains legacy tables for existing data
- Writes to both legacy and enhanced tables during claims
- Preserves existing fraud scores and claim history

## Policy Tiers

The system supports four policy tiers:

### Basic
- Max payout: $5,000
- Deductible: $1,000
- No luxury coverage
- No roadside assistance
- Approval priority: 10 (lowest)

### Standard (Default)
- Max payout: $15,000
- Deductible: $500
- Roadside assistance included
- Approval priority: 5

### Premium
- Max payout: $35,000
- Deductible: $250
- Luxury coverage
- Rental reimbursement
- Medical coverage
- Approval priority: 3

### Elite
- Max payout: $100,000
- Deductible: $100
- Full replacement value
- Priority investigation
- All premium features
- Approval priority: 1 (highest)

## Risk Profile System

The system tracks driver behavior to calculate risk scores:

### Tracked Metrics

- Average driving speed
- Night driving frequency
- Rain driving frequency
- Police encounters
- DUI history
- Fraud suspicion
- Aggressive driving incidents
- Safe driving streak
- Claim frequency
- Claim approval/denial ratio

### Risk Score Impact

- **Low risk (0-30)**: Faster approvals, lower scrutiny
- **Medium risk (31-60)**: Standard investigation
- **High risk (61-100)**: Detailed investigation, more follow-up questions

## UI Integration Recommendations

### Phone App Integration

Replace chat notifications with phone app UI:

```lua
-- Example for phone integration
TriggerClientEvent('phone:receiveNotification', src, {
    title = 'Blaine County Mutual',
    message = verdict.reasoning,
    type = verdict.decision,
    data = verdict
})
```

### Input Dialog Integration

Replace the placeholder statement input:

```lua
-- Example using ox_lib
local input = lib.inputDialog('Insurance Claim', {
    { type = 'textarea', label = 'Describe what happened', required = true }
})

if input then
    expandedData.playerStatement = input[1]
end
```

### Claim Letter Display

Replace chat display with proper UI:

```lua
-- Example for NUI display
SendNUIMessage({
    type = 'showClaimLetter',
    letter = letterData.formatted
})
```

## Troubleshooting

### Common Issues

1. **API Key Missing**
   - Ensure `setr ai_adjuster_api_key "sk-ant-..."` is in server.cfg
   - Check convar name matches `Config.APIKeyConvar`

2. **Database Errors**
   - Ensure oxmysql is started before this resource
   - Check MySQL credentials are correct

3. **Framework Integration**
   - All HOOK comments must be replaced with framework-specific code
   - Test identifier and money functions

4. **Witness Detection Not Working**
   - Ensure player ped detection is working
   - Check `Config.Investigation.WitnessSearchRadius`

5. **Mechanic Inspection Failing**
   - Check API key is valid
   - System falls back to rule-based if AI fails

## Performance Considerations

### API Costs

Each claim now involves multiple AI calls:
- Mechanic inspection (1 call)
- Witness summaries (1 call, optional)
- Insurance decision (1 call)
- Follow-up questions (additional calls if needed)

Estimated cost per claim: $0.01 - $0.05 depending on complexity

### Database Performance

- Indexes are created on frequently queried columns
- JSON data is stored for complex structures
- Consider regular cleanup of old claims

### Server Load

- Investigation is asynchronous and non-blocking
- Cooldown prevents claim spam
- Witness detection is lightweight

## Security Considerations

### Server-Side Validation

- All client data is validated server-side
- Vehicle ownership verification (requires integration)
- Damage thresholds enforced
- Cooldowns prevent abuse

### API Security

- API key stored in server convar (not in code)
- No client-side API calls
- Rate limiting via cooldowns

## Support

For issues or questions:
1. Check this integration guide
2. Review HOOK comments in code
3. Check server console for error messages
4. Verify database tables were created
5. Test framework integrations individually

## Optional Integration Modules

The following modules are included as optional integrations. These are primarily interfaces and data structures that require additional framework-specific connections to be fully functional. They are not required for core insurance claim processing.

### Towing Service Integration (`server/towing.lua`)

**Purpose:** Towing company management and cost calculation for insurance claims.

**Features:**
- Multiple towing company profiles with different rates
- Distance-based cost calculation
- Tow request tracking and status updates
- Towing history per citizen

**Integration Requirements:**
- Connect `UpdateTowingStatus` to your tow truck job system
- Add admin permission checks in the `updateTowingStatus` event handler
- Integrate with vehicle spawn/despawn systems for towed vehicles

**Exports:**
- `RequestTowing(claimId, citizenid, vehiclePlate, pickupLocation, dropoffLocation, companyId)`
- `GetTowingStatus(requestId, callback)`
- `UpdateTowingStatus(requestId, status, driverName, actualCost)`
- `GetTowingCompanies()`
- `GetTowingHistory(citizenid, limit, callback)`

---

### GPS Tracking (`server/gps_tracking.lua`)

**Purpose:** Real-time vehicle location recording and accident reconstruction.

**Features:**
- GPS point recording with speed and heading
- Accident reconstruction from GPS data
- Speed and driving pattern analysis
- Sudden stop and rapid acceleration detection

**Integration Requirements:**
- Implement client-side GPS data collection using `RecordGPSPoint` export
- Call `StartGPSTracking` when a crash is detected
- Call `StopGPSTracking` when investigation is complete
- Integrate with vehicle telemetry systems if available

**Exports:**
- `StartGPSTracking(claimId, citizenid, vehiclePlate, trackingType)`
- `RecordGPSPoint(trackingId, latitude, longitude, altitude, speed, heading)`
- `StopGPSTracking(trackingId)`
- `GetGPSTrackingData(claimId, callback)`
- `AnalyzeGPSData(claimId, callback)`

---

### Mobile API (`server/mobile_api.lua`)

**Purpose:** Token-based authentication and data endpoints for external mobile applications.

**Features:**
- Secure token generation and validation
- Claim status and timeline endpoints
- User profile data for mobile consumption
- Device management and token revocation

**Integration Requirements:**
- Develop external mobile app to consume these endpoints
- Implement token refresh logic on client side
- Add rate limiting for API calls
- Consider HTTPS for production deployments

**Exports:**
- `GenerateMobileToken(citizenid, deviceId, deviceType, expiresInDays)`
- `ValidateMobileToken(token)`
- `RevokeMobileToken(token)`
- `GetMobileClaimStatus(citizenid, claimId, callback)`
- `GetMobileClaimTimeline(claimId, callback)`
- `GetMobileUserProfile(citizenid, callback)`

---

### Medical Billing (`server/medical_billing.lua`)

**Purpose:** Medical expense tracking, coverage verification, and payment processing.

**Features:**
- Medical procedure code database (CPT-like codes)
- Coverage calculation based on policy tier
- Provider type management
- Bill submission and status tracking

**Integration Requirements:**
- Connect to your EMS/medical system for automatic bill submission
- Integrate with hospital systems for procedure data
- Add payment processing integration with your banking system
- Configure procedure codes to match your server's medical system

**Exports:**
- `SubmitMedicalBill(claimId, citizenid, providerName, providerType, treatmentDate, serviceType, diagnosis, procedureCodesList, billedAmount)`
- `GetMedicalBillStatus(billId, callback)`
- `ProcessMedicalBill(billId, status, invoiceNumber)`
- `GetClaimMedicalBills(claimId, callback)`
- `GetMedicalBillingHistory(citizenid, limit, callback)`
- `GetProcedureCodes()`
- `GetProviderTypes()`

---

### Rental Car Coordination (`server/rental_cars.lua`)

**Purpose:** Rental car booking, coverage verification, and cost management.

**Features:**
- Multiple rental company profiles
- Coverage verification based on policy tier
- Cost calculation based on vehicle type and duration
- Rental request tracking and status updates

**Integration Requirements:**
- Connect to your rental car job system
- Add vehicle spawn logic for rental vehicles
- Integrate with your economy system for payments
- Add admin permission checks for status updates

**Exports:**
- `RequestRentalCar(claimId, citizenid, pickupDate, returnDate, vehicleType, coverageType, companyId)`
- `GetRentalStatus(requestId, callback)`
- `UpdateRentalStatus(requestId, status, confirmationNumber)`
- `GetRentalCompanies()`
- `GetCoverageTypes()`
- `GetRentalHistory(citizenid, limit, callback)`
- `CheckRentalCoverage(policyTier, callback)`

---

### Enabling Optional Modules

To enable these modules:

1. **Database Tables:** Each module creates its own database tables automatically on first startup
2. **Configuration:** No additional configuration is required in `config.lua`
3. **Event Registration:** All modules register their own events automatically
4. **Framework Hooks:** Review each module for `-- HOOK` comments and add framework-specific code

### Disabling Optional Modules

If you don't need a module, you can prevent it from loading by:

1. Removing the module file from the `server/` directory
2. Or commenting out the module's event registrations in `server/main.lua`
