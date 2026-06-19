-- ==============================
-- Inspired
-- ==============================
-- ExwindTools (https://www.curseforge.com/wow/addons/exwindtools)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local type = type

-- ==============================
-- 공유 디스패치 테이블
-- ==============================
dodo.GossipFrame = dodo.GossipFrame or {}
local GF = dodo.GossipFrame

GF._on_option_setup         = GF._on_option_setup         or {}
GF._on_available_quest_setup = GF._on_available_quest_setup or {}
GF._on_active_quest_setup   = GF._on_active_quest_setup   or {}
GF._on_show                 = GF._on_show                 or {}
GF._on_closed               = GF._on_closed               or {}

-- ==============================
-- 정적 디스패치 함수 (가비지 프리)
-- ==============================
local function dispatch_option(self, optionInfo)
    for _, fn in ipairs(GF._on_option_setup) do fn(self, optionInfo) end
end

local function dispatch_available_quest(self, questInfo)
    for _, fn in ipairs(GF._on_available_quest_setup) do fn(self, questInfo) end
end

local function dispatch_active_quest(self, questInfo)
    for _, fn in ipairs(GF._on_active_quest_setup) do fn(self, questInfo) end
end

-- ==============================
-- 훅 설치 (Blizzard_UIPanels_Game 로드 후 가능)
-- ==============================
local option_done = false
local avail_done  = false
local active_done = false

local function try_install_hooks()
    if not option_done and type(_G.GossipOptionButtonMixin) == "table" then
        hooksecurefunc(_G.GossipOptionButtonMixin, "Setup", dispatch_option)
        option_done = true
    end
    if not avail_done and type(_G.GossipAvailableQuestButtonMixin) == "table" then
        hooksecurefunc(_G.GossipAvailableQuestButtonMixin, "Setup", dispatch_available_quest)
        avail_done = true
    end
    if not active_done and type(_G.GossipActiveQuestButtonMixin) == "table" then
        hooksecurefunc(_G.GossipActiveQuestButtonMixin, "Setup", dispatch_active_quest)
        active_done = true
    end
    return option_done and avail_done and active_done
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local event_frame = CreateFrame("Frame")
event_frame:RegisterEvent("ADDON_LOADED")
event_frame:RegisterEvent("PLAYER_LOGIN")
event_frame:RegisterEvent("GOSSIP_SHOW")
event_frame:RegisterEvent("GOSSIP_CLOSED")

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            dodoDB = dodoDB or {}
        end
        if arg1 == "Blizzard_UIPanels_Game" then
            if try_install_hooks() then
                self:UnregisterEvent("ADDON_LOADED")
                self:UnregisterEvent("PLAYER_LOGIN")
            end
        end
    elseif event == "PLAYER_LOGIN" then
        if try_install_hooks() then
            self:UnregisterEvent("ADDON_LOADED")
            self:UnregisterEvent("PLAYER_LOGIN")
        end
    elseif event == "GOSSIP_SHOW" then
        for _, fn in ipairs(GF._on_show) do fn() end
    elseif event == "GOSSIP_CLOSED" then
        for _, fn in ipairs(GF._on_closed) do fn() end
    end
end

event_frame:SetScript("OnEvent", on_event)

if try_install_hooks() then
    event_frame:UnregisterEvent("ADDON_LOADED")
    event_frame:UnregisterEvent("PLAYER_LOGIN")
end
