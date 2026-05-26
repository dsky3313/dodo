-- ==============================
-- Inspired
-- ==============================
-- BResLustTracker [Retail] (https://www.curseforge.com/wow/addons/breslusttracker)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("BloodBrez", module)

local LibIcon = dodo.LibIcon
local LibEditMode = LibStub and LibStub("LibEditMode", true)

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
-- 프레임 및 이벤트 핸들러 정의
-- ==============================
local frame
local bloodIcon
local bloodOverlay
local bloodOverlayGlow
local bloodOverlayTimer
local brezIcon

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID
local GetSpellCharges = C_Spell.GetSpellCharges
local GetTime = GetTime
local ipairs = ipairs
local issecretvalue = issecretvalue or function() return false end
local math_ceil = math.ceil
local PlaySoundFile = PlaySoundFile
local tostring = tostring
local UIParent = UIParent

local BL_ICON_SPELL    = 2825
local BREZ_SPELL_ID    = 20484
local blActiveUntil  = 0
local blPhase        = "idle"   -- "idle" / "active" / "sated" / "init"
local brezDesatCache = nil
local isSatedActive  = false

-- ==============================
-- 기능 1: 영웅심 추적
-- ==============================
local update_bloodlust

local function actual_OnOverlayUpdate()
    local now = GetTime()
    if blActiveUntil > 0 and now < blActiveUntil then
        local rem = math_ceil(blActiveUntil - now - 1)
        local remainingText = tostring(rem < 0 and 0 or rem)
        if remainingText ~= bloodOverlayTimer._lastText then
            bloodOverlayTimer:SetText(remainingText)
            bloodOverlayTimer._lastText = remainingText
        end
    else
        bloodOverlay:SetScript("OnUpdate", nil)
        update_bloodlust()
    end
end

local function OnOverlayUpdate(self)
    dodo.Throttle("BloodBrezOverlayUpdate", actual_OnOverlayUpdate, 0.1)
end

local function update_bloodlust()
    local foundAura = nil
    for _, id in ipairs(BL_DEBUFFS) do
        local aura = GetPlayerAuraBySpellID(id)
        if aura then foundAura = aura; break end
    end

    local now = GetTime()
    if foundAura then
        local isExpSecret = issecretvalue(foundAura.expirationTime)
        if not isSatedActive then
            if not isExpSecret then
                local debuffStartTime = foundAura.expirationTime - foundAura.duration
                blActiveUntil = debuffStartTime + 40
                isSatedActive = true
                if now < blActiveUntil then PlaySoundFile(Settings.soundPath, "Master") end
            else
                isSatedActive = true
                PlaySoundFile(Settings.soundPath, "Master")
                blActiveUntil = 0
            end
        end

        local isShowingOverlay = false
        
        if not isExpSecret and blActiveUntil > 0 and now < blActiveUntil then
            if blPhase ~= "active" then
                blPhase = "active"
                bloodIcon.icon:SetDesaturated(false)
                bloodIcon.cooldown:Clear()
                bloodIcon.Name:SetText("")
                bloodOverlay:Show()
                bloodOverlay:SetScript("OnUpdate", OnOverlayUpdate)
            end
            isShowingOverlay = true
        else
            if blPhase ~= "sated" then
                blPhase = "sated"
                bloodOverlay:Hide()
                bloodOverlay:SetScript("OnUpdate", nil)
                bloodIcon.icon:SetDesaturated(true)
                bloodIcon.cooldown:SetCooldown(foundAura.expirationTime - foundAura.duration, foundAura.duration)
                bloodIcon.Name:SetText("")
            end
            isShowingOverlay = false
        end

        if isShowingOverlay then bloodOverlay:Show() else bloodOverlay:Hide() end
    else
        if blPhase ~= "idle" then
            blPhase = "idle"
            isSatedActive = false
            blActiveUntil = 0
            bloodOverlay:Hide()
            bloodOverlay:SetScript("OnUpdate", nil)
            bloodOverlayTimer:SetText("")
            bloodIcon.icon:SetDesaturated(false)
            bloodIcon.cooldown:Clear()
            bloodIcon.Name:SetText("")
        end
    end
end

-- ==============================
-- 기능 2: 전투부활 추적
-- ==============================
local function update_brez()
    local chargeInfo = GetSpellCharges(BREZ_SPELL_ID)
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

    local isCurrentSecret = issecretvalue(current)
    local chargeText = tostring(current)
    if chargeText ~= brezIcon.Count._lastText or isCurrentSecret then
        brezIcon.Count:SetText(chargeText)
        if not isCurrentSecret then brezIcon.Count._lastText = chargeText end
    end
    brezIcon.Count:SetTextColor(1, 0.82, 0)

    if current == 0 and duration > 0 then
        if brezDesatCache ~= true then brezDesatCache = true; brezIcon.icon:SetDesaturated(true) end
        brezIcon.cooldown:SetCooldown(start, duration)
    else
        if brezDesatCache ~= false then brezDesatCache = false; brezIcon.icon:SetDesaturated(false) end
        if duration > 0 then brezIcon.cooldown:SetCooldown(start, duration) else brezIcon.cooldown:Clear() end
    end
end

-- ==============================
-- 기능 3: 레이아웃 및 디스플레이
-- ==============================
local function apply_icons()
    local size = (dodo.DB and dodo.DB.bloodBrezSize) or Settings.iconsize[1]
    local padding = (dodo.DB and dodo.DB.bloodBrezPadding) or Settings.iconPadding

    -- 컨테이너(부모 프레임) 크기를 아이콘 크기와 패딩에 맞게 동적 조절
    frame:SetSize(size * 2 + padding, size)

    bloodIcon:SetSize(size, size)
    if bloodIcon.RescaleIcon then bloodIcon:RescaleIcon() end
    brezIcon:SetSize(size, size)
    if brezIcon.RescaleIcon then brezIcon:RescaleIcon() end

    brezIcon:ClearAllPoints()
    brezIcon:SetPoint("LEFT", bloodIcon, "RIGHT", padding, 0)

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
-- 모듈 On/Off 활성화 상태 제어
-- ==============================
local function update_module_state()
    local isEnabled = (dodo.DB and dodo.DB.enableBloodBrezModule ~= false)
    if not isEnabled then
        frame:Hide()
        frame:UnregisterAllEvents()
        
        if LibEditMode and LibEditMode.frameSelections and LibEditMode.frameSelections[frame] then
            LibEditMode.frameSelections[frame]:Hide()
        end
    else
        frame:Show()
        frame:RegisterUnitEvent("UNIT_AURA", "player")
        frame:RegisterEvent("SPELL_UPDATE_CHARGES")
        frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        
        update_bloodlust()
        update_brez()
        
        if LibEditMode and LibEditMode:IsInEditMode() and LibEditMode.frameSelections and LibEditMode.frameSelections[frame] then
            LibEditMode.frameSelections[frame]:ShowHighlighted()
        end
    end
end

dodo.UpdateBloodBrezModuleState = update_module_state

-- ==============================
-- 모듈 생명주기
-- ==============================
local function OnEvent(self, event, ...)
    local inEdit = LibEditMode and LibEditMode:IsInEditMode()
    if inEdit or not frame:IsShown() then return end

    if event == "UNIT_AURA" then
        update_bloodlust()
    elseif event == "SPELL_UPDATE_CHARGES" or event == "SPELL_UPDATE_COOLDOWN" then
        update_brez()
    elseif event == "PLAYER_ENTERING_WORLD" then
        update_bloodlust()
        update_brez()
    end
end

local function create_ui()
    if frame then return end

    frame = CreateFrame("Frame", "BLBR_TrackerFrame", UIParent)
    frame:SetSize(100, 50)
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", Settings.iconPositionX, Settings.iconPositionY)

    bloodIcon = LibIcon:Create("BLBR_BloodlustIcon", frame, {
        isAction = false,
        iconsize = Settings.iconsize,
    })
    bloodIcon:SetPoint("LEFT", frame, "LEFT", 0, 0)

    bloodOverlay = CreateFrame("Frame", nil, bloodIcon)
    bloodOverlay:SetAllPoints(bloodIcon)
    bloodOverlay:Hide()

    bloodOverlayGlow = bloodOverlay:CreateTexture(nil, "ARTWORK")
    bloodOverlayGlow:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
    bloodOverlayGlow:SetVertexColor(0, 1, 0, 1)
    bloodOverlayGlow:SetAllPoints(bloodOverlay)
    bloodOverlayGlow:SetBlendMode("BLEND")

    bloodOverlayTimer = bloodOverlay:CreateFontString(nil, "ARTWORK", "NumberFontNormal")
    bloodOverlayTimer:SetPoint("TOPLEFT", bloodOverlay, "TOPLEFT", 5, -5)
    bloodOverlayTimer:SetTextColor(0.1, 1, 0.1)

    brezIcon = LibIcon:Create("BLBR_BrezIcon", frame, {
        isAction = false,
        iconsize = Settings.iconsize,
    })
    brezIcon:SetPoint("LEFT", bloodIcon, "RIGHT", Settings.iconPadding, 0)
end

local function initialize()
    create_ui()

    if dodo.DB and dodo.DB.bloodBrezX and dodo.DB.bloodBrezY then
        frame:ClearAllPoints()
        frame:SetPoint(dodo.DB.bloodBrezPoint or "BOTTOMLEFT", UIParent, dodo.DB.bloodBrezPoint or "BOTTOMLEFT", dodo.DB.bloodBrezX, dodo.DB.bloodBrezY)
    end

    apply_icons()
end

local isInitialized = false
function module:OnEnable()
    initialize()
    update_bloodlust()
    update_brez()
    update_module_state()

    if isInitialized then return end
    isInitialized = true

    -- LibEditMode 등록
    frame.editModeName = "dodo 블러드 & 전투부활"
    if LibEditMode then
        LibEditMode:AddFrame(
            frame,
            function(f, layoutName, point, x, y)
                if dodo.DB then
                    dodo.DB.bloodBrezX = x
                    dodo.DB.bloodBrezY = y
                    dodo.DB.bloodBrezPoint = point
                end
            end,
            {
                point = "BOTTOMLEFT",
                x = Settings.iconPositionX,
                y = Settings.iconPositionY,
            },
            "dodo 블러드 & 전투부활"
        )

        LibEditMode:AddFrameSettings(frame, {
            {
                kind = LibEditMode.SettingType.Slider,
                name = "아이콘 크기",
                desc = "블러드 및 전투부활 아이콘 크기를 조절합니다.",
                default = 46,
                minValue = 40,
                maxValue = 70,
                valueStep = 2,
                get = function()
                    return (dodo.DB and dodo.DB.bloodBrezSize) or 46
                end,
                set = function(_, newValue)
                    if dodo.DB then
                        dodo.DB.bloodBrezSize = newValue
                    end
                    if dodo.UpdateBloodBrezLayout then
                        dodo.UpdateBloodBrezLayout()
                    end
                end,
            },
            {
                kind = LibEditMode.SettingType.Slider,
                name = "아이콘 간격",
                desc = "두 아이콘 사이의 간격을 조절합니다.",
                default = 2,
                minValue = 0,
                maxValue = 6,
                valueStep = 1,
                get = function()
                    return (dodo.DB and dodo.DB.bloodBrezPadding) or 2
                end,
                set = function(_, newValue)
                    if dodo.DB then
                        dodo.DB.bloodBrezPadding = newValue
                    end
                    if dodo.UpdateBloodBrezLayout then
                        dodo.UpdateBloodBrezLayout()
                    end
                end,
            },
        })

        if not frame.dodoHookedCallbacks then
            frame.dodoHookedCallbacks = true

            LibEditMode:RegisterCallback("enter", function()
                local isEnabled = (dodo.DB and dodo.DB.enableBloodBrezModule ~= false)
                if isEnabled then
                    frame:Show()
                    -- Mock 상태 표시
                    bloodIcon.icon:SetDesaturated(false)
                    bloodOverlay:Show()
                    bloodOverlayTimer:SetText("40")
                    brezIcon.icon:SetDesaturated(false)
                    brezIcon.Count:SetText("3")
                    brezIcon.Count:Show()
                end
            end)

            LibEditMode:RegisterCallback("exit", function()
                blPhase = "init"
                brezDesatCache = nil
                local isEnabled = (dodo.DB and dodo.DB.enableBloodBrezModule ~= false)
                if isEnabled then
                    update_bloodlust()
                    update_brez()
                else
                    frame:Hide()
                end
            end)
        end
    end

    if dodo.RegisterEditModeSetting then
        dodo.RegisterEditModeSetting("전투", {
            {
                name = "블러드 & 전투부활",
                get = function() return dodo.DB and dodo.DB.enableBloodBrezModule ~= false end,
                set = function(checked)
                    if dodo.DB then dodo.DB.enableBloodBrezModule = checked end
                    update_module_state()
                end
            }
        })
    end

    frame:SetScript("OnEvent", OnEvent)
end

-- ==============================
-- 외부 노출
-- ==============================
dodo.UpdateBloodBrezLayout = function()
    apply_icons()
    if LibEditMode and LibEditMode:IsInEditMode() then
        bloodIcon.icon:SetDesaturated(false)
        bloodOverlay:Show()
        bloodOverlayTimer:SetText("40")
        brezIcon.icon:SetDesaturated(false)
        brezIcon.Count:SetText("3")
        brezIcon.Count:Show()
    end
end