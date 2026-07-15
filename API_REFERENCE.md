# API Reference

Quick reference for integrating with the AI Insurance Adjuster system.

## Server Exports

### Core Investigation

```lua
-- Start a new insurance investigation
-- Returns: success (boolean), result (table|nil), error (string|nil)
exports['ai_insurance_adjuster']:StartInvestigation(crashData, src, callback)
```

**Parameters:**
- `crashData` (table): Accident data including vehicle, driver, and accident details
- `src` (number): Player server ID
- `callback` (function): Callback function(success, result, error)

**Example:**
```lua
exports['ai_insurance_adjuster']:StartInvestigation(crashData, source, function(success, result, err)
    if success then
        print('Claim started:', result.claim_number)
    else
        print('Error:', err)
    end
end)
```

---

### Framework Utilities

```lua
-- Get player citizenid (framework-agnostic)
-- Returns: citizenid (string)
exports['ai_insurance_adjuster']:GetCitizenId(src)

-- Pay out money to player
-- Returns: success (boolean)
exports['ai_insurance_adjuster']:PayoutPlayer(src, amount)

-- Get character name (framework-agnostic)
-- Returns: name (string)
exports['ai_insurance_adjuster']:GetCharacterName(src)
```

---

### Repair Cost Calculator

```lua
-- Calculate repair cost for a single part
-- Returns:
{
    part = string,
    action = "repair" | "replace",
    severity = "minor" | "moderate" | "major" | "critical",
    parts_cost = number,
    labor_cost = number,
    labor_hours = number,
    total_cost = number,
    category = string
}
exports['ai_insurance_adjuster']:CalculatePartRepairCost(partName, severity, action)

-- Calculate total repair estimate from mechanic assessment
-- Returns:
{
    itemized_costs = array,
    parts_cost = number,
    labor_cost = number,
    labor_hours = number,
    shop_fee = number,
    environmental_fee = number,
    tax = number,
    subtotal = number,
    total_cost = number,
    damaged_parts_count = number,
    economic_modifier = number
}
exports['ai_insurance_adjuster']:CalculateRepairEstimate(mechanicAssessment, vehicleData)

-- Calculate vehicle value for total loss determination
-- Returns: number (vehicle value)
exports['ai_insurance_adjuster']:CalculateVehicleValue(vehicleModel, vehicleClass, mileage, condition)

-- Determine if vehicle is total loss
-- Returns: boolean (isTotalLoss), number (threshold)
exports['ai_insurance_adjuster']:IsTotalLoss(repairCost, vehicleValue)

-- Calculate deductible based on policy
-- Returns: number (deductible amount)
exports['ai_insurance_adjuster']:CalculateDeductible(policyTier, accidentType, driverAtFault)

-- Calculate maximum payout based on policy
-- Returns: number (max payout)
exports['ai_insurance_adjuster']:CalculateMaximumPayout(policyTier, vehicleClass, isLuxury)

-- Validate coverage for a claim
-- Returns:
{
    is_covered = boolean,
    max_payout = number,
    is_total_loss = boolean,
    total_loss_threshold = number,
    luxury_excluded = boolean,
    exceeds_max_payout = boolean,
    covered_amount = number,
    rejection_reason = string | nil
}
exports['ai_insurance_adjuster']:ValidateCoverage(policyTier, vehicleClass, repairCost, vehicleValue)

-- Calculate approved amount after deductible and limits
-- Returns: number (approved amount)
exports['ai_insurance_adjuster']:CalculateApprovedAmount(repairCost, deductible, maxPayout, coverageValidation)

-- Generate repair summary for AI
-- Returns: string (summary)
exports['ai_insurance_adjuster']:GenerateRepairSummary(repairEstimate, coverageValidation)
```

---

### Fraud Detection Engine

