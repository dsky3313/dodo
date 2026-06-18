-- ==============================
-- Inspired
-- ==============================
-- ExwindTools (https://www.curseforge.com/wow/addons/exwindtools) — ExTools.GossipID

-- ==============================
-- 설정 및 테이블
-- ==============================
-- 지정된 gossipOptionID를 NPC 대화창에서 자동 선택.
-- 프리셋 + 사용자 커스텀 목록 지원.
--
-- enableGossipAutoSelect   : 마스터 토글 (기본 ON)
-- gossipAutoCustom         : { [optionID]={ enabled=bool, name=string } } 커스텀 목록
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local C_GossipInfo  = C_GossipInfo
local C_Timer       = C_Timer
local CreateFrame   = CreateFrame
local ipairs        = ipairs
local string        = string
local table         = table
local tonumber      = tonumber
local type          = type

-- ==============================
-- Core 디스패처 참조
-- ==============================
local GF = dodo.GossipFrame

-- ==============================
-- 프리셋 ID 목록 (항상 자동선택, 개별 토글 없음)
-- ==============================
local PRESET_IDS = {
    138618, 136301, 136271, 136316, 136280, 136624, -- 사론 포로구출
    107065, 107081, 107082, 107083, 107088,         -- 알게타르 대학
    137133,                                         -- 공결탑 제나스
    107387, 107428, 137387,                         -- 마이사라동굴
}

local PRESET_SET = {}
for _, id in ipairs(PRESET_IDS) do
    PRESET_SET[id] = true
end

-- ==============================
-- DB 헬퍼
-- ==============================
local function is_auto_enabled()
    return dodoDB and dodoDB.enableGossipAutoSelect ~= false
end

local function get_entry_state(option_id)
    if PRESET_SET[option_id] then
        return "preset_on"
    end
    local custom = dodoDB.gossipAutoCustom
    if custom then
        local entry = custom[option_id]
        if type(entry) == "table" then
            if entry.enabled ~= false then return "custom_on" end
            return "custom_off"
        end
    end
    return nil
end


-- ==============================
-- 자동 선택 로직
-- ==============================
local last_signature  = nil
local auto_scheduled  = false

local function build_signature(options)
    if not options or #options == 0 then return nil end
    local parts = {}
    for i, opt in ipairs(options) do
        local id   = opt and tonumber(opt.gossipOptionID) or 0
        local name = opt and tostring(opt.name or "") or ""
        parts[i] = string.format("%d:%s", id, name)
    end
    return table.concat(parts, "|")
end

local function do_auto_select()
    auto_scheduled = false
    if not is_auto_enabled() then return end
    if not C_GossipInfo or not C_GossipInfo.GetOptions then return end

    local options = C_GossipInfo.GetOptions()
    if not options or #options == 0 then return end

    local sig = build_signature(options)
    if not sig or sig == last_signature then return end

    for _, opt in ipairs(options) do
        local id = opt and tonumber(opt.gossipOptionID)
        if id and id > 0 then
            local state = get_entry_state(id)
            if state == "preset_on" or state == "custom_on" then
                last_signature = sig
                C_GossipInfo.SelectOption(id)
                return
            end
        end
    end
end

local function schedule_auto_select()
    if auto_scheduled then return end
    auto_scheduled = true
    C_Timer.After(0, do_auto_select)
end

-- ==============================
-- 훅 콜백 (Core 디스패처 → 여기로)
-- ==============================
local function on_option_setup(self, optionInfo)
    if not is_auto_enabled() then return end
    schedule_auto_select()
end

local function on_gossip_show()
    last_signature = nil
    if not is_auto_enabled() then return end
    schedule_auto_select()
end

local function on_gossip_closed()
    last_signature = nil
end

-- Core 디스패처에 등록
if GF then
    GF._on_option_setup[#GF._on_option_setup + 1] = on_option_setup
    GF._on_show[#GF._on_show + 1]                 = on_gossip_show
    GF._on_closed[#GF._on_closed + 1]             = on_gossip_closed
end

-- ==============================
-- 초기화
-- ==============================
local init_frame = CreateFrame("Frame")
init_frame:RegisterEvent("ADDON_LOADED")

local function on_init_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        if dodoDB.enableGossipAutoSelect == nil then dodoDB.enableGossipAutoSelect = true end
        if type(dodoDB.gossipAutoCustom) ~= "table" then dodoDB.gossipAutoCustom = {} end
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
    Checkbox(category, "enableGossipAutoSelect", "자동 선택", "M+ 던전 버프 NPC 대화를 자동으로 선택합니다.", true, nil)
end)
