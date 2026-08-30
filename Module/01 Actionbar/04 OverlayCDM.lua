-- ==============================
-- Inspired
-- ==============================
-- CDMButtonAuras (https://www.curseforge.com/wow/addons/cdmbuttonauras)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local BAR_INDEX_MAP = dodo.BAR_INDEX_MAP

local CDM_DB_KEYS = {
    ["MainActionBar"]       = "useActionbarCDMBar1",
    ["MultiBarBottomLeft"]  = "useActionbarCDMBar2",
    ["MultiBarBottomRight"] = "useActionbarCDMBar3",
    ["MultiBarRight"]       = "useActionbarCDMBar4",
    ["MultiBarLeft"]        = "useActionbarCDMBar5",
    ["MultiBar5"]           = "useActionbarCDMBar6",
    ["MultiBar6"]           = "useActionbarCDMBar7",
    ["MultiBar7"]           = "useActionbarCDMBar8",
}

local CDM_DEFAULTS = {
    ["MainActionBar"]       = true,
    ["MultiBarBottomLeft"]  = true,
    ["MultiBarBottomRight"] = false,
    ["MultiBarRight"]       = false,
    ["MultiBarLeft"]        = false,
    ["MultiBar5"]           = false,
    ["MultiBar6"]           = false,
    ["MultiBar7"]           = false,
    ["StanceBar"]           = false,
    ["PetActionBar"]        = false,
}

local ALL_CDM_GROUPS = {
    { group = "ActionButton",              barName = "MainActionBar"       },
    { group = "MultiBarBottomLeftButton",  barName = "MultiBarBottomLeft"  },
    { group = "MultiBarBottomRightButton", barName = "MultiBarBottomRight" },
    { group = "MultiBarRightButton",       barName = "MultiBarRight"       },
    { group = "MultiBarLeftButton",        barName = "MultiBarLeft"        },
    { group = "MultiBar5Button",           barName = "MultiBar5"           },
    { group = "MultiBar6Button",           barName = "MultiBar6"           },
    { group = "MultiBar7Button",           barName = "MultiBar7"           },
}

local CustomCDMConfigs = { -- 물약 지속시간 (스펠ID - 아이템ID)
    [1236616] = { matchIDs = { 241308, 241309 }, duration = 30, type = 3 }, -- 빛의 잠재력 
    [1236994] = { matchIDs = { 241288, 241289 }, duration = 30, type = 3 }, -- 무모함의 물약
}

local enableCDMADebug = false

local CDMMapping = { -- CDM SpellID - Actionabar SpellID
    [386634] = 12294, -- 집행자의 정밀함  - 필사의 일격 (무전)
    [184361] = 1464, -- 격노  - 광란 (분전)
    [12950] = 190411, -- 소용돌이 연마  - 소용돌이 (분전)

    [195181] = 195182, -- 뼈의 보호막 - 골수분쇄
}

-- ==============================
-- 캐싱
-- ==============================
local BuffBarCooldownViewer = BuffBarCooldownViewer
local BuffIconCooldownViewer = BuffIconCooldownViewer
local C_CooldownViewer = C_CooldownViewer
local C_Item = C_Item
local C_Spell = C_Spell
local C_Timer = C_Timer
local C_UnitAuras = C_UnitAuras
local CreateFrame = CreateFrame
local Enum = Enum
local GetActionInfo = GetActionInfo
local GetTime = GetTime
local hooksecurefunc = hooksecurefunc
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local issecretvalue = issecretvalue
local Item = Item
local math_abs = math.abs
local pairs = pairs
local rawget = rawget
local type = type
local wipe = wipe

local custom_cdmauras = dodo.customCDMAuras
local custom_cdmspell_map = dodo.customCDMSpellMap

-- 현재 표시 중인 overlay만 추적 (poll 최적화)
local active_cdm_overlays = {}

-- ==============================
-- 기능 구현
-- ==============================
local function is_bar_cdm_enabled(barName)
    if not barName then return false end
    local dbKey = CDM_DB_KEYS[barName]
    if not dbKey then return CDM_DEFAULTS[barName] or false end
    if not dodoDB then return CDM_DEFAULTS[barName] or false end
    local val = dodoDB[dbKey]
    if val == nil then return CDM_DEFAULTS[barName] or false end
    return val
end

local function customize_cooldown_text(cooldown)
    if not cooldown or cooldown.__textHooked then return end
    local region = cooldown:GetCountdownFontString()
    if region then
        local parent = cooldown:GetParent()
        region:SetParent(parent)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -5)
        region:SetTextColor(0, 1, 0, 1)

        hooksecurefunc(region, "SetTextColor", function(self, r, g, b, a)
            if r ~= 0 or g ~= 1 or b ~= 0 then
                self:SetTextColor(0, 1, 0, 1)
            end
        end)
        hooksecurefunc(region, "SetPoint", function(self, point, relativeTo, relativePoint, x, y)
            if relativeTo ~= parent or point ~= "TOPLEFT" or x ~= 5 or y ~= -5 then
                self:SetParent(parent)
                self:ClearAllPoints()
                self:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -5)
            end
        end)
        cooldown.__textHooked = true
    end
