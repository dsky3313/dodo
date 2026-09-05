-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local Checkbox            = Checkbox
local CreateFrame         = CreateFrame
local BreakUpLargeNumbers = BreakUpLargeNumbers
local hooksecurefunc      = hooksecurefunc
local IsInInstance        = IsInInstance
local pcall               = pcall

-- ==============================
-- 상태
-- ==============================
local combined_label
local bag_label
local icon_size      = 12
local bag_open       = false
local combined_open  = false
local event_frame    = CreateFrame("Frame")

-- ==============================
-- 갱신
-- ==============================
local function update_display(label)
    if not label then return end
    if not (C_WowTokenPublic and C_WowTokenPublic.GetCurrentMarketPrice) then return end
    local price = C_WowTokenPublic.GetCurrentMarketPrice()
    if price and price > 0 then
        local gold = BreakUpLargeNumbers(math.floor(price / 10000))
        label:SetText("|A:wow-token-gold:" .. icon_size .. ":" .. icon_size .. "|a " .. gold)
        label:Show()
    end
end

local function update_visible()
    if combined_open then update_display(combined_label) end
    if bag_open      then update_display(bag_label)      end
end

-- ==============================
-- 가방 열기/닫기 훅
-- ==============================
local function on_bag_show(label)
    if not dodoDB or dodoDB.enableToken == false then return end
    if IsInInstance() then return end
    if C_WowTokenPublic and C_WowTokenPublic.UpdateMarketPrice then
        pcall(C_WowTokenPublic.UpdateMarketPrice)
    end
    event_frame:RegisterEvent("TOKEN_MARKET_PRICE_UPDATED")
    update_display(label)
end

local function on_bag_hide(label)
    event_frame:UnregisterEvent("TOKEN_MARKET_PRICE_UPDATED")
    if label then label:Hide() end
end

local function on_combined_show() combined_open = true;  on_bag_show(combined_label) end
local function on_combined_hide() combined_open = false; on_bag_hide(combined_label) end
local function on_bag1_show()    bag_open = true;       on_bag_show(bag_label)      end
local function on_bag1_hide()    bag_open = false;      on_bag_hide(bag_label)      end

event_frame:SetScript("OnEvent", function(self, event)
    if event == "TOKEN_MARKET_PRICE_UPDATED" then update_visible() end
end)

-- ==============================
-- 초기화
-- ==============================
local function make_label(parent, anchor_frame)
    -- ContainerFrame1MoneyFrameGoldButtonText 에서 폰트·색상 복사
    local ref = _G["ContainerFrame1MoneyFrameGoldButtonText"]
    local fp, fs, ff = STANDARD_TEXT_FONT, 12, ""
    local r, g, b    = 1, 1, 1
    if ref then
        fp, fs, ff = ref:GetFont()
        r, g, b    = ref:GetTextColor()
        fp = fp or STANDARD_TEXT_FONT
        fs = fs or 12
        ff = ff or ""
    end
    icon_size = math.floor(fs + 0.5)

    local lbl = parent:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(fp, fs, ff)
    lbl:SetPoint("BOTTOMRIGHT", anchor_frame, "BOTTOMRIGHT", -8, -16)
    lbl:SetTextColor(r or 1, g or 1, b or 1, 1)
    lbl:Hide()
    return lbl
end

local init_frame = CreateFrame("Frame")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", function(self, event)
    if dodoDB.enableToken == nil then dodoDB.enableToken = true end

    -- 합쳐진 가방
    if ContainerFrameCombinedBags then
        combined_label = make_label(ContainerFrameCombinedBags, ContainerFrameCombinedBags)
        hooksecurefunc(ContainerFrameCombinedBags, "Show", on_combined_show)
        hooksecurefunc(ContainerFrameCombinedBags, "Hide", on_combined_hide)
    end

    -- 개별 가방: 훅은 ContainerFrame1, 앵커는 ContainerFrameContainer(전체 가방 영역)
    if ContainerFrame1 then
        local anchor = ContainerFrameContainer or ContainerFrame1
        bag_label = make_label(ContainerFrame1, anchor)
        hooksecurefunc(ContainerFrame1, "Show", on_bag1_show)
        hooksecurefunc(ContainerFrame1, "Hide", on_bag1_hide)
    end

    self:UnregisterEvent("PLAYER_LOGIN")
end)

-- ==============================
-- 설정 등록
-- ==============================
dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["편의기능.편의기능"] = dodo.OptionRegistrations["편의기능.편의기능"] or {}
table.insert(dodo.OptionRegistrations["편의기능.편의기능"], function(category)
    dodo.UI:SettingsCheckbox(category, "enableToken", "가방 토큰 시세", "가방을 열 때 현재 와우 토큰 시세를 표시합니다. 인스턴스 내부에서는 표시되지 않습니다.", true, nil)
end)
