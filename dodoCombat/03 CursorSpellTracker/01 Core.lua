-- ==============================
-- Inspired
-- ==============================
-- CursorSpellTracker 핵심 엔진(커서 추종 + 쿨다운 준비알림 + 버프 지속시간 표시) 단순 포팅

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local AuraUtil = AuraUtil
local BuffBarCooldownViewer = BuffBarCooldownViewer
local BuffIconCooldownViewer = BuffIconCooldownViewer
local C_CooldownViewer = C_CooldownViewer
local C_Spell = C_Spell
local C_SpellBook = C_SpellBook
local C_Timer = C_Timer
local C_UnitAuras = C_UnitAuras
local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local issecretvalue = issecretvalue or function() return false end
local math_abs = math.abs
local math_max = math.max
local pairs = pairs
local pcall = pcall
local rawget = rawget
local type = type
local UIParent = UIParent
local wipe = wipe

-- ==============================
-- Config (글로우 - 크기/위치/열 배치는 /dd 설정창, 99 Options.lua)
-- ==============================
local Config = {
    -- 글로우(반짝임) 색상. 원본 아틀라스가 노란 계열이라 색은 곱연산으로 적용됨.
    glowColor = dodo.Colors.PrimarySoft.SoftGreen,
    glowAlpha = 0.6, -- 글로우 투명도 (1 = 불투명, 0 = 안 보임)
}

local D = dodo.COMBAT_DEFAULTS
local ROW_BY_GROUP = dodo.CST_ROW_BY_GROUP
local GROUP_ORDER = dodo.CST_GROUP_ORDER

local ordered_group = {} -- GROUP_ORDER에 있는 group 조회용 (로드 시 1회)
for _, group in ipairs(GROUP_ORDER) do ordered_group[group] = true end

local function cfg(key)
    local v = dodoDB[key]
    if v == nil then return D[key] end
    return v
end

-- ==============================
-- 트래킹 대상 (specID별 스펠 데이터는 00 Data.lua)
-- ==============================
local TRACKED_SPELLS_BY_SPEC = dodo.CST_SPELLS_BY_SPEC

