Config = {}

-- How much vehicle "health" must drop before we even consider it a claimable crash
-- (prevents someone filing a claim over a scratch)
Config.MinDamageThreshold = 150.0 -- out of 1000 max engine health delta

-- Base payout curve. Real payout = BasePayout * damagePercent * (1 - suspicionPenalty)
Config.BasePayout = 15000

-- Every player has a rolling "fraud score" 0-100 stored in DB.
-- The higher it is, the more skeptical the adjuster's system prompt is told to be.
Config.FraudScoreDecayPerDay = 2 -- score slowly forgives over time if you behave

-- AI provider configuration. Server owners can reorder or disable providers
-- without editing the code by changing the Providers list below.
Config.AI = {
    Provider = 'gemini',
    Model = 'gemini-2.5-flash',
    PromptVersion = 'v1',
    TimeoutMs = 10000,
    RetryAttempts = 2,
    CacheEnabled = true,
    LuaFallbackEnabled = true,
    Providers = {
        {
            Name = 'gemini',
            Enabled = true,
            Priority = 1
        },
        {
            Name = 'groq',
            Enabled = true,
            Priority = 2
        },
        {
            Name = 'openrouter',
            Enabled = true,
            Priority = 3
        },
        {
            Name = 'ollama',
            Enabled = false,
            Priority = 4
        }
    }
}

Config.AIPromptVersion = Config.AI.PromptVersion or 'v1'

-- Legacy compatibility for existing modules
Config.AIModel = Config.AI.Model

-- Set this in server.cfg: setr ai_adjuster_api_key "..."
-- Provider-specific keys can also be set via:
-- setr ai_adjuster_gemini_api_key "..."
-- setr ai_adjuster_groq_api_key "..."
-- setr ai_adjuster_openrouter_api_key "..."
Config.APIKeyConvar = 'ai_adjuster_api_key'

-- Logging configuration
Config.Logging = {
    Enabled = true,
    Level = 'INFO',
    Debug = false
}

-- Framework integration settings
Config.Framework = {
    Type = 'none', -- none, esx, qbcore, qbox
    UseOxLib = false,
    UseOxMysql = true
}

-- UI / notification integration settings
Config.UI = {
    NotificationMode = 'chat', -- chat, nui, custom
    UseNUI = false,
    Notify = nil -- optional function(title, message)
}

-- Database configuration
Config.Database = {
    CreateTablesOnStartup = true,
    UsePrefix = false,
    Prefix = ''
}

-- Cooldown between claims per player (seconds) - stops claim spam
Config.ClaimCooldown = 300

-- The adjuster's personality. Tweak this to change the vibe of every verdict.
Config.AdjusterPersona = [[
You are Denise Okafor, a mid-level claims adjuster at Blaine County Mutual Insurance.
You are polite but unimpressed. You have seen every excuse in the book. You are not a pushover,
but you are not cruel either - you approve legitimate claims without drama and deny fraudulent
ones with dry, bureaucratic precision. You occasionally reference your caseload or your coffee.
You never break character and never mention that you are an AI.
]]

-- Investigation Settings
Config.Investigation = {
    -- Witness detection radius in meters
    WitnessSearchRadius = 100.0,
    
    -- Maximum number of follow-up questions before auto-deny
    MaxFollowUpRounds = 2,
    
    -- Whether to use AI for witness summaries (fallback to simple summaries if false)
    UseAIForWitnessSummaries = true,
    
    -- Whether to use AI for mechanic inspection (fallback to rule-based if false)
    UseAIForMechanicInspection = true,
    
    -- Default policy tier for new vehicles
    DefaultPolicyTier = 'standard'
}

-- Risk Profile Settings
Config.RiskProfile = {
    -- Speed threshold (mph) above which driving is considered "fast"
    FastDrivingThreshold = 75,
    
    -- Night driving hours (24-hour format)
    NightStartHour = 20,
    NightEndHour = 6,
    
    -- How much each factor contributes to risk score
    RiskWeights = {
        ClaimFrequency = 10,      -- Per claim in last 30 days
        DeniedClaims = 15,        -- Per denied claim
        PoliceEncounters = 5,      -- Per police encounter
        DUI = 25,                  -- Per DUI
        FraudSuspicion = 20,       -- Per fraud suspicion point
        AggressiveDriving = 10,    -- Per aggressive driving incident
        Speeding = 0.5,            -- Per mph over threshold
        SafeDrivingBonus = -1      -- Per day of safe driving streak
    }
}

-- Company Information (used in claim letters)
Config.Company = {
    Name = 'Blaine County Mutual Insurance',
    Address = '120 Route 68, Sandy Shores, Blaine County 92505',
    Phone = '(555) 123-4567',
    Website = 'www.blainecountymutual.ins'
}

Config.DefaultInsuranceCompany = 'blaine'
Config.InsuranceCompanies = {
    blaine = {
        id = 'blaine',
        name = 'Blaine County Mutual',
        adjuster_style = 'pragmatic',
        payout_modifier = 1.0,
        deductible_modifier = 1.0
    },
    sanandreas = {
        id = 'sanandreas',
        name = 'San Andreas Assurance',
        adjuster_style = 'cautious',
        payout_modifier = 0.95,
        deductible_modifier = 1.05
    },
    pacific = {
        id = 'pacific',
        name = 'Pacific Shield',
        adjuster_style = 'aggressive',
        payout_modifier = 1.05,
        deductible_modifier = 0.9
    },
    vinewood = {
        id = 'vinewood',
        name = 'Vinewood Elite Insurance',
        adjuster_style = 'premium',
        payout_modifier = 1.1,
        deductible_modifier = 0.8
    }
}
