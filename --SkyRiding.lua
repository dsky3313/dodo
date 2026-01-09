local addonName, hodoSkyriding = ...

-----------------------------------------------------------
-- 1. 테이블 (Settings & Constants)
-----------------------------------------------------------
local SPELLS = {
    THRILL = 377234,
    ASCENT = 372610,
    METHOD = 404464,
    VIGOR_TRACK = 372608, -- 기력 충전 추적용 ID
}

local ascentStart = 0
local ASCENT_BOOST_DURATION = 3.5

local function init_db()
    hodoDB = hodoDB or {}
    hodoDB.x = hodoDB.x or 0
    hodoDB.y = hodoDB.y or -150
    hodoDB.scale = hodoDB.scale or 1.0
    hodoDB.width = hodoDB.width or 220
end

local function Lerp(start, finish, alpha)
    return start + (finish - start) * alpha
end

-----------------------------------------------------------
-- 2. 디스플레이 (UI Creation)
-----------------------------------------------------------
local function init_ui()
    init_db()

    -- [메인 프레임]
    hodoSkyriding.frame = CreateFrame("Frame", "HodoSkyRideFrame", UIParent)
    hodoSkyriding.frame:SetSize(hodoDB.width, 50)
    hodoSkyriding.frame:SetPoint("CENTER", UIParent, "CENTER", hodoDB.x, hodoDB.y)
    hodoSkyriding.frame:SetScale(hodoDB.scale)
    hodoSkyriding.frame:SetMovable(true)
    hodoSkyriding.frame:EnableMouse(true)
    hodoSkyriding.frame:SetClampedToScreen(true)

    -- [편집 모드 선택기]
    local selection = CreateFrame("Frame", nil, hodoSkyriding.frame, "EditModeSystemSelectionTemplate")
    selection:SetAllPoints(hodoSkyriding.frame)
    selection:SetFrameLevel(500)
    selection.system = { GetSystemName = function() return "Hodo 하늘비행" end }
    hodoSkyriding.selection = selection

    -- [속도 바]
    hodoSkyriding.bg = hodoSkyriding.frame:CreateTexture(nil, "BACKGROUND")
    hodoSkyriding.bg:SetSize(hodoDB.width, 16)
    hodoSkyriding.bg:SetPoint("TOP", hodoSkyriding.frame, "TOP", 0, 0)
    hodoSkyriding.bg:SetAtlas("ui-castingbar-background")

    hodoSkyriding.bar = CreateFrame("StatusBar", nil, hodoSkyriding.frame)
    hodoSkyriding.bar:SetSize(hodoDB.width - 4, 12)
    hodoSkyriding.bar:SetPoint("CENTER", hodoSkyriding.bg, "CENTER", 0, 0)
    hodoSkyriding.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

    hodoSkyriding.fixedMarker = hodoSkyriding.bar:CreateTexture(nil, "OVERLAY", nil, 4)
    hodoSkyriding.fixedMarker:SetAtlas("gradientbar-marker-diamond")
    hodoSkyriding.fixedMarker:SetSize(26, 26)
    hodoSkyriding.fixedMarker:SetPoint("CENTER", hodoSkyriding.bar, "LEFT", (789/1200)*(hodoDB.width-4), 0)

    hodoSkyriding.marker = hodoSkyriding.bar:CreateTexture(nil, "OVERLAY", nil, 5)
    hodoSkyriding.marker:SetAtlas("UI-CastingBar-Pip")
    hodoSkyriding.marker:SetSize(4, 18)

    hodoSkyriding.text = hodoSkyriding.bar:CreateFontString(nil, "OVERLAY", nil, 6)
    hodoSkyriding.text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    hodoSkyriding.text:SetPoint("CENTER", hodoSkyriding.bar, "CENTER", 0, 0)

    -- [기력 바 (6스택 재설계)]
    hodoSkyriding.vigor = {}
    local vigorWidth = (hodoDB.width - (5 * 4)) / 6 -- 4px 간격으로 6개 배치

    for i = 1, 6 do
        local slot = CreateFrame("Frame", nil, hodoSkyriding.frame)
        slot:SetSize(vigorWidth, 12)
        
        -- 기본 배경 (Inscription 아틀라스)
        slot.tex = slot:CreateTexture(nil, "BACKGROUND")
        slot.tex:SetAllPoints()
        slot.tex:SetAtlas("Professions-Specialization-Node-Inscription")
        slot.tex:SetDesaturated(true)
        slot.tex:SetAlpha(0.3)

        -- 쿨타임/스와이프 레이어
        slot.cd = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
        slot.cd:SetAllPoints()
        slot.cd:SetFrameLevel(slot:GetFrameLevel() + 2)
        slot.cd:SetSwipeTexture("Professions-Specialization-Node-Inscription")
        slot.cd:SetSwipeColor(0, 0.8, 1, 0.8) -- 충전 중일 때 파란색 빛
        slot.cd:SetHideCountdownNumbers(true)

        -- 충전 완료 시 채워질 텍스처
        slot.fill = slot:CreateTexture(nil, "OVERLAY")
        slot.fill:SetAllPoints()
        slot.fill:SetAtlas("Professions-Specialization-Node-Inscription")
        slot.fill:SetVertexColor(0, 0.9, 1) -- 완충 시 밝은 파란색
        slot.fill:Hide()

        if i == 1 then
            slot:SetPoint("TOPLEFT", hodoSkyriding.bg, "BOTTOMLEFT", 0, -6)
        else
            slot:SetPoint("LEFT", hodoSkyriding.vigor[i-1], "RIGHT", 4, 0)
        end
        hodoSkyriding.vigor[i] = slot
    end
    
    hodoSkyriding.prevSpeed = 0
