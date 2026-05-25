-- ==============================
-- Inspired damageMeterEnabled 0 / 1
-- ==============================
-- DamageMeterTools 暴雪傷害統計增強 (https://www.curseforge.com/wow/addons/damagemetertools)
-- Default DamageMeter Tweaks (https://www.curseforge.com/wow/addons/default-damagemeter-tweaks)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("DamageMeter", module)

local LibEditMode = LibStub and LibStub("LibEditMode", true)

local snapConfig = {
    point = "BOTTOM",       -- 2번 창의 기준점
    relativePoint = "TOP",  -- 1번 창의 기준점
    xOffset = 0,            -- 좌우 간격
    yOffset = 2             -- 상하 간격
}

local MAX_DAMAGE_WINDOWS = 3 -- 블리자드 지원 최대 개수

-- ==============================
-- 프레임 및 이벤트 핸들러 정의
-- ==============================
local win1
local winCache = {}    -- 모든 세션 윈도우 캐싱

-- ==============================
-- 캐싱
-- ==============================
local abs = math.abs
local CreateFrame = CreateFrame
local C_DamageMeter = C_DamageMeter
local DamageMeter = DamageMeter
local GameTooltip = GameTooltip
local hooksecurefunc = hooksecurefunc
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local issecretvalue = issecretvalue
local PlaySound = PlaySound
local SOUNDKIT = SOUNDKIT
local UIParent = UIParent
local _G = _G

local function get_session_window(i)
    if winCache[i] then return winCache[i] end
    local win = (i == 1 and DamageMeterSessionWindow1) or
                (i == 2 and DamageMeterSessionWindow2) or
                (i == 3 and DamageMeterSessionWindow3) or
                _G["DamageMeterSessionWindow"..i]
    if win then winCache[i] = win end
    return win
end

-- ==============================
-- 기능 1: 창 크기 동기화 및 스냅
-- ==============================
local function apply_window_settings(i, win1, isSyncEnabled, isSnapEnabled)
    if InCombatLockdown() then return end
    local win = get_session_window(i)
    if not win then return end

    -- 1. 크기 조절 및 버튼 잠금
    win:SetResizable(not isSyncEnabled)
    local container = win.MinimizeContainer
    local btn = container and container.ResizeButton
    if btn then
        if isSyncEnabled and btn:IsShown() then
            btn:Hide()
        elseif not isSyncEnabled and not btn:IsShown() then
            btn:Show()
            if container and not container:IsShown() then container:Show() end
        end
    end

    -- 2. 스냅 및 크기 동기화
    if isSnapEnabled and win:IsShown() then
        local prevWin = get_session_window(i-1)
        if prevWin then
            -- 위치 고정
            local point, relativeTo = win:GetPoint()
            if relativeTo ~= prevWin then
                win:ClearAllPoints()
                win:SetPoint("BOTTOMLEFT", prevWin, "TOPLEFT", snapConfig.xOffset, snapConfig.yOffset)
            end

            -- 크기 동기화
            if isSyncEnabled then
                local w1, h1 = win1:GetSize()
                local w, h = win:GetSize()
                if abs(w - w1) > 0.1 or abs(h - h1) > 0.1 then
                    win:SetSize(w1, h1)
                end
            end

            -- 이동 기능 차단
            if not win.dodoOriginalStartMoving then
                win.dodoOriginalStartMoving = win.StartMoving
            end
            win.StartMoving = function() end
            win:SetMovable(true)
            if win.SetUserPlaced then win:SetUserPlaced(false) end
        end
    else
        -- 이동 기능 복구
        if win.dodoOriginalStartMoving then
            win.StartMoving = win.dodoOriginalStartMoving
            win.dodoOriginalStartMoving = nil
        end

        local point, relativeTo = win:GetPoint()
        if relativeTo and relativeTo == get_session_window(i-1) then
            local left, bottom = win:GetLeft(), win:GetBottom()
            win:ClearAllPoints()
            if left and bottom then
                win:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
            else
                win:SetPoint("CENTER", UIParent, "CENTER", 0, (i-1)*50)
            end
            if win.SetUserPlaced then win:SetUserPlaced(true) end
        end
        win:SetMovable(true)
    end
end

-- 크기 동기화
local function sync_all_window_sizes()
    local win1 = get_session_window(1)
    if not win1 then return end

    local isModuleEnabled = dodo.DB and dodo.DB.enableDamageMeterModule ~= false
    local isSyncEnabled = isModuleEnabled and (dodo.DB and dodo.DB.useDmgMeterSyncSize ~= false)
    local isSnapEnabled = isModuleEnabled and (dodo.DB and dodo.DB.useDmgMeterSnap ~= false)

    -- 2~3번 창까지 공통 로직 적용
    for i = 2, MAX_DAMAGE_WINDOWS do
        apply_window_settings(i, win1, isSyncEnabled, isSnapEnabled)
    end
end

-- 메인 창 크기 실시간 동기화
local function hook_main_size()
    if win1 or DamageMeterSessionWindow1 then
        win1 = win1 or DamageMeterSessionWindow1
        if not win1.dodoHookedOnSize then
            win1.dodoHookedOnSize = true
            win1:HookScript("OnSizeChanged", function()
                if dodo.DB and dodo.DB.enableDamageMeterModule ~= false then
                    sync_all_window_sizes()
                end
            end)
        end
    end
end

-- ==============================
-- 기능 2: 피해량 초기화 버튼
-- ==============================
local function create_reset_button(win)
    if not win or win.dodoResetBtn then return end

    local resetBtn = CreateFrame("Button", nil, win)
    resetBtn:SetSize(30, 30)
    resetBtn:SetFrameLevel(win:GetFrameLevel() + 20)

    -- atlas
    resetBtn:SetNormalAtlas("common-dropdown-c-button")
    resetBtn:SetPushedAtlas("common-dropdown-c-button-pressed-1")
    resetBtn:SetHighlightAtlas("common-dropdown-c-button-hover-1")

    -- atlas Pushed
    resetBtn:GetNormalTexture():SetDrawLayer("BACKGROUND", 0)
    resetBtn:GetPushedTexture():SetDrawLayer("BACKGROUND", 1)

    resetBtn:SetScript("OnMouseDown", function()
        resetBtn:GetNormalTexture():SetAlpha(0)
        resetBtn:GetHighlightTexture():SetAlpha(0)
    end)
    resetBtn:SetScript("OnMouseUp", function()
        resetBtn:GetNormalTexture():SetAlpha(1)
        resetBtn:GetHighlightTexture():SetAlpha(1)
    end)

    -- atlas hover
    local highlight = resetBtn:GetHighlightTexture()
    if highlight then
        highlight:SetBlendMode("BLEND")
    end

    -- icon
    resetBtn.IconFrame = CreateFrame("Frame", nil, resetBtn)
    resetBtn.IconFrame:SetAllPoints()

    -- icon
    resetBtn.Icon = resetBtn.IconFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    resetBtn.Icon:SetPoint("CENTER", 0, 0)
    resetBtn.Icon:SetSize(14, 14)
    resetBtn.Icon:SetAtlas("UI-RefreshButton")

    if win.SessionDropdown and win.SessionDropdown:IsShown() then
        resetBtn:SetPoint("RIGHT", win.SessionDropdown, "LEFT", -4, 0)
    else
        resetBtn:SetPoint("RIGHT", win.SettingsDropdown, "LEFT", -4, 0)
    end

    -- 클릭 이벤트
    resetBtn:SetScript("OnClick", function()
        C_DamageMeter.ResetAllCombatSessions()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)

    -- 툴팁
    resetBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("피해량 초기화", 1, 1, 1)
        GameTooltip:Show()
    end)
    resetBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    win.dodoResetBtn = resetBtn
end

local function apply_reset_buttons()
    local isEnabled = dodo.DB and dodo.DB.enableDamageMeterModule ~= false and dodo.DB.useDmgMeterResetButton ~= false
    for i = 1, MAX_DAMAGE_WINDOWS do
        local win = get_session_window(i)
        if win then
            if isEnabled then
                create_reset_button(win)
                if win.dodoResetBtn then win.dodoResetBtn:Show() end
            else
                if win.dodoResetBtn then win.dodoResetBtn:Hide() end
            end
        end
    end
end

-- ==============================
-- 기능 3: 모듈 적용
-- ==============================
local function update_feature()
    sync_all_window_sizes()
    apply_reset_buttons()
end

-- ==============================
-- 모듈 On/Off 활성화 상태 제어
-- ==============================
local function update_module_state()
    update_feature()
end

dodo.UpdateDamageMeterModuleState = update_module_state

-- ==============================
-- 초기화
-- ==============================
local function initialize()
    hook_main_size()
end

-- ==============================
-- 모듈 생명주기
-- ==============================
local isInitialized = false
function module:OnEnable()
    update_feature()
    update_module_state()

    if isInitialized then return end
    isInitialized = true

    initialize()

    dodo.HookOnce(DamageMeter, "ShowNewSecondarySessionWindow", function()
        if dodo.DB and dodo.DB.enableDamageMeterModule ~= false then
            sync_all_window_sizes()
            apply_reset_buttons()
        end
    end)

    -- LibEditMode 등록
    if LibEditMode then
        local settingType = LibEditMode.SettingType
        local damageMeterSystem = Enum.EditModeSystem.DamageMeter or 10

        LibEditMode:AddSystemSettings(damageMeterSystem, {
            {
                kind = settingType.Checkbox,
                name = "창 크기 동기화",
                desc = "보조 창들의 크기를 메인 창과 동일하게 맞춥니다.",
                default = true,
                get = function()
                    return (dodo.DB and dodo.DB.useDmgMeterSyncSize ~= false)
                end,
                set = function(_, newValue)
                    if dodo.DB then dodo.DB.useDmgMeterSyncSize = newValue end
                    if dodo.DB and dodo.DB.enableDamageMeterModule ~= false then
                        sync_all_window_sizes()
                    end
                end,
            },
            {
                kind = settingType.Checkbox,
                name = "창 붙이기",
                desc = "보조 창을 메인 창 상단에 붙입니다.",
                default = true,
                get = function()
                    return (dodo.DB and dodo.DB.useDmgMeterSnap ~= false)
                end,
                set = function(_, newValue)
                    if dodo.DB then dodo.DB.useDmgMeterSnap = newValue end
                    if dodo.DB and dodo.DB.enableDamageMeterModule ~= false then
                        sync_all_window_sizes()
                    end
                end,
            },
            {
                kind = settingType.Checkbox,
                name = "초기화 버튼 생성",
                desc = "미터기 상단에 데이터 초기화(Reset) 버튼을 생성합니다.",
                default = true,
                get = function()
                    return (dodo.DB and dodo.DB.useDmgMeterResetButton ~= false)
                end,
                set = function(_, newValue)
                    if dodo.DB then dodo.DB.useDmgMeterResetButton = newValue end
                    if dodo.DB and dodo.DB.enableDamageMeterModule ~= false then
                        apply_reset_buttons()
                    end
                end,
            },
        })
    end

    if dodo.RegisterEditModeSetting then
        dodo.RegisterEditModeSetting("전투", {
            {
                name = "피해량 측정기",
                get = function() return dodo.DB and dodo.DB.enableDamageMeterModule ~= false end,
                set = function(checked)
                    if dodo.DB then dodo.DB.enableDamageMeterModule = checked end
                    update_module_state()
                end
            }
        })
    end
end