```lua
-- Calculate fraud score for a claim
-- Returns:
{
    score = number (0-100),
    level = "none" | "low" | "medium" | "high" | "critical",
    indicators = array of strings,
    factors = table
}
exports['ai_insurance_adjuster']:CalculateFraudScore(citizenid, claimData, driverProfile, recentClaims)

-- Determine fraud level from score
-- Returns: string ("none" | "low" | "medium" | "high" | "critical")
exports['ai_insurance_adjuster']:DetermineFraudLevel(score)

-- Update fraud score in database
-- Returns: void
exports['ai_insurance_adjuster']:UpdateFraudScoreDB(citizenid, fraudScore)

-- Get fraud score history for analysis
-- Returns: array of fraud score records
exports['ai_insurance_adjuster']:GetFraudScoreHistory(citizenid, days, callback)
```

---

### Driver Risk Assessment Engine

```lua
-- Calculate driver risk score
-- Returns:
{
    score = number (0-100),
    category = "very_safe" | "safe" | "average" | "high_risk" | "dangerous",
    factors = table,
    metrics = table
}
exports['ai_insurance_adjuster']:CalculateDriverRiskScore(driverProfile, drivingHistory, recentClaims)

-- Determine risk category from score
-- Returns: string ("very_safe" | "safe" | "average" | "high_risk" | "dangerous")
exports['ai_insurance_adjuster']:DetermineRiskCategory(score)

-- Update driver risk profile in database
-- Returns: void
exports['ai_insurance_adjuster']:UpdateDriverRiskProfile(citizenid, riskAssessment)

-- Get risk score history
-- Returns: array of risk score records
exports['ai_insurance_adjuster']:GetRiskScoreHistory(citizenid, days, callback)
```

---

### Confidence Calculation Engine

```lua
-- Calculate investigation confidence based on evidence completeness
-- Returns:
{
    score = number (0-100),
    level = "very_low" | "low" | "medium" | "high",
    evidence_quality = table,
    missing_evidence = array of strings
}
exports['ai_insurance_adjuster']:CalculateInvestigationConfidence(evidence)

-- Determine confidence level from score
-- Returns: string ("very_low" | "low" | "medium" | "high")
exports['ai_insurance_adjuster']:DetermineConfidenceLevel(score)

-- Check if confidence is sufficient for decision
-- Returns: boolean
exports['ai_insurance_adjuster']:IsConfidenceSufficient(confidenceScore, decisionType)

-- Generate confidence summary for AI
-- Returns: string (summary)
exports['ai_insurance_adjuster']:GenerateConfidenceSummary(confidenceAssessment)
```

---

### Policy Validation Engine

```lua
-- Validate policy for a claim
-- Returns:
{
    is_valid = boolean,
    coverage_details = table,
    restrictions = array of strings,
    benefits = array of strings,
    tier = string
}
exports['ai_insurance_adjuster']:ValidatePolicy(policyTier, vehicleClass, claimData)

-- Calculate coverage limits
-- Returns:
{
    max_payout = number,
    deductible = number,
    covered_amount = number,
    exceeds_limit = boolean
}
exports['ai_insurance_adjuster']:CalculateCoverageLimits(policyTier, vehicleClass, repairCost)

-- Calculate claim eligibility
-- Returns:
{
    eligible = boolean,
    reasons = array of strings,
    warnings = array of strings
}
exports['ai_insurance_adjuster']:CalculateClaimEligibility(policyValidation, coverageLimits, driverProfile)

-- Calculate premium adjustment based on risk
-- Returns: number (adjusted premium)
exports['ai_insurance_adjuster']:CalculatePremiumAdjustment(basePremium, riskScore, claimHistory)

-- Generate policy summary for AI
-- Returns: string (summary)
exports['ai_insurance_adjuster']:GeneratePolicySummary(policyValidation, coverageLimits)

-- Get policy information for a tier
-- Returns: policy table
exports['ai_insurance_adjuster']:GetPolicyInfo(tierName)

-- Get all available policies
-- Returns: table of all policies
exports['ai_insurance_adjuster']:GetAllPolicies()

-- Check if policy tier exists
-- Returns: boolean
exports['ai_insurance_adjuster']:PolicyExists(tierName)
```

