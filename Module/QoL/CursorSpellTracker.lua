-- ==============================
-- Inspired
-- ==============================
-- CursorSpellTracker 핵심 엔진(커서 추종 + 쿨다운 준비알림 + 버프 지속시간 표시) 단순 포팅

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local UIParent = UIParent
local C_Spell = C_Spell
local C_SpellBook = C_SpellBook
local C_UnitAuras = C_UnitAuras
local C_Timer = C_Timer
local issecretvalue = issecretvalue or function() return false end
local ipairs = ipairs
local math_abs = math.abs

-- ==============================
-- Config (기본값 - 위치/크기 수정은 여기서)
-- ==============================
local Config = {
    iconSize = 28, -- 아이콘 크기
    offsetX = 42,  -- 커서 기준 X 오프셋
    offsetY = -34, -- 커서 기준 Y 오프셋
    iconGap = 2,   -- 아이콘 간 간격
}

-- ==============================
-- 트래킹 대상 (specID별, 확장 포인트)
-- ==============================
-- type: "cooldown" (쿨다운 준비알림, 차지 지원) | "aura" (버프 스택+지속시간 표시)
local TRACKED_SPELLS_BY_SPEC = {
    [264] = { -- 복원 주술사
        { spellID = 77130, type = "cooldown" }, -- 영혼정화
        { spellID = 61295, type = "cooldown", glowAuraSpellID = 53390 }, -- 성난해일 (굽이치는 물결 보유시 반짝임)
    },
}

-- ==============================
-- 로컬 상태
-- ==============================
local iconHolder
local icons = {}
local active_spells = {}
local lastCursorX, lastCursorY = -1, -1
local anyVisible = false
local stateElapsed = 0
local STATE_INTERVAL = 0.2

-- ==============================
-- 유틸
-- ==============================
local function safe_num(value)
    if value == nil or issecretvalue(value) then return 0 end
    return value
end

-- GetPlayerAuraBySpellID 누락 케이스 대비 인덱스 스캔 보강 (CST ReadAuraBySpellIDSafe 참고)
local function find_player_aura(spellID)
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
    if aura then return aura end

    for i = 1, 40 do
        local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not a then break end
        local sid = a.spellId
        if not issecretvalue(sid) and sid == spellID then return a end
    end
    return nil
end

-- ==============================
-- 아이콘 생성 (UI/Icon.lua LibIcon:Create 디자인 차용)
-- ==============================
local function rescale_icon(f)
    local margin = math.max(2, f:GetWidth() * 0.07)
    f.icon:ClearAllPoints()
    f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", margin, -margin)
    f.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -margin, margin)
end

local function create_icon(index)
    local f = CreateFrame("Frame", nil, iconHolder)
    f:Hide()
    f:SetSize(Config.iconSize, Config.iconSize)

    f.icon = f:CreateTexture(nil, "BACKGROUND")
    f.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    rescale_icon(f)

    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints(f.icon)
    f.cooldown:SetFrameLevel(f:GetFrameLevel() + 1)
    f.cooldown:SetDrawEdge(false)
    f.cooldown:SetDrawSwipe(true)
    f.cooldown:SetSwipeColor(0, 0, 0, 0.8)

    local overlay = CreateFrame("Frame", nil, f)
    overlay:SetAllPoints(f)
    overlay:SetFrameLevel(f:GetFrameLevel() + 2)

    f.border = overlay:CreateTexture(nil, "ARTWORK")
    f.border:SetAtlas("UI-HUD-ActionBar-IconFrame")
    f.border:SetAllPoints(f)

    f.count = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    f.count:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -2, 2)
    f.count:SetTextColor(dodo.Colors.Gold.r, dodo.Colors.Gold.g, dodo.Colors.Gold.b)

    icons[index] = f
end

-- ==============================
-- 커서 추종
-- ==============================
local function update_cursor_position()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    x, y = x / scale, y / scale
    if math_abs(x - lastCursorX) < 0.5 and math_abs(y - lastCursorY) < 0.5 then return end
    lastCursorX, lastCursorY = x, y

    iconHolder:ClearAllPoints()
    iconHolder:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
        x + Config.offsetX,
        y + Config.offsetY)
end

