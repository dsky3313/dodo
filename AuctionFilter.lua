local addonName, ns = ...

------------------------------
-- 필터 적용 로직
------------------------------
-- 경매장 필터
local function checkAuctionFilter()
    local bar = AuctionHouseFrame and AuctionHouseFrame.SearchBar
    if not bar or not bar.FilterButton then return end

    -- 설정값이 없으면 기본적으로 false(혹은 true)로 설정
    local isChecked = (hodoDB and hodoDB.useAuctionFilter) or false
    bar.FilterButton.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = isChecked
    bar:UpdateClearFiltersButton()
end

-- 주문제작 필터
local function checkCraftFilter()
    local craftFrame = ProfessionsCustomerOrdersFrame
    local dropdown = craftFrame and craftFrame.BrowseOrders and craftFrame.BrowseOrders.SearchBar and craftFrame.BrowseOrders.SearchBar.FilterDropdown
    if not dropdown or not dropdown.filters then return end

    local isChecked = (hodoDB and hodoDB.useCraftFilter) or false
    dropdown.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = isChecked
    dropdown:ValidateResetState()
end

-- 통합 실행 함수 (외부 공유용)
function ns.AuctionFilter()
    checkAuctionFilter()
    checkCraftFilter()
end

------------------------------
-- 이벤트 및 후킹 핸들러
------------------------------
local initFilterFrame = CreateFrame("Frame")
initFilterFrame:RegisterEvent("ADDON_LOADED") -- 지연 로딩 대응
initFilterFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
initFilterFrame:RegisterEvent("CRAFTINGORDERS_SHOW_CUSTOMER")

initFilterFrame:SetScript("OnEvent", function(self, event, arg1)
    -- 1. 경매장 UI 애드온이 로드되는 시점에 후킹 (가장 확실한 방법)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_AuctionHouseUI" then
        if not self.auctionHouseHooked then
            AuctionHouseFrame.SearchBar:HookScript("OnShow", function()
                C_Timer.After(0, checkAuctionFilter)
            end)
            self.auctionHouseHooked = true
        end

    -- 2. 경매장이 켜졌을 때
    elseif event == "AUCTION_HOUSE_SHOW" then
        if not self.auctionHouseHooked and AuctionHouseFrame then
            AuctionHouseFrame.SearchBar:HookScript("OnShow", function()
                C_Timer.After(0, checkAuctionFilter)
            end)
            self.auctionHouseHooked = true
        end
        checkAuctionFilter()

    -- 3. 주문제작 창이 켜졌을 때
    elseif event == "CRAFTINGORDERS_SHOW_CUSTOMER" then
        if not self.craftOrdersHooked and ProfessionsCustomerOrdersFrame then
            local browseOrders = ProfessionsCustomerOrdersFrame.BrowseOrders
            if browseOrders and browseOrders.SearchBar and browseOrders.SearchBar.FilterDropdown then
                browseOrders.SearchBar.FilterDropdown:HookScript("OnShow", function()
                    C_Timer.After(0, checkCraftFilter)
                end)
                self.craftOrdersHooked = true
            end
        end
        checkCraftFilter()
    end
end)