-- ==============================
-- Inspired
-- ==============================
-- DamageMeterTools 暴雪傷害統計增強 (https://www.curseforge.com/wow/addons/damagemetertools)
-- Damage Meter Anchored (https://www.curseforge.com/wow/addons/damage-meter-anchored)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- 스냅 설정 (수정 가능)
local snap_config = {
    point = "BOTTOM",       -- 2번 창의 기준점
    relativePoint = "TOP",  -- 1번 창의 기준점
    xOffset = 0,            -- 좌우 간격
    yOffset = 2             -- 상하 간격
}

local max_damage_windows = 3

-- ==============================
-- 캐싱
-- ==============================
local InCombatLockdown = InCombatLockdown
local UIParent = UIParent
local _G = _G
local abs = math.abs

local win_1
local win_cache = {}

local function get_session_window(i)
    if win_cache[i] then return win_cache[i] end
    local win = (i == 1 and DamageMeterSessionWindow1) or
                (i == 2 and DamageMeterSessionWindow2) or
                (i == 3 and DamageMeterSessionWindow3) or
                _G["DamageMeterSessionWindow"..i]
    if win then win_cache[i] = win end
    return win
end

local function apply_window_settings(i, main_win, is_sync_enabled, is_snap_enabled)
    if InCombatLockdown() then return end
    local win = get_session_window(i)
    if not win then return end

    -- 1. 크기 조절 및 버튼 잠금
    win:SetResizable(not is_sync_enabled)
    local container = win.MinimizeContainer
    local btn = container and container.ResizeButton
    if btn then
        if is_sync_enabled and btn:IsShown() then
            btn:Hide()
        elseif not is_sync_enabled and not btn:IsShown() then
            btn:Show()
            if container and not container:IsShown() then container:Show() end
        end
    end

    -- 2. 스냅 및 크기 동기화
    if is_snap_enabled and win:IsShown() then
        local prev_win = get_session_window(i-1)
        if prev_win then
            -- 위치 고정
            local point, relative_to = win:GetPoint()
            if relative_to ~= prev_win then
                win:ClearAllPoints()
                win:SetPoint("BOTTOMLEFT", prev_win, "TOPLEFT", snap_config.xOffset, snap_config.yOffset)
            end

            -- 크기 동기화
            if is_sync_enabled then
                local w1, h1 = main_win:GetSize()
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

        local point, relative_to = win:GetPoint()
        if relative_to and relative_to == get_session_window(i-1) then
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
    local main_win = get_session_window(1)
    if not main_win then return end

    local is_enabled = dodoDB and dodoDB.enableDamageMeter ~= false
    local is_sync_enabled = is_enabled and dodoDB.dmgMeterSyncSize ~= false
    local is_snap_enabled = is_enabled and dodoDB.dmgMeterSnap ~= false

    for i = 2, max_damage_windows do
        apply_window_settings(i, main_win, is_sync_enabled, is_snap_enabled)
    end
end

-- 메인 창 크기 실시간 동기화 정적 핸들러
local function on_main_size_changed()
    local is_enabled = dodoDB and dodoDB.enableDamageMeter ~= false
    if not is_enabled then return end
    sync_all_window_sizes()
end

local is_hooked = false
local function hook_main_size()
    if is_hooked then return end
    win_1 = win_1 or DamageMeterSessionWindow1
    if win_1 then
        win_1:HookScript("OnSizeChanged", on_main_size_changed)
        is_hooked = true
    end
end

local function update_state()
    local is_enabled = dodoDB and dodoDB.enableDamageMeter ~= false
    local is_sync_enabled = is_enabled and dodoDB.dmgMeterSyncSize ~= false
    local is_snap_enabled = is_enabled and dodoDB.dmgMeterSnap ~= false

    if is_enabled and (is_sync_enabled or is_snap_enabled) then
        hook_main_size()
        sync_all_window_sizes()
    else
        -- 비활성화 상태 복원
        for i = 2, max_damage_windows do
            local win = get_session_window(i)
            if win then
                win:SetResizable(true)
                local container = win.MinimizeContainer
                local btn = container and container.ResizeButton
                if btn and not btn:IsShown() then
                    btn:Show()
                end
                if win.dodoOriginalStartMoving then
                    win.StartMoving = win.dodoOriginalStartMoving
                    win.dodoOriginalStartMoving = nil
                end
                win:SetMovable(true)
            end
        end
    end
end

-- 외부 바인딩 노출
dodo.UpdateDamageMeterSyncState = update_state
dodo.SyncDamageMeterSize = sync_all_window_sizes
