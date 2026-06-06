-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...

-- ==============================
-- 캐싱
-- ==============================
local C_ChallengeMode = C_ChallengeMode
local C_GossipInfo = C_GossipInfo
local C_MythicPlus = C_MythicPlus
local CreateFrame = CreateFrame
local GossipFrame = GossipFrame
local hooksecurefunc = hooksecurefunc
local IsInInstance = IsInInstance
local string = string
local UnitName = UnitName

-- ==============================
-- 기능 1: 린도르미 감지 및 쐐기돌 정보 획득
-- ==============================
local function is_lindormi()
    local in_instance = IsInInstance()
    if in_instance then return false end

    local name = UnitName("npc")
    if name == "린도르미" or name == "Lindormi" then
        return true
    end
    return false
end

local function get_keystone_text()
    local map_id = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local level = C_MythicPlus.GetOwnedKeystoneLevel()
    if map_id and level and level > 0 then
        local dungeon_name = C_ChallengeMode.GetMapUIInfo(map_id)
        if dungeon_name then
            return string.format("|cff00ff00[%d]|r %s", level, dungeon_name)
        end
    end
    return "|cff888888보유 쐐기돌 없음|r"
end

-- ==============================
-- 기능 2: 가십 텍스트 업데이트 (안전한 hooksecurefunc 방식)
-- ==============================
local function update_gossip_text()
    if not is_lindormi() then return end
    
    local text = C_GossipInfo.GetText() or ""
    if text:find("모험 이야기") then
        local greetingText = GossipFrame and GossipFrame.GreetingPanel and GossipFrame.GreetingPanel.GreetingText
        if greetingText then
            local current_text = greetingText:GetText() or ""
            -- 이미 추가되었는지 확인하여 중복 추가 방지
            if not current_text:find("보유 쐐기돌") then
                local keystone_info = get_keystone_text()
                greetingText:SetText(current_text .. "\n\n|cffffff00보유 쐐기돌|r\n" .. keystone_info)
            end
        end
    end
end

-- GossipFrame의 Update 함수가 호출된 후에 텍스트를 업데이트하도록 안전하게 훅
if GossipFrame then
    hooksecurefunc(GossipFrame, "Update", update_gossip_text)
else
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, event, name)
        if name == "Blizzard_GossipFrame" or GossipFrame then
            hooksecurefunc(GossipFrame, "Update", update_gossip_text)
            self:UnregisterAllEvents()
        end
    end)
end
