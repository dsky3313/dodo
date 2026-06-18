-- ==============================
-- Inspired
-- ==============================
-- ExwindTools (https://www.curseforge.com/wow/addons/exwindtools) — ExTools.GossipID

-- ==============================
-- 설정 및 테이블
-- ==============================
-- gossipOptionID / questID를 대화창 각 선택지·퀘스트 버튼에 [ID:숫자] 형태로 표시.
-- enableGossipID       : 마스터 토글 (기본 ON)
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local GossipFrame = GossipFrame
local string = string
local tonumber = tonumber
local type = type

-- ==============================
-- Core 디스패처 참조
-- ==============================
local GF = dodo.GossipFrame

-- ==============================
-- 기능: ID 추가 헬퍼
-- ==============================
local function is_enabled()
    return dodoDB and dodoDB.enableGossipID ~= false
end

local function has_id_tag(text)
    return type(text) == "string" and text:find("%[ID:%d+%]")
end

local function append_id(button, id)
    if not id or id <= 0 then return end
    local text = button:GetText()
    if not text or text == "" or has_id_tag(text) then return end
    button:SetText(string.format("%s |cff888888[ID:%d]|r", text, id))
    if button.Resize then button:Resize() end
end

-- ==============================
-- 훅 콜백
-- ==============================
local function on_option_setup(self, optionInfo)
    if not is_enabled() then return end
    local id = optionInfo and tonumber(optionInfo.gossipOptionID)
    if not id or id <= 0 then
        id = optionInfo and tonumber(optionInfo.orderIndex)
    end
    append_id(self, id)
end

local function on_available_quest_setup(self, questInfo)
    if not is_enabled() then return end
    append_id(self, questInfo and questInfo.questID)
end

local function on_active_quest_setup(self, questInfo)
    if not is_enabled() then return end
    append_id(self, questInfo and questInfo.questID)
end

-- Core 디스패처에 등록
if GF then
    GF._on_option_setup[#GF._on_option_setup + 1]                 = on_option_setup
    GF._on_available_quest_setup[#GF._on_available_quest_setup + 1] = on_available_quest_setup
    GF._on_active_quest_setup[#GF._on_active_quest_setup + 1]     = on_active_quest_setup
end

-- ==============================
-- 갱신
-- ==============================
local function refresh_gossip()
    if GossipFrame and GossipFrame:IsShown() and GossipFrame.Update then
        GossipFrame:Update()
    end
end

-- ==============================
-- 초기화
-- ==============================
local init_frame = CreateFrame("Frame")
init_frame:RegisterEvent("ADDON_LOADED")

local function on_init_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        if dodoDB.enableGossipID == nil then dodoDB.enableGossipID = true end
        self:UnregisterEvent("ADDON_LOADED")
    end
end

init_frame:SetScript("OnEvent", on_init_event)

-- ==============================
-- 설정 등록
-- ==============================
dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["인터페이스.대화창"] = dodo.OptionRegistrations["인터페이스.대화창"] or {}
table.insert(dodo.OptionRegistrations["인터페이스.대화창"], function(category)
    Checkbox(category, "enableGossipID", "ID 표시", "NPC 대화창 선택지·퀘스트에 ID를 표시합니다.", true, refresh_gossip)
end)