---

### Client Evidence Collection

```lua
-- Collect vehicle information (client-side)
-- Returns: vehicle info table
exports['ai_insurance_adjuster']:CollectVehicleInfo()

-- Collect accident information (client-side)
-- Returns: accident info table
exports['ai_insurance_adjuster']:CollectAccidentInfo()
```

---

### Additional Features

```lua
-- Save photo evidence for a claim
-- Returns: success (boolean)
exports['ai_insurance_adjuster']:SavePhotoEvidence(claimId, citizenid, photoUrl, caption)

-- Get photo evidence for a claim
-- Returns: photo evidence array
exports['ai_insurance_adjuster']:GetPhotoEvidence(claimId, callback)

-- List all photo evidence
-- Returns: photo evidence array
exports['ai_insurance_adjuster']:ListPhotoEvidence(citizenid, callback)

-- Build dashboard data for player portal
-- Returns: dashboard data table
exports['ai_insurance_adjuster']:BuildDashboardData(citizenid, callback)

-- Build portal data for claim history
-- Returns: portal data table
exports['ai_insurance_adjuster']:BuildPortalData(citizenid, callback)

-- Generate damage reconstruction visualization
-- Returns: reconstruction data table
exports['ai_insurance_adjuster']:GenerateDamageReconstruction(claimId, callback)

-- Save claim history entry
-- Returns: void
exports['ai_insurance_adjuster']:SaveClaimHistoryEntry(claimId, entryType, details)

-- Get investigation history
-- Returns: history array
exports['ai_insurance_adjuster']:GetInvestigationHistory(citizenid, days, callback)

-- Save adjuster memory for context
-- Returns: void
exports['ai_insurance_adjuster']:SaveAdjusterMemory(citizenid, memoryType, content)

-- Get adjuster memory
-- Returns: memory table
exports['ai_insurance_adjuster']:GetAdjusterMemory(citizenid, callback)
```

---

## Server Events

### Client → Server

```lua
-- Submit a new insurance claim
TriggerServerEvent('ai_insurance_adjuster:submitClaim', crashData)
```

**Parameters:**
- `crashData` (table): Complete accident data including vehicle, driver, and accident details

**Response:** Triggers `ai_insurance_adjuster:verdict` on client when complete

---

```lua
-- Submit answers to follow-up questions from AI
TriggerServerEvent('ai_insurance_adjuster:submitFollowUpAnswers', claimId, answers)
```

**Parameters:**
- `claimId` (number): Claim ID
- `answers` (table): Array of answers to questions

**Response:** Triggers `ai_insurance_adjuster:verdict` or `ai_insurance_adjuster:followUpQuestions` on client

---

```lua
-- Request claim portal data
TriggerServerEvent('ai_insurance_adjuster:requestPortalData')
```

**Response:** Triggers `ai_insurance_adjuster:portalData` on client

---

```lua
-- Request dashboard data
TriggerServerEvent('ai_insurance_adjuster:requestDashboard')
```

**Response:** Triggers `ai_insurance_adjuster:dashboardData` on client

---

```lua
-- Request claim letter/report
TriggerServerEvent('ai_insurance_adjuster:requestClaimLetter', claimId)
```

**Parameters:**
- `claimId` (number): Claim ID

**Response:** Triggers `ai_insurance_adjuster:claimLetter` on client

---

```lua
-- Submit photo evidence for a claim
TriggerServerEvent('ai_insurance_adjuster:submitPhotoEvidence', claimId, photoUrl, caption)
```

**Parameters:**
- `claimId` (number): Claim ID
- `photoUrl` (string): URL to photo
- `caption` (string): Photo description

---

### Server → Client

```lua
-- Claim verdict (approved/denied/investigate)
TriggerClientEvent('ai_insurance_adjuster:verdict', source, verdict)
```