-- 쿨다운/충전/알려진 주문 변화 → 다음 프레임 1회 재평가 (0.2초 폴링 대체)
local STATE_EVENTS = { "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "SPELLS_CHANGED" }

-- ==============================
-- 로컬 상태
-- ==============================
local icon_holder
local icons = {}
local active_spells = {}
local last_cursor_x, last_cursor_y = -1, -1
local any_visible = false
local cached_scale = 1

local state_dirty = true     -- 재평가 필요 (이벤트/훅에서 세움)
local layout_dirty = true    -- 아이콘 표시 구성 변경 → 재배치 필요
local tracker_running = false

-- 레이아웃 캐시 (ApplyLayout / 초기화에서만 갱신, 매 틱 cfg 조회 제거)
local icon_size, step, row_step, two_rows = 26, 26, 26, true
local offset_x, offset_y = 0, 0

local function refresh_layout_cache()
    icon_size = cfg("cursorSpellTrackerIconSize")
    step = icon_size + cfg("cursorSpellTrackerIconGap")     -- 가로 (아이콘 간격)
    row_step = icon_size + cfg("cursorSpellTrackerRowGap")  -- 세로 (열 간격)
    two_rows = cfg("cursorSpellTrackerRowCount") == "2"
    offset_x = cfg("cursorSpellTrackerX")
    offset_y = cfg("cursorSpellTrackerY")
end

-- 파일 스코프 프레임 (CPU 집계 기준 = 생성 시점 애드온)
local tracker_frame = CreateFrame("Frame") -- OnUpdate: 커서 추종 + dirty 재평가
tracker_frame:Hide()
local init_frame = CreateFrame("Frame")    -- 이벤트 수신

-- 이벤트/훅에서 호출: 할당 0, 실제 평가는 다음 프레임 OnUpdate에서 1회로 합침
local function request_update()
    state_dirty = true
    if tracker_running then tracker_frame:Show() end
end

-- ==============================
-- 유틸
-- ==============================
-- 전투 중 쿨다운/충전/오라 수치는 secret value로 반환됨 (WoW 12.x).
-- secret은 비교/연산 시 Lua 에러를 던지므로 issecretvalue로 걸러내고,
-- 판정 불가 시 기존 표시를 유지한다 (0으로 뭉개지 않음).
local function readable_num(value)
    if value == nil or issecretvalue(value) or type(value) ~= "number" then return nil end
    return value
end

-- 전투 중 targeted helper가 secret/nil을 반환해도 "존재함"으로 처리하기 위한 sentinel.
-- 수치 필드가 전부 nil이므로 지속시간/스택 표시는 생략되고 존재 판정만 가능.
local AURA_SECRET_PRESENT = { secretPresent = true }

local function find_player_aura(spellID)
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
    if aura then
        if type(aura) == "table" then return aura end
        -- 전투 중 secret/비테이블 반환: ID 지정 조회가 non-nil이면 존재로 간주 (CST acceptAura)
        return AURA_SECRET_PRESENT
    end

    if AuraUtil and AuraUtil.FindAuraBySpellID then
        local auraF = AuraUtil.FindAuraBySpellID(spellID, "player", "HELPFUL")
        if auraF then
            if type(auraF) == "table" then return auraF end
            return AURA_SECRET_PRESENT
        end
    end

    return nil
end

-- ==============================
-- CDM(쿨다운 관리자) 버프 미러링 (OverlayCDM 방식)
-- ==============================
-- 전투 중에는 아우라 조회 API가 전부 막히므로 (targeted 조회 nil, 인덱스 스캔
-- spellId secret) 버프 존재 판정은 CDM 뷰어 item 프레임으로 통일한다.
-- item 연결: OnCooldownIDSet 훅 (Acquire 시점엔 cooldownID가 아직 nil - RefreshData에서 설정됨)
-- 활성 변화: OnAuraInstanceInfoSet/Cleared 훅 → dirty만 세우고 다음 프레임에 판정
--           (훅 시점엔 IsShown이 아직 이전 값)
local cdm_tracked_items = {} -- CDM item 프레임 -> 우리쪽 aura spellID (관심 항목만)
local cdm_hooked = {}        -- item 프레임 -> true (item당 훅 1회)

local function cdm_match_aura_id(sid)
    if not sid then return nil end
    for _, entry in ipairs(active_spells) do
        if entry.glowAuraSpellID and (sid == entry.glowAuraSpellID or sid == entry.glowCDMSpellID) then
            return entry.glowAuraSpellID
        end
    end
    return nil
end

-- item이 현재 표시 중인 cooldownID를 우리 트래킹 대상과 매칭
-- (item 프레임은 풀에서 재사용되므로 cooldownID가 바뀔 수 있음)
local function update_cdm_item(item)
    local auraID
    local cooldownID = item.cooldownID
    if cooldownID and C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo then
        local cdInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
        if cdInfo and type(cdInfo) == "table" then
            auraID = cdm_match_aura_id(readable_num(cdInfo.spellID))
            if not auraID and type(cdInfo.linkedSpellIDs) == "table" then
                for _, lid in ipairs(cdInfo.linkedSpellIDs) do
                    auraID = cdm_match_aura_id(readable_num(lid))
                    if auraID then break end
                end
            end
        end
    end
    cdm_tracked_items[item] = auraID
end

-- item 훅 콜백 (정적 함수, 익명 클로저 없음)
local function on_cdm_cooldown_id_set(item)
    local prev = cdm_tracked_items[item]
    update_cdm_item(item)
    -- 우리 대상으로 연결되거나 연결이 풀리면 글로우 재판정
    if prev or cdm_tracked_items[item] then request_update() end
end

local function on_cdm_aura_changed(item) -- 인자(secret 가능)는 쓰지 않음
    if cdm_tracked_items[item] then request_update() end
end

local function hook_cdm_item(item)
    if cdm_hooked[item] or not item.OnCooldownIDSet then return end
    cdm_hooked[item] = true
    hooksecurefunc(item, "OnCooldownIDSet", on_cdm_cooldown_id_set)
    if item.OnAuraInstanceInfoSet then hooksecurefunc(item, "OnAuraInstanceInfoSet", on_cdm_aura_changed) end
    if item.OnAuraInstanceInfoCleared then hooksecurefunc(item, "OnAuraInstanceInfoCleared", on_cdm_aura_changed) end
end

-- hooksecurefunc(viewer, "OnAcquireItemFrame") 콜백
local function on_acquire_item_frame(_, item)
    hook_cdm_item(item)
    update_cdm_item(item)
end

-- 뷰어 1개 스캔 (뷰어 목록 테이블 생성 없이 직접 호출)
local function scan_cdm_viewer(viewer)
    if not (viewer and viewer.GetItemFrames) then return end
    local ok, items = pcall(viewer.GetItemFrames, viewer)
    if ok and type(items) == "table" then
        for _, item in ipairs(items) do
            hook_cdm_item(item)
            update_cdm_item(item)
        end
    end
end

-- 로그인/특성 변경 시에만 호출 (주기 재스캔 없음)
local function rescan_cdm_items()
    for item in pairs(cdm_tracked_items) do update_cdm_item(item) end
    scan_cdm_viewer(BuffIconCooldownViewer)
    scan_cdm_viewer(BuffBarCooldownViewer)
end

local cdm_hooks_installed = false
local function init_cdm_hooks()
    if cdm_hooks_installed then return end
    cdm_hooks_installed = true
    if BuffIconCooldownViewer then pcall(hooksecurefunc, BuffIconCooldownViewer, "OnAcquireItemFrame", on_acquire_item_frame) end
    if BuffBarCooldownViewer then pcall(hooksecurefunc, BuffBarCooldownViewer, "OnAcquireItemFrame", on_acquire_item_frame) end
    rescan_cdm_items()
end

local function is_cdm_aura_active(auraSpellID)
    for item, auraID in pairs(cdm_tracked_items) do
        if auraID == auraSpellID and item:IsShown() then
            -- auraInstanceID는 secret일 수 있음: secret이면 값 존재 = 활성
            local aid = rawget(item, "auraInstanceID")
            if issecretvalue(aid) or aid ~= nil then return true end
        end
    end
    return false
end

-- ==============================
-- 아이콘 생성 (UI/Icon.lua LibIcon:Create 디자인 차용)
-- ==============================
local function rescale_icon(f)
    local margin = math_max(2, f:GetWidth() * 0.07)
    f.icon:ClearAllPoints()
    f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", margin, -margin)
    f.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -margin, margin)
