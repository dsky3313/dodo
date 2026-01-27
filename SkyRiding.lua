-- [ 1. 설정 및 변수 ] --
local config = {
    fontSize = 16,
    fontPath = "Fonts\\2002.TTF", 
    pos = {"CENTER", 0, -150},    
    barWidth = 209,               
    barHeight = 11,               
}

local surgeSpellId = 372608
local thrillBuffId = 377234
local galeBuffId = 388367 
local ascentSpellId = 372610
local ascentDuration, surgeDuration = 3.5, 1.0

local prevSpeed, prevCharges = 0, 0
local ascentStart, surgeStart = 0, 0

-- [ 2. 메인 UI 프레임 ] --
local frame = CreateFrame("StatusBar", "LirooSpeedBar", UIParent)
frame:SetSize(config.barWidth, config.barHeight)
frame:SetPoint(config.pos[1], config.pos[2], config.pos[3])
frame:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
frame:SetMinMaxValues(0, 1.2)
frame:Hide()

local bg = frame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(true)
bg:SetAtlas("ui-castingbar-background", true)
bg:SetDesaturated(true)

-- [ 3. 정수(Essence) 6칸 생성 ] --
frame.essences = {}
local numEssences, essenceSize = 6, 24
local totalWidth = essenceSize * numEssences

for i = 1, numEssences do
    local container = CreateFrame("Frame", nil, frame)
    container:SetSize(essenceSize, essenceSize)
    if i == 1 then
        container:SetPoint("TOP", bg, "BOTTOM", -(totalWidth / 2) + (essenceSize / 2), -4)
    else
        container:SetPoint("LEFT", frame.essences[i-1].container, "RIGHT", 0, 0)
    end

    local ebg = container:CreateTexture(nil, "BACKGROUND")
    ebg:SetAtlas("UF-Essence-BG", true)
    ebg:SetAllPoints(); ebg:SetDesaturated(true)

    local filling = CreateFrame("Frame", nil, container)
    filling:SetAllPoints(); filling:Hide()
    filling.timer = filling:CreateTexture(nil, "OVERLAY")
    filling.timer:SetAtlas("UF-Essence-TimerSpin", true); filling.timer:SetPoint("CENTER")
    filling.trail = filling:CreateTexture(nil, "ARTWORK")
    filling.trail:SetAtlas("UF-Essence-Spinner", true); filling.trail:SetPoint("CENTER")

    local cd = CreateFrame("Cooldown", nil, container, "CooldownFrameTemplate")
    cd:SetAllPoints(); cd:SetDrawSwipe(false); cd:SetDrawEdge(false); cd:SetHideCountdownNumbers(true)

    local iconActive = container:CreateTexture(nil, "OVERLAY", nil, 5)
    iconActive:SetAtlas("UF-Essence-Icon-Active", true); iconActive:SetPoint("CENTER"); iconActive:Hide()

    local done = CreateFrame("Frame", nil, container)
    done:SetAllPoints(); done:Hide()
    done.burst = done:CreateTexture(nil, "OVERLAY", nil, 6)
    done.burst:SetAtlas("UF-Essence-FX-Burst", true); done.burst:SetPoint("CENTER")
    done.rim = done:CreateTexture(nil, "OVERLAY", nil, 4)
    done.rim:SetAtlas("UF-Essence-RimGlow", true); done.rim:SetPoint("CENTER")
    
    done.anim = done:CreateAnimationGroup()
    local bRot = done.anim:CreateAnimation("Rotation"); bRot:SetChildKey("burst"); bRot:SetDuration(0.3); bRot:SetDegrees(-30)
    local bAlpha = done.anim:CreateAnimation("Alpha"); bAlpha:SetChildKey("burst"); bAlpha:SetFromAlpha(1); bAlpha:SetToAlpha(0); bAlpha:SetDuration(0.5)
    local rScale = done.anim:CreateAnimation("Scale"); rScale:SetChildKey("rim"); rScale:SetScale(1.2, 1.2); rScale:SetDuration(0.4)
    local rAlpha = done.anim:CreateAnimation("Alpha"); rAlpha:SetFromAlpha(1); rAlpha:SetToAlpha(0); rAlpha:SetDuration(0.4)
    done.anim:SetScript("OnFinished", function() done:Hide() end)

    local deplete = CreateFrame("Frame", nil, container)
    deplete:SetAllPoints(); deplete:Hide()
    deplete.smoke = deplete:CreateTexture(nil, "OVERLAY", nil, 7)
    deplete.smoke:SetAtlas("UF-Essence-FX-Smoke", true); deplete.smoke:SetPoint("CENTER")

    deplete.anim = deplete:CreateAnimationGroup()
    local sScale = deplete.anim:CreateAnimation("Scale"); sScale:SetScale(1.4, 1.4); sScale:SetDuration(0.6)
    local sAlpha = deplete.anim:CreateAnimation("Alpha"); sAlpha:SetFromAlpha(1); sAlpha:SetToAlpha(0); sAlpha:SetDuration(0.6)
    local sTrans = deplete.anim:CreateAnimation("Translation"); sTrans:SetOffset(0, 10); sTrans:SetDuration(0.6)
    deplete.anim:SetScript("OnFinished", function() deplete:Hide() end)

    frame.essences[i] = { container = container, ebg = ebg, cd = cd, filling = filling, iconActive = iconActive, done = done, deplete = deplete }
