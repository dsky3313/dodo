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
-- 캐싱
-- ==============================
local C_Timer = C_Timer
local Checkbox = Checkbox
local CreateFrame = CreateFrame
local Enum = Enum
local RunNextFrame = RunNextFrame
local type = type

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
local craft_retries = 0
local main_frame = CreateFrame("Frame")

-- ==============================
-- 기능 2: 상태 업데이트
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
local function apply_auction_filter()
    if dodoDB.enableExpFilter == false then return end
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
        if craft_retries > 0 then
            craft_retries = craft_retries - 1
            RunNextFrame(on_craft_filter_next_frame)
        end
        return
    end

    filterDropdown.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
    if filterDropdown.ValidateResetState then filterDropdown:ValidateResetState() end
end

-- 주문 제작 필터 적용 (초기화 지연 대비 재시도 로직 포함)
local function apply_craft_filter(remaining_retries)
    if dodoDB.enableExpFilter == false then return end
    if not (Enum and Enum.AuctionHouseFilter and Enum.AuctionHouseFilter.CurrentExpansionOnly) then return end

    craft_retries = remaining_retries or 0
    RunNextFrame(on_craft_filter_next_frame)
end

-- 동적 이벤트 제어 및 비활성화 시 자원 소모 0화
local function update_events()
    local is_enabled = dodoDB.enableExpFilter ~= false

    if is_enabled then
        main_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        main_frame:RegisterEvent("AUCTION_HOUSE_SHOW")
        main_frame:RegisterEvent("CRAFTINGORDERS_SHOW_CUSTOMER")
    else
        main_frame:UnregisterAllEvents()
    end
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function apply_all_filters()
    apply_auction_filter()
    apply_craft_filter(3)
end

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
    elseif event == "PLAYER_LOGIN" then
        if dodoDB.enableExpFilter == nil then dodoDB.enableExpFilter = true end
        update_events()
        self:UnregisterEvent("ADDON_LOADED")
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "AUCTION_HOUSE_SHOW" then
        apply_auction_filter()
    elseif event == "CRAFTINGORDERS_SHOW_CUSTOMER" then
        apply_craft_filter(3)
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, apply_all_filters)
    end
end

main_frame:RegisterEvent("ADDON_LOADED")
main_frame:RegisterEvent("PLAYER_LOGIN")
main_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["인터페이스.편의기능"] = dodo.OptionRegistrations["인터페이스.편의기능"] or {}
table.insert(dodo.OptionRegistrations["인터페이스.편의기능"], function(category)
    Checkbox(category, "enableExpFilter", "확장팩 필터", "경매장/주문 제작창을 열 때 자동으로 현재 확장팩 필터를 적용합니다.", true, function(value)
        update_events()
        if value then apply_all_filters() end
    end)
end)