end

local function create_icon(index)
    local f = CreateFrame("Frame", nil, icon_holder)
    f:Hide()
    f.cst_shown = false
    f:SetSize(icon_size, icon_size)

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
    f.count:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 1, 1)
    f.count:SetTextColor(dodo.Colors.Primary.Gold.r, dodo.Colors.Primary.Gold.g, dodo.Colors.Primary.Gold.b)

    icons[index] = f
end

-- ==============================
-- 커서 추종
-- ==============================
-- 앵커 1개(CENTER)만 쓰므로 같은 point SetPoint는 덮어쓰기 → ClearAllPoints는 초기화 시 1회
local function update_cursor_position()
    local x, y = GetCursorPosition()
    x, y = x / cached_scale, y / cached_scale
    if math_abs(x - last_cursor_x) < 0.5 and math_abs(y - last_cursor_y) < 0.5 then return end
    last_cursor_x, last_cursor_y = x, y
    icon_holder:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x + offset_x, y + offset_y)
end

-- ==============================
-- 상태 평가 (표시 여부만 반환, Show/Hide는 update_visual에서 변화 시에만)
-- ==============================
local function update_cooldown_icon(icon, entry)
    local spellID = entry.spellID
    if not (C_SpellBook.IsSpellInSpellBook(spellID) or C_SpellBook.IsSpellKnown(spellID)) then
        if icon.glowOverlay then icon.glowOverlay:Update(false) end
        return false
    end

    -- 비전투/전투 공통: DurationObject를 Cooldown 프레임에 직접 넘김
    -- (secret 수치를 애드온이 만지지 않고 블리자드가 렌더링, maxCharges/isActive는 NeverSecret)
    local dur
    local charges = C_Spell.GetSpellCharges(spellID)
    if charges and charges.maxCharges > 1 then
        icon.count:SetText(charges.currentCharges) -- secret도 FontString에 그대로 전달 가능
        icon.has_count = true
        if charges.isActive then dur = C_Spell.GetSpellChargeDuration(spellID) end -- 재충전 스와이프
    else
        if icon.has_count then
            icon.count:SetText("")
            icon.has_count = false
        end
        local cd = C_Spell.GetSpellCooldown(spellID)
        if cd and cd.isActive then
            dur = C_Spell.GetSpellCooldownDuration(spellID, true) -- ignoreGCD: GCD만 걸리면 0 → 스와이프 없음
        end
    end
    if dur then
        pcall(icon.cooldown.SetCooldownFromDurationObject, icon.cooldown, dur, true) -- true: 0이면 Clear
    else
        icon.cooldown:Clear()
    end

    if entry.glowAuraSpellID then
        if not icon.glowOverlay then
            icon.glowOverlay = CreateFrame("Frame", nil, icon, "PotionOverlayTemplate")
            icon.glowOverlay:SetAllPoints(icon)
            icon.glowOverlay:SetFrameLevel(icon:GetFrameLevel() + 3)
            local glowSize = icon_size * 1.4
            icon.glowOverlay.Proc:SetSize(glowSize, glowSize)
            local gc = Config.glowColor
            if gc then
                icon.glowOverlay.Proc:SetVertexColor(gc.r or 1, gc.g or 1, gc.b or 1, Config.glowAlpha or 1)
            end
        end
        icon.glowOverlay:Update(is_cdm_aura_active(entry.glowAuraSpellID))
    end

    return true