end

-- [ 4. 장식 요소 ] --
local border = frame:CreateTexture(nil, "OVERLAY", nil, 1)
border:SetAtlas("UI-CastingBar-Frame", true)
border:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 3); border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -3)

local diamond = frame:CreateTexture(nil, "OVERLAY", nil, 7)
diamond:SetAtlas("gradientbar-marker-diamond", true)
diamond:SetSize(16, 16)

local targetVal = (789 / 100 * 7) / 84
local correctedPos = (function(v)
    local t = 0.6
    if v <= t then return v end
    return t + (0.6) * math.pow(math.min(v - t, 0.4) * 2.5, 1.2)
end)(targetVal)
diamond:SetPoint("CENTER", frame, "LEFT", (correctedPos / 1.2) * config.barWidth, 0)

local spark = frame:CreateTexture(nil, "OVERLAY", nil, 6)
spark:SetAtlas("UI-CastingBar-Pip", true); spark:SetSize(4, config.barHeight * 1.5); spark:SetBlendMode("ADD")

local text = frame:CreateFontString(nil, "OVERLAY")
text:SetFont(config.fontPath, config.fontSize, "OUTLINE")
text:SetPoint("LEFT", frame, "RIGHT", 12, 0)

-- [ 5. 핵심 로직 ] --
local function UpdateEssenceStatus()
    local chargeInfo = C_Spell.GetSpellCharges(surgeSpellId)
    if not chargeInfo then return end

    local currentCharges, chargeStart, chargeDuration = chargeInfo.currentCharges, chargeInfo.cooldownStartTime, chargeInfo.cooldownDuration
    local actualDuration = (chargeDuration and chargeDuration > 0) and chargeDuration or 10

    if currentCharges < prevCharges then
        for i = currentCharges + 1, prevCharges do
            local e = frame.essences[i]
            if e then e.deplete:Show(); e.deplete.anim:Play(); e.iconActive:Hide() end
        end
    elseif currentCharges > prevCharges then
        for i = prevCharges + 1, currentCharges do
            local e = frame.essences[i]
            if e then e.done:Show(); e.done.anim:Play() end
        end
    end
    prevCharges = currentCharges

    for i = 1, numEssences do
        local e = frame.essences[i]
        if i <= currentCharges then
            e.filling:Hide(); e.cd:Hide(); e.ebg:SetDesaturated(false)
            if not e.deplete.anim:IsPlaying() then e.iconActive:Show() end
        elseif i == currentCharges + 1 then
            e.iconActive:Hide(); e.filling:Show()
            local progress = math.min((GetTime() - chargeStart) / actualDuration, 1)
            local angle = -progress * (math.pi * 2)
            e.filling.timer:SetRotation(angle); e.filling.trail:SetRotation(angle)
            e.cd:Show(); e.cd:SetCooldown(chargeStart, actualDuration); e.ebg:SetDesaturated(true)
        else
            e.iconActive:Hide(); e.filling:Hide(); e.cd:Hide(); e.ebg:SetDesaturated(true)
        end
    end
