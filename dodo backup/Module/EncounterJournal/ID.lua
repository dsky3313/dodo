---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local select      = select

dodo.EJID = dodo.EJID or {}
local M = dodo.EJID

local enabled = false
local hooked  = false

-- ==============================
-- 능력 헤더 툴팁
-- ==============================
local function header_on_enter(self)
    if not enabled then return end
    local parent = self:GetParent()
    if not parent then return end
    local spellID = parent.spellID
    if not spellID or spellID == 0 then return end
    GameTooltip:SetOwner(parent, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("spell:" .. spellID, EJ_GetDifficulty(), EJ_GetContentTuningID())
    GameTooltip:Show()
end

local function refresh_headers()
    local encounter = EncounterJournal and EncounterJournal.encounter
    if not encounter then return end
    local usedHeaders = encounter.usedHeaders
    if not usedHeaders then return end
    for _, infoHeader in pairs(usedHeaders) do
        local btn = infoHeader.button
        if btn then
            if not btn.ejid_hooks_set then
                btn:SetScript("OnEnter", header_on_enter)
                btn:SetScript("OnLeave", GameTooltip_Hide)
                btn.ejid_hooks_set = true
            end
            local spellID = infoHeader.spellID
            if not btn.eventIDdisplay then
                btn.eventIDdisplay = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                btn.eventIDdisplay:SetTextColor(0.902, 0.788, 0.671)
            end
            local anchor
            if btn.icon2 and btn.icon2:IsShown() then
                anchor = btn.icon2
            elseif btn.icon1 and btn.icon1:IsShown() then
                anchor = btn.icon1
            end
            btn.eventIDdisplay:ClearAllPoints()
            if anchor then
                btn.eventIDdisplay:SetPoint("LEFT", anchor, "LEFT", -50, 0)
            else
                btn.eventIDdisplay:SetPoint("LEFT", btn, "RIGHT", -55, 0)
            end
            btn.eventIDdisplay:SetText(enabled and (spellID and spellID ~= 0) and tostring(spellID) or "")
        end
    end
end

-- ==============================
-- 보스 버튼 encounterID (dungeonEncounterID)
-- ==============================
local function refresh_boss_button(button, data)
    if not data or not data.bossID then
        if button.encounterIDdisplay then button.encounterIDdisplay:SetText("") end
        return
    end
    local encounterID = select(7, EJ_GetEncounterInfo(data.bossID))
    if not button.encounterIDdisplay then
        button.encounterIDdisplay = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.encounterIDdisplay:SetPoint("TOPRIGHT", button, "TOPRIGHT", -10, -10)
        button.encounterIDdisplay:SetTextColor(0.902, 0.788, 0.671)
    end
    button.encounterIDdisplay:SetText(enabled and (encounterID or "") or "")
end

local function on_boss_frame_acquired(_, button, data)
    refresh_boss_button(button, data)
end

local function refresh_bosses()
    local info = EncounterJournal and EncounterJournal.encounter and EncounterJournal.encounter.info
    if not info then return end
    info.BossesScrollBox:ForEachFrame(refresh_boss_button)
end

-- ==============================
-- 훅 등록 (한 번만)
-- ==============================
local deferred_pending = false

local function on_deferred_tick()
    deferred_pending = false
    refresh_headers()
end

local function deferred_refresh()
    if deferred_pending then return end
    deferred_pending = true
    C_Timer.After(0, on_deferred_tick)
end

local function setup_hooks()
    if hooked then return end
    hooked = true

    hooksecurefunc("EncounterJournal_ToggleHeaders", refresh_headers)
    EncounterJournal:HookScript("OnShow", deferred_refresh)
    EncounterJournalEncounterFrameInfo:HookScript("OnShow", deferred_refresh)

    local scrollBox = EncounterJournalEncounterFrameInfo.BossesScrollBox
    local view = scrollBox:GetView()
    view:RegisterCallback(ScrollBoxListViewMixin.Event.OnAcquiredFrame, on_boss_frame_acquired, scrollBox)
end

-- ==============================
-- 활성화 토글
-- ==============================
function M.SetEnabled(val)
    enabled = val
    if hooked then
        refresh_headers()
        refresh_bosses()
    end
end

-- ==============================
-- 초기화
-- ==============================
local init_frame = CreateFrame("Frame")

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_EncounterJournal" then
            setup_hooks()
            self:UnregisterEvent("ADDON_LOADED")
        elseif arg1 == addonName then
            if dodoDB.enableEJID == nil then dodoDB.enableEJID = true end
        end
    elseif event == "PLAYER_LOGIN" then
        M.SetEnabled(dodoDB.enableEJID ~= false)
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end

init_frame:RegisterEvent("ADDON_LOADED")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", on_event)
if EncounterJournal_ToggleHeaders then setup_hooks() end

-- ==============================
-- 설정 등록
-- ==============================
local function update_enabled()
    M.SetEnabled(dodoDB.enableEJID ~= false)
end

dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["인터페이스.모험안내서"] = dodo.OptionRegistrations["인터페이스.모험안내서"] or {}
table.insert(dodo.OptionRegistrations["인터페이스.모험안내서"], function(category)
    Checkbox(category, "enableEJID", "ID 표시", "모험 안내서에 우두머리와 능력의 ID를 표시합니다.", true, update_enabled)
end)
