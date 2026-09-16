-- ==============================
-- Inspired
-- ==============================
-- Leatrix Plus (https://www.curseforge.com/wow/addons/leatrix-plus)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local CanGuildBankRepair = CanGuildBankRepair
local CanMerchantRepair = CanMerchantRepair
local Checkbox = Checkbox
local format = string.format
local GetGuildBankWithdrawMoney = GetGuildBankWithdrawMoney
local GetGuildBankMoney = GetGuildBankMoney
local GetMoney = GetMoney
local GetRepairAllCost = GetRepairAllCost
local RepairAllItems = RepairAllItems
local hooksecurefunc = hooksecurefunc

local C_CurrencyInfo = C_CurrencyInfo
local C_MerchantFrame = C_MerchantFrame
local PREFIX = "[|cff00ff00dodo|r]"

-- ==============================
-- 동작 (EQOL 훅 방식)
-- ==============================
local function on_merchant_show()
    if not dodoDB then return end
    if dodoDB.enableMerchant == false then return end

    -- 1. 자동 수리
    if CanMerchantRepair() then
        local repairCost = GetRepairAllCost()
        if repairCost > 0 then
            local costString = C_CurrencyInfo.GetCoinTextureString(repairCost)
            local repairedByGuild = false

            -- 길드 수리 시도
            if CanGuildBankRepair() then
                local withdrawLimit = GetGuildBankWithdrawMoney()
                local guildBankMoney = GetGuildBankMoney()
                
                -- 인출 한도가 무제한(-1)이거나 수리비보다 크고, 실제 은행 잔고도 수리비보다 많을 때만 길드 수리 진행
                if (withdrawLimit == -1 or withdrawLimit >= repairCost) and (guildBankMoney >= repairCost) then
                    RepairAllItems(true)
                    print(format("%s 자동 수리 (길드): %s", PREFIX, costString))
                    repairedByGuild = true
                end
            end

            -- 길드 수리 실패/불가 시 개인 자금으로 수리
            if not repairedByGuild then
                if GetMoney() >= repairCost then
                    RepairAllItems()
                    print(format("%s 자동 수리 : %s", PREFIX, costString))
                else
                    print(format("%s 수리비 부족", PREFIX))
                end
            end
        end
    end

    -- 2. 잡템 자동 판매
    if C_MerchantFrame.IsSellAllJunkEnabled() then
        C_MerchantFrame.SellAllJunkItems()
    end
end

-- ==============================
-- 초기화 훅 설정 (EQOL 초경량 최적화)
-- ==============================
-- 불필요한 프레임 생성 및 이벤트 감시를 제거하고 창이 열릴 때만 즉각 반응하도록 수정
hooksecurefunc(MerchantFrame, "Show", on_merchant_show)

-- ==============================
-- 설정 등록
-- ==============================
dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["인터페이스.편의기능"] = dodo.OptionRegistrations["인터페이스.편의기능"] or {}
table.insert(dodo.OptionRegistrations["인터페이스.편의기능"], function(category)
    Checkbox(category, "enableMerchant", "자동 판매 & 수리", "상인 창을 열 때 잡템 판매 및 장비 자동 수리를 진행합니다.", true, nil)
end)