end

-----------------------------------------------------------
-- 3. 활성 조건 (Triggers / Events)
-----------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

-----------------------------------------------------------
-- 4. 조건 & 동작 (Logic & OnUpdate)
-----------------------------------------------------------
local function on_update()
    if not hodoSkyriding.frame then return end

    local isEditMode = EditModeManager and EditModeManager:IsEditModeActive()
    local hasThrill = C_UnitAuras.GetPlayerAuraBySpellID(SPELLS.THRILL)
    local isBoosting = hasThrill and (GetTime() < ascentStart + ASCENT_BOOST_DURATION)
    local isSkyriding = C_UnitAuras.GetPlayerAuraBySpellID(SPELLS.METHOD)

    -- [표시 조건]
    if isEditMode then
        hodoSkyriding.frame:Show()
        hodoSkyriding.selection:Show()
    elseif IsMounted() and isSkyriding then
        hodoSkyriding.frame:Show()
        hodoSkyriding.selection:Hide()
    else
        hodoSkyriding.frame:Hide()
        return
    end

    -- [속도 바 동작]
    local _, _, fSpeed = C_PlayerInfo.GetGlidingInfo()
    local speedPct = (fSpeed or GetUnitSpeed("player")) / 7 * 100
    hodoSkyriding.prevSpeed = Lerp(hodoSkyriding.prevSpeed, speedPct, 0.15)
    
    local barTex = hodoSkyriding.bar:GetStatusBarTexture()
    barTex:SetAtlas(isBoosting and "UI-CastingBar-Filling-Channel" or (hasThrill and "UI-CastingBar-Filling-ApplyingCrafting" or "UI-CastingBar-Filling-Standard"))
    
    hodoSkyriding.bar:SetValue(hodoSkyriding.prevSpeed)
    hodoSkyriding.text:SetText(math.floor(speedPct) .. "%")
    hodoSkyriding.marker:SetPoint("CENTER", hodoSkyriding.bar, "LEFT", (math.min(1200, hodoSkyriding.prevSpeed)/1200) * hodoSkyriding.bar:GetWidth(), 0)

    -- [기력 바 동작 (6스택 추적)]
    local info = C_Spell.GetSpellCharges(SPELLS.VIGOR_TRACK)
    if info then
        for i = 1, 6 do
            local slot = hodoSkyriding.vigor[i]
            if i <= info.currentCharges then
                -- 충전 완료
                slot.fill:Show()
                slot.cd:Hide()
                slot.tex:SetAlpha(1)
            elseif i == info.currentCharges + 1 and info.cooldownDuration > 0 then
                -- 충전 중 (스와이프 작동)
                slot.fill:Hide()
                slot.cd:Show()
                slot.cd:SetCooldown(info.cooldownStartTime, info.cooldownDuration)
                slot.tex:SetAlpha(0.3)
            else
                -- 미충전 대기 상태
                slot.fill:Hide()
                slot.cd:Hide()
                slot.tex:SetAlpha(0.3)
            end
        end
    end
end

-----------------------------------------------------------
-- 5. 동작 실행 (Event Handler)
-----------------------------------------------------------
eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == addonName then
        init_ui()
        C_Timer.NewTicker(0.016, on_update)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and arg1 == "player" then
        local spellID = select(3, ...)
        if spellID == SPELLS.ASCENT then
            ascentStart = GetTime()
        end
    end
end)