end

-- CDM Overlay Mixin
CDMOverlayMixin = {}

function CDMOverlayMixin:OnLoad()
    local parent = self:GetParent()
    self:SetSize(parent:GetSize())
    self.InnerGlow:SetVertexColor(0, 1, 0, 1)
    self.Count:SetTextColor(1, 1, 0)

    if parent.cooldown then
        self:SetFrameLevel(parent.cooldown:GetFrameLevel() + 1)
    end

    self.Cooldown:SetPoint("TOPLEFT", parent.icon, "LEFT", 5, 0)
    self.Cooldown:SetPoint("BOTTOMRIGHT", parent.icon, "BOTTOM", 0, 3)
    self.Cooldown:SetDrawSwipe(false)
    self.Cooldown:SetUseAuraDisplayTime(true)
    self.Cooldown:SetCountdownFont("NumberFontNormal")
    self.Cooldown:SetCountdownAbbrevThreshold(60)
    self.Cooldown:SetScript('OnCooldownDone', function () self:Update() end)
    self:Hide()
end

function CDMOverlayMixin:StartCustomCDM(spellID, duration, startTime)
    self.customCDMSpellID = spellID
    self.customCDMEndTime = startTime + duration

    active_cdm_overlays[self] = true
    self.InnerGlow:Show()
    self.Cooldown:SetCooldown(startTime, duration)
    self.Cooldown:Show()
    self:Show()

    customize_cooldown_text(self.Cooldown)
end

function CDMOverlayMixin:StopCustomCDM()
    active_cdm_overlays[self] = nil
    self.viewerItem = nil
    self.customCDMSpellID = nil
    self.customCDMEndTime = nil
    self.Cooldown:Clear()
    self.Cooldown:Hide()
    self.InnerGlow:Hide()
    self.Count:Hide()
    self.TimerCooldown:Hide()
    self:Hide()
end

