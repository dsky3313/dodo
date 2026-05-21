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

-- 경매장 필터 적용
local function apply_auction_filter()
    if not dodo.DB or dodo.DB.enableExpFilterModule == false then return end
    if not (Enum and Enum.AuctionHouseFilter and Enum.AuctionHouseFilter.CurrentExpansionOnly) then return end

    RunNextFrame(function()
        local frame = AuctionHouseFrame
        local searchBar = frame and frame.SearchBar
        local filterButton = searchBar and searchBar.FilterButton
        
        -- 성능최적화: 불필요한 type() 문자열 평가 대신 존재 여부만 안전하게 확인
        if filterButton and filterButton.filters then
            filterButton.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
            searchBar:UpdateClearFiltersButton()
        end
    end)
end

-- 주문 제작 필터 적용 (초기화 지연 대비 재시도 로직 포함)
local function apply_craft_filter(remaining_retries)
    if not dodo.DB or dodo.DB.enableExpFilterModule == false then return end
    if not (Enum and Enum.AuctionHouseFilter and Enum.AuctionHouseFilter.CurrentExpansionOnly) then return end

    RunNextFrame(function()
        local frame = ProfessionsCustomerOrdersFrame
        local browseOrders = frame and frame.BrowseOrders
        local searchBar = browseOrders and browseOrders.SearchBar
        local filterDropdown = searchBar and searchBar.FilterDropdown

        -- 성능최적화: 불필요한 type() 문자열 평가 생략
        if not filterDropdown or not filterDropdown.filters then
            if (remaining_retries or 0) > 0 then
                apply_craft_filter((remaining_retries or 0) - 1)
            end
            return
        end

        filterDropdown.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
        if filterDropdown.ValidateResetState then filterDropdown:ValidateResetState() end
    end)
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
function module:OnEnable()
    initialize()

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("AUCTION_HOUSE_SHOW")
    f:RegisterEvent("CRAFTINGORDERS_SHOW_CUSTOMER")

    f:SetScript("OnEvent", function(self, event)
        if event == "AUCTION_HOUSE_SHOW" then
            apply_auction_filter()
        elseif event == "CRAFTINGORDERS_SHOW_CUSTOMER" then
            apply_craft_filter(3)
        elseif event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(1, apply_filters)
        end
    end)

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