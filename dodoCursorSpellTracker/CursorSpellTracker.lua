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
local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local UIParent = UIParent
local C_Spell = C_Spell
local C_SpellBook = C_SpellBook
local C_UnitAuras = C_UnitAuras
local C_Timer = C_Timer
local C_CooldownViewer = C_CooldownViewer
local GetTime = GetTime
local BuffBarCooldownViewer = BuffBarCooldownViewer
local BuffIconCooldownViewer = BuffIconCooldownViewer
local hooksecurefunc = hooksecurefunc
local pairs = pairs
local rawget = rawget
local issecretvalue = issecretvalue or function() return false end
local ipairs = ipairs
local math_abs = math.abs
local pcall = pcall
local type = type

-- ==============================
-- Config (글로우 - 크기/위치/열 배치는 /dd 설정창, 99 Options.lua)
-- ==============================
local Config = {
    -- 글로우(반짝임) 색상. 원본 아틀라스가 노란 계열이라 색은 곱연산으로 적용됨.
    -- 원본 그대로: r=1, g=1, b=1
    glowColor = { r = 0.2, g = 1.0, b = 0.2 },
    glowAlpha = 0.6, -- 글로우 투명도 (1 = 불투명, 0 = 안 보임)
}

local D = dodo.CST_DEFAULTS
local ROW_BY_GROUP = dodo.CST_ROW_BY_GROUP

local function cfg(key)
    local v = dodoDB[key]
    if v == nil then return D[key] end
    return v
end

