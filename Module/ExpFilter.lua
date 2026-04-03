-- ==============================
-- 설정 및 상수
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
-- Enum cache for performance
local AHF = Enum.AuctionHouseFilter.CurrentExpansionOnly

-- Function cache references
local GetAuctionHouseFrame = function() return AuctionHouseFrame end
local GetCraftFrame = function() return ProfessionsCustomerOrdersFrame end

-- ==============================
-- 동작
-- ==============================
-- 경매장 필터
local function checkAuctionFilter()
    local isEnabled = (dodoDB.useAuctionFilter ~= false) -- 기본값 true
    local auctionFrame = GetAuctionHouseFrame()
    local searchBar = auctionFrame and auctionFrame.SearchBar

    if not searchBar or not searchBar.FilterButton then return end
    searchBar.FilterButton.filters[AHF] = isEnabled
    searchBar:UpdateClearFiltersButton()
end

-- 주문제작 필터
local function checkCraftFilter()
    local isEnabled = (dodoDB.useCraftFilter ~= false) -- 기본값 true
    local craftFrame = GetCraftFrame()
    
    if not craftFrame or not craftFrame.BrowseOrders then return end
    
    local searchBar = craftFrame.BrowseOrders.SearchBar
    local dropdown = searchBar and searchBar.FilterDropdown

    if not dropdown or not dropdown.filters then return end
    dropdown.filters[AHF] = isEnabled
    dropdown:ValidateResetState()
end

-- 통합 실행 함수 (외부 공유용)
function dodo.AuctionFilter()
    checkAuctionFilter()
    checkCraftFilter()
end


-- ==============================
-- 이벤트
-- ==============================
local initFilterFrame = CreateFrame("Frame")
initFilterFrame:RegisterEvent("ADDON_LOADED")
initFilterFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

initFilterFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.1, function()
            initFilterFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
            initFilterFrame:RegisterEvent("CRAFTINGORDERS_SHOW_CUSTOMER")
            dodo.AuctionFilter()
        end)
    elseif event == "ADDON_LOADED" and arg1 == "Blizzard_AuctionHouseUI" then
        if AuctionHouseFrame and AuctionHouseFrame.SearchBar then
            AuctionHouseFrame.SearchBar:HookScript("OnShow", function()
                C_Timer.After(0, checkAuctionFilter)
            end)
            initFilterFrame:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "AUCTION_HOUSE_SHOW" then
        checkAuctionFilter()

    elseif event == "CRAFTINGORDERS_SHOW_CUSTOMER" then
        if not initFilterFrame.craftOrdersHooked and ProfessionsCustomerOrdersFrame then
            local browseOrders = ProfessionsCustomerOrdersFrame.BrowseOrders
            if browseOrders and browseOrders.SearchBar and browseOrders.SearchBar.FilterDropdown then
                browseOrders.SearchBar.FilterDropdown:HookScript("OnShow", function()
                    C_Timer.After(0, checkCraftFilter)
                end)
                initFilterFrame.craftOrdersHooked = true
            end
        end
        checkCraftFilter()
    end
end)