function CDMOverlayMixin:Update()
    local parent = self:GetParent()
    if not parent then return end

    local barName = dodo.get_bar_name_by_button(parent)
    if not barName or not is_bar_cdm_enabled(barName) then self:StopCustomCDM(); return end

    -- 물약 바 CDM 처리: OverlayPotion이 로드된 경우 해당 바의 포션 여부 확인
    if dodo.is_bar_potion_proc_enabled and dodo.is_bar_potion_proc_enabled(barName) and parent.action then
        local actionType, id = GetActionInfo(parent.action)
        local activeFake = nil
        local matchedSpellID = nil
        if actionType == "spell" then
            local baseSpellID = C_Spell.GetBaseSpell(id)
            matchedSpellID = baseSpellID or id
            activeFake = custom_cdmauras[matchedSpellID]
        elseif actionType == "item" then
            local _, spellID = C_Item.GetItemSpell(id)
            matchedSpellID = spellID or id
            activeFake = custom_cdmauras[matchedSpellID]
        end

        if activeFake and matchedSpellID then
            local remaining = activeFake.duration - (GetTime() - activeFake.startTime)
            if remaining > 0 then
                self:StartCustomCDM(matchedSpellID, activeFake.duration, activeFake.startTime)
                return
            else
                custom_cdmauras[matchedSpellID] = nil
            end
        end
    end

    local item = self.viewerItem
    if item and item.isActive then
        -- 초기 시드: 현재 CDM 프레임 상태 반영 (이후 갱신은 hook_viewer_item 후킹이 처리)
        local appFS = (item.Applications and item.Applications.Applications)
                   or (item.Icon and item.Icon.Applications)
        if appFS then
            local val = appFS:GetText()
            if val ~= nil and (issecretvalue(val) or (val ~= "" and val ~= "0")) then
                self.Count:SetText(val)
                self.Count:Show()
            else
                self.Count:Hide()
            end
        else
            self.Count:Hide()
        end
        self.Cooldown:Hide() -- 쿨다운은 SetCooldownFromDurationObject/SetCooldown 후킹에서 채워짐

        active_cdm_overlays[self] = true
        self.InnerGlow:Show()
        self:Show()
    else
        self:StopCustomCDM()
    end
end

