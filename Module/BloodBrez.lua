-- ==============================
-- BLBR - Bloodlust & Battle Res Tracker
-- standalone addon
-- ==============================
-- 의존: Icon.lua (dodo.IconLib)
local addonName, dodo = ...
local IconLib = dodo.IconLib

-- ==============================
-- 설정
-- ==============================
local Settings = {
    iconPositionX = 470,
    iconPositionY = 4,
    iconPadding   = 0,
    iconsize      = {45, 45},
    fontsize      = 12,
    soundPath     = "Interface\\AddOns\\" .. addonName .. "\\Media\\Sound\\1-Stimpack.mp3",
}

-- ==============================
-- 캐싱
-- ==============================
local AU            = C_UnitAuras
local C_Spell       = C_Spell
local GetTime       = GetTime
local PlaySoundFile = PlaySoundFile
local math_ceil     = math.ceil
local math_floor    = math.floor

-- ==============================
-- 스펠 ID 테이블
-- ==============================
local BL_DEBUFFS = {
    57723,  -- 소진 (영웅심)
    57724,  -- 만족함 (피의 욕망)
    80354,  -- 시간 변위 (시간왜곡)
    264689, -- 피로 (원초적 분노)
    390435, -- 탈진 (위상의 격노)
}

local BREZ_SPELL_ID = 20484
local BL_ICON_SPELL = 2825

-- ==============================
-- 상태 변수
-- ==============================
local isSatedActive  = false
local blActiveUntil  = 0
local blPhase        = "idle"   -- "idle" / "active" / "sated" / "init"
local brezDesatCache = nil

-- ==============================
-- 프레임 & 아이콘 생성
-- ==============================
local frame = CreateFrame("Frame", "BLBR_TrackerFrame", UIParent)
frame:SetSize(100, 50)
frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", Settings.iconPositionX, Settings.iconPositionY)

local blIcon = IconLib:Create("BLBR_BloodlustIcon", frame, {
    isAction = false,
    iconsize = Settings.iconsize,
})
blIcon:SetPoint("LEFT", frame, "LEFT", 0, 0)

-- ── 블러드 활성 오버레이 (dodo_Actionbar2OverlayTemplate 구조 재현) ──
-- InnerGlow: UI-HUD-ActionBar-IconFrame-Mouseover atlas
-- Timer: 녹색 카운트 FontString (NumberFontNormal)
local blOverlay = CreateFrame("Frame", nil, blIcon)
blOverlay:SetAllPoints(blIcon)
blOverlay:Hide()

local blOverlayGlow = blOverlay:CreateTexture(nil, "ARTWORK")
blOverlayGlow:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
blOverlayGlow:SetVertexColor(0, 1, 0, 1)
blOverlayGlow:SetAllPoints(blOverlay)
blOverlayGlow:SetBlendMode("BLEND")

local blOverlayTimer = blOverlay:CreateFontString(nil, "ARTWORK", "NumberFontNormal")
blOverlayTimer:SetPoint("TOPLEFT", blOverlay, "TOPLEFT", 5, -5)
blOverlayTimer:SetTextColor(0.1, 1, 0.1)

local brezIcon = IconLib:Create("BLBR_BrezIcon", frame, {
    isAction = false,
    iconsize = Settings.iconsize,
})
brezIcon:SetPoint("LEFT", blIcon, "RIGHT", Settings.iconPadding, 0)

-- ==============================
-- 업데이트 함수
-- ==============================

local function UpdateBloodlust()
    local foundAura = nil
    for _, id in ipairs(BL_DEBUFFS) do
        local aura = AU.GetPlayerAuraBySpellID(id)
        if aura then
            foundAura = aura
            break
        end
    end

    local now = GetTime()

    if foundAura then
        if not isSatedActive then
            local debuffStartTime = foundAura.expirationTime - foundAura.duration
            blActiveUntil = debuffStartTime + 40
            isSatedActive = true
            if now < blActiveUntil then
                PlaySoundFile(Settings.soundPath, "Master")
            end
        end

        if now < blActiveUntil then
            -- ── 활성 페이즈: 컬러 + InnerGlow + 녹색 카운트 ──
            if blPhase ~= "active" then
                blPhase = "active"
                blIcon.icon:SetDesaturated(false)
                blIcon.cooldown:Clear()
                blIcon.Name:SetText("")
                blOverlay:Show()
            end
            local remaining = math_ceil(blActiveUntil - now - 1)
            blOverlayTimer:SetText(tostring(remaining < 0 and 0 or remaining))
        else
            -- ── 소진 페이즈: 흑백 + 오버레이 off + 디버프 쿨다운 스윕 ──
            if blPhase ~= "sated" then
                blPhase = "sated"
                blOverlay:Hide()
                blOverlayTimer:SetText("")
                blIcon.icon:SetDesaturated(true)
                blIcon.cooldown:SetCooldown(
                    foundAura.expirationTime - foundAura.duration,
                    foundAura.duration
                )
                blIcon.Name:SetText("")
            end
        end
    else
        -- ── 대기: 오버레이 off, 컬러 ──
        if blPhase ~= "idle" then
            blPhase = "idle"
            isSatedActive = false
            blActiveUntil = 0
            blOverlay:Hide()
            blOverlayTimer:SetText("")
            blIcon.icon:SetDesaturated(false)
            blIcon.cooldown:Clear()
            blIcon.Name:SetText("")
        end
    end
