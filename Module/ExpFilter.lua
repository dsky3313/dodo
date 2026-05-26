-- ==============================
-- Inspired
-- ==============================
-- Default 'Current expansion only' filter (https://wago.io/FW6qfBuIH)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("ExpFilter", module)

-- ==============================
-- 캐싱
-- ==============================
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local RunNextFrame = RunNextFrame or (C_Timer and C_Timer.After and function(func) C_Timer.After(0, func) end)

-- ==============================
-- 기능 1: 필터 적용
-- ==============================

local function do_auction_filter()
    local frame = AuctionHouseFrame
    local searchBar = frame and frame.SearchBar
    local filterButton = searchBar and searchBar.FilterButton
    
    if filterButton and filterButton.filters then
        filterButton.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
        searchBar:UpdateClearFiltersButton()
    end
end

local function apply_auction_filter()
    if not dodo.DB or dodo.DB.enableExpFilterModule == false then return end
    if not (Enum and Enum.AuctionHouseFilter and Enum.AuctionHouseFilter.CurrentExpansionOnly) then return end

    RunNextFrame(do_auction_filter)
end

local current_craft_retries = 0
local function do_craft_filter()
    local frame = ProfessionsCustomerOrdersFrame
    local browseOrders = frame and frame.BrowseOrders
    local searchBar = browseOrders and browseOrders.SearchBar
    local filterDropdown = searchBar and searchBar.FilterDropdown

    if not filterDropdown or not filterDropdown.filters then
        if current_craft_retries > 0 then
            current_craft_retries = current_craft_retries - 1
            RunNextFrame(do_craft_filter)
        end
        return
    end

    filterDropdown.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
    if filterDropdown.ValidateResetState then filterDropdown:ValidateResetState() end
end

local function apply_craft_filter(remaining_retries)
    if not dodo.DB or dodo.DB.enableExpFilterModule == false then return end
    if not (Enum and Enum.AuctionHouseFilter and Enum.AuctionHouseFilter.CurrentExpansionOnly) then return end

    current_craft_retries = remaining_retries or 0
    RunNextFrame(do_craft_filter)
end

-- ==============================
-- 기능 2: 외부 노출 및 이벤트 연동
-- ==============================
local function apply_filters()
    apply_auction_filter()
    apply_craft_filter(3)
end

-- ==============================
-- 초기화
-- ==============================
local function initialize()
    if dodo.DB and dodo.DB.enableExpFilterModule == nil then
        dodo.DB.enableExpFilterModule = false
    end
end

-- ==============================
-- 모듈 생명주기
-- ==============================
local isInitialized = false
function module:OnEnable()
    initialize()

    if isInitialized then return end
    isInitialized = true

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("AUCTION_HOUSE_SHOW")
    f:RegisterEvent("CRAFTINGORDERS_SHOW_CUSTOMER")

    local function on_event(self, event)
        if event == "AUCTION_HOUSE_SHOW" then
            apply_auction_filter()
        elseif event == "CRAFTINGORDERS_SHOW_CUSTOMER" then
            apply_craft_filter(3)
        elseif event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(1, apply_filters)
        end
    end

    f:SetScript("OnEvent", on_event)

    -- dodoEditModePanel 내부에 2열 그리드로 세부 설정 주입
    if dodo.RegisterEditModeSetting then
        dodo.RegisterEditModeSetting("편의기능", {
            {
                name = "현행 확장팩 필터",
                get = function() return dodo.DB and dodo.DB.enableExpFilterModule or false end,
                set = function(checked)
                    if dodo.DB then 
                        dodo.DB.enableExpFilterModule = checked 
                    end
                    apply_filters()
                end
            }
        })
    end
end