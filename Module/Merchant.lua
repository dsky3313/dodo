-- ==============================
-- Inspired
-- ==============================
-- Leatrix Plus (https://www.curseforge.com/wow/addons/leatrix-plus)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("Merchant", module)

-- ==============================
-- 캐싱
-- ==============================
local C_CurrencyInfo = C_CurrencyInfo
local C_MerchantFrame = C_MerchantFrame
local CanGuildBankRepair = CanGuildBankRepair
local CanMerchantRepair = CanMerchantRepair
local format = string.format
local GetGuildBankMoney = GetGuildBankMoney
local GetGuildBankWithdrawMoney = GetGuildBankWithdrawMoney
local GetMoney = GetMoney
local GetRepairAllCost = GetRepairAllCost
local hooksecurefunc = hooksecurefunc
local RepairAllItems = RepairAllItems

local PREFIX = "[|cff00ff00dodo|r]"

-- ==============================
-- 기능 1: 상점 자동화
-- ==============================
local function on_merchant_show()
    if not dodo.DB or dodo.DB.enableMerchantModule == false then return end

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
-- 초기화
-- ==============================
local function initialize()
    if dodo.DB and dodo.DB.enableMerchantModule == nil then
        dodo.DB.enableMerchantModule = false
    end
end

-- ==============================
-- 모듈 생명주기
-- ==============================
function module:OnEnable()
    initialize()

    hooksecurefunc(MerchantFrame, "Show", on_merchant_show)

    -- dodoEditModePanel 내부에 세부 설정 주입 (비시각적 상점 설정)
    if dodo.RegisterEditModeSetting then
        dodo.RegisterEditModeSetting("편의기능", {
            {
                name = "자동 수리/판매",
                get = function() return dodo.DB and dodo.DB.enableMerchantModule or false end,
                set = function(checked)
                    if dodo.DB then 
                        dodo.DB.enableMerchantModule = checked 
                    end
                end
            }
        })
    end
end
