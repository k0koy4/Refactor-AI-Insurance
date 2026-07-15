--[[
    ai.lua
    Handles communication with configurable AI providers
    (Gemini, Groq, OpenRouter, Ollama, etc.)

    Input: a claim table built by main.lua, containing crash telemetry + player history.
    Output (via callback): a verdict table:
        {
            decision = "approve" | "deny" | "investigate",
            payout = number,
            suspicion_score = number (0-100),
            reasoning = string,   -- in-character explanation, shown to player
            flags = { "speeding", "prior_claims", ... } -- structured tags for your own logic/logs
        }
]]

local aiResponseCache = {}

local function GeneratePromptHash(text)
    local hash = 2166136261
    for i = 1, #text do
        hash = (hash * 16777619) % 4294967296
        hash = hash ~ string.byte(text, i)
    end
    return string.format('%08x', hash)
end

local function GetCacheKey(promptHash, promptVersion)
    return promptHash .. ':' .. tostring(promptVersion)
end

local function LogAIOutcome(options)
    if not MySQL or not MySQL.insert then
        return
    end

    MySQL.insert([[
        INSERT INTO ai_logs
        (claim_id, provider, model, prompt_version, prompt_hash, tokens, response_time_ms, success, error_reason)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        options.claimId or nil,
        options.provider or 'unknown',
        options.model or Config.AIModel or 'unknown',
        options.promptVersion or Config.AIPromptVersion or 'v1',
        options.promptHash or nil,
        options.tokens or nil,
        options.responseTimeMs or 0,
        options.success and 1 or 0,
        options.errorReason or nil
    })
end

local function GetCachedAIResponse(promptHash, promptVersion, cb)
    local cacheKey = GetCacheKey(promptHash, promptVersion)
    if aiResponseCache[cacheKey] then
        cb(aiResponseCache[cacheKey])
        return
    end

    if not MySQL or not MySQL.single then
        cb(nil)
        return
    end

    MySQL.single([[
        SELECT response_text FROM ai_response_cache
        WHERE prompt_hash = ? AND prompt_version = ?
        LIMIT 1
    ]], { promptHash, promptVersion }, function(row)
        if row and row.response_text then
            aiResponseCache[cacheKey] = row.response_text
            cb(row.response_text)
        else
            cb(nil)
        end
    end)
end

local function StoreCachedAIResponse(promptHash, promptVersion, provider, model, responseText)
    if not MySQL or not MySQL.insert then
        return
    end

    aiResponseCache[GetCacheKey(promptHash, promptVersion)] = responseText
    MySQL.insert([[
        INSERT INTO ai_response_cache
        (prompt_hash, prompt_version, provider, model, response_text)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE provider = VALUES(provider), model = VALUES(model), response_text = VALUES(response_text)
    ]], {
        promptHash,
        promptVersion,
        provider,
        model,
        responseText
    })
end

local function getAIProviderSequence()
    local aiConfig = Config.AI or {}
    local providers = {}

    if type(aiConfig.Providers) == 'table' and #aiConfig.Providers > 0 then
        for _, entry in ipairs(aiConfig.Providers) do
            if type(entry) == 'table' and entry.Name and entry.Enabled ~= false then
                table.insert(providers, { Name = entry.Name, Priority = tonumber(entry.Priority) or 999 })
            elseif type(entry) == 'string' and entry ~= '' then
                table.insert(providers, { Name = entry, Priority = 999 })
            end
        end

        table.sort(providers, function(a, b)
            return a.Priority < b.Priority
        end)
    else
        local primary = aiConfig.Provider or 'gemini'
        table.insert(providers, { Name = primary, Priority = 1 })
        for _, fallback in ipairs(aiConfig.Fallbacks or {}) do
            if fallback ~= primary then
                table.insert(providers, { Name = fallback, Priority = 999 })
            end
        end
    end

    if #providers == 0 then
        table.insert(providers, { Name = 'gemini', Priority = 1 })
    end

    return providers
end

local function getAIProviderModel(provider)
    local aiConfig = Config.AI or {}
    if provider == 'groq' then
        return 'llama-3.3-70b-versatile'
    elseif provider == 'openrouter' then
        return 'openai/gpt-4o-mini'
    elseif provider == 'ollama' then
        return aiConfig.Model or Config.AIModel or 'llama3.1'
    end

    return aiConfig.Model or Config.AIModel or 'gemini-2.5-flash'
end

local function getAIProviderApiKey(provider)
    local providerKey = GetConvar(('ai_adjuster_%s_api_key'):format(provider), '')
    if providerKey ~= '' then
        return providerKey
    end

    return GetConvar(Config.APIKeyConvar or 'ai_adjuster_api_key', '')
end

local function buildAIRequest(provider, systemPrompt, userContent, maxTokens)
    local model = getAIProviderModel(provider)
    local prompt = tostring(userContent or '')

    if provider == 'gemini' then
        local body = {
            contents = {
                {
                    parts = {
                        { text = prompt }
                    }
                }
            },
            generationConfig = {
                temperature = 0.2,
                maxOutputTokens = maxTokens or 1500
            }
        }

        if systemPrompt and systemPrompt ~= '' then
            body.system_instruction = {
                parts = {
                    { text = systemPrompt }
                }
            }
        end

        return {
            endpoint = ('https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s'):format(model, getAIProviderApiKey(provider)),
            method = 'POST',
            headers = { ['Content-Type'] = 'application/json' },
            body = json.encode(body)
        }
    elseif provider == 'groq' then
        return {
            endpoint = 'https://api.groq.com/openai/v1/chat/completions',
            method = 'POST',
            headers = {
                ['Content-Type'] = 'application/json',
                ['Authorization'] = 'Bearer ' .. getAIProviderApiKey(provider)
            },
            body = json.encode({
                model = model,
                messages = {
                    { role = 'system', content = systemPrompt or '' },
                    { role = 'user', content = prompt }
                },
                max_tokens = maxTokens or 1500,
                temperature = 0.2
            })
        }
    elseif provider == 'openrouter' then
        return {
            endpoint = 'https://openrouter.ai/api/v1/chat/completions',
            method = 'POST',
            headers = {
                ['Content-Type'] = 'application/json',
                ['Authorization'] = 'Bearer ' .. getAIProviderApiKey(provider),
                ['HTTP-Referer'] = 'https://localhost',
                ['X-Title'] = 'ai_insurance_adjuster'
            },
            body = json.encode({
                model = model,
                messages = {
                    { role = 'system', content = systemPrompt or '' },
                    { role = 'user', content = prompt }
                },
                max_tokens = maxTokens or 1500,
                temperature = 0.2
            })
        }
    elseif provider == 'ollama' then
        return {
            endpoint = 'http://127.0.0.1:11434/api/chat',
            method = 'POST',
            headers = { ['Content-Type'] = 'application/json' },
            body = json.encode({
                model = model,
                messages = {
                    { role = 'system', content = systemPrompt or '' },
                    { role = 'user', content = prompt }
                },
                stream = false
            })
        }
    end
end

local function extractAIText(provider, response)
    local ok, decoded = pcall(json.decode, response)
    if not ok or not decoded then
        return nil
    end

    if provider == 'gemini' then
        if decoded.candidates then
            for _, candidate in ipairs(decoded.candidates) do
                if candidate.content and candidate.content.parts then
                    for _, part in ipairs(candidate.content.parts) do
                        if part.text and part.text ~= '' then
                            return part.text
                        end
                    end
                end
            end
        end
    elseif provider == 'groq' or provider == 'openrouter' then
        if decoded.choices and decoded.choices[1] and decoded.choices[1].message then
            return decoded.choices[1].message.content
        end
    elseif provider == 'ollama' then
        if decoded.message and decoded.message.content then
            return decoded.message.content
        end
    end

    return nil
end

function BuildLuaFallbackVerdict(claimData)
    local riskScore = tonumber(claimData and claimData.risk_assessment and claimData.risk_assessment.score) or 50
    local fraudLevel = claimData and claimData.fraud_assessment and claimData.fraud_assessment.level or 'medium'
    local approvedAmount = tonumber(claimData and claimData.approved_amount) or 0

    local decision = 'investigate'
    if claimData and claimData.policy_validation and claimData.policy_validation.is_valid == false then
        decision = 'denied'
    elseif fraudLevel == 'critical' or riskScore >= 80 then
        decision = 'investigate'
    elseif riskScore <= 35 and fraudLevel ~= 'high' and fraudLevel ~= 'critical' then
        decision = 'approved'
    end

    return {
        decision = decision,
        confidence = math.max(40, math.min(90, tonumber(claimData and claimData.confidence_assessment and claimData.confidence_assessment.score) or 60)),
        fraudRisk = fraudLevel,
        riskScore = riskScore,
        repairEstimate = claimData and claimData.repair_estimate or { parts = 0, labor = 0, total = 0 },
        approvedAmount = approvedAmount,
        deductible = claimData and claimData.coverage_limits and claimData.coverage_limits.deductible or 0,
        flags = { 'lua_fallback', 'provider_retry' },
        reasoning = 'The provider chain was unavailable, so the investigation was completed with a conservative Lua fallback based on the available evidence.',
        nextAction = nil,
        adjusterNotes = 'Fallback mode engaged after provider retries failed.',
        mechanicSummary = 'Mechanic findings were preserved from the available evidence.',
        investigationSummary = 'The claim was reviewed using deterministic internal rules because the external provider chain was unavailable.',
        followUpQuestions = nil
    }
end

function CallAIWithFallbacks(systemPrompt, userContent, maxTokens, cb, options)
    options = options or {}
    local providers = getAIProviderSequence()
    local promptVersion = options.promptVersion or Config.AIPromptVersion or 'v1'
    local promptHash = options.promptHash or GeneratePromptHash(tostring(systemPrompt or '') .. '\n' .. tostring(userContent or ''))
    local claimId = options.claimId
    local maxAttempts = 2
    local startedAt = (GetGameTimer and GetGameTimer()) or (os.time() * 1000)

    local function finish(success, text, err, provider, responseTimeMs)
        if not success then
            LogAIOutcome({
                claimId = claimId,
                provider = provider or 'all',
                promptVersion = promptVersion,
                promptHash = promptHash,
                responseTimeMs = responseTimeMs or 0,
                success = false,
                errorReason = err or 'all_providers_failed'
            })
        end
        cb(success, text, err, provider)
    end

    local function attemptProvider(providerEntry, attemptNumber, providerIndex)
        local providerName = providerEntry.Name
        if attemptNumber > maxAttempts then
            if providerIndex < #providers then
                attemptProvider(providers[providerIndex + 1], 1, providerIndex + 1)
                return
            end

            local fallbackText = options.luaFallbackText or json.encode(BuildLuaFallbackVerdict(options.claimData))
            LogAIOutcome({
                claimId = claimId,
                provider = 'lua_fallback',
                promptVersion = promptVersion,
                promptHash = promptHash,
                responseTimeMs = ((GetGameTimer and GetGameTimer()) or (os.time() * 1000)) - startedAt,
                success = true,
                errorReason = 'all_providers_failed'
            })
            finish(true, fallbackText, 'all_providers_failed', 'lua_fallback')
            return
        end

        local request = buildAIRequest(providerName, systemPrompt, userContent, maxTokens)
        if not request then
            if providerIndex < #providers then
                attemptProvider(providers[providerIndex + 1], 1, providerIndex + 1)
            else
                finish(false, nil, 'unsupported_provider', providerName)
            end
            return
        end

        GetCachedAIResponse(promptHash, promptVersion, function(cachedText)
            if cachedText then
                LogAIOutcome({
                    claimId = claimId,
                    provider = 'cache',
                    promptVersion = promptVersion,
                    promptHash = promptHash,
                    responseTimeMs = 0,
                    success = true,
                    errorReason = nil
                })
                finish(true, cachedText, nil, 'cache')
                return
            end

            PerformHttpRequest(request.endpoint, function(statusCode, response, headers)
                local text = nil
                local responseTimeMs = ((GetGameTimer and GetGameTimer()) or (os.time() * 1000)) - startedAt
                if statusCode == 200 and response then
                    text = extractAIText(providerName, response)
                end

                if text and text ~= '' then
                    StoreCachedAIResponse(promptHash, promptVersion, providerName, getAIProviderModel(providerName), text)
                    LogAIOutcome({
                        claimId = claimId,
                        provider = providerName,
                        model = getAIProviderModel(providerName),
                        promptVersion = promptVersion,
                        promptHash = promptHash,
                        responseTimeMs = responseTimeMs,
                        success = true,
                        errorReason = nil
                    })
                    finish(true, text, nil, providerName, responseTimeMs)
                    return
                end

                print(('^3[ai_insurance_adjuster] Provider %s failed (%s): %s^0'):format(providerName, tostring(statusCode), tostring(response)))
                if attemptNumber < maxAttempts then
                    attemptProvider(providerEntry, attemptNumber + 1, providerIndex)
                elseif providerIndex < #providers then
                    attemptProvider(providers[providerIndex + 1], 1, providerIndex + 1)
                else
                    local fallbackText = options.luaFallbackText or json.encode(BuildLuaFallbackVerdict(options.claimData))
                    LogAIOutcome({
                        claimId = claimId,
                        provider = 'lua_fallback',
                        promptVersion = promptVersion,
                        promptHash = promptHash,
                        responseTimeMs = responseTimeMs,
                        success = true,
                        errorReason = 'all_providers_failed'
                    })
                    finish(true, fallbackText, 'all_providers_failed', 'lua_fallback', responseTimeMs)
                end
            end, request.method, request.body, request.headers)
        end)
    end

    attemptProvider(providers[1] or { Name = 'gemini', Priority = 1 }, 1, 1)
end

function buildSystemPrompt()
    return Config.AdjusterPersona .. [[

Prompt version: ]] .. tostring(Config.AIPromptVersion or 'v1') .. [[

You will be given structured JSON describing a vehicle insurance claim including:
- Vehicle information (model, plate, class, VIN, mileage, value, policy tier)
- Driver information (name, history, fraud score, risk score, driving record)
- Accident details (location, time, weather, speeds, collision data, occupant info)
- Vehicle health (engine, body, fuel tank, tires, doors, windows)
- Mechanic inspection report (damaged parts only - no costs)
- Repair estimate (CALCULATED by Lua - parts cost, labor cost, total)
- Witness statements
- Police reports (if any)
- EMS reports (if any)
- Player statement
- Fraud score (CALCULATED by Lua - 0-100, with indicators)
- Risk score (CALCULATED by Lua - 0-100, with category)
- Confidence score (CALCULATED by Lua - 0-100, based on evidence completeness)
- Policy validation (CALCULATED by Lua - coverage, limits, eligibility)
- Coverage information (max payout, deductible, approved amount)

You are a professional insurance adjuster. Make decisions based ONLY on the evidence provided.
DO NOT calculate or estimate any monetary values - all costs are pre-calculated.

Respond with ONLY a JSON object, no markdown fences, no preamble, in this exact shape:
{
  "decision": "approved|denied|investigate|partial",
  "confidence": <integer 0-100, use the provided confidence score>,
  "fraudRisk": "low|medium|high|critical",
  "riskScore": <integer 0-100, use the provided risk score>,
  "repairEstimate": {
    "parts": <number, use provided value>,
    "labor": <number, use provided value>,
    "total": <number, use provided value>
  },
  "approvedAmount": <number, use provided calculated value>,
  "deductible": <number, use provided calculated value>,
  "flags": ["<short_tag>", ...],
  "reasoning": "<2-4 sentences, in character as Denise, addressed to the claimant>",
  "nextAction": "<what happens next, or null if decision is final>",
  "adjusterNotes": "<professional notes about the case>",
  "mechanicSummary": "<brief summary of mechanic findings>",
  "investigationSummary": "<brief summary of evidence reviewed>",
  "followUpQuestions": ["<question>", ...] or null
}

Guidelines:
- Use the pre-calculated values provided - DO NOT recalculate or estimate costs
- Consider ALL evidence: vehicle damage, driver history, witness statements, police/EMS reports
- Reference the driver's policy tier (basic, standard, premium, elite) in your decision
- Reference the fraud score and risk score in your assessment
- Use the confidence score to determine if you have enough evidence
- "investigate" means you need more evidence before deciding - use followUpQuestions
- "partial" means you approve only part of the claim based on policy limits
- approvedAmount is already calculated - just approve or deny based on your analysis
- Include relevant flags: "speeding", "prior_claims", "witness_conflict", "policy_limit", "fraud_indicators", etc.
- If evidence conflicts with player statement, ask follow-up questions
- If fraud score is high (>60) or critical (>80), require additional investigation
- If confidence is low (<50), request more information before deciding
]]

--- Calls the configured AI provider chain with the claim data and returns a parsed verdict via callback.
--- @param claimData table
--- @param cb function(success: boolean, verdict: table|nil, rawError: string|nil)
function InvestigateClaim(claimData, cb)
    local claimId = claimData and claimData.claim_id or nil
    local promptVersion = claimData and claimData.prompt_version or Config.AIPromptVersion or 'v1'

    CallAIWithFallbacks(buildSystemPrompt(), json.encode(claimData), 1500, function(success, text, err, provider)
        if not success or not text then
            print('^1[ai_insurance_adjuster] All AI providers failed: ' .. tostring(err) .. '^0')
            cb(false, nil, err or 'all_providers_failed')
            return
        end

        -- Strip stray markdown fences just in case the model adds them
        text = text:gsub('```json', ''):gsub('```', ''):gsub('^%s+', ''):gsub('%s+$', '')

        local verdictOk, verdict = pcall(json.decode, text)
        if not verdictOk or not verdict or not verdict.decision then
            print(('^1[ai_insurance_adjuster] Failed to parse verdict JSON from %s: %s^0'):format(provider or 'unknown', tostring(text)))
            cb(false, nil, 'parse_failed')
            return
        end

        verdict.promptVersion = promptVersion
        verdict.provider = provider or 'unknown'
        cb(true, verdict, nil)
    end, {
        claimId = claimId,
        promptVersion = promptVersion,
        claimData = claimData,
        luaFallbackText = json.encode(BuildLuaFallbackVerdict(claimData))
    })
end
