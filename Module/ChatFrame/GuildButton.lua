-- ==============================
-- Inspired
-- ==============================
-- Guild Button (https://wago.io/Cx_wsXks4)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}
dodo.DB = dodo.DB or dodoDB

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local GetClassColor = GetClassColor
local GetGuildInfo = GetGuildInfo
local GetGuildRosterInfo = GetGuildRosterInfo
local GetGuildRosterMOTD = GetGuildRosterMOTD
local GetNumGuildMembers = GetNumGuildMembers
local ToggleGuildFrame = ToggleGuildFrame
local UIParent = UIParent
local issecretvalue = issecretvalue or function() return false end
local ipairs = ipairs
local table_insert = table.insert
local table_sort = table.sort

-- ==============================
-- 길드 버튼 프레임 및 상태 관리
-- ==============================
local guild_button
local guild_button_text
local guild_button_texture

local function escape_member_note(note)
    return note == nil and "" or "(" .. note .. ")"
end

local function sort_by_name(a, b)
    local name_a = GetGuildRosterInfo(a) or ""
    local name_b = GetGuildRosterInfo(b) or ""
    if issecretvalue(name_a) or issecretvalue(name_b) then
        return false
    end
    return name_a < name_b
end

local function set_guild_button_text()
    if not guild_button then return end
    local _, numOnlineMembers = GetNumGuildMembers()
    if guild_button_text == nil then
        guild_button_text = guild_button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        guild_button_text:SetPoint("BOTTOM", 0, 0)
    end
    guild_button_text:SetText(numOnlineMembers)
    guild_button_text:SetHeight(9)
end

local function hide_tooltip()
    GameTooltip:Hide()
end

local function show_tooltip()
    if not guild_button then return end
    local guildName, _ = GetGuildInfo('player')
    if not guildName then return end
    local total, online = GetNumGuildMembers()
    local textColorR, textColorG, textColorB, textColorA = 1, 1, 1, 1
    GameTooltip:SetOwner(guild_button, "ANCHOR_RIGHT")

    -- Title
    GameTooltip:AddDoubleLine(guildName, online..'/'..total, textColorR, textColorG, textColorB, textColorR, textColorG, textColorB)
    GameTooltip:AddLine(' ')

    -- Guild Message of the Day
    local guildMessage = GetGuildRosterMOTD()
    if guildMessage ~= '' then
        GameTooltip:AddLine(guildMessage, textColorR, textColorG, textColorB, textColorA)
        GameTooltip:AddLine(' ')
    end

    local tempMembers = {}
    for i = 1, total do
        local memberName, _, _, _, _, _, _, _, isMemberConnected = GetGuildRosterInfo(i)
        if memberName and isMemberConnected then
            table_insert(tempMembers, i)
        end
    end

    table_sort(tempMembers, sort_by_name)

    local shownCount = 0
    for _, i in ipairs(tempMembers) do
        shownCount = shownCount + 1
        if shownCount > 50 then
            GameTooltip:AddLine('...', online - 50, textColorR, textColorG, textColorB, textColorA)
            break
        end

        local memberName, _, _, _, _, memberZone, memberNote, _, _, _, memberClass = GetGuildRosterInfo(i)
        local cr, cg, cb, _ = GetClassColor(memberClass)
        GameTooltip:AddDoubleLine(memberName .. " " .. escape_member_note(memberNote), memberZone, cr, cg, cb, textColorR, textColorG, textColorB)
    end
    GameTooltip:Show()
end

local function on_guild_button_click(self, button)
    ToggleGuildFrame()
end

local function on_guild_roster_update()
    set_guild_button_text()
end

local function create_guild_button()
    if guild_button then return end

    guild_button = CreateFrame("Button", "SmartMicroMenuGuildButton", UIParent)
    guild_button:SetFrameStrata("LOW")
    guild_button:SetPoint("TOP", "QuickJoinToastButton", "BOTTOM", 0, 0)
    guild_button:SetWidth(32)
    guild_button:SetHeight(32)

    guild_button_texture = guild_button:CreateTexture(nil, "BACKGROUND")
    guild_button_texture:SetAtlas("quickjoin-button-friendslist-up")
    guild_button_texture:SetAllPoints(guild_button)
    guild_button_texture:SetVertexColor(0,1,0)
    guild_button.texture = guild_button_texture

    guild_button:SetScript("OnEvent", on_guild_roster_update)
    guild_button:SetScript("OnEnter",  show_tooltip)
    guild_button:SetScript("OnLeave",  hide_tooltip)
    guild_button:SetScript("OnMouseUp", on_guild_button_click)

    set_guild_button_text()
end

-- ==============================
-- 상태 업데이트 및 초기화
-- ==============================
local function update_state()
    local is_enabled = (dodo.DB and dodo.DB.enableChatModule ~= false and dodo.DB.useGuildButton ~= false)
    if is_enabled then
        create_guild_button()
        if guild_button then
            guild_button:Show()
            guild_button:RegisterEvent("GUILD_ROSTER_UPDATE")
            set_guild_button_text()
        end
    else
        if guild_button then
            guild_button:Hide()
            guild_button:UnregisterEvent("GUILD_ROSTER_UPDATE")
        end
    end
end

dodo.UpdateChatGuildButtonState = update_state

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if dodo.DB.useGuildButton == nil then dodo.DB.useGuildButton = true end
    update_state()
    self:UnregisterAllEvents()
end)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.ChatFrame, {
        {
            name = "길드 버튼 표시",
            get = function() return dodo.DB and dodo.DB.useGuildButton ~= false end,
            set = function(checked)
                if dodo.DB then dodo.DB.useGuildButton = checked end
                update_state()
            end,
            disabled = function() return dodo.DB and dodo.DB.enableChatModule == false end,
        }
    })
end
