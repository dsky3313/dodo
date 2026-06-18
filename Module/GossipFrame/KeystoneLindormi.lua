-- ==============================
-- Inspired
-- ==============================
-- MKS_Helper (https://www.curseforge.com/wow/addons/mks-helper)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local C_ChallengeMode = C_ChallengeMode
local C_GossipInfo = C_GossipInfo
local C_MythicPlus = C_MythicPlus
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GossipFrame = GossipFrame
local IsInInstance = IsInInstance
local issecretvalue = issecretvalue
local string = string
local table = table
local UnitName = UnitName

-- ==============================
-- 로컬 프레임 및 상태
-- ==============================
local info_frame = nil
local event_frame = nil

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
    if map_id and level and not issecretvalue(level) and level > 0 then
        local dungeon_name = C_ChallengeMode.GetMapUIInfo(map_id)
        if dungeon_name then
            return string.format("|T4352494:14:14:0:0|t |cff00ff00[%d]|r %s", level, dungeon_name)
        end
    end
    return "|T4352494:14:14:0:0|t |cff888888보유 쐐기돌 없음|r"
end

-- ==============================
-- 기능 2: 독립 정보 프레임 생성 및 표시 (투명, 좌측하단)
-- ==============================
local function create_info_frame()
    if info_frame then return end

    info_frame = CreateFrame("Frame", nil, GossipFrame)
    info_frame:SetSize(220, 20)
    info_frame:SetPoint("TOP", GossipFrame, "TOP", 0, -35)

    local content = info_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    content:SetPoint("CENTER", info_frame, "CENTER", 0, 0)
    content:SetJustifyH("LEFT")
    info_frame.content = content
end

local function update_info_frame()
    if is_lindormi() then
        create_info_frame()
        if info_frame then
            info_frame.content:SetText(get_keystone_text())
            info_frame:Show()
        end
    elseif info_frame then
        info_frame:Hide()
    end
end

local function update_info_frame_deferred()
    if info_frame and info_frame:IsShown() then
        update_info_frame()
    end
end

local function trigger_deferred_updates()
    C_Timer.After(0.2, update_info_frame_deferred)
    C_Timer.After(0.5, update_info_frame_deferred)
    C_Timer.After(1.0, update_info_frame_deferred)
end

local function hide_info_frame()
    if info_frame then
        info_frame:Hide()
    end
end

-- ==============================
-- 기능 3: 상태 업데이트 및 자원 제어 (자원소모 0% 실현)
-- ==============================
local function update_visual()
    local is_enabled = (dodoDB and dodoDB.enableKeystoneLindormi ~= false)
    if is_enabled then
        if event_frame then
            event_frame:RegisterEvent("GOSSIP_SHOW")
            event_frame:RegisterEvent("GOSSIP_CLOSED")
        end
    else
        if event_frame then
            event_frame:UnregisterAllEvents()
        end
        hide_info_frame()
    end
end

local function initialize()
    if dodoDB and dodoDB.enableKeystoneLindormi == nil then
        dodoDB.enableKeystoneLindormi = true
    end
    update_visual()
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
event_frame = CreateFrame("Frame")

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        initialize()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "GOSSIP_SHOW" then
        if is_lindormi() then
            update_info_frame()
            self:RegisterEvent("CHAT_MSG_LOOT")
        end
    elseif event == "GOSSIP_CLOSED" then
        hide_info_frame()
        self:UnregisterEvent("CHAT_MSG_LOOT")
    elseif event == "CHAT_MSG_LOOT" then
        trigger_deferred_updates()
    end
end

event_frame:RegisterEvent("ADDON_LOADED")
event_frame:RegisterEvent("PLAYER_LOGIN")
event_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["인터페이스.대화창"] = dodo.OptionRegistrations["인터페이스.대화창"] or {}
table.insert(dodo.OptionRegistrations["인터페이스.대화창"], function(category)
    Checkbox(category, "enableKeystoneLindormi", "린도르미 현재돌", "린도르미 NPC 대화창에 보유 쐐기돌 정보를 표시합니다.", true, update_visual)
end)
