-- ==============================
-- Inspired
-- ==============================
-- BResLustTracker [Retail] (https://www.curseforge.com/wow/addons/breslusttracker)

-- ==============================
-- 설정 및 테이블
-- ==============================
local addonName, dodo = ...
local IconLib = dodo.IconLib
dodoDB = dodoDB or {}

local Settings = {
    iconPositionX = 465,
    iconPositionY = 2,
    iconPadding   = 2,
    iconsize      = {45, 45},
    fontsize      = 12,
    soundPath     = "Interface\\AddOns\\" .. addonName .. "\\Media\\Sound\\1-Stimpack.mp3",
}

local BL_DEBUFFS = {
    57723,  -- 소진 (영웅심)
    57724,  -- 만족함 (피의 욕망)
    80354,  -- 시간 변위 (시간왜곡)
    264689, -- 피로 (원초적 분노)
    390435, -- 탈진 (위상의 격노)
}

-- ==============================
-- 캐싱
-- ==============================
-- 함수
local CreateFrame   = CreateFrame
local GetTime       = GetTime
local math_ceil     = math.ceil
local PlaySoundFile = PlaySoundFile

-- 변수
local AU            = C_UnitAuras
local BL_ICON_SPELL = 2825
local BREZ_SPELL_ID = 20484
local C_Spell       = C_Spell

local blActiveUntil  = 0
local blPhase        = "idle"   -- "idle" / "active" / "sated" / "init"
local brezDesatCache = nil
local isSatedActive  = false

-- ==============================
-- 디스플레이
-- ==============================
local frame = CreateFrame("Frame", "BLBR_TrackerFrame", UIParent)
frame:SetSize(100, 50)
frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", Settings.iconPositionX, Settings.iconPositionY)

local bloodIcon = IconLib:Create("BLBR_BloodlustIcon", frame, {
    isAction = false,
    iconsize = Settings.iconsize,
})
bloodIcon:SetPoint("LEFT", frame, "LEFT", 0, 0)

local bloodOverlay = CreateFrame("Frame", nil, bloodIcon)
bloodOverlay:SetAllPoints(bloodIcon)
bloodOverlay:Hide()

local bloodOverlayGlow = bloodOverlay:CreateTexture(nil, "ARTWORK")
bloodOverlayGlow:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
bloodOverlayGlow:SetVertexColor(0, 1, 0, 1)
bloodOverlayGlow:SetAllPoints(bloodOverlay)
bloodOverlayGlow:SetBlendMode("BLEND")

local bloodOverlayTimer = bloodOverlay:CreateFontString(nil, "ARTWORK", "NumberFontNormal")
bloodOverlayTimer:SetPoint("TOPLEFT", bloodOverlay, "TOPLEFT", 5, -5)
bloodOverlayTimer:SetTextColor(0.1, 1, 0.1)

local brezIcon = IconLib:Create("BLBR_BrezIcon", frame, {
    isAction = false,
    iconsize = Settings.iconsize,
})
brezIcon:SetPoint("LEFT", bloodIcon, "RIGHT", Settings.iconPadding, 0)

-- ==============================
-- 동작
-- ==============================
local function UpdateBloodlust()
    local foundAura = nil
    for _, id in ipairs(BL_DEBUFFS) do
        local aura = AU.GetPlayerAuraBySpellID(id)
        if aura then foundAura = aura; break end
    end

    local now = GetTime()
    if foundAura then
        if not isSatedActive then
            local debuffStartTime = foundAura.expirationTime - foundAura.duration
            blActiveUntil = debuffStartTime + 40
            isSatedActive = true
            if now < blActiveUntil then PlaySoundFile(Settings.soundPath, "Master") end
        end

        if now < blActiveUntil then
            if blPhase ~= "active" then
                blPhase = "active"
                bloodIcon.icon:SetDesaturated(false)
                bloodIcon.cooldown:Clear()
                bloodIcon.Name:SetText("")
                bloodOverlay:Show()
            end
            local remaining = math_ceil(blActiveUntil - now - 1)
            bloodOverlayTimer:SetText(tostring(remaining < 0 and 0 or remaining))
        else
            if blPhase ~= "sated" then
                blPhase = "sated"
                bloodOverlay:Hide()
                bloodOverlayTimer:SetText("")
                bloodIcon.icon:SetDesaturated(true)
                bloodIcon.cooldown:SetCooldown(foundAura.expirationTime - foundAura.duration, foundAura.duration)
                bloodIcon.Name:SetText("")
            end
        end
    else
        if blPhase ~= "idle" then
            blPhase = "idle"
            isSatedActive = false
            blActiveUntil = 0
            bloodOverlay:Hide()
            bloodOverlayTimer:SetText("")
            bloodIcon.icon:SetDesaturated(false)
            bloodIcon.cooldown:Clear()
            bloodIcon.Name:SetText("")
        end
    end
end

local function UpdateBrez()
    local chargeInfo = C_Spell.GetSpellCharges(BREZ_SPELL_ID)
    if not chargeInfo or (chargeInfo.currentCharges == 0 and chargeInfo.maxCharges == 0) then
        brezIcon.Count:SetText("")
        if brezDesatCache ~= false then
            brezDesatCache = false
            brezIcon.icon:SetDesaturated(false)
            brezIcon.cooldown:Clear()
        end
        return
    end

    local current  = chargeInfo.currentCharges   or 0
    local start    = chargeInfo.cooldownStartTime or 0
    local duration = chargeInfo.cooldownDuration  or 0

    brezIcon.Count:SetText(tostring(current))
    brezIcon.Count:SetTextColor(1, 0.82, 0)

    if current == 0 and duration > 0 then
        if brezDesatCache ~= true then brezDesatCache = true; brezIcon.icon:SetDesaturated(true) end
        brezIcon.cooldown:SetCooldown(start, duration)
    else
        if brezDesatCache ~= false then brezDesatCache = false; brezIcon.icon:SetDesaturated(false) end
        if duration > 0 then brezIcon.cooldown:SetCooldown(start, duration) else brezIcon.cooldown:Clear() end
    end
end

local function ApplyIcons()
    bloodIcon:ApplyConfig({ type = "spell", id = BL_ICON_SPELL, fontsize = Settings.fontsize })
    bloodIcon.icon:SetDesaturated(false)
    bloodIcon.cooldown:Clear()
    bloodIcon.Name:SetText("")
    blPhase = "init"

    brezIcon:ApplyConfig({ type = "spell", id = BREZ_SPELL_ID, fontsize = Settings.fontsize })
    brezIcon.icon:SetDesaturated(false)
    brezDesatCache = false
end

-- ==============================
-- 이벤트
-- ==============================
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
    elseif event == "PLAYER_ENTERING_WORLD" then
        ApplyIcons()
        dodo.BloodBrez() -- 초기 설정 적용
    end
end)

C_Timer.After(1, function()
    ApplyIcons()
    dodo.BloodBrez()
    C_Timer.NewTicker(0.5, function()
        if frame:IsShown() then -- 프레임이 보일 때만 업데이트
            UpdateBloodlust()
            UpdateBrez()
        end
    end)
end)

-- ==============================
-- 외부 노출 (Option.lua용)
-- ==============================
dodo.BloodBrez = function()
    local isEnabled = (dodoDB and dodoDB.useBloodBrez ~= false)
    if isEnabled then frame:Show() else frame:Hide() end
end