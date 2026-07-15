# AI Insurance Adjuster

A modular FiveM insurance investigation resource for handling crash claims from initial damage detection through investigation, verdict generation, claim letters, repair-order creation, and optional player-facing portal data. The resource is designed to be dropped into a large RP codebase with lightweight integration points rather than as a tightly coupled standalone experience.

## Features

### Core Flow
- Damage detection on the client and claim submission through a simple command flow
- Server-side evidence validation and claim record creation
- Multi-stage investigation with mechanic, witness, police, EMS, and AI analysis stages
- Structured verdicts with confidence, fraud risk, repair estimate, and follow-up questions
- Claim letters, repair-order creation, history tracking, and basic player portal/dashboard data

### Evidence and Risk Handling
- Vehicle information, health, and accident context are collected and stored
- Driver profiles and risk/fraud scoring are maintained for future investigations
- Policy-tier validation and payout calculations are supported through the shared engines
- Optional photo evidence attachment is supported through the evidence subsystem

### Extensibility
- AI provider chain is configurable from config.lua
- Framework hooks are isolated and documented for ESX, QBCore, QBox, and generic setups
- The resource is structured as a set of focused server/client modules rather than a single monolith

## How it works

1. Client detects a meaningful drop in vehicle engine health (a crash)
2. Comprehensive evidence is collected (vehicle health, accident details, occupant info)
3. Player runs `/fileclaim` to submit the claim
4. Multi-stage investigation begins:
   - Evidence validation and collection
   - Mechanic inspection identifies damaged components. The repair calculator determines costs, and the AI reviews the completed assessment during the investigation.
   - Witness detection and summary generation
   - Police/EMS report attachment (if available)
   - AI analysis of all evidence
5. If evidence is insufficient, AI asks follow-up questions
6. Final decision with structured JSON output:
   - Decision (approved/denied/investigate)
   - Confidence score (0-100)
   - Fraud risk assessment (low/medium/high)
   - Repair estimate (parts, labor, total)
   - Approved amount and deductible
   - Professional reasoning and notes
7. Professional claim letter is generated and sent to player
8. Payout processed if approved

## Setup

1. Ensure oxmysql is started before this resource.
2. Add the resource to your server configuration:
   ```cfg
   ensure oxmysql
   ensure ai_insurance_adjuster
   setr ai_adjuster_api_key "your-key-here"
   ```
3. The database schema is created automatically on startup when enabled in config.lua.
4. If you want to use a custom UI instead of chat notifications, configure Config.UI in config.lua.

## Framework Integration

The resource already includes generic fallbacks, but the following hook points should be reviewed for production integration:

- Player identity and name lookups are handled in [server/utils.lua](server/utils.lua)
- Payouts are handled in [server/utils.lua](server/utils.lua)
- Optional police and EMS report attachment is handled in [server/investigation.lua](server/investigation.lua)
- Client notifications can be redirected through Config.UI in [config.lua](config.lua)

See [INTEGRATION.md](INTEGRATION.md) for detailed guidance.

## Configuration

The main settings live in [config.lua](config.lua). Key areas include:

```lua
Config.MinDamageThreshold = 150.0
Config.ClaimCooldown = 300

Config.AI = {
    Provider = 'gemini',
    Model = 'gemini-2.5-flash',
    RetryAttempts = 2,
    CacheEnabled = true,
    LuaFallbackEnabled = true,
    Providers = {
        { Name = 'gemini', Enabled = true, Priority = 1 },
        { Name = 'groq', Enabled = true, Priority = 2 },
        { Name = 'openrouter', Enabled = true, Priority = 3 },
        { Name = 'ollama', Enabled = false, Priority = 4 }
    }
}

Config.Framework = {
    Type = 'none',
    UseOxLib = false,
    UseOxMysql = true
}

Config.UI = {
    NotificationMode = 'chat',
    UseNUI = false,
    Notify = nil
}
```

### AI Persona

