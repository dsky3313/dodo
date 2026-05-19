-- ==============================
-- Inspired
-- ==============================
-- ActionBarsEnhanced (https://www.curseforge.com/wow/addons/actionbarsenhanced)
-- ActionBar Interrupt Highlight (https://www.curseforge.com/wow/addons/actionbarinterrupthighlight)
-- CDMButtonAuras (https://www.curseforge.com/wow/addons/cdmbuttonauras)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("ActionBar", module)

local LibEditMode = LibStub and LibStub("LibEditMode", true)

local config = {
    colors = {
        range  = { r = 0.9, g = 0.1, b = 0.1 },
        mana   = { r = 0.1, g = 0.3, b = 1.0 },
        normal = { r = 1.0, g = 1.0, b = 1.0 }
    },
    replaceText = {
        { "SHIFT[%-%+]", "S" },
        { "CTRL[%-%+]", "C" },
        { "ALT[%-%+]", "A" },
        { "NUMPADMINUS", "N-" },
        { "NUMPADPLUS", "N+" },
        { "SPACE", "SP" },
        { "MOUSEWHEELUP", "MWU" },
        { "MOUSEWHEELDOWN", "MWD" },
        { "[%s%-]", "" }
    }
}

local CDMMapping = {
    [386634] = 12294, -- 집행자의 정밀함  - 필사의 일격 (무전)
    [12950] = 190411, 6343 -- 소용돌이 연마  - 소용돌이 (분전)
}

local customCDMConfigs = {
    [241309] = { duration = 30 }, -- 빛의 잠재력 (3성)
    [241308] = { duration = 30 }  -- 빛의 잠재력 (2성)
}

local Interrupts = {
    [47528]  = true, -- Mind Freeze          (죽기)
    [183752] = true, -- Disrupt              (악마사냥꾼)
    [78675]  = true, -- Solar Beam           (드루이드)
    [106839] = true, -- Skull Bash           (드루이드)
    [147362] = true, -- Counter Shot         (사냥꾼)
    [187707] = true, -- Muzzle               (사냥꾼)
    [2139]   = true, -- Counterspell         (마법사)
    [116705] = true, -- Spear Hand Strike    (수도사)
    [96231]  = true, -- Rebuke               (성기사)
    [15487]  = true, -- Silence              (사제)
    [1766]   = true, -- Kick                 (도적)
    [57994]  = true, -- Wind Shear           (주술사)
    [119910] = true, -- Spell Lock           (술사 지옥사냥개)
    [132409] = true, -- Spell Lock           (술사 지옥 약탈자)
    [89766]  = true, -- Axe Toss             (술사 지옥경비원)
    [6552]   = true, -- Pummel               (전사)
    [351338] = true, -- Quell                (기원사)
}

local IntEvents = {
    'ACTIONBAR_SLOT_CHANGED',
    'PLAYER_TARGET_CHANGED',
    'PLAYER_FOCUS_CHANGED',
}

local IntUnitEvents = {
    'UNIT_SPELLCAST_CHANNEL_START',
    'UNIT_SPELLCAST_CHANNEL_STOP',
    'UNIT_SPELLCAST_CHANNEL_UPDATE',
    'UNIT_SPELLCAST_DELAYED',
    'UNIT_SPELLCAST_FAILED',
    'UNIT_SPELLCAST_INTERRUPTED',
    'UNIT_SPELLCAST_INTERRUPTIBLE',
    'UNIT_SPELLCAST_NOT_INTERRUPTIBLE',
    'UNIT_SPELLCAST_START',
    'UNIT_SPELLCAST_STOP',
}

-- ==============================
-- 캐싱
-- ==============================
local ActionBarButtonEventsFrame = ActionBarButtonEventsFrame
local ActionBarButtonRangeCheckFrame = ActionBarButtonRangeCheckFrame
local AnchorUtil = AnchorUtil
local BuffBarCooldownViewer = BuffBarCooldownViewer
local BuffIconCooldownViewer = BuffIconCooldownViewer
local C_ActionBar = C_ActionBar
local C_CooldownViewer = C_CooldownViewer
local C_Item = C_Item
local C_Spell = C_Spell
local C_Timer = C_Timer
local C_UnitAuras = C_UnitAuras
local CreateColor = CreateColor
local CreateFrame = CreateFrame
local CreateFramePool = CreateFramePool
local Enum = Enum
local FrameUtil = FrameUtil
local GetActionInfo = GetActionInfo
local GetTime = GetTime
local GridLayoutUtil = GridLayoutUtil
local hooksecurefunc = hooksecurefunc
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local issecretvalue = issecretvalue
local Item = Item
local MainActionBar = MainActionBar
local math_ceil = math.ceil
local MultiBar5 = MultiBar5
local MultiBar6 = MultiBar6
local MultiBar7 = MultiBar7
local MultiBarBottomLeft = MultiBarBottomLeft
local MultiBarBottomRight = MultiBarBottomRight
local MultiBarLeft = MultiBarLeft
local MultiBarRight = MultiBarRight
local next = next
local pairs = pairs
local PetActionBar = PetActionBar
local PixelUtil = PixelUtil
local rawget = rawget
local StanceBar = StanceBar
local string_format = string.format
local table_insert = table.insert
local time = time
local type = type
local UnitCastingDuration = UnitCastingDuration
local UnitCastingInfo = UnitCastingInfo
local UnitChannelDuration = UnitChannelDuration
local UnitChannelInfo = UnitChannelInfo
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local wipe = wipe

local inCombat = false
local registeredButtons = {}
local watchedUnit = 'target'

local DesatCurve = C_CurveUtil.CreateCurve()
DesatCurve:SetType(Enum.LuaCurveType.Step)
DesatCurve:AddPoint(0, 0)
DesatCurve:AddPoint(0.001, 1)

local ReadyCurve = C_CurveUtil.CreateCurve()
ReadyCurve:SetType(Enum.LuaCurveType.Step)
ReadyCurve:AddPoint(0, 1)
ReadyCurve:AddPoint(0.001, 0)

local IntCooldownCurve = C_CurveUtil.CreateCurve()
IntCooldownCurve:SetType(Enum.LuaCurveType.Step)
IntCooldownCurve:AddPoint(0, 0)
IntCooldownCurve:AddPoint(0.001, 1)

local timerColorCurve = C_CurveUtil.CreateColorCurve()
timerColorCurve:SetType(Enum.LuaCurveType.Linear)
timerColorCurve:AddPoint(0.0,  CreateColor(1, 0.5, 0.5, 1))
timerColorCurve:AddPoint(3.0,  CreateColor(1, 1,   0.5, 1))
timerColorCurve:AddPoint(3.01, CreateColor(1, 1,   1,   1))
timerColorCurve:AddPoint(10.0, CreateColor(1, 1,   1,   1))

local customCDMAuras = {}
local customCDMSpellMap = {}

-- ==============================
-- 기능 1: 아이콘 색상 및 텍스트
-- ==============================
local keyCache = {}
local function get_shortened_key(text)
    local RANGE_INDICATOR = "●"
    if not text or text == "" or text == RANGE_INDICATOR then return text end
    if keyCache[text] then return keyCache[text] end
    local result = text:upper()
    for _, rule in ipairs(config.replaceText) do result = result:gsub(rule[1], rule[2]) end
    keyCache[text] = result
    return result
end

local function update_button_text(btn)
    if not btn.HotKey then return end
    
    local enabled = (dodo.DB and dodo.DB.enableActionBarModule ~= false)
    local hideHotkeys = enabled and (dodo.DB and dodo.DB.useActionbarHideHotkeys ~= false)
    local hideMacroNames = enabled and (dodo.DB and dodo.DB.useActionbarHideMacroNames == true)
    
    local RANGE_INDICATOR = "●"
    local text = btn.HotKey:GetText()

    if hideHotkeys then
        btn.HotKey:SetAlpha(text == RANGE_INDICATOR and 1 or 0)
    else
        btn.HotKey:SetAlpha(1)
        local short = get_shortened_key(text)
        if text ~= short then btn.HotKey:SetText(short) end
    end
    if btn.Name and not (btn:GetName() or ""):find("Pet") then
        btn.Name:SetAlpha(hideMacroNames and 0 or 1)
    end
end

local function update_icon_color(btn)
    if not btn.icon then return end

    local enabled = (dodo.DB and dodo.DB.enableActionBarModule ~= false)
    local useColor = enabled and (dodo.DB and dodo.DB.useActionbarColor ~= false)
    if not useColor then
        btn.icon:SetVertexColor(1, 1, 1)
        btn.icon:SetDesaturation(0)
        return
    end

    local r, g, b, desat = 1, 1, 1, 0
    if btn.__isOutOfRange then
        r, g, b, desat = config.colors.range.r, config.colors.range.g, config.colors.range.b, 1
    elseif btn.__isNotEnoughMana then
        r, g, b, desat = config.colors.mana.r, config.colors.mana.g, config.colors.mana.b, 1
    else
        r, g, b = config.colors.normal.r, config.colors.normal.g, config.colors.normal.b
        if btn.__isUsable == false then
            desat = 1
        elseif btn.__cdVal then
            desat = btn.__cdVal:EvaluateRemainingDuration(DesatCurve)
        else
            desat = 0
        end
    end
    btn.icon:SetVertexColor(r, g, b)
    btn.icon:SetDesaturation(desat)
end

local function update_state(btn)
    if not btn.action then return end
    local isUsable, notEnoughMana = C_ActionBar.IsUsableAction(btn.action)
    local inRange = C_ActionBar.IsActionInRange(btn.action)
    btn.__isUsable = isUsable
    btn.__isNotEnoughMana = notEnoughMana
    btn.__isOutOfRange = (inRange == false)
    update_icon_color(btn)
    update_button_text(btn)
end

local function update_cooldown_state(btn)
    if not btn.action then return end
    local dur  = C_ActionBar.GetActionCooldownDuration(btn.action)
    local info = C_ActionBar.GetActionCooldown(btn.action)
    btn.__cdVal = (dur and info and not info.isOnGCD) and dur or nil
    update_icon_color(btn)
end

local function actionbar_apply_color()
    for btn in pairs(registeredButtons) do
        if btn:IsVisible() then update_icon_color(btn) end
    end
end

local function actionbar_apply_text()
    for btn in pairs(registeredButtons) do
        if btn:IsVisible() then update_button_text(btn) end
    end
end
-- ==============================
-- 기능 2: 패딩
-- ==============================
local function update_padding(frame)
    if InCombatLockdown() or not frame or not frame.shownButtonContainers then return end

    local enabled = (dodo.DB and dodo.DB.enableActionBarModule ~= false)
    if not enabled then return end

    local pad = (dodo.DB and dodo.DB.actionbarPadding) or 0
    local numRows = frame.numRows or 1
    local stride  = math_ceil(#frame.shownButtonContainers / numRows)
    local xMult   = frame.addButtonsToRight and 1 or -1
    local yMult   = frame.addButtonsToTop and 1 or -1
    local anchor  = frame.addButtonsToTop
        and (frame.addButtonsToRight and "BOTTOMLEFT" or "BOTTOMRIGHT")
        or  (frame.addButtonsToRight and "TOPLEFT"    or "TOPRIGHT")

    local layout = frame.isHorizontal
        and GridLayoutUtil.CreateStandardGridLayout(stride, pad, pad, xMult, yMult)
        or  GridLayoutUtil.CreateVerticalGridLayout(stride, pad, pad, xMult, yMult)
    GridLayoutUtil.ApplyGridLayout(frame.shownButtonContainers, AnchorUtil.CreateAnchor(anchor, frame, anchor), layout)
    if frame.Layout then frame:Layout() end
end

local function actionbar_apply_padding()
    local bars = {
        MainActionBar, MultiBarBottomLeft, MultiBarBottomRight,
        MultiBarRight, MultiBarLeft, MultiBar5, MultiBar6, MultiBar7,
        StanceBar, PetActionBar
    }
    for _, bar in ipairs(bars) do
        if bar then update_padding(bar) end
    end
end
-- ==============================
-- 기능 3: CDM 오버레이
-- ==============================
local function get_action_spell_or_item_id(actionID)
    local actionType, id = GetActionInfo(actionID)
    if actionType == "spell" then
        return "spell", id
    elseif actionType == "item" then
        return "item", id
    elseif actionType == "macro" then
        local spellID = C_ActionBar.GetActionMacroSpellIndex(actionID)
        if spellID then
            return "spell", spellID
        end
    end
    return nil, nil
end

local cdmUpdateFrame = CreateFrame("Frame")
local elapsedSinceLastUpdate = 0
local activeOverlays = {}

local function CDMUpdateFrame_OnUpdate(self, elapsed)
    elapsedSinceLastUpdate = elapsedSinceLastUpdate + elapsed
    local interval = inCombat and 0.1 or 1.0
    if elapsedSinceLastUpdate < interval then return end
    elapsedSinceLastUpdate = 0

    local hasActive = false
    local now = GetTime()
    for overlay in pairs(activeOverlays) do
        if overlay.fakeAuraSpellID and overlay.fakeAuraEndTime then
            hasActive = true
            local remaining = overlay.fakeAuraEndTime - now
            if remaining > -0.5 then
                overlay.Timer:SetFormattedText("%.0f", remaining > 0 and remaining or 0)
                overlay.Timer:Show()
                overlay.InnerGlow:Show()
                overlay:Show()
            else
                customCDMAuras[overlay.fakeAuraSpellID] = nil
                overlay:StopFakeAura()
            end
        else
            local item = overlay.viewerItem
            local auraInstanceID = item and rawget(item, "auraInstanceID")
            local auraDataUnit   = item and rawget(item, "auraDataUnit")
            if auraInstanceID and auraDataUnit then
                hasActive = true
                local durObj = C_UnitAuras.GetAuraDuration(auraDataUnit, auraInstanceID)
                if durObj then
                    local remaining = durObj:GetRemainingDuration()
                    local isSecret = issecretvalue(remaining)
                    if isSecret or (remaining ~= overlay._lastRemaining) then
                        overlay.Timer:SetFormattedText("%.0f", remaining)
                        overlay.Timer:Show()
                        if not isSecret then
                            overlay._lastRemaining = remaining
                        end
                    end
                else
                    overlay:StopTicker()
                end
            else
                overlay:StopTicker()
            end
        end
    end

    if not hasActive then
        self:SetScript("OnUpdate", nil)
    end
end

-- CDM Overlay Mixin
CDMOverlayMixin = {}

function CDMOverlayMixin:OnLoad()
    local parent = self:GetParent()
    self:SetSize(parent:GetSize())
    self:SetFrameLevel(parent:GetFrameLevel() + 1)
    self.InnerGlow:SetVertexColor(0, 1, 0, 1)
    self.Timer:SetTextColor(0, 1, 0)
    self.Timer:Hide()
    self.Count:SetTextColor(1, 1, 0)
    self:Hide()
end

function CDMOverlayMixin:StartTicker()
    activeOverlays[self] = true
    if not cdmUpdateFrame:GetScript("OnUpdate") then
        cdmUpdateFrame:SetScript("OnUpdate", CDMUpdateFrame_OnUpdate)
    end
end

function CDMOverlayMixin:StopTicker()
    activeOverlays[self] = nil
    self._lastRemaining = nil
    self.Timer:Hide()
    self.Count:Hide()
    self.InnerGlow:Hide()
    self:Hide()
    if not next(activeOverlays) then
        cdmUpdateFrame:SetScript("OnUpdate", nil)
    end
end

function CDMOverlayMixin:StartFakeAura(spellID, duration)
    self.fakeAuraSpellID = spellID
    self.fakeAuraEndTime = GetTime() + duration
    self.InnerGlow:Show()
    self.Timer:Show()
    self:Show()

    activeOverlays[self] = true
    if not cdmUpdateFrame:GetScript("OnUpdate") then
        cdmUpdateFrame:SetScript("OnUpdate", CDMUpdateFrame_OnUpdate)
    end
end

function CDMOverlayMixin:StopFakeAura()
    self.fakeAuraSpellID = nil
    self.fakeAuraEndTime = nil
    self:StopTicker()
end

function CDMOverlayMixin:Update()
    local enabled = (dodo.DB and dodo.DB.enableActionBarModule ~= false)
    local isEnabled = enabled and (dodo.DB and dodo.DB.useActionbarCDM ~= false)
    if not isEnabled then self:StopTicker(); return end

    local parent = self:GetParent()
    local parentName = parent and parent:GetName() or ""
    if parentName:find("^MultiBar7Button") and parent.action then
        local actionType, id = get_action_spell_or_item_id(parent.action)
        local activeFake = nil
        local matchedSpellID = nil
        if actionType == "spell" then
            local baseSpellID = C_Spell.GetBaseSpell(id)
            matchedSpellID = baseSpellID or id
            activeFake = customCDMAuras[matchedSpellID]
        elseif actionType == "item" then
            local _, spellID = C_Item.GetItemSpell(id)
            matchedSpellID = spellID or id
            activeFake = customCDMAuras[matchedSpellID]
        end

        if activeFake then
            local remaining = activeFake.duration - (GetTime() - activeFake.startTime)
            if remaining > 0 then
                self:StartFakeAura(matchedSpellID, remaining)
                return
            else
                customCDMAuras[matchedSpellID] = nil
            end
        end
    end

    local item = self.viewerItem
    local auraInstanceID = item and rawget(item, "auraInstanceID")
    local auraDataUnit   = item and rawget(item, "auraDataUnit")

    if auraInstanceID and auraDataUnit then
        local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(auraDataUnit, auraInstanceID)
        if aura then
            local count = C_UnitAuras.GetAuraApplicationDisplayCount(auraDataUnit, auraInstanceID)
            local hasDisplayCount = false
            if issecretvalue(count) then
                hasDisplayCount = true
            elseif type(count) == "number" then
                hasDisplayCount = (count > 0)
            elseif type(count) == "string" then
                hasDisplayCount = (count ~= "" and count ~= "0")
            end

            if hasDisplayCount then
                self.Count:SetText(count)
                self.Count:Show()
            else
                self.Count:Hide()
            end

            self.InnerGlow:Show()
            self:Show()

            self:StartTicker()
        else
            self:StopTicker()
        end
    else
        self:StopTicker()
    end
end

-- ==============================
-- 기능 3: CDM 오버레이 (캐시/후킹)
-- ==============================
local function build_button_cache()
    dodo.buttonCache = dodo.buttonCache or {}
    wipe(dodo.buttonCache)
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
                    if spellName then
                        dodo.buttonCache[spellName] = dodo.buttonCache[spellName] or {}
                        table_insert(dodo.buttonCache[spellName], btn)
                    end
                end
            end
        end
    end
end

local function update_cdm_from_item(item)
    local isEnabled = (dodo.DB and dodo.DB.useActionbarCDM ~= false)
    if not isEnabled or not item or not item.cooldownID then return end

    local cdInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(item.cooldownID)
    if not cdInfo or not cdInfo.spellID then return end
    local baseSpellID = C_Spell.GetBaseSpell(cdInfo.spellID)
    
    -- 매핑 확인 (버프 ID -> 대상 스펠 ID)
    local targetSpellID = CDMMapping[baseSpellID] or baseSpellID
    local spellName = C_Spell.GetSpellName(targetSpellID)

    local buttons = spellName and dodo.buttonCache and dodo.buttonCache[spellName]
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

local function hook_viewer_item(item)
    if not item.__AB2Hooked then
        hooksecurefunc(item, "RefreshData", function() update_cdm_from_item(item) end)
        item.__AB2Hooked = true
    end
    update_cdm_from_item(item)
end

local isCachePending = false
local function build_special_button_cache()
    if InCombatLockdown() or isCachePending then return end
    isCachePending = true
    C_Timer.After(0.1, function()
        isCachePending = false
        if InCombatLockdown() then return end
        
        local cdmBars = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBar7Button" }
        for _, group in ipairs(cdmBars) do
            for i = 1, 12 do
                local btn = _G[group .. i]
                if btn and btn.action then
                    if not btn.cdmOverlay then
                        btn.cdmOverlay = CreateFrame("Frame", nil, btn, "CDMOverlayTemplate")
                    end
                    btn.cdmOverlay:ClearAllPoints()
                    btn.cdmOverlay:SetAllPoints(btn)
                end
            end
        end
        build_button_cache()
    end)
end

local function actionbar_apply_cdm()
    local cdmBars = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBar7Button" }
    for _, group in ipairs(cdmBars) do
        for i = 1, 12 do
            local btn = _G[group .. i]
            if btn and btn.cdmOverlay then btn.cdmOverlay:Update() end
        end
    end
end
-- ==============================
-- 기능 4: 커스텀 CDM (물약)
-- ==============================
local function init_fake_aura_spells()
    for id, config in pairs(customCDMConfigs) do
        if C_Item.GetItemInfoInstant(id) then
            -- 아이템(Item)으로 판별된 경우
            local item = Item:CreateFromItemID(id)
            if item and not item:IsItemEmpty() then
                item:ContinueOnItemLoad(function()
                    local _, spellID = C_Item.GetItemSpell(id)
                    if spellID then
                        customCDMSpellMap[spellID] = id
                    end
                end)
            end
            customCDMSpellMap[id] = id
        else
            -- 주문(Spell)으로 판별된 경우
            customCDMSpellMap[id] = id
        end
    end
end

local function get_matching_buttons(targetSpellID, targetItemID)
    local matched = {}
    for i = 1, 12 do
        local btn = _G["MultiBar7Button" .. i]
        if btn and btn.action then
            local actionType, id = get_action_spell_or_item_id(btn.action)
            if actionType == "spell" then
                local baseSpellID = C_Spell.GetBaseSpell(id)
                if baseSpellID == targetSpellID or id == targetSpellID then
                    table_insert(matched, btn)
                end
            elseif actionType == "item" then
                if id == targetItemID then
                    table_insert(matched, btn)
                end
            end
        end
    end
    return matched
end


-- ==============================
-- 기능 5: 차단 오버레이
-- ==============================
InterruptOverlayMixin = {}

function InterruptOverlayMixin:OnHide()
    self:StopAnim()
    self:StopTimer()
end

function InterruptOverlayMixin:OnUpdate(elapsed)
    self.timerElapsed = (self.timerElapsed or 0) + elapsed
    if self.timerElapsed < 0.1 then return end
    self.timerElapsed = 0
    if self.duration then
        local remaining = self.duration:GetRemainingDuration()
        local isSecret = issecretvalue(remaining)
        if isSecret or (remaining ~= self._lastRemaining) then
            local color = self.duration:EvaluateRemainingDuration(timerColorCurve)
            self.TimerReady:SetFormattedText("%.1f", remaining)
            self.TimerCooldown:SetFormattedText("%.1f", remaining)
            self.TimerReady:SetTextColor(color:GetRGB())
            if not isSecret then
                self._lastRemaining = remaining
            end
        end
    else
        self:StopTimer()
    end
end

function InterruptOverlayMixin:StopAnim()
    if self.ProcLoop:IsPlaying() then self.ProcLoop:Stop() end
end

function InterruptOverlayMixin:StartTimer(duration)
    self.duration = duration
    self.timerElapsed = 0.1
    self.TimerReady:Show()
    self.TimerCooldown:Show()
    self:SetScript('OnUpdate', self.OnUpdate)
end

function InterruptOverlayMixin:StopTimer()
    self.duration = nil
    self.timerElapsed = 0
    self.TimerReady:Hide()
    self.TimerCooldown:Hide()
    self:SetScript('OnUpdate', nil)
end

function InterruptOverlayMixin:Update(active, notInterruptible, duration, readyVal, cooldownVal)
    local isEnabled = (dodo.DB and dodo.DB.useActionbarInterrupt ~= false)
    if not isEnabled then self:Hide(); return end

    if active then
        self:StartTimer(duration)
        self.ProcReady:SetAlpha(readyVal)
        self.TimerReady:SetAlpha(readyVal)
        self.ProcCooldown:SetAlpha(cooldownVal)
        self.TimerCooldown:SetAlpha(cooldownVal)
        if not self.ProcLoop:IsPlaying() then self.ProcLoop:Play() end
        self:SetAlphaFromBoolean(notInterruptible, 0, 1)
        self:Show()
    else
        self:Hide()
    end
end

function InterruptOverlayMixin:Attach(actionButton)
    self:SetParent(actionButton)
    self.button = actionButton
    self:ClearAllPoints()
    self:SetPoint('CENTER')
    local w, h = actionButton:GetSize()
    PixelUtil.SetSize(self, w, h)
    self.ProcReady:SetSize(w * 1.4, h * 1.4)
    self.ProcCooldown:SetSize(w * 1.4, h * 1.4)
    if actionButton.cooldown and not actionButton.__dodoAB3Hooked then
        actionButton.cooldown:HookScript("OnCooldownDone", function()
            dodoAB3ControllerMixin.controller:Update()
        end)
        actionButton.__dodoAB3Hooked = true
    end
end

-- Interrupt Controller Mixin
dodoAB3ControllerMixin = {}

function dodoAB3ControllerMixin:OnLoad()
    dodoAB3ControllerMixin.controller = self
    self:RegisterEvent('PLAYER_LOGIN')
end

function dodoAB3ControllerMixin:Initialize()
    self.overlayPool = CreateFramePool('Frame', nil, 'InterruptOverlayTemplate')
    FrameUtil.RegisterFrameForEvents(self, IntEvents)
    for _, event in ipairs(IntUnitEvents) do
        self:RegisterUnitEvent(event, 'focus', 'target')
    end
    watchedUnit = UnitExists('focus') and 'focus' or 'target'
end

function dodoAB3ControllerMixin:IsRelevantActionID(actionID)
    local _, spellID = GetActionInfo(actionID)
    if Interrupts[spellID] then return true end
    for overlay in self.overlayPool:EnumerateActive() do
        if overlay.spellID == spellID then return true end
    end
    return false
end

function dodoAB3ControllerMixin:CreateOverlays()
    self.overlayPool:ReleaseAll()
    for _, actionButton in pairs(ActionBarButtonEventsFrame.frames) do
        local _, spellID = GetActionInfo(actionButton.action)
        if Interrupts[spellID] then
            local overlay = self.overlayPool:Acquire()
            overlay.spellID = spellID
            overlay:Attach(actionButton)
        end
    end
end

function dodoAB3ControllerMixin:RefreshOverlays(isActive, notInterruptible, castDuration)
    for overlay in self.overlayPool:EnumerateActive() do
        local readyVal, cooldownVal = 1, 0
        if isActive and overlay.button and overlay.button.action then
            local cdDuration = C_ActionBar.GetActionCooldownDuration(overlay.button.action)
            local cdInfo     = C_ActionBar.GetActionCooldown(overlay.button.action)
            if cdDuration and cdInfo and not cdInfo.isOnGCD then
                readyVal    = cdDuration:EvaluateRemainingDuration(ReadyCurve)
                cooldownVal = cdDuration:EvaluateRemainingDuration(IntCooldownCurve)
            end
        end
        overlay:Update(isActive, notInterruptible, castDuration, readyVal, cooldownVal)
    end
end

function dodoAB3ControllerMixin:Update()
    local enabled = (dodo.DB and dodo.DB.enableActionBarModule ~= false)
    local isEnabled = enabled and (dodo.DB and dodo.DB.useActionbarInterrupt ~= false)
    if not isEnabled then
        self:RefreshOverlays(false)
        return
    end

    local name, notInterruptible
    name, _, _, _, _, _, _, notInterruptible = UnitCastingInfo(watchedUnit)
    if name then
        self:RefreshOverlays(true, notInterruptible, UnitCastingDuration(watchedUnit))
        return
    end
    name, _, _, _, _, _, notInterruptible = UnitChannelInfo(watchedUnit)
    if name then
        self:RefreshOverlays(true, notInterruptible, UnitChannelDuration(watchedUnit))
        return
    end
    self:RefreshOverlays(false)
end

function dodoAB3ControllerMixin:OnEvent(event, ...)
    if event == 'PLAYER_LOGIN' then
        self:Initialize()
        self:CreateOverlays()
        self:Update()
    elseif event == 'ACTIONBAR_SLOT_CHANGED' then
        local actionID = ...
        if self:IsRelevantActionID(actionID) then
            self:CreateOverlays()
            self:Update()
        end
    elseif event == 'PLAYER_TARGET_CHANGED' or event == 'PLAYER_FOCUS_CHANGED' then
        watchedUnit = UnitExists('focus') and 'focus' or 'target'
        self:Update()
    elseif event:sub(1, 14) == 'UNIT_SPELLCAST' then
        local unit = ...
        if unit == watchedUnit then self:Update() end
    end
end

local function actionbar_apply_interrupt()
    if dodoAB3ControllerMixin.controller then
        dodoAB3ControllerMixin.controller:Update()
    end
end
-- ==============================
-- 이벤트
-- ==============================
local f = CreateFrame("Frame")
f:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
f:RegisterEvent("ACTION_RANGE_CHECK_UPDATE")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
f:RegisterEvent("UNIT_DIED")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "ACTIONBAR_SLOT_CHANGED" then
        local slot = ...
        if not slot or slot <= 72 then
            build_special_button_cache()
        end
    elseif event == "ACTION_RANGE_CHECK_UPDATE" then
        local slot = ...
        local slotButtons = ActionBarButtonRangeCheckFrame.actions and ActionBarButtonRangeCheckFrame.actions[slot]
        if slotButtons then
            for _, btn in pairs(slotButtons) do
                if btn:IsVisible() then update_state(btn) end
            end
        end
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        inCombat = (event == "PLAYER_REGEN_DISABLED")
        if not inCombat then build_special_button_cache() end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unitTarget, castGUID, spellID = ...
        local matchedItemID = customCDMSpellMap[spellID]
        if matchedItemID then
            local itemConfig = customCDMConfigs[matchedItemID]
            local duration = itemConfig and itemConfig.duration or 30
            if not customCDMAuras[spellID] then
                customCDMAuras[spellID] = { startTime = GetTime(), duration = duration, savedTime = time() }
                local buttons = get_matching_buttons(spellID, matchedItemID)
                for _, btn in ipairs(buttons) do
                    if btn.cdmOverlay then
                        btn.cdmOverlay:StartFakeAura(spellID, duration)
                    end
                end
            end
        end
    elseif event == "UNIT_DIED" then
        local guid = ...
        if guid == UnitGUID("player") then
            wipe(customCDMAuras)
            for overlay in pairs(activeOverlays) do
                if overlay.fakeAuraSpellID then
                    overlay:StopFakeAura()
                end
            end
        end
    end
end)

-- ==============================
-- 모듈 생명주기
-- ==============================
function module:OnEnable()
    if dodo.DB then
        if dodo.DB.enableActionBarModule == nil then dodo.DB.enableActionBarModule = true end
        if dodo.DB.useActionbarColor == nil then dodo.DB.useActionbarColor = true end
        if dodo.DB.useActionbarHideHotkeys == nil then dodo.DB.useActionbarHideHotkeys = true end
        if dodo.DB.useActionbarHideMacroNames == nil then dodo.DB.useActionbarHideMacroNames = false end
        if dodo.DB.actionbarPadding == nil then dodo.DB.actionbarPadding = 0 end
        if dodo.DB.useActionbarCDM == nil then dodo.DB.useActionbarCDM = true end
        if dodo.DB.useActionbarInterrupt == nil then dodo.DB.useActionbarInterrupt = true end
    end

    local groups = {
        "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
        "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
        "StanceButton", "PetActionButton"
    }
    for _, group in ipairs(groups) do
        for i = 1, 12 do
            local btn = _G[group .. i]
            if btn then
                registeredButtons[btn] = true
                if btn.Update then hooksecurefunc(btn, "Update", update_state) end
                if btn.UpdateUsable then hooksecurefunc(btn, "UpdateUsable", update_state) end
                if (group == "StanceButton" or group == "PetActionButton") and btn.UpdateState then
                    hooksecurefunc(btn, "UpdateState", update_state)
                end
                if btn.cooldown then
                    btn.cooldown:HookScript("OnCooldownDone", function()
                        btn.__cdVal = nil
                        update_icon_color(btn)
                    end)
                end
                update_state(btn)
                update_cooldown_state(btn)
            end
        end
    end

    hooksecurefunc("ActionButton_ApplyCooldown", function(cd)
        local btn = cd:GetParent()
        if btn and registeredButtons[btn] then
            C_Timer.After(0, function()
                if btn:IsVisible() then update_cooldown_state(btn) end
            end)
        end
    end)

    local bars = {
        MainActionBar, MultiBarBottomLeft, MultiBarBottomRight,
        MultiBarRight, MultiBarLeft, MultiBar5, MultiBar6, MultiBar7,
        StanceBar, PetActionBar
    }
    for _, bar in ipairs(bars) do
        if bar then
            hooksecurefunc(bar, "UpdateGridLayout", update_padding)
            update_padding(bar)
        end
    end

    local cdmHook = function(_, item) hook_viewer_item(item) end
    hooksecurefunc(BuffBarCooldownViewer, "OnAcquireItemFrame", cdmHook)
    hooksecurefunc(BuffIconCooldownViewer, "OnAcquireItemFrame", cdmHook)

    C_Timer.After(0.5, function()
        init_fake_aura_spells()
        build_special_button_cache()
        for _, item in ipairs(BuffBarCooldownViewer:GetItemFrames()) do hook_viewer_item(item) end
        for _, item in ipairs(BuffIconCooldownViewer:GetItemFrames()) do hook_viewer_item(item) end
    end)

    if LibEditMode then
        local settingType = LibEditMode.SettingType
        local actionBarSystem = Enum.EditModeSystem.ActionBar or 1
    
        LibEditMode:AddSystemSettings(actionBarSystem, {
            {
                kind = settingType.Slider,
                name = "아이콘 패딩",
                desc = "행동단축바 버튼 사이의 간격을 조절합니다.",
                default = 0,
                minValue = -5,
                maxValue = 10,
                valueStep = 1,
                get = function()
                    return dodo.DB and dodo.DB.actionbarPadding or 0
                end,
                set = function(_, newValue)
                    if dodo.DB then
                        dodo.DB.actionbarPadding = newValue
                    end
                    actionbar_apply_padding()
                end,
            },
            {
                kind = settingType.Checkbox,
                name = "아이콘 색상 변경",
                desc = "사거리 부족 (빨강) \n자원 부족 (파랑) \n사용불가(흑백) 색상을 적용합니다.",
                default = true,
                get = function()
                    return dodo.DB and dodo.DB.useActionbarColor ~= false
                end,
                set = function(_, newValue)
                    if dodo.DB then
                        dodo.DB.useActionbarColor = newValue
                    end
                    actionbar_apply_color()
                end,
            },
            {
                kind = settingType.Checkbox,
                name = "아이콘 단축키 숨기기",
                desc = "행동단축바 버튼의 단축키 텍스트를 숨깁니다.",
                default = true,
                get = function()
                    return dodo.DB and dodo.DB.useActionbarHideHotkeys ~= false
                end,
                set = function(_, newValue)
                    if dodo.DB then
                        dodo.DB.useActionbarHideHotkeys = newValue
                    end
                    actionbar_apply_text()
                end,
            },
            {
                kind = settingType.Checkbox,
                name = "아이콘 매크로명 숨기기",
                desc = "행동단축바 버튼의 매크로 이름을 숨깁니다.",
                default = false,
                get = function()
                    return dodo.DB and dodo.DB.useActionbarHideMacroNames == true
                end,
                set = function(_, newValue)
                    if dodo.DB then
                        dodo.DB.useActionbarHideMacroNames = newValue
                    end
                    actionbar_apply_text()
                end,
            },
            {
                kind = settingType.Checkbox,
                name = "CDM 강화효과 오버레이",
                desc = "추적 중인 강화효과(CDM)를 강조하여 표시합니다.",
                default = true,
                get = function()
                    return dodo.DB and dodo.DB.useActionbarCDM ~= false
                end,
                set = function(_, newValue)
                    if dodo.DB then
                        dodo.DB.useActionbarCDM = newValue
                    end
                    actionbar_apply_cdm()
                end,
            },
            {
                kind = settingType.Checkbox,
                name = "차단 오버레이",
                desc = "주시 혹은 대상을 차단 가능할 때 버튼에 강조 효과를 줍니다.",
                default = true,
                get = function()
                    return dodo.DB and dodo.DB.useActionbarInterrupt ~= false
                end,
                set = function(_, newValue)
                    if dodo.DB then
                        dodo.DB.useActionbarInterrupt = newValue
                    end
                    actionbar_apply_interrupt()
                end,
            },
        })
    end
end

-- ==============================
-- 외부 노출 (통합 편집모드 연동용)
-- ==============================
dodo.UpdateActionBarModuleState = function()
    for btn in pairs(registeredButtons) do
        if btn:IsVisible() then
            update_state(btn)
            update_cooldown_state(btn)
        end
    end
    
    local bars = {
        MainActionBar, MultiBarBottomLeft, MultiBarBottomRight,
        MultiBarRight, MultiBarLeft, MultiBar5, MultiBar6, MultiBar7,
        StanceBar, PetActionBar
    }
    for _, bar in ipairs(bars) do
        if bar and bar.UpdateGridLayout then
            if not InCombatLockdown() then
                bar:UpdateGridLayout()
            end
        end
    end

    local cdmBars = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBar7Button" }
    for _, group in ipairs(cdmBars) do
        for i = 1, 12 do
            local btn = _G[group .. i]
            if btn and btn.cdmOverlay then btn.cdmOverlay:Update() end
        end
    end

    if dodoAB3ControllerMixin.controller then
        dodoAB3ControllerMixin.controller:Update()
    end
end