-- ==============================
-- 상태 평가 + 렌더
-- ==============================
local function update_cooldown_icon(icon, entry)
    local spellID = entry.spellID
    if not (C_SpellBook.IsSpellInSpellBook(spellID) or C_SpellBook.IsSpellKnown(spellID)) then
        if icon.glowOverlay then icon.glowOverlay:Update(false) end
        icon:Hide()
        return false
    end

    local startTime, duration = 0, 0
    local charges = C_Spell.GetSpellCharges(spellID)
    if charges and charges.maxCharges and charges.maxCharges > 1 then
        local current = safe_num(charges.currentCharges)
        icon.count:SetText(current > 1 and current or "")
        startTime, duration = safe_num(charges.cooldownStartTime), safe_num(charges.cooldownDuration)
    else
        icon.count:SetText("")
        local cd = C_Spell.GetSpellCooldown(spellID)
        if cd then
            startTime, duration = safe_num(cd.startTime), safe_num(cd.duration)
        end
    end

    icon.cooldown:SetCooldown(startTime, duration)

    if entry.glowAuraSpellID then
        if not icon.glowOverlay then
            icon.glowOverlay = CreateFrame("Frame", nil, icon, "PotionOverlayTemplate")
            icon.glowOverlay:SetAllPoints(icon)
            icon.glowOverlay:SetFrameLevel(icon:GetFrameLevel() + 3)
            local glowSize = Config.iconSize * 1.4
            icon.glowOverlay.Proc:SetSize(glowSize, glowSize)
        end
        icon.glowOverlay:Update(find_player_aura(entry.glowAuraSpellID) ~= nil)
    end

    icon:Show()
    return true
end

local function update_aura_icon(icon, entry)
    local aura = find_player_aura(entry.spellID)
    if not aura then
        icon:Hide()
        return false
    end

    local duration, expirationTime = safe_num(aura.duration), safe_num(aura.expirationTime)
    if duration > 0 then
        icon.cooldown:SetCooldown(expirationTime - duration, duration)
    else
        icon.cooldown:Clear()
    end

    local applications = safe_num(aura.applications)
    icon.count:SetText(applications > 1 and applications or "")

    icon:Show()
    return true
end

-- ==============================
-- 레이아웃/표시
-- ==============================
local function update_visual()
    local size = Config.iconSize
    local visibleIndex = 0

    for i, entry in ipairs(active_spells) do
        local icon = icons[i]
        local shown
        if entry.type == "aura" then
            shown = update_aura_icon(icon, entry)
        else
            shown = update_cooldown_icon(icon, entry)
        end

        if shown then
            icon:SetSize(size, size)
            rescale_icon(icon)
            icon:ClearAllPoints()
            icon:SetPoint("LEFT", iconHolder, "LEFT", visibleIndex * (size + Config.iconGap), 0)
            visibleIndex = visibleIndex + 1
        end
    end

    anyVisible = visibleIndex > 0
end

local function hide_all_icons()
    for i = 1, #icons do
        if icons[i].glowOverlay then icons[i].glowOverlay:Update(false) end
        icons[i]:Hide()
    end
    anyVisible = false
end

-- ==============================
-- spec별 트래킹 목록 갱신
-- ==============================
local function setup_icons()
    for i, entry in ipairs(active_spells) do
        if not icons[i] then create_icon(i) end
        icons[i].icon:SetTexture(C_Spell.GetSpellTexture(entry.spellID))
    end
    for i = #active_spells + 1, #icons do
        icons[i]:Hide()
    end
end

local SPEC_RETRY_DELAY = 1
local SPEC_MAX_RETRIES = 10
local spec_retry_count = 0

local function refresh_active_spells()
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex)
    if not specID then
        if spec_retry_count < SPEC_MAX_RETRIES then
            spec_retry_count = spec_retry_count + 1
            C_Timer.After(SPEC_RETRY_DELAY, refresh_active_spells)
        end
        return
    end

    spec_retry_count = 0
    active_spells = TRACKED_SPELLS_BY_SPEC[specID] or {}
    if iconHolder then
        setup_icons()
        update_visual()
    end
end

-- ==============================
-- OnUpdate
-- ==============================
local trackerFrame = CreateFrame("Frame")
trackerFrame:Hide()

local function on_update(self, elapsed)
    if anyVisible then
        update_cursor_position()
    end

    stateElapsed = stateElapsed + elapsed
    if stateElapsed >= STATE_INTERVAL then
        stateElapsed = 0
        update_visual()
    end
end
trackerFrame:SetScript("OnUpdate", on_update)

-- ==============================
-- 초기화
-- ==============================
local function initialize()
    if dodoDB.enableCursorSpellTracker == nil then dodoDB.enableCursorSpellTracker = true end

    iconHolder = CreateFrame("Frame", "dodoCursorSpellTrackerHolder", UIParent)
    iconHolder:SetSize(1, 1)
    iconHolder:SetFrameStrata("TOOLTIP")

    refresh_active_spells()

    if dodoDB.enableCursorSpellTracker then
        trackerFrame:Show()
    end
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local initFrame = CreateFrame("Frame")

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
    elseif event == "PLAYER_LOGIN" then
        initialize()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 == "player" then
        refresh_active_spells()
    end
end

initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
initFrame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("편의기능", {
        {
            name = "커서 스펠 트래커",
            get = function() return dodoDB.enableCursorSpellTracker ~= false end,
            set = function(checked)
                dodoDB.enableCursorSpellTracker = checked
                if checked then
                    trackerFrame:Show()
                else
                    trackerFrame:Hide()
                    hide_all_icons()
                end
            end
        },
    })
end
