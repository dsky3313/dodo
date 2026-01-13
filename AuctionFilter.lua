------------------------------
-- 테이블
------------------------------
local addonName, ns = ...

local function isIns() -- 인스확인
    local _, instanceType, difficultyID = GetInstanceInfo()
    return (difficultyID == 8 or instanceType == "raid") -- 1 일반 / 8 쐐기
end

local AHF = Enum.AuctionHouseFilter.CurrentExpansionOnly
------------------------------
-- 동작
------------------------------
-- 경매장 필터
local function checkAuctionFilter()
    if isIns() then return end

    local isEnabled = (hodoDB.useAuctionFilter ~= false) -- 기본값 true
    local AuctionFrame = AuctionHouseFrame and AuctionHouseFrame.SearchBar

    if not AuctionFrame or not AuctionFrame.FilterButton then return end
    AuctionFrame.FilterButton.filters[AHF] = isEnabled
    AuctionFrame:UpdateClearFiltersButton()
end

-- 주문제작 필터
local function checkCraftFilter()
    if isIns() then return end

    local isEnabled = (hodoDB.useCraftFilter ~= false) -- 기본값 true
    local craftFrame = ProfessionsCustomerOrdersFrame
    local dropdown = craftFrame and craftFrame.BrowseOrders and craftFrame.BrowseOrders.SearchBar and craftFrame.BrowseOrders.SearchBar.FilterDropdown

    if not dropdown or not dropdown.filters then return end
    dropdown.filters[AHF] = isEnabled
    dropdown:ValidateResetState()
end

-- 통합 실행 함수 (외부 공유용)
function ns.AuctionFilter()
    checkAuctionFilter()
    checkCraftFilter()
end

------------------------------
-- 이벤트
------------------------------
local initFilterFrame = CreateFrame("Frame")
initFilterFrame:RegisterEvent("ADDON_LOADED")
initFilterFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

initFilterFrame:SetScript("OnEvent", function(self, event, arg1)
      if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.1, function()
            if isIns() then
                initFilterFrame:UnregisterEvent("AUCTION_HOUSE_SHOW")
                initFilterFrame:UnregisterEvent("CRAFTINGORDERS_SHOW_CUSTOMER")
            else
                initFilterFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
                initFilterFrame:RegisterEvent("CRAFTINGORDERS_SHOW_CUSTOMER")
                ns.AuctionFilter()
            end
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