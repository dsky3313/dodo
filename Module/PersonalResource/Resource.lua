-- ==============================
-- Inspired
-- ==============================
-- dodo PersonalResource - 텍스트 레이아웃 커스터마이징

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...

local PR = dodo.PersonalResource
if not PR then return end

local DEFAULT_FONT_SIZE = 12

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc
local PersonalResourceDisplayFrame = PersonalResourceDisplayFrame

-- ==============================
-- 로컬 상태
-- ==============================
local original_sizes = {}
local is_active = false
local hooks_installed = false

-- ==============================
-- 폰트 유틸
-- ==============================
local function save_original(fs)
    if not fs or original_sizes[fs] then return end
    local _, size = fs:GetFont()
    if size then original_sizes[fs] = size end
end

local function set_font(fs, size)
    if not fs then return end
    local font, _, flags = fs:GetFont()
    if font then fs:SetFont(font, size, flags) end
end

local function restore_font(fs)
    if not fs then return end
    local font, _, flags = fs:GetFont()
    if font and original_sizes[fs] then
        fs:SetFont(font, original_sizes[fs], flags)
    end
end

-- ==============================
-- 레이아웃 (훅에서 매 갱신마다 호출)
-- ==============================
local function apply_layout(bar)
    if not is_active then return end
    if bar.LeftText then bar.LeftText:Hide() end
    if bar.RightText then
        bar.RightText:ClearAllPoints()
        bar.RightText:SetPoint("CENTER", bar, "TOP", 0, 0)
    end
end

local function install_hooks(bars)
    if hooks_installed then return end
    hooks_installed = true
    for i = 1, #bars do
        local bar = bars[i]
        if bar then
            hooksecurefunc(bar, "UpdateTextStringWithValues", apply_layout)
        end
    end
end

-- ==============================
-- 적용
-- ==============================
local function apply_font_size()
    local prd = PersonalResourceDisplayFrame
    if not prd then return end

    local db = dodo.DB or dodoDB
    if not db then return end

    local bars = {
        prd.HealthBarsContainer and prd.HealthBarsContainer.healthBar,
        prd.PowerBar,
        prd.AlternatePowerBar,
    }

    for i = 1, #bars do
        local bar = bars[i]
        if bar then
            save_original(bar.TextString)
            save_original(bar.LeftText)
            save_original(bar.RightText)
        end
    end

    local enabled = db.enablePersonalResource ~= false
    is_active = enabled

    if enabled then
        install_hooks(bars)
        local size = db.personalResourceFontSize or DEFAULT_FONT_SIZE
        for i = 1, #bars do
            local bar = bars[i]
            if bar then
                set_font(bar.TextString, size)
                set_font(bar.LeftText, size)
                set_font(bar.RightText, size)
                apply_layout(bar)
            end
        end
    else
        for i = 1, #bars do
            local bar = bars[i]
            if bar then
                restore_font(bar.TextString)
                restore_font(bar.LeftText)
                restore_font(bar.RightText)
                if bar.UpdateTextString then bar:UpdateTextString() end
            end
        end
    end
end

PR.ApplyFontSize = apply_font_size

-- ==============================
-- 이벤트 핸들러
-- ==============================
local eventFrame = CreateFrame("Frame")

local function on_event(self, event)
    apply_font_size()
end

eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록 (A방법: PRD 날개 패널)
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.PersonalResourceDisplay, {
        {
            name = "텍스트 크기 커스텀",
            get  = function() return dodo.DB and dodo.DB.enablePersonalResource ~= false end,
            set  = function(v)
                if dodo.DB then dodo.DB.enablePersonalResource = v end
                apply_font_size()
            end,
        },
        {
            name   = "텍스트 크기",
            type   = "slider",
            minVal = 8,
            maxVal = 20,
            step   = 1,
            get    = function() return dodo.DB and dodo.DB.personalResourceFontSize or DEFAULT_FONT_SIZE end,
            set    = function(v)
                if dodo.DB then dodo.DB.personalResourceFontSize = v end
                apply_font_size()
            end,
        },
    })
end
