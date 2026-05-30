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

local FeaturePaddingBars = {
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

-- ==============================
-- 캐싱
-- ==============================
local AnchorUtil = AnchorUtil
local Enum = Enum
local GridLayoutUtil = GridLayoutUtil
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local math_ceil = math.ceil

local anchor_cache = {}
local layout_cache = {}

-- ==============================
-- 기능 구현
-- ==============================
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
    if not frame_name or not FeaturePaddingBars[frame_name] then return end

    local is_enabled = (dodoDB and dodoDB.enableActionbar ~= false and dodoDB.useActionbarPadding ~= false)
    local pad
    if is_enabled then
        pad = dodoDB.actionbarPadding or 0
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
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.ActionBar, {
        {
            name = "아이콘: 간격",
            get = function() return dodoDB and dodoDB.useActionbarPadding ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useActionbarPadding = checked end
                dodo.ActionbarApplyPadding()
            end,
            disabled = function() return dodoDB and dodoDB.enableActionbar == false end
        },
        {
            name = "버튼 간격",
            type = "slider",
            get = function() return dodoDB and dodoDB.actionbarPadding or 0 end,
            set = function(val)
                if dodoDB then dodoDB.actionbarPadding = val end
                dodo.ActionbarApplyPadding()
            end,
            minVal = -5,
            maxVal = 10,
            step = 1,
            disabled = function() return dodoDB and (dodoDB.enableActionbar == false or dodoDB.useActionbarPadding == false) end
        }
    })
end