The adjuster's personality is configured through Config.AdjusterPersona. The default is Denise Okafor, a professional but unimpressed claims adjuster.

### Provider Resilience

The AI layer tries providers in order, retries automatically, and falls back to a Lua-based verdict when all external providers fail. It also caches repeated prompts, logs request outcomes, and tags each claim with the prompt version used.

## Public API

### Server Exports

The resource exposes a small set of server exports for external integration:

```text
StartInvestigation(playerId, crashData)
Returns: claimId

GetClaim(claimId)
Returns: claim record

ApproveClaim(claimId)
Returns: boolean

CancelClaim(claimId)
Returns: boolean
```

The current implementation is wired through the investigation flow in [server/investigation.lua](server/investigation.lua), and the helper exports are exposed from [server/utils.lua](server/utils.lua), [server/photo_evidence.lua](server/photo_evidence.lua), [server/player_portal.lua](server/player_portal.lua), and [server/logger.lua](server/logger.lua).

### Events

```text
insurance:submitClaim
insurance:claimUpdated
insurance:investigationFinished
```

The actual runtime event names used by the resource are the prefixed variants below:

- `ai_insurance_adjuster:submitClaim`
- `ai_insurance_adjuster:requestPortalData`
- `ai_insurance_adjuster:requestDashboard`
- `ai_insurance_adjuster:submitPhotoEvidence`
- `ai_insurance_adjuster:requestClaimLetter`
- `ai_insurance_adjuster:submitFollowUpAnswers`

### Client Events

- `ai_insurance_adjuster:verdict`
- `ai_insurance_adjuster:notify`
- `ai_insurance_adjuster:followUpQuestions`
- `ai_insurance_adjuster:claimLetter`
- `ai_insurance_adjuster:dashboardData`
- `ai_insurance_adjuster:portalData`

### Callbacks

The resource uses the standard FiveM NUI callback style for dashboard UI close handling:
- `closeDashboard`

### Exports

The resource exposes a small set of server exports for external integration:

- `GetCitizenId` from [server/utils.lua](server/utils.lua)
- `PayoutPlayer` from [server/utils.lua](server/utils.lua)
- `GetCharacterName` from [server/utils.lua](server/utils.lua)
- `SavePhotoEvidence` / `GetPhotoEvidence` from [server/photo_evidence.lua](server/photo_evidence.lua)
- `BuildDashboardData` from [server/player_portal.lua](server/player_portal.lua)
- `BuildPortalData` from [server/commercial_features.lua](server/commercial_features.lua)
- `Logger` from [server/logger.lua](server/logger.lua)

### Events

Server events:
- `ai_insurance_adjuster:submitClaim`
- `ai_insurance_adjuster:requestPortalData`
- `ai_insurance_adjuster:requestDashboard`
- `ai_insurance_adjuster:submitPhotoEvidence`
- `ai_insurance_adjuster:requestClaimLetter`
- `ai_insurance_adjuster:submitFollowUpAnswers`

Client events:
- `ai_insurance_adjuster:verdict`
- `ai_insurance_adjuster:notify`
- `ai_insurance_adjuster:followUpQuestions`
- `ai_insurance_adjuster:claimLetter`
- `ai_insurance_adjuster:dashboardData`
- `ai_insurance_adjuster:portalData`

### Callbacks

The resource uses the standard FiveM NUI callback style for dashboard UI close handling:
- `closeDashboard`

## Compatibility Matrix

| Area | Status | Notes |
| --- | --- | --- |
| FiveM / GTA V | Supported | Designed for standard FiveM resources |
| oxmysql | Supported | Recommended and assumed in the default setup |
| ESX | Partial | Generic fallback exists; framework-specific hooks should be verified |
| QBCore | Partial | Generic fallback exists; framework-specific hooks should be verified |
| QBox | Partial | Generic fallback exists; framework-specific hooks should be verified |
| Custom framework | Supported | The core modules are framework-agnostic and can be adapted |
| Chat notifications | Supported | Default path |
| NUI notifications | Supported | Configurable through Config.UI |