-- ==============================
-- 트래킹 대상 (specID별, 확장 포인트)
-- ==============================
-- type: "cooldown" (쿨다운 준비알림, 차지 지원) | "aura" (버프 스택+지속시간 표시)
-- group: "interrupt" | "cc" ... (ROW_BY_GROUP 참고, 배치 열 결정)
local TRACKED_SPELLS_BY_SPEC = {
    -- 전사
    [71] = { -- 무기
        { spellID = 6552, type = "cooldown", group = "interrupt" }, -- 차단
        { spellID = 107570, type = "cooldown", group = "cc" }, -- 폭망
        { spellID = 46968, type = "cooldown", group = "cc" }, -- 충파
        -- { spellID = 5246, type = "cooldown", group = "cc" }, -- 공포
    },
    [72] = { -- 분노
        { spellID = 6552, type = "cooldown", group = "interrupt" }, -- 차단
        { spellID = 107570, type = "cooldown", group = "cc" }, -- 폭망
        { spellID = 46968, type = "cooldown", group = "cc" }, -- 충파
        -- { spellID = 5246, type = "cooldown", group = "cc" }, -- 공포
    },
    [73] = { -- 방어
        { spellID = 6552, type = "cooldown", group = "interrupt" }, -- 차단
        { spellID = 107570, type = "cooldown", group = "cc" }, -- 폭망
        { spellID = 46968, type = "cooldown", group = "cc" }, -- 충파
        -- { spellID = 5246, type = "cooldown", group = "cc" }, -- 공포
    },
    -- 성기사
    [65] = {},   -- 신성
    [66] = {},   -- 보호
    [70] = {},   -- 징벌
    -- 사냥꾼
    [253] = {},  -- 야수
    [254] = {},  -- 사격
    [255] = {},  -- 생존
    -- 도적
    [259] = {},  -- 암살
    [260] = {},  -- 무법
    [261] = {},  -- 잠행
    -- 사제
    [256] = {},  -- 수양
    [257] = {},  -- 신성
    [258] = {},  -- 암흑
    -- 죽음의 기사
    [250] = {},  -- 혈기
    [251] = {},  -- 냉기
    [252] = {},  -- 부정
    -- 주술사
    [262] = {},  -- 정기
    [263] = {},  -- 고양
    -- 마법사
    [62] = {},   -- 비전
    [63] = {},   -- 화염
    [64] = {},   -- 냉기
    -- 흑마법사
    [265] = {},  -- 고통
    [266] = {},  -- 악마
    [267] = {},  -- 파괴
    -- 수도사
    [268] = {},  -- 양조
    [270] = {},  -- 운무
    [269] = {},  -- 풍운
    -- 드루이드
    [102] = {},  -- 조화
    [103] = {},  -- 야성
    [104] = {},  -- 수호
    [105] = {},  -- 회복
    -- 악마사냥꾼
    [577] = {},  -- 파멸
    [581] = {},  -- 복수
    [1480] = {}, -- 포식
    -- 기원사
    [1467] = {}, -- 황폐
    [1468] = {}, -- 보존
    [1473] = {}, -- 증강

    [264] = { -- 복원 주술사
        { spellID = 57994, type = "cooldown", group = "interrupt" }, -- 영혼정화
        { spellID = 77130, type = "cooldown", group = "interrupt" }, -- 영혼정화
        -- 성난해일 (굽이치는 물결 보유시 반짝임)
        -- glowCDMSpellID: 블리자드 CDM 추적 버프에는 버프 ID(53390)가 아닌 특성 ID(51564)로 등록됨
        { spellID = 61295, type = "cooldown", glowAuraSpellID = 53390, glowCDMSpellID = 51564 },
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
local cached_scale = 1

-- ==============================
-- 유틸
-- ==============================
-- 전투 중 쿨다운/충전/오라 수치는 secret value로 반환됨 (WoW 12.x).
-- secret은 비교/연산 시 Lua 에러를 던지므로 판정은 반드시 pcall 내부에서 수행하고,
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
-- 블리자드가 item 프레임에 심는 auraInstanceID 필드를 rawget으로 읽는 방식으로,
-- OverlayCDM(단축바 강화효과 오버레이)에서 전투 중 동작이 검증된 경로.
local cdm_tracked_items = {} -- CDM item 프레임 -> 우리쪽 aura spellID (관심 항목만)
local cdm_rescan_at = 0

local function cdm_match_aura_id(sid)
    if not sid then return nil end
    for _, entry in ipairs(active_spells) do
        if entry.glowAuraSpellID and (sid == entry.glowAuraSpellID or sid == entry.glowCDMSpellID) then
            return entry.glowAuraSpellID
        end
    end
    return nil
end

-- item이 현재 표시 중인 cooldownID를 우리 트래킹 대상과 매칭 (RefreshData마다 갱신 -
-- item 프레임은 풀에서 재사용되므로 cooldownID가 바뀔 수 있음)
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

local function hook_cdm_item(item)
    update_cdm_item(item)
end

local function rescan_cdm_items()
    for item in pairs(cdm_tracked_items) do update_cdm_item(item) end
    local viewers = { BuffIconCooldownViewer, BuffBarCooldownViewer }
    for i = 1, #viewers do
        local viewer = viewers[i]
        if viewer and viewer.GetItemFrames then
            local ok, items = pcall(viewer.GetItemFrames, viewer)
            if ok and type(items) == "table" then
                for _, item in ipairs(items) do hook_cdm_item(item) end
            end
        end
    end
end

local cdm_hooks_installed = false
local function init_cdm_hooks()
    if cdm_hooks_installed then return end
    cdm_hooks_installed = true
    local viewers = { BuffIconCooldownViewer, BuffBarCooldownViewer }
    for i = 1, #viewers do
        local viewer = viewers[i]
        if viewer then
            pcall(hooksecurefunc, viewer, "OnAcquireItemFrame", function(_, item) hook_cdm_item(item) end)
        end
    end
    rescan_cdm_items()
end

local function is_cdm_aura_active(auraSpellID)
    local matched = false
    for item, auraID in pairs(cdm_tracked_items) do
        if auraID == auraSpellID then
            matched = true
            -- 활성 판정은 훅 시점이 아니라 매 폴링마다 item 필드를 직접 읽음 (OverlayCDM 방식)
            if item:IsShown() and rawget(item, "auraInstanceID") ~= nil then
                return true
            end
        end
    end
    if not matched then
        -- 로그인/특성 변경 직후 CDM item을 아직 못 찾은 경우 재스캔 (5초 스로틀)
        local now = GetTime()
        if now - cdm_rescan_at > 5 then
            cdm_rescan_at = now
            rescan_cdm_items()
        end
    end
    return false
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
    local size = cfg("cursorSpellTrackerIconSize")
    f:SetSize(size, size)

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
local function update_cursor_position()
    local x, y = GetCursorPosition()
    x, y = x / cached_scale, y / cached_scale
    if math_abs(x - lastCursorX) < 0.5 and math_abs(y - lastCursorY) < 0.5 then return end
    lastCursorX, lastCursorY = x, y

    iconHolder:ClearAllPoints()
    iconHolder:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
        x + cfg("cursorSpellTrackerX"),
        y + cfg("cursorSpellTrackerY"))
end

-- ==============================
-- 상태 평가 + 렌더
-- ==============================
-- GCD만 걸린 상태 판정 (isOnGCD도 secret일 수 있어 먼저 검증)
local function is_on_gcd(cd)
    local onGCD = cd and cd.isOnGCD
    return not issecretvalue(onGCD) and onGCD == true
end

local function update_cooldown_icon(icon, entry)
    local spellID = entry.spellID
    if not (C_SpellBook.IsSpellInSpellBook(spellID) or C_SpellBook.IsSpellKnown(spellID)) then
        if icon.glowOverlay then icon.glowOverlay:Update(false) end
        icon:Hide()
        return false
    end

    local charges = C_Spell.GetSpellCharges(spellID)
    local maxCharges = charges and readable_num(charges.maxCharges)
    -- 전투 중 maxCharges가 secret(nil)이어도 charges 테이블 존재 = 충전 스킬로 간주
    local isChargeSpell = charges ~= nil and (maxCharges == nil or maxCharges > 1)

    if isChargeSpell then
        local current = readable_num(charges.currentCharges)
        if current then
            icon.count:SetText(current)
        elseif not pcall(icon.count.SetText, icon.count, charges.currentCharges) then
            -- secret 충전 수는 FontString이 직접 표시 가능 (CST SafeSetText 방식)
            icon.count:SetText("")
        end
    else
        icon.count:SetText("")
    end

    local startTime, duration
    if isChargeSpell then
        startTime = readable_num(charges.cooldownStartTime)
        duration = readable_num(charges.cooldownDuration)
    else
        local cd = C_Spell.GetSpellCooldown(spellID)
        if is_on_gcd(cd) then
            -- GCD는 쿨다운으로 표시 안 함 (CST duration<=1.5 필터 대응)
            startTime, duration = 0, 0
        elseif cd then
            startTime = readable_num(cd.startTime)
            duration = readable_num(cd.duration)
        else
            startTime, duration = 0, 0
        end
    end

    if startTime and duration then
        icon.cooldown:SetCooldown(startTime, duration)
    elseif is_on_gcd(C_Spell.GetSpellCooldown(spellID)) then
        -- 전투 중 충전 스킬 폴백 경로도 GCD면 스와이프 생략
        icon.cooldown:Clear()
    elseif C_Spell.GetSpellCooldownDuration and icon.cooldown.SetCooldownFromDurationObject then
        -- 전투 중 secret: DurationObject를 Cooldown 프레임에 직접 넘겨
        -- 애드온이 secret 수치를 만지지 않고 블리자드가 렌더링 (CST 방식)
        local ok, durObj = pcall(C_Spell.GetSpellCooldownDuration, spellID)
        if ok and durObj then
            pcall(icon.cooldown.SetCooldownFromDurationObject, icon.cooldown, durObj, true)
        end
    end

    if entry.glowAuraSpellID then
        if not icon.glowOverlay then
            icon.glowOverlay = CreateFrame("Frame", nil, icon, "PotionOverlayTemplate")
            icon.glowOverlay:SetAllPoints(icon)
            icon.glowOverlay:SetFrameLevel(icon:GetFrameLevel() + 3)
            local glowSize = cfg("cursorSpellTrackerIconSize") * 1.4
            icon.glowOverlay.Proc:SetSize(glowSize, glowSize)
            local gc = Config.glowColor
            if gc then
                icon.glowOverlay.Proc:SetVertexColor(gc.r or 1, gc.g or 1, gc.b or 1, Config.glowAlpha or 1)
            end
        end
        icon.glowOverlay:Update(is_cdm_aura_active(entry.glowAuraSpellID))
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

    icon:Show()
    return true
end

-- ==============================
-- 레이아웃/표시
-- ==============================
local row_counts = { 0, 0 } -- 열별 표시 개수 (재사용, 가비지 방지)

local function update_visual()
    local size = cfg("cursorSpellTrackerIconSize")
    local step = size + cfg("cursorSpellTrackerIconGap")    -- 가로 (아이콘 간격)
    local rowStep = size + cfg("cursorSpellTrackerRowGap")  -- 세로 (열 간격)
    local twoRows = cfg("cursorSpellTrackerRowCount") == "2"
    row_counts[1], row_counts[2] = 0, 0

    for i, entry in ipairs(active_spells) do
        local icon = icons[i]
        local shown
        if entry.type == "aura" then
            shown = update_aura_icon(icon, entry)
        else
            shown = update_cooldown_icon(icon, entry)
        end

        if shown then
            local row = twoRows and ROW_BY_GROUP[entry.group] or 1
            icon:ClearAllPoints()
            -- 1열이 기준(하단), 2열은 1열 위에 가로 배치
            icon:SetPoint("LEFT", iconHolder, "LEFT", row_counts[row] * step, (row - 1) * rowStep)
            row_counts[row] = row_counts[row] + 1
        end
    end

    anyVisible = row_counts[1] + row_counts[2] > 0
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

local update_tracker_running -- trackerFrame 생성 후 정의

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
    rescan_cdm_items()
    if iconHolder then
        setup_icons()
        update_visual()
        update_tracker_running()
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

-- 토글 꺼짐 또는 현재 특성 추적 대상 없음 → OnUpdate 정지 (자원소모 0)
update_tracker_running = function()
    if dodoDB.enableCursorSpellTracker ~= false and #active_spells > 0 then
        trackerFrame:Show()
    else
        trackerFrame:Hide()
        hide_all_icons()
    end
end

-- ==============================
-- 초기화
-- ==============================
local function initialize()
    if dodoDB.enableCursorSpellTracker == nil then dodoDB.enableCursorSpellTracker = true end

    iconHolder = CreateFrame("Frame", "dodoCursorSpellTrackerHolder", UIParent)
    iconHolder:SetSize(1, 1)
    iconHolder:SetFrameStrata("TOOLTIP")

    init_cdm_hooks()
    C_Timer.After(1, rescan_cdm_items) -- CDM 뷰어 초기화가 늦는 경우 대비 (OverlayCDM의 0.5s 지연과 동일 목적)

    refresh_active_spells()
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local initFrame = CreateFrame("Frame")

local function on_event(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        cached_scale = UIParent:GetEffectiveScale()
        initialize()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 == "player" then
        refresh_active_spells()
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        cached_scale = UIParent:GetEffectiveScale()
    end
end

initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
initFrame:RegisterEvent("UI_SCALE_CHANGED")
initFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
initFrame:SetScript("OnEvent", on_event)

-- ==============================
-- 공개 API
-- ==============================
function dodo.CursorSpellTrackerSetEnabled(val)
    update_tracker_running()
end

-- 설정창 크기/간격/위치/열 배치 변경 즉시 반영
function dodo.CursorSpellTrackerApplyLayout()
    local size = cfg("cursorSpellTrackerIconSize")
    for i = 1, #icons do
        local f = icons[i]
        f:SetSize(size, size)
        rescale_icon(f)
        if f.glowOverlay then f.glowOverlay.Proc:SetSize(size * 1.4, size * 1.4) end
    end
    lastCursorX, lastCursorY = -1, -1 -- 다음 프레임에 오프셋 재적용
    if trackerFrame:IsShown() then update_visual() end
end

-- 미리보기용 현재 특성 추적 목록
function dodo.CursorSpellTrackerGetActiveSpells()
    return active_spells
end
