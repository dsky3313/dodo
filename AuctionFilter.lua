------------------------------
-- 테이블
------------------------------
local AH_Filter = Enum.AuctionHouseFilter.CurrentExpansionOnly
local C_Timer_After = C_Timer.After

------------------------------
-- 동작
------------------------------
function checkAuctionFilter()
    local db = hodoDB or {}
    local AHF = AuctionHouseFrame
    local Bar = AHF and AHF.SearchBar
    if not Bar or not Bar.FilterButton then return end

    local AF_Check = (db and db.useAuctionFilter) or false
    Bar.FilterButton.filters[AH_Filter] = AF_Check
    Bar:UpdateClearFiltersButton()
end

function checkCraftFilter()
    local db = hodoDB
    local CF_Check = (db and db.useCraftFilter) or false
    local PCF = ProfessionsCustomerOrdersFrame
    local Dropdown = PCF and PCF.BrowseOrders and PCF.BrowseOrders.SearchBar.FilterDropdown
    if not Dropdown or not Dropdown.filters then return end

    Dropdown.filters[AH_Filter] = CF_Check
    Dropdown:ValidateResetState()
end

function AuctionFilter()
    checkAuctionFilter()
    checkCraftFilter()
end

------------------------------
-- 이벤트
------------------------------
local initFilterFrame = CreateFrame("Frame")
initFilterFrame:RegisterEvent("CRAFTINGORDERS_SHOW_CUSTOMER")
initFilterFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
initFilterFrame:SetScript("OnEvent", function(self, event)
    hodoDB = hodoDB or {}

    if event == "AUCTION_HOUSE_SHOW" then
        if not self.auctionHouseHooked then
            AuctionHouseFrame.SearchBar:HookScript("OnShow", function()
                C_Timer.After(0, checkAuctionFilter)
            end)
            self.auctionHouseHooked = true
        end
        checkAuctionFilter()

    elseif event == "CRAFTINGORDERS_SHOW_CUSTOMER" then
        if not self.craftOrdersHooked then
            local SearchBar = ProfessionsCustomerOrdersFrame.BrowseOrders.SearchBar
            if SearchBar and SearchBar.FilterDropdown then
                SearchBar.FilterDropdown:HookScript("OnShow", function()
                    C_Timer.After(0, checkCraftFilter)
                end)
            end
            self.craftOrdersHooked = true
        end
        checkCraftFilter()
    end
end)