end

local function update_aura_icon(icon, entry)
    local aura = find_player_aura(entry.spellID)
    if not aura then return false end

    local duration = readable_num(aura.duration)
    local expirationTime = readable_num(aura.expirationTime)
    if duration and expirationTime then
        if duration > 0 then
            icon.cooldown:SetCooldown(expirationTime - duration, duration)
        else
            icon.cooldown:Clear()
        end
    end
    -- 전투 중 secret이면 기존 표시 유지 (0으로 초기화하지 않음)

    local applications = readable_num(aura.applications)
    if applications then
        icon.count:SetText(applications)
    elseif aura.applications == nil or not pcall(icon.count.SetText, icon.count, aura.applications) then
        icon.count:SetText("")
    end

    return true
end

-- ==============================
-- 레이아웃/표시
-- ==============================
local row_counts = { 0, 0 } -- 열별 표시 개수 (재사용, 가비지 방지)

local function place_icon(icon, entry)
    local row = two_rows and ROW_BY_GROUP[entry.group] or 1
    icon:ClearAllPoints()
    -- 1열이 기준(하단), 2열은 1열 위에 가로 배치
    icon:SetPoint("LEFT", icon_holder, "LEFT", row_counts[row] * step, (row - 1) * row_step)
    row_counts[row] = row_counts[row] + 1
end

-- 표시 구성이 바뀔 때만 재배치. 같은 열 안은 GROUP_ORDER 순 → 나머지 group은 데이터 순
local function relayout()
    layout_dirty = false
    row_counts[1], row_counts[2] = 0, 0
    for g = 1, #GROUP_ORDER do
        local group = GROUP_ORDER[g]
        for i, entry in ipairs(active_spells) do
            if entry.group == group and icons[i].cst_shown then place_icon(icons[i], entry) end
        end
    end
    for i, entry in ipairs(active_spells) do
        if not ordered_group[entry.group] and icons[i].cst_shown then place_icon(icons[i], entry) end
    end
    any_visible = row_counts[1] + row_counts[2] > 0
end

local function update_visual()
    for i, entry in ipairs(active_spells) do
        local icon = icons[i]
        local shown
        if entry.type == "aura" then
            shown = update_aura_icon(icon, entry)
        else
            shown = update_cooldown_icon(icon, entry)
        end
        if shown ~= icon.cst_shown then
            icon.cst_shown = shown
            icon:SetShown(shown)
            layout_dirty = true
        end
    end
    if layout_dirty then relayout() end
end

local function hide_all_icons()
    for i = 1, #icons do
        local icon = icons[i]
        if icon.glowOverlay then icon.glowOverlay:Update(false) end
        icon.cst_shown = false
        icon:Hide()
    end
    any_visible = false
    layout_dirty = true
end

-- ==============================
-- OnUpdate (보이는 아이콘 있을 때만 실행)
-- ==============================
local function on_update(self)
    if state_dirty then
        state_dirty = false
        update_visual()
        if not any_visible then
            self:Hide() -- 표시할 게 없으면 다음 이벤트까지 비용 0
            return
        end
    end
    update_cursor_position()
end
tracker_frame:SetScript("OnUpdate", on_update)

-- 토글 꺼짐 또는 현재 특성 추적 대상 없음 → 상태 이벤트 해제 + OnUpdate 정지 (자원소모 0)
local function update_tracker_running()
    tracker_running = dodoDB.enableCursorSpellTracker ~= false and #active_spells > 0
    for i = 1, #STATE_EVENTS do
        if tracker_running then
            init_frame:RegisterEvent(STATE_EVENTS[i])
        else
            init_frame:UnregisterEvent(STATE_EVENTS[i])
        end
    end
    if tracker_running then
        request_update()
    else
        tracker_frame:Hide()
        hide_all_icons()
    end
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
        local icon = icons[i]
        if icon.glowOverlay then icon.glowOverlay:Update(false) end
        icon.cst_shown = false
        icon:Hide()
    end
    layout_dirty = true -- 슬롯별 주문이 바뀌었을 수 있음
end