local function build_button_cache()
    dodo.buttonCache = dodo.buttonCache or {}
    for _, arr in pairs(dodo.buttonCache) do wipe(arr) end
    local groups = {
        "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
        "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
        "StanceButton"
    }
    for _, group in ipairs(groups) do
        for i = 1, 12 do
            local btn = _G[group .. i]
            if btn and btn.action then
                local _, actionSpellID = GetActionInfo(btn.action)
                if actionSpellID then
                    local baseSpellID = C_Spell.GetBaseSpell(actionSpellID)
                    local spellName = C_Spell.GetSpellName(baseSpellID)
                    local rawSpellName = C_Spell.GetSpellName(actionSpellID)

                    if spellName then
                        if not dodo.buttonCache[spellName] then dodo.buttonCache[spellName] = {} end
                        dodo.buttonCache[spellName][#dodo.buttonCache[spellName] + 1] = btn
                    end

                    if rawSpellName and rawSpellName ~= spellName then
                        if not dodo.buttonCache[rawSpellName] then dodo.buttonCache[rawSpellName] = {} end
                        dodo.buttonCache[rawSpellName][#dodo.buttonCache[rawSpellName] + 1] = btn
                    end
                end
            end
        end
    end
end

local function update_cdm_from_item(item)
    if not item or not item.cooldownID then return end
    if not dodoDB or dodoDB.enableActionbar == false then return end

    local cdInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(item.cooldownID)
    if not cdInfo or not cdInfo.spellID then return end
    local baseSpellID = C_Spell.GetBaseSpell(cdInfo.spellID)
    if enableCDMADebug then
        local debugName = C_Spell.GetSpellName(baseSpellID)
        if debugName then
            print("[dodo CDM Debug] 검지된 버프 ID: " .. tostring(baseSpellID) .. " (" .. tostring(debugName) .. ")")
        end
    end

    local targetSpellID = CDMMapping[baseSpellID] or baseSpellID
    local spellName = C_Spell.GetSpellName(targetSpellID)
    if spellName then
        local buttons = dodo.buttonCache and dodo.buttonCache[spellName]
        if buttons then
            for _, btn in ipairs(buttons) do
                if btn.cdmOverlay then
                    local hasAuraData = rawget(item, "auraDataUnit") ~= nil and rawget(item, "auraInstanceID") ~= nil
                    btn.cdmOverlay.viewerItem = hasAuraData and item or nil
                    btn.cdmOverlay:Update()
                end
            end
        end
    end
end

-- 아이콘형 CDM 카운트다운 텍스트 폴링 (secret 값은 SetCooldown 불가 → GetCountdownFontString 우회)
-- active_cdm_overlays만 순회 — registeredButtons 전체 순회 대비 96→실제 활성 수로 감소
local function poll_cdm_timer_overlays()
    for overlay in pairs(active_cdm_overlays) do
        local item = overlay.viewerItem
        local text
        if item and item.isActive then
            if item.Cooldown and item.Cooldown.GetCountdownFontString then
                local cfs = item.Cooldown:GetCountdownFontString()
                text = cfs and cfs:GetText()
            elseif item.Bar and item.Bar.Duration then
                text = item.Bar.Duration:GetText()
            end
        end
        if text and (issecretvalue(text) or text ~= "") then
            overlay.TimerCooldown:SetText(text)
            overlay.TimerCooldown:Show()
        else
            overlay.TimerCooldown:Hide()
        end
    end
end

local function mirror_count_to_overlays(item, val)
    for btn in pairs(dodo.registeredButtons) do
        if btn.cdmOverlay and btn.cdmOverlay.viewerItem == item then
            if val ~= nil and (issecretvalue(val) or (val ~= "" and val ~= "0")) then
                btn.cdmOverlay.Count:SetText(val)
                btn.cdmOverlay.Count:Show()
            else
                btn.cdmOverlay.Count:Hide()
            end
        end
    end
end

local function mirror_cooldown_to_overlays(item, durObj, useAuraDisplayTime)
    for btn in pairs(dodo.registeredButtons) do
        if btn.cdmOverlay and btn.cdmOverlay.viewerItem == item then
            if durObj then
                btn.cdmOverlay.Cooldown:SetCooldownFromDurationObject(durObj, useAuraDisplayTime)
                btn.cdmOverlay.Cooldown:Show()
                customize_cooldown_text(btn.cdmOverlay.Cooldown)
            else
                btn.cdmOverlay.Cooldown:Hide()
            end
        end
    end
end

local function mirror_setcooldown_to_overlays(item, start, dur, modRate)
    -- secret 값은 tainted 코드에서 SetCooldown에 전달 불가 → 타이머 표시 포기
    if issecretvalue(start) or issecretvalue(dur) then return end
    for btn in pairs(dodo.registeredButtons) do
        if btn.cdmOverlay and btn.cdmOverlay.viewerItem == item then
            if start and start > 0 and dur and dur > 0 then
                btn.cdmOverlay.Cooldown:SetCooldown(start, dur, modRate)
                btn.cdmOverlay.Cooldown:Show()
                customize_cooldown_text(btn.cdmOverlay.Cooldown)
            else
                btn.cdmOverlay.Cooldown:Hide()
            end
        end
    end
end

local function hook_viewer_item(item)
    if not item.__AB2Hooked then
        hooksecurefunc(item, "RefreshData", function() update_cdm_from_item(item) end)

        -- 스택 카운트: CDM이 Applications FontString에 값 쓸 때 오버레이 미러
        -- (secret value도 SetText에 그대로 전달 가능)
        local appFS = (item.Applications and item.Applications.Applications)
                   or (item.Icon and item.Icon.Applications)
        if appFS then
            hooksecurefunc(appFS, "SetText", function(_, val)
                mirror_count_to_overlays(item, val)
            end)
        end

        -- 쿨다운 타이머: CDM이 자기 Cooldown 업데이트할 때 오버레이 미러
        if item.Cooldown then
            hooksecurefunc(item.Cooldown, "SetCooldownFromDurationObject", function(_, durObj, useAuraDisplayTime)
                mirror_cooldown_to_overlays(item, durObj, useAuraDisplayTime)
            end)
            hooksecurefunc(item.Cooldown, "SetCooldown", function(_, start, dur, modRate)
                mirror_setcooldown_to_overlays(item, start, dur, modRate)
            end)
        end

        item.__AB2Hooked = true
    end
    update_cdm_from_item(item)
end

local is_cache_pending = false
local function do_build_special_button_cache()
    is_cache_pending = false
    if InCombatLockdown() then return end

    for _, entry in ipairs(ALL_CDM_GROUPS) do
        for i = 1, 12 do
            local btn = _G[entry.group .. i]
            if btn then
                local barName = dodo.get_bar_name_by_button(btn)
                if btn.action and barName and is_bar_cdm_enabled(barName) then
                    if not btn.cdmOverlay then
                        btn.cdmOverlay = CreateFrame("Frame", nil, btn, "CDMOverlayTemplate")
                    end
                    btn.cdmOverlay:ClearAllPoints()
                    btn.cdmOverlay:SetAllPoints(btn)
                elseif btn.cdmOverlay then
                    btn.cdmOverlay:Hide()
                end
            end
        end
    end
    build_button_cache()
end

local function build_special_button_cache()
    if InCombatLockdown() or is_cache_pending then return end
    is_cache_pending = true
    C_Timer.After(0.1, do_build_special_button_cache)
end
dodo.BuildSpecialButtonCache = build_special_button_cache

local function init_custom_cdm_spells()
    for key, itemConfig in pairs(CustomCDMConfigs) do
        custom_cdmspell_map[key] = key
        if itemConfig.matchIDs then
            for _, tID in ipairs(itemConfig.matchIDs) do
                if C_Item.GetItemInfoInstant(tID) then
                    local item = Item:CreateFromItemID(tID)
                    if item and not item:IsItemEmpty() then
                        item:ContinueOnItemLoad(function()
                            local _, spellID = C_Item.GetItemSpell(tID)
                            if spellID then
                                custom_cdmspell_map[spellID] = key
                            end
                        end)
                    end
                else
                    custom_cdmspell_map[tID] = key
                end
            end
        end

        if type(key) == "number" and not itemConfig.matchIDs and C_Item.GetItemInfoInstant(key) then
            local item = Item:CreateFromItemID(key)
            if item and not item:IsItemEmpty() then
                item:ContinueOnItemLoad(function()
                    local _, spellID = C_Item.GetItemSpell(key)
                    if spellID then
                        custom_cdmspell_map[spellID] = key
                    end
                end)
            end
        end
    end
end

local _matched_buf = {}
local function get_matching_buttons(targetSpellID, configKey)
    wipe(_matched_buf)
    local itemConfig = CustomCDMConfigs[configKey]
    for btn in pairs(dodo.registeredButtons) do
        if btn.action then
            local actionType, id = GetActionInfo(btn.action)
            if actionType == "spell" then
                local baseSpellID = C_Spell.GetBaseSpell(id)
                local isMatch = false
                if itemConfig and itemConfig.matchIDs then
                    for _, tID in ipairs(itemConfig.matchIDs) do
                        if baseSpellID == tID or id == tID then isMatch = true; break end
                    end
                end
                if isMatch or baseSpellID == targetSpellID or id == targetSpellID or id == configKey or baseSpellID == configKey then
                    _matched_buf[#_matched_buf + 1] = btn
                end
            elseif actionType == "item" then
                local isMatch = false
                if itemConfig and itemConfig.matchIDs then
                    for _, tID in ipairs(itemConfig.matchIDs) do
                        if id == tID then isMatch = true; break end
                    end
                end
                if isMatch or id == configKey then
                    _matched_buf[#_matched_buf + 1] = btn
                else
                    local _, btnSpellID = C_Item.GetItemSpell(id)
                    if btnSpellID and btnSpellID == targetSpellID then
                        _matched_buf[#_matched_buf + 1] = btn
                    end
                end
            end
        end
    end
    return _matched_buf
end

dodo.ActionbarOnSpellcastSucceeded = function(unitTarget, castGUID, spellID)
    local matchedItemID = custom_cdmspell_map[spellID]
    if matchedItemID then
        local itemConfig = CustomCDMConfigs[matchedItemID]
        local duration = itemConfig and itemConfig.duration or 30
        local refreshType = itemConfig and itemConfig.type or 1

        local now = GetTime()
        local activeAura = custom_cdmauras[spellID]

        if activeAura then
            local remaining = activeAura.duration - (now - activeAura.startTime)
            if remaining > 0 then
                if refreshType == 2 then -- Add
                    activeAura.duration = remaining + duration
                    activeAura.startTime = now
                elseif refreshType == 3 then -- Reset
                    activeAura.duration = duration
                    activeAura.startTime = now
                end
            else
                custom_cdmauras[spellID] = { startTime = now, duration = duration }
            end
        else
            custom_cdmauras[spellID] = { startTime = now, duration = duration }
        end

        local updatedAura = custom_cdmauras[spellID]

        local buttons = get_matching_buttons(spellID, matchedItemID)
        for _, btn in ipairs(buttons) do
            if btn.cdmOverlay then
                btn.cdmOverlay:StartCustomCDM(spellID, updatedAura.duration, updatedAura.startTime)
            end
        end
    end
end

dodo.ActionbarInitCDM = function()
    local cdmHook = function(_, item) hook_viewer_item(item) end
    hooksecurefunc(BuffBarCooldownViewer, "OnAcquireItemFrame", cdmHook)
    hooksecurefunc(BuffIconCooldownViewer, "OnAcquireItemFrame", cdmHook)

    init_custom_cdm_spells()

    local function on_login_delay()
        build_special_button_cache()
        for _, item in ipairs(BuffBarCooldownViewer:GetItemFrames()) do hook_viewer_item(item) end
        for _, item in ipairs(BuffIconCooldownViewer:GetItemFrames()) do hook_viewer_item(item) end
    end
    C_Timer.After(0.5, on_login_delay)
    C_Timer.NewTicker(0.1, poll_cdm_timer_overlays)
end

dodo.ActionbarApplyCDM = function()
    for btn in pairs(dodo.registeredButtons) do
        if btn.cdmOverlay then btn.cdmOverlay:Update() end
    end
end

-- ==============================
dodo.AB_CDM_DB_KEYS  = CDM_DB_KEYS
dodo.AB_CDM_DEFAULTS = CDM_DEFAULTS

if enableCDMADebug then
    -- ==============================
    -- 디버그용 슬래시 명령어 등록 (enableCDMADebug = true 로 수정해야 작동)
    -- ==============================
    SLASH_DODOCDM1 = "/dodocdm"
    SlashCmdList["DODOCDM"] = function()
        print("[dodo CDM] 단축바 실시간 감지 디버그 시작")
        local groups = {
            "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
            "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
            "StanceButton"
        }
        local count = 0
        for _, group in ipairs(groups) do
            for i = 1, 12 do
                local btn = _G[group .. i]
                if btn and btn.action then
                    local actionType, actionSpellID = GetActionInfo(btn.action)
                    if actionSpellID then
                        local baseSpellID = C_Spell.GetBaseSpell(actionSpellID) or actionSpellID
                        local spellName = C_Spell.GetSpellName(baseSpellID)
                        if spellName then
                            print(string.format("[%s%d] 타입: %s | 원래 ID: %s | Base ID: %s | 이름: %s",
                                group, i, tostring(actionType), tostring(actionSpellID), tostring(baseSpellID), tostring(spellName)))
                            count = count + 1
                        end
                    end
                end
            end
        end
        print("[dodo CDM] 단축바 실시간 감지 디버그 완료 (총 " .. count .. "개 감지)")
    end
end