-- ==============================
-- 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local CanGuildBankRepair = CanGuildBankRepair
local CanMerchantRepair = CanMerchantRepair
local CreateFrame = CreateFrame
local format = string.format
local GetGuildBankWithdrawMoney = GetGuildBankWithdrawMoney
local GetMoney = GetMoney
local GetRepairAllCost = GetRepairAllCost
local RepairAllItems = RepairAllItems
local C_CurrencyInfo = C_CurrencyInfo

local PREFIX = "[|cff00ff00dodo|r]"

-- ==============================
-- 동작
-- ==============================
-- 자동 수리
local function autoRepair()
    if not CanMerchantRepair() then return end

    local repairCost = GetRepairAllCost()
    if repairCost <= 0 then return end

    local costString = C_CurrencyInfo.GetCoinTextureString(repairCost)
    if CanGuildBankRepair() and GetGuildBankWithdrawMoney() >= repairCost then
        RepairAllItems(true)
        print(format("%s 자동 수리 (길드): %s", PREFIX, costString))
        return
    end

    -- 5. 개인 자금 확인
    if GetMoney() >= repairCost then
        RepairAllItems()
        print(format("%s 자동 수리 : %s", PREFIX, costString))
    else
        print(format("%s 수리비 부족", PREFIX))
    end
end

-- 잡템  판매
local function sellJunk()
    if not C_MerchantFrame.IsSellAllJunkEnabled() then return end
    C_MerchantFrame.SellAllJunkItems()
end

-- ==============================
-- 이벤트
-- ==============================
local initMerchant = CreateFrame("Frame")
initMerchant:RegisterEvent("MERCHANT_SHOW")

initMerchant:SetScript("OnEvent", function(self, event)
    autoRepair()
    sellJunk()
end)
