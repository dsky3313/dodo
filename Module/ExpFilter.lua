-- ==============================
-- Inspired
-- ==============================
-- Default 'Current expansion only' filter (https://wago.io/FW6qfBuIH)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱 (가나다 순 정렬)
-- ==============================
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local RunNextFrame = RunNextFrame
local type = type

local craftRetries = 0

-- ==============================
-- 동작 로직 (EnhanceQoL 완벽 이식 - 가비지 프리)
-- ==============================

-- 경매장 필터 적용 프레임 틱
local function on_auction_filter_next_frame()
    local frame = AuctionHouseFrame
    local searchBar = frame and frame.SearchBar
    local filterButton = searchBar and searchBar.FilterButton
    
    if filterButton and type(filterButton.filters) == "table" then
        filterButton.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
        searchBar:UpdateClearFiltersButton()
    end
end

-- 경매장 필터 적용
local function ApplyAuctionFilter()
    if dodoDB.useAuctionFilter == false then return end
    if not (Enum and Enum.AuctionHouseFilter and Enum.AuctionHouseFilter.CurrentExpansionOnly) then return end

    RunNextFrame(on_auction_filter_next_frame)
end

-- 주문 제작 필터 적용 프레임 틱 (최대 3프레임 재시도)
local function on_craft_filter_next_frame()
    local frame = ProfessionsCustomerOrdersFrame
    local browseOrders = frame and frame.BrowseOrders
    local searchBar = browseOrders and browseOrders.SearchBar
    local filterDropdown = searchBar and searchBar.FilterDropdown

    -- 블리자드 UI 초기화가 지연될 경우 최대 3프레임까지 재시도
    if not filterDropdown or type(filterDropdown.filters) ~= "table" then
        if craftRetries > 0 then
            craftRetries = craftRetries - 1
            RunNextFrame(on_craft_filter_next_frame)
        end
        return
    end

    filterDropdown.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
    if filterDropdown.ValidateResetState then filterDropdown:ValidateResetState() end
end

-- 주문 제작 필터 적용 (초기화 지연 대비 재시도 로직 포함)
local function ApplyCraftFilter(remainingRetries)
    if dodoDB.useCraftFilter == false then return end
    if not (Enum and Enum.AuctionHouseFilter and Enum.AuctionHouseFilter.CurrentExpansionOnly) then return end

    craftRetries = remainingRetries or 0
    RunNextFrame(on_craft_filter_next_frame)
end

-- ==============================
-- 외부 노출 (Option.lua 호환성)
-- ==============================
dodo.AuctionFilter = function()
    ApplyAuctionFilter()
    ApplyCraftFilter(3)
end
dodo.expFilter = dodo.AuctionFilter

-- ==============================
-- 이벤트 핸들러 (가비지 프리 정적 참조)
-- ==============================
local function on_event(self, event)
    if event == "AUCTION_HOUSE_SHOW" then
        ApplyAuctionFilter()
    elseif event == "CRAFTINGORDERS_SHOW_CUSTOMER" then
        -- 주문 제작 창은 최대 3번 재시도
        ApplyCraftFilter(3)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- 로딩이 끝난 후 혹시 창이 열려있는 상태라면 바로 적용
        C_Timer.After(1, dodo.AuctionFilter)
    end
end

-- ==============================
-- 전역 이벤트 리스너
-- ==============================
local f = CreateFrame("Frame")
-- 설정 적용 및 애드온 로드 직후 확인용
f:RegisterEvent("PLAYER_ENTERING_WORLD")
-- 실제 블리자드 UI 창이 열릴 때 발생하는 전용 이벤트
f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:RegisterEvent("CRAFTINGORDERS_SHOW_CUSTOMER")
f:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 동적 등록 (Option.lua 연동)
-- ==============================
local SettingsPanel = SettingsPanel
local Checkbox = Checkbox

dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["interface"] = dodo.OptionRegistrations["interface"] or {}
table.insert(dodo.OptionRegistrations["interface"], function(category)
    local layout = SettingsPanel:GetLayout(category)
    if not layout then return end

    Checkbox(category, "useAuctionFilter", "경매장 필터", "경매장에서 '현행 확장팩 전용'을 자동 활성화합니다.", true, dodo.expFilter)
    Checkbox(category, "useCraftFilter", "주문제작 필터", "주문제작에서 '현행 확장팩 전용'을 자동 활성화합니다.", true, dodo.expFilter)
end)