end

local function UpdateBrez()
    local chargeInfo = C_Spell.GetSpellCharges(BREZ_SPELL_ID)

    if not chargeInfo or (chargeInfo.currentCharges == 0 and chargeInfo.maxCharges == 0) then
        brezIcon.Count:SetText("")
        brezIcon.Name:SetText("")
        if brezDesatCache ~= false then
            brezDesatCache = false
            brezIcon.icon:SetDesaturated(false)
            brezIcon.cooldown:Clear()
        end
        return
    end

    local current  = chargeInfo.currentCharges   or 0
    local maxC     = chargeInfo.maxCharges        or 1
    local start    = chargeInfo.cooldownStartTime or 0
    local duration = chargeInfo.cooldownDuration  or 0

    brezIcon.Count:SetText(tostring(current))
    brezIcon.Count:SetTextColor(1, 0.82, 0)

    if current == 0 and duration > 0 then
        if brezDesatCache ~= true then
            brezDesatCache = true
            brezIcon.icon:SetDesaturated(true)
        end
        brezIcon.cooldown:SetCooldown(start, duration)
        local remaining = (start + duration) - GetTime()
        if remaining > 0 then
            local m = math_floor(remaining / 60)
            local s = math_floor(remaining % 60)
            brezIcon.Name:SetText(m > 0 and string.format("%d:%02d", m, s) or tostring(s))
        else
            brezIcon.Name:SetText("")
        end
    elseif current < maxC and start > 0 and duration > 0 then
        if brezDesatCache ~= false then
            brezDesatCache = false
            brezIcon.icon:SetDesaturated(false)
        end
        brezIcon.cooldown:SetCooldown(start, duration)
        local remaining = (start + duration) - GetTime()
        if remaining > 0 then
            local m = math_floor(remaining / 60)
            local s = math_floor(remaining % 60)
            brezIcon.Name:SetText(m > 0 and string.format("%d:%02d", m, s) or tostring(s))
        else
            brezIcon.Name:SetText("")
        end
    else
        if brezDesatCache ~= false then
            brezDesatCache = false
            brezIcon.icon:SetDesaturated(false)
            brezIcon.cooldown:Clear()
        end
        brezIcon.Name:SetText("")
    end
end

-- ==============================
-- 초기화
-- ==============================
local function ApplyIcons()
    blIcon:ApplyConfig({
        type     = "spell",
        id       = BL_ICON_SPELL,
        fontsize = Settings.fontsize,
    })
    -- UpdateStatus가 isKnown=false(스킬 미보유 클래스)로
    -- SetDesaturated(true)를 호출하므로 ApplyConfig 직후 강제 복원
    blIcon.icon:SetDesaturated(false)
    blIcon.cooldown:Clear()
    blPhase = "init"

    -- Name은 오버레이 Timer로 대체되므로 숨김
    blIcon.Name:SetText("")

    brezIcon:ApplyConfig({
        type     = "spell",
        id       = BREZ_SPELL_ID,
        fontsize = Settings.fontsize,
    })
    brezIcon.icon:SetDesaturated(false)
    brezDesatCache = false

    brezIcon.Name:ClearAllPoints()
    brezIcon.Name:SetPoint("TOP", brezIcon, "BOTTOM", 0, -2)
    brezIcon.Name:SetTextColor(1, 1, 1)
end

-- ==============================
-- 이벤트 & 틱
-- ==============================
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        ApplyIcons()
    end
end)

C_Timer.After(1, function()
    ApplyIcons()
    C_Timer.NewTicker(0.1, function()
        UpdateBloodlust()
        UpdateBrez()
    end)
end)