-- 기본 데이터(00 Data.lua) - 사용자 끈 주문 + 사용자 추가 주문 합성 (원본 표 불변, 결과 테이블 재사용)
-- dodoDB.cursorSpellTrackerDisabled = { [specID] = { [spellID] = true(사용자 끔) | false(사용자 켬) } }
--   nil = 사용자 미변경 → 데이터 기본값 (entry.enabled == false 면 꺼짐)
-- dodoDB.cursorSpellTrackerCustom   = { [specID] = { { spellID = , group = }, ... } }
-- 판정 규칙은 99 Options Preview.lua cst_is_disabled와 동일하게 유지
local merged_spells = {}

local function is_entry_disabled(disabled, entry)
    local v = disabled and disabled[entry.spellID]
    if v == nil then return entry.enabled == false end
    return v
end

local function build_active_spells(specID)
    wipe(merged_spells)
    local disabledBySpec = dodoDB.cursorSpellTrackerDisabled
    local disabled = disabledBySpec and disabledBySpec[specID]

    local base = TRACKED_SPELLS_BY_SPEC[specID]
    if base then
        for _, entry in ipairs(base) do
            if not is_entry_disabled(disabled, entry) then
                merged_spells[#merged_spells + 1] = entry
            end
        end
    end

    local customBySpec = dodoDB.cursorSpellTrackerCustom
    local custom = customBySpec and customBySpec[specID]
    if custom then
        for _, entry in ipairs(custom) do
            if not is_entry_disabled(disabled, entry) then
                merged_spells[#merged_spells + 1] = entry -- type 없음 = cooldown 처리
            end
        end
    end
    return merged_spells
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
    active_spells = build_active_spells(specID)
    rescan_cdm_items()
    if icon_holder then
        setup_icons()
        update_tracker_running()
    end
end

-- ==============================
-- 이벤트
-- ==============================
-- 토글 ON일 때만 특성/배율 이벤트 수신 (OFF 시 백그라운드 자원소모 0)
local function set_events(enabled)
    if enabled then
        init_frame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
        init_frame:RegisterEvent("UI_SCALE_CHANGED")
        init_frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
    else
        init_frame:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        init_frame:UnregisterEvent("UI_SCALE_CHANGED")
        init_frame:UnregisterEvent("DISPLAY_SIZE_CHANGED")
    end
end

-- ==============================
-- 초기화
-- ==============================
local function initialize()
    if dodoDB.enableCursorSpellTracker == nil then dodoDB.enableCursorSpellTracker = true end
    refresh_layout_cache()

    icon_holder = CreateFrame("Frame", "dodoCursorSpellTrackerHolder", UIParent)
    icon_holder:SetSize(1, 1)
    icon_holder:SetFrameStrata("TOOLTIP")
    icon_holder:ClearAllPoints()

    init_cdm_hooks()
    C_Timer.After(1, rescan_cdm_items) -- CDM 뷰어 초기화가 늦는 경우 대비 (OverlayCDM의 0.5s 지연과 동일 목적)

    set_events(dodoDB.enableCursorSpellTracker ~= false)
    refresh_active_spells()
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_event(self, event)
    -- 고빈도 이벤트 먼저: dirty만 세움 (페이로드 spellID는 secret 여부 불명확 → 미사용, 전체 재평가)
    if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" or event == "SPELLS_CHANGED" then
        request_update()
    elseif event == "PLAYER_LOGIN" then
        cached_scale = UIParent:GetEffectiveScale()
        initialize()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        refresh_active_spells()
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        cached_scale = UIParent:GetEffectiveScale()
        last_cursor_x, last_cursor_y = -1, -1
    end
end

init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 공개 API
-- ==============================
function dodo.CursorSpellTrackerSetEnabled(val)
    set_events(val)
    if val then
        -- OFF 동안 놓친 특성 변경/배율 변경 반영
        cached_scale = UIParent:GetEffectiveScale()
        refresh_active_spells()
    else
        update_tracker_running()
    end
end

-- 설정창 크기/간격/위치/열 배치 변경 즉시 반영
function dodo.CursorSpellTrackerApplyLayout()
    refresh_layout_cache()
    for i = 1, #icons do
        local f = icons[i]
        f:SetSize(icon_size, icon_size)
        rescale_icon(f)
        if f.glowOverlay then f.glowOverlay.Proc:SetSize(icon_size * 1.4, icon_size * 1.4) end
    end
    last_cursor_x, last_cursor_y = -1, -1 -- 다음 프레임에 오프셋 재적용
    layout_dirty = true
    request_update()
end

-- 미리보기용 현재 특성 추적 목록
function dodo.CursorSpellTrackerGetActiveSpells()
    return active_spells
end

-- 설정창 주문 목록 편집(끄기/추가/삭제) 후 현재 특성 목록 재구성
function dodo.CursorSpellTrackerRefreshSpells()
    refresh_active_spells()
end
