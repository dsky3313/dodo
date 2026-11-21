-- ==============================
-- Inspired
-- ==============================
-- EllesmereUI (https://www.curseforge.com/wow/addons/ellemereui)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

local AcceptQuest                = AcceptQuest
local C_GossipInfo               = C_GossipInfo
local CompleteQuest              = CompleteQuest
local CreateFrame                = CreateFrame
local GetNumQuestChoices         = GetNumQuestChoices
local GetQuestReward             = GetQuestReward
local IsQuestCompletable         = IsQuestCompletable
local IsShiftKeyDown             = IsShiftKeyDown
local UnitGUID                   = UnitGUID

-- ==============================
-- 헤더 설정 아이콘
-- ==============================
local function add_quest_header_settings_icon()
    local header = ObjectiveTrackerFrame and ObjectiveTrackerFrame.Header
    if not header or header.dodoSettingsBtn then return end

    dodo.UI:AddHeaderSettingsButton(header, "dodo_QuestTrackerSettingsDropdown", "퀘스트 설정",
        function(_, rootDescription)
            rootDescription:SetTag("MENU_DODO_QUEST_SETTINGS")
            rootDescription:CreateCheckbox(
                "퀘스트 자동 수락",
                function() return dodoDB.autoAccept end,
                function() dodoDB.autoAccept = not dodoDB.autoAccept end
            )
            rootDescription:CreateCheckbox(
                "퀘스트 자동 완료",
                function() return dodoDB.autoTurnIn end,
                function() dodoDB.autoTurnIn = not dodoDB.autoTurnIn end
            )
            rootDescription:CreateDivider()
            rootDescription:CreateButton("dodo 설정 열기", function()
                if Settings and Settings.OpenToCategory then
                    local cat = Settings.GetCategory and Settings.GetCategory("dodo")
                    if cat then Settings.OpenToCategory(cat) end
                end
            end)
        end)
end

-- ==============================
-- 자동 수락 / 자동 완료
-- ==============================
local prevent_npc_guid = nil
local auto_frame = CreateFrame("Frame")
auto_frame:RegisterEvent("QUEST_DETAIL")
auto_frame:RegisterEvent("QUEST_PROGRESS")
auto_frame:RegisterEvent("QUEST_COMPLETE")
auto_frame:RegisterEvent("GOSSIP_SHOW")
auto_frame:RegisterEvent("PLAYER_LOGIN")
auto_frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        add_quest_header_settings_icon()
        return
    end

    if event == "GOSSIP_SHOW" then
        if not C_GossipInfo then return end

        if dodoDB.enableQOL ~= false and dodoDB.autoTurnIn and C_GossipInfo.GetActiveQuests then
            for _, quest in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
                if quest.questID and quest.isComplete then
                    C_GossipInfo.SelectActiveQuest(quest.questID)
                    return
                end
            end
        end

        if dodoDB.enableQOL ~= false and dodoDB.autoAccept and C_GossipInfo.GetAvailableQuests then
            if dodoDB.autoAcceptShiftSkip ~= false and IsShiftKeyDown() then return end
            local available = C_GossipInfo.GetAvailableQuests()
            if available and #available > 0 then
                local npc_guid = UnitGUID("npc")
                -- 퀘스트 여러 개면 이 NPC는 수동 선택
                if #available > 1 then prevent_npc_guid = npc_guid end
                if prevent_npc_guid ~= npc_guid and available[1].questID then
                    C_GossipInfo.SelectAvailableQuest(available[1].questID)
                end
            end
        end

        -- "(퀘스트)" 라벨 선택지가 정확히 1개일 때만 자동 선택 (다른 선택지가 섞여 있어도 무관)
        if dodoDB.enableQOL ~= false and dodoDB.autoAccept and C_GossipInfo.GetOptions then
            if dodoDB.autoAcceptShiftSkip ~= false and IsShiftKeyDown() then return end
            local quest_opt, quest_cnt = nil, 0
            for _, opt in ipairs(C_GossipInfo.GetOptions() or {}) do
                if opt.gossipOptionID and bit.band(opt.flags or 0, Enum.GossipOptionRecFlags.QuestLabelPrepend) ~= 0 then
                    quest_opt = opt
                    quest_cnt = quest_cnt + 1
                end
            end
            if quest_cnt == 1 then C_GossipInfo.SelectOption(quest_opt.gossipOptionID) end
        end
        return
    end

    if event == "QUEST_DETAIL" then
        if dodoDB.enableQOL == false or not dodoDB.autoAccept then return end
        if dodoDB.autoAcceptShiftSkip ~= false and IsShiftKeyDown() then return end
        AcceptQuest()

    elseif event == "QUEST_PROGRESS" then
        if dodoDB.enableQOL == false or not dodoDB.autoTurnIn then return end
        if dodoDB.autoTurnInShiftSkip ~= false and IsShiftKeyDown() then return end
        -- 필요한 아이템 다 갖췄을 때만 "계속"
        if IsQuestCompletable() then CompleteQuest() end

    elseif event == "QUEST_COMPLETE" then
        if dodoDB.enableQOL == false or not dodoDB.autoTurnIn then return end
        if dodoDB.autoTurnInShiftSkip ~= false and IsShiftKeyDown() then return end
        local n = GetNumQuestChoices()
        -- 보상 선택이 없을 때만 자동 완료 (선택지 있으면 수동)
        if n <= 1 then GetQuestReward(n) end
    end
end)