end

local function OnUpdate(self, elapsed)
    local isGliding, _, forwardSpeed = C_PlayerInfo.GetGlidingInfo()
    if not isGliding then self:Hide(); prevSpeed = 0; return end

    local targetSpeed = forwardSpeed / 84
    local smoothSpeed = FrameDeltaLerp(prevSpeed, targetSpeed, 0.2)
    prevSpeed = smoothSpeed

    local finalValue = (function(v)
        local t = 0.6
        if v <= t then return v end
        return t + (0.6) * math.pow(math.min(v - t, 0.4) * 2.5, 1.2)
    end)(smoothSpeed)

    self:SetValue(finalValue)
    spark:SetPoint("CENTER", self, "LEFT", (finalValue / 1.2) * config.barWidth, 0)
    text:SetText(string.format("%.0f", forwardSpeed * (100 / 7)))

    local now = GetTime()
    local thrill = C_UnitAuras.GetPlayerAuraBySpellID(thrillBuffId)
    local gale = C_UnitAuras.GetPlayerAuraBySpellID(galeBuffId)
    local boosting = thrill and (now < ascentStart + ascentDuration)
    local surging = (now < surgeStart + surgeDuration)

    -- [핵심 수정: 우선순위 변경]
    if boosting then
        -- 상승/정지 효과가 가장 먼저 (초록색)
        self:SetStatusBarTexture("UI-CastingBar-Filling-Channel")
        self:SetStatusBarColor(1, 1, 1)
        text:SetTextColor(0.1, 1, 0.1)
        spark:SetVertexColor(0.1, 1, 0.1)
    elseif gale then
        -- 돌풍 버프가 그 다음 (하늘색 바 + 진한 파랑 글자)
        self:SetStatusBarTexture("UI-CastingBar-Filling-ApplyingCrafting")
        self:SetStatusBarColor(0.3, 0.6, 1)
        text:SetTextColor(0.3, 0.6, 1)
        spark:SetVertexColor(0.3, 0.6, 1)
    elseif thrill then
        -- 하늘의 전율 버프 (파란색) -> 쇄도(surging)보다 위에 두어 쇄도 중에도 파란색 유지
        self:SetStatusBarTexture("UI-CastingBar-Filling-ApplyingCrafting")
        self:SetStatusBarColor(1, 1, 1)
        text:SetTextColor(0.41, 0.8, 0.9)
        spark:SetVertexColor(0.41, 0.8, 0.9)
    elseif surging then
        -- 쇄도 효과 (전율이 없을 때만 노란색으로 표시됨)
        self:SetStatusBarTexture("UI-CastingBar-Filling-Standard")
        self:SetStatusBarColor(1, 0.9, 0.5)
        text:SetTextColor(1, 1, 1)
        spark:SetVertexColor(1, 1, 1)
    else
        -- 기본 상태
        self:SetStatusBarTexture("UI-CastingBar-Filling-Standard")
        self:SetStatusBarColor(1, 1, 1)
        text:SetTextColor(1, 1, 1)
        spark:SetVertexColor(1, 1, 1)
    end
    UpdateEssenceStatus()
end

-- [ 6. 이벤트 핸들러 ] --
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED"); frame:RegisterEvent("SPELL_UPDATE_CHARGES"); frame:RegisterEvent("PLAYER_IS_GLIDING_CHANGED")
frame:SetScript("OnEvent", function(self, event, unit, _, spellID)
    if event == "PLAYER_IS_GLIDING_CHANGED" then
        if C_PlayerInfo.GetGlidingInfo() then self:Show() end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
        if spellID == surgeSpellId then 
            surgeStart = GetTime() 
        elseif spellID == ascentSpellId then 
            ascentStart = GetTime() 
        end
    end
    UpdateEssenceStatus()
end)
frame:SetScript("OnUpdate", OnUpdate)