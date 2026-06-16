-- ==============================
-- Inspired
-- ==============================
-- ActionBarsEnhanced (https://www.curseforge.com/wow/addons/actionbarsenhanced)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local BAR_INDEX_MAP = dodo.BAR_INDEX_MAP

local PADDING_DEFAULTS = {
    ["MainActionBar"]       = true,
    ["MultiBarBottomLeft"]  = true,
    ["MultiBarBottomRight"] = true,
    ["MultiBarRight"]       = true,
    ["MultiBarLeft"]        = true,
    ["MultiBar5"]           = true,
    ["MultiBar6"]           = true,
    ["MultiBar7"]           = true,
    ["StanceBar"]           = true,
    ["PetActionBar"]        = true,
}

local PADDING_VAL_DEFAULTS = {
    ["MainActionBar"]       = 0,
    ["MultiBarBottomLeft"]  = 0,
    ["MultiBarBottomRight"] = 0,
    ["MultiBarRight"]       = 0,
    ["MultiBarLeft"]        = 0,
    ["MultiBar5"]           = 0,
    ["MultiBar6"]           = 0,
    ["MultiBar7"]           = 0,
    ["StanceBar"]           = 0,
    ["PetActionBar"]        = 0,
}

local PADDING_DB_KEYS = {
    ["MainActionBar"]       = "useActionbarPaddingBar1",
    ["MultiBarBottomLeft"]  = "useActionbarPaddingBar2",
    ["MultiBarBottomRight"] = "useActionbarPaddingBar3",
    ["MultiBarRight"]       = "useActionbarPaddingBar4",
    ["MultiBarLeft"]        = "useActionbarPaddingBar5",
    ["MultiBar5"]           = "useActionbarPaddingBar6",
    ["MultiBar6"]           = "useActionbarPaddingBar7",
    ["MultiBar7"]           = "useActionbarPaddingBar8",
    ["StanceBar"]           = "useActionbarPaddingBarStance",
    ["PetActionBar"]        = "useActionbarPaddingBarPet",
}

local PADDING_VAL_KEYS = {
    ["MainActionBar"]       = "actionbarPaddingBar1",
    ["MultiBarBottomLeft"]  = "actionbarPaddingBar2",
    ["MultiBarBottomRight"] = "actionbarPaddingBar3",
    ["MultiBarRight"]       = "actionbarPaddingBar4",
    ["MultiBarLeft"]        = "actionbarPaddingBar5",
    ["MultiBar5"]           = "actionbarPaddingBar6",
    ["MultiBar6"]           = "actionbarPaddingBar7",
    ["MultiBar7"]           = "actionbarPaddingBar8",
    ["StanceBar"]           = "actionbarPaddingBarStance",
    ["PetActionBar"]        = "actionbarPaddingBarPet",
}



-- ==============================
-- 캐싱
-- ==============================
local AnchorUtil = AnchorUtil
local Enum = Enum
local GridLayoutUtil = GridLayoutUtil
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local math_ceil = math.ceil
local pairs = pairs

local anchor_cache = {}
local layout_cache = {}

-- ==============================
-- 기능 구현
-- ==============================
local function is_bar_padding_enabled(barName)
    local dbKey = PADDING_DB_KEYS[barName]
    if not dbKey then return PADDING_DEFAULTS[barName] or false end
    if not dodoDB then return PADDING_DEFAULTS[barName] or false end
    local val = dodoDB[dbKey]
    if val == nil then return PADDING_DEFAULTS[barName] or false end
    return val
end

local function get_cached_anchor(anchor_point, frame)
    local key = anchor_point .. "_" .. frame:GetName()
    if not anchor_cache[key] then
        anchor_cache[key] = AnchorUtil.CreateAnchor(anchor_point, frame, anchor_point)
    end
    return anchor_cache[key]
end

local function get_cached_layout(is_horizontal, stride, pad, x_mult, y_mult)
    local key = (is_horizontal and "H" or "V") .. "_" .. stride .. "_" .. pad .. "_" .. x_mult .. "_" .. y_mult
    if not layout_cache[key] then
        if is_horizontal then
            layout_cache[key] = GridLayoutUtil.CreateStandardGridLayout(stride, pad, pad, x_mult, y_mult)
        else
            layout_cache[key] = GridLayoutUtil.CreateVerticalGridLayout(stride, pad, pad, x_mult, y_mult)
        end
    end
    return layout_cache[key]
end

local function update_padding(frame)
    if InCombatLockdown() or not frame or not frame.shownButtonContainers then return end

    local frame_name = frame:GetName()
    if not frame_name or not PADDING_DB_KEYS[frame_name] then return end

    local valKey = PADDING_VAL_KEYS[frame_name]
    local is_enabled = (dodoDB and dodoDB.enableActionbar ~= false and is_bar_padding_enabled(frame_name))
    local pad
    if is_enabled then
        pad = (dodoDB and valKey and dodoDB[valKey]) or PADDING_VAL_DEFAULTS[frame_name] or 0
    else
        pad = frame.buttonPadding or 2
    end

    local num_rows = frame.numRows or 1
    local stride   = math_ceil(#frame.shownButtonContainers / num_rows)
    local x_mult   = frame.addButtonsToRight and 1 or -1
    local y_mult   = frame.addButtonsToTop and 1 or -1
    local anchor   = frame.addButtonsToTop
        and (frame.addButtonsToRight and "BOTTOMLEFT" or "BOTTOMRIGHT")
        or  (frame.addButtonsToRight and "TOPLEFT"    or "TOPRIGHT")

    local layout = get_cached_layout(frame.isHorizontal, stride, pad, x_mult, y_mult)
    local anchor_obj = get_cached_anchor(anchor, frame)

    GridLayoutUtil.ApplyGridLayout(frame.shownButtonContainers, anchor_obj, layout)
    if frame.Layout then frame:Layout() end
end
dodo.ActionbarUpdatePadding = update_padding

dodo.ActionbarApplyPadding = function()
    local bars = {
        MainActionBar, MultiBarBottomLeft, MultiBarBottomRight,
        MultiBarRight, MultiBarLeft, MultiBar5, MultiBar6, MultiBar7,
        StanceBar, PetActionBar
    }
    for _, bar in ipairs(bars) do
        if bar then
            update_padding(bar)
        end
    end
end

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    for idx, barName in pairs(BAR_INDEX_MAP) do
        local sysID    = string.format("%d_%d", Enum.EditModeSystem.ActionBar, idx)
        local enableKey = PADDING_DB_KEYS[barName]
        local valKey    = PADDING_VAL_KEYS[barName]
        dodo.RegisterEditModeSystemSetting(sysID, {
            {
                name = "아이콘: 간격",
                get = function()
                    if not dodoDB then return PADDING_DEFAULTS[barName] or false end
                    local val = dodoDB[enableKey]
                    return val == nil and (PADDING_DEFAULTS[barName] or false) or val
                end,
                set = function(checked)
                    if dodoDB then dodoDB[enableKey] = checked end
                    local bar = _G[barName]
                    if bar then update_padding(bar) end
                end,
                disabled = function() return dodoDB and dodoDB.enableActionbar == false end
            },
            {
                name = "버튼 간격",
                type = "slider",
                get = function()
                    if not dodoDB then return PADDING_VAL_DEFAULTS[barName] or 0 end
                    local val = dodoDB[valKey]
                    return val == nil and (PADDING_VAL_DEFAULTS[barName] or 0) or val
                end,
                set = function(val)
                    if dodoDB then dodoDB[valKey] = val end
                    local bar = _G[barName]
                    if bar then update_padding(bar) end
                end,
                minVal = -5,
                maxVal = 10,
                step = 1,
                disabled = function()
                    return (dodoDB and dodoDB.enableActionbar == false)
                        or not is_bar_padding_enabled(barName)
                end
            }
        })
    end
end