**Verdict Table:**
```lua
{
    decision = "approved|denied|investigate|partial",
    confidence = 0-100,
    fraudRisk = "low|medium|high|critical",
    riskScore = 0-100,
    repairEstimate = { parts, labor, total },
    approvedAmount = number,
    deductible = number,
    flags = { "speeding", "prior_claims", ... },
    reasoning = "string",
    nextAction = "string|null",
    adjusterNotes = "string",
    mechanicSummary = "string",
    investigationSummary = "string",
    followUpQuestions = [ "question1", "question2" ] or null
}
```

---

```lua
-- Follow-up questions from AI
TriggerClientEvent('ai_insurance_adjuster:followUpQuestions', source, questions)
```

**Parameters:**
- `questions` (array): Array of question strings

---

```lua
-- General notification
TriggerClientEvent('ai_insurance_adjuster:notify', source, message)
```

**Parameters:**
- `message` (string): Notification text

---

```lua
-- Claim letter/report data
TriggerClientEvent('ai_insurance_adjuster:claimLetter', source, letterData)
```

**Letter Data Table:**
```lua
{
    claim_number = "string",
    claimant_name = "string",
    vehicle = "string",
    date = "string",
    decision = "string",
    approved_amount = number,
    deductible = number,
    reasoning = "string",
    adjuster_name = "string",
    company_name = "string",
    company_address = "string"
}
```

---

```lua
-- Dashboard data for NUI
TriggerClientEvent('ai_insurance_adjuster:dashboardData', source, dashboardData)
```

**Dashboard Data Table:**
```lua
{
    activeClaims = array,
    recentClaims = array,
    statistics = {
        total_claims = number,
        approved_claims = number,
        denied_claims = number,
        total_payout = number
    }
}
```

---

```lua
-- Portal data for claim history
TriggerClientEvent('ai_insurance_adjuster:portalData', source, portalData)
```

**Portal Data Table:**
```lua
{
    memory = array,
    claims = array,
    fraud_score = number,
    risk_score = number
}
```

---

## Quick Integration Example

```lua
-- Basic claim submission from client
local crashData = {
    vehicle = GetVehicleInfo(),
    accident = GetAccidentInfo(),
    driver = GetDriverInfo()
}

TriggerServerEvent('ai_insurance_adjuster:submitClaim', crashData)

-- Listen for verdict
RegisterNetEvent('ai_insurance_adjuster:verdict', function(verdict)
    if verdict.decision == 'approved' then
        print('Claim approved! Amount: $' .. verdict.approvedAmount)
    elseif verdict.decision == 'denied' then
        print('Claim denied: ' .. verdict.reasoning)
    end
end)
```

```lua
-- Using exports for custom integration
local citizenid = exports['ai_insurance_adjuster']:GetCitizenId(source)
local riskScore = exports['ai_insurance_adjuster']:CalculateDriverRiskScore(driverProfile, history, claims)

if riskScore.score > 70 then
    print('High risk driver detected')
end
```

---

## Event Naming Convention

All events use the `ai_insurance_adjuster:` prefix to avoid conflicts.

- **Client → Server**: Action-oriented (submitClaim, requestPortalData)
- **Server → Client**: Data-oriented (verdict, dashboardData, notify)

---

## Data Structures

### CrashData
```lua
{
    vehicle = {
        model = string,
        plate = string,
        vehicle_class = string,
        vin = string,
        mileage = number,
        value = number
    },
    driver = {
        name = string,
        citizenid = string,
        fraud_score = number,
        driving_history = table
    },
    accident = {
        gps_location = { x, y, z },
        speed_at_impact = number,
        number_of_impacts = number,
        rollovers = boolean,
        airbag_deployed = boolean
    },
    player_statement = string
}
```

---

## Framework Integration Hooks

The system includes framework adapters in `server/utils.lua`:

- **QBCore**: Uses `QBCore.Functions.GetPlayer`
- **ESX**: Uses `ESX.GetPlayerFromId`
- **Standalone**: Uses player identifiers directly

Custom adapters can be added by modifying the framework detection logic.