## API Output Format

The insurance AI returns structured JSON:

```json
{
  "decision": "approved|denied|investigate",
  "confidence": 85,
  "fraudRisk": "low|medium|high",
  "riskScore": 25,
  "repairEstimate": {
    "parts": 4200,
    "labor": 1800,
    "total": 6000
  },
  "approvedAmount": 5200,
  "deductible": 800,
  "flags": ["speeding", "prior_claims"],
  "reasoning": "In-character explanation",
  "nextAction": "null or next step",
  "adjusterNotes": "Professional notes",
  "mechanicSummary": "Mechanic findings",
  "investigationSummary": "Evidence reviewed",
  "followUpQuestions": ["question1", "question2"] or null
}
```

## Cost Considerations

Each claim involves multiple AI calls:
- Mechanic inspection (1 call)
- Witness summaries (1 call, optional)
- Insurance decision (1 call)
- Follow-up questions (additional calls if needed)

Estimated cost per claim: $0.01 - $0.05 depending on complexity.

## Architecture

```text
shared/
├── database.lua      # Database schema initialization
└── utils.lua         # Shared utility functions

client/
├── main.lua          # Main client logic and claim flow
└── evidence.lua      # Evidence collection helpers

server/
├── main.lua          # Main server entrypoints
├── utils.lua         # Shared server adapters
├── evidence.lua      # Evidence collection and validation
├── witness.lua       # Witness detection system
├── mechanic.lua      # Mechanic inspection flow
├── ai.lua            # Insurance decision AI
├── investigation.lua # Multi-stage investigation workflow
├── report.lua        # Claim letter generation
└── logger.lua        # Centralized logging helper
```

## Documentation

- `INTEGRATION.md` - Detailed integration guide for framework hooks
- `README.md` - This file, system overview
- Code comments throughout - Look for `-- HOOK` markers

## Troubleshooting

1. **API Key Missing** - Ensure `setr ai_adjuster_api_key` is in server.cfg
2. **Database Errors** - Ensure oxmysql is started before this resource
3. **Framework Integration** - All HOOK comments must be replaced
4. **Witness Detection** - Check `Config.Investigation.WitnessSearchRadius`
5. **Mechanic Inspection** - Falls back to rule-based if AI fails

## Design Philosophy

This system is designed to feel like a real insurance company investigating accidents:
- AI makes conclusions based only on evidence provided
- No hallucination of details
- Follow-up questions when evidence is insufficient
- Professional, bureaucratic tone
- Multi-stage investigation process
- Risk-based decision making

## Optional Integrations

The following modules are included as optional integrations. These are primarily interfaces and data structures that require additional framework-specific connections to be fully functional:

### Towing Service Integration (`server/towing.lua`)
- Towing company management and cost calculation
- Tow request tracking and status updates
- Requires integration with tow truck job system
- Status: Interface ready, requires job system integration

### GPS Tracking (`server/gps_tracking.lua`)
- Real-time vehicle location recording
- Accident reconstruction from GPS data
- Speed and driving pattern analysis
- Requires client-side GPS data collection
- Status: Data structures ready, requires client integration

### Mobile API (`server/mobile_api.lua`)
- Token-based authentication for external apps
- Claim status and timeline endpoints
- User profile data for mobile consumption
- Requires external mobile app development
- Status: API endpoints ready, requires mobile app

### Medical Billing (`server/medical_billing.lua`)
- Medical procedure code database
- Coverage calculation and bill submission
- Provider type management
- Requires integration with EMS/medical systems
- Status: Billing logic ready, requires medical system integration

### Rental Car Coordination (`server/rental_cars.lua`)
- Rental company management and booking
- Coverage verification for rental reimbursement
- Cost calculation based on vehicle type and duration
- Requires integration with rental job system
- Status: Booking logic ready, requires rental system integration

These modules are not required for core insurance claim processing and can be enabled selectively based on your server's needs and existing systems.
