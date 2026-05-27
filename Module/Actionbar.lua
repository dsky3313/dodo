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
dodoDB = dodoDB or {}

local FeatureBars = {
    color = {
        ["MainActionBar"]       = true,
        ["MultiBarBottomLeft"]  = true,
        ["MultiBarBottomRight"] = true,
        ["MultiBarRight"]       = false,
        ["MultiBarLeft"]        = false,
        ["MultiBar5"]           = false,
        ["MultiBar6"]           = false,
        ["MultiBar7"]           = false,
        ["StanceBar"]           = false,
        ["PetActionBar"]        = false,
    },
    textHide = {
        ["MainActionBar"]       = true,
        ["MultiBarBottomLeft"]  = true,
        ["MultiBarBottomRight"] = true,
        ["MultiBarRight"]       = false,
        ["MultiBarLeft"]        = false,
        ["MultiBar5"]           = false,
        ["MultiBar6"]           = false,
        ["MultiBar7"]           = true,
        ["StanceBar"]           = true,
        ["PetActionBar"]        = true,
    },
    textShorten = {
        ["MainActionBar"]       = true,
        ["MultiBarBottomLeft"]  = true,
        ["MultiBarBottomRight"] = true,
        ["MultiBarRight"]       = false,
        ["MultiBarLeft"]        = false,
        ["MultiBar5"]           = false,
        ["MultiBar6"]           = false,
        ["MultiBar7"]           = true,
        ["StanceBar"]           = true,
        ["PetActionBar"]        = true,
    },
    padding = {
        ["MainActionBar"]       = true,
        ["MultiBarBottomLeft"]  = true,
        ["MultiBarBottomRight"] = true,
        ["MultiBarRight"]       = true,
        ["MultiBarLeft"]        = true,
        ["MultiBar5"]           = true,
        ["MultiBar6"]           = true,
        ["MultiBar7"]           = true,
        ["StanceBar"]           = true,
        ["PetActionBar"]        = true,
    },
    cdm = {
        ["MainActionBar"]       = true,
        ["MultiBarBottomLeft"]  = true,
        ["MultiBarBottomRight"] = true,
        ["MultiBar7"]           = true,
    },
    interrupt = {
        ["MainActionBar"]       = true,
    },
    potion = {
        ["MultiBar7"]           = true,
    }
}

local CDMMapping = {
    [386634] = 12294, -- 집행자의 정밀함  - 필사의 일격 (무전)
    [12950] = 190411, 6343 -- 소용돌이 연마  - 소용돌이 (분전)
}

local POTION_IDS = { -- 포션 쿨
    [241308] = true, [241309] = true, -- 빛의 잠재력
}

local customCDMConfigs = { -- 포션 cdm
    [1236616] = { matchIDs = { 241308, 241309 }, duration = 30, type = 3 }, --1236616(버프ID) 발동 시 241308, 241309(물약 등) 매칭
}

local customCDMAuras = {}
local customCDMSpellMap = {}

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
local C_Container = C_Container
local C_Item = C_Item
local C_Spell = C_Spell
local C_UnitAuras = C_UnitAuras
local CreateColor = CreateColor
local CreateFrame = CreateFrame
local GetActionInfo = GetActionInfo
local GetTime = GetTime
local hooksecurefunc = hooksecurefunc
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local issecretvalue = issecretvalue
local Item = Item
local math_ceil = math.ceil
local next = next
local pairs = pairs
local rawget = rawget
local string_format = string.format
local table_insert = table.insert
local tostring = tostring
local type = type
local UnitCastingDuration = UnitCastingDuration
local UnitCastingInfo = UnitCastingInfo
local UnitChannelDuration = UnitChannelDuration
local UnitChannelInfo = UnitChannelInfo
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local wipe = wipe

local ActionBarButtonEventsFrame = ActionBarButtonEventsFrame
local ActionBarButtonRangeCheckFrame = ActionBarButtonRangeCheckFrame
local AnchorUtil = AnchorUtil
local BuffBarCooldownViewer = BuffBarCooldownViewer
local BuffIconCooldownViewer = BuffIconCooldownViewer
local CreateFramePool = CreateFramePool
local FrameUtil = FrameUtil
local GridLayoutUtil = GridLayoutUtil
local MainActionBar = MainActionBar
local MultiBar5 = MultiBar5
local MultiBar6 = MultiBar6
local MultiBar7 = MultiBar7
local MultiBarBottomLeft = MultiBarBottomLeft
local MultiBarBottomRight = MultiBarBottomRight
local MultiBarLeft = MultiBarLeft
local MultiBarRight = MultiBarRight
local PixelUtil = PixelUtil
local PetActionBar = PetActionBar
local StanceBar = StanceBar

local activeOverlays = {}
local inCombat = false
local registeredButtons = {}
local watchedUnit = 'target'
local update_potion_proc

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

local function get_bar_name_by_button(btn)
    if not btn then return nil end
    if btn.__barName then return btn.__barName end

    local name = btn:GetName()
    if not name then return nil end

    local barName
    if name:find("^ActionButton") then
        barName = "MainActionBar"
    elseif name:find("^MultiBarBottomLeftButton") then
        barName = "MultiBarBottomLeft"
    elseif name:find("^MultiBarBottomRightButton") then
        barName = "MultiBarBottomRight"
    elseif name:find("^MultiBarRightButton") then
        barName = "MultiBarRight"
    elseif name:find("^MultiBarLeftButton") then
        barName = "MultiBarLeft"
    elseif name:find("^MultiBar5Button") then
        barName = "MultiBar5"
    elseif name:find("^MultiBar6Button") then
        barName = "MultiBar6"
    elseif name:find("^MultiBar7Button") then
        barName = "MultiBar7"
    elseif name:find("^StanceButton") then
        barName = "StanceBar"
    elseif name:find("^PetActionButton") then
        barName = "PetActionBar"
    end

    btn.__barName = barName
    return barName
end

-- ==============================
-- 기능 1: 아이콘 색상 및 단축키 텍스트
-- ==============================
local keyCache = {}
local function GetShortenedKey(text)
    local RANGE_INDICATOR = "●"
    if not text or text == "" or text == RANGE_INDICATOR then return text end
    if keyCache[text] then return keyCache[text] end
    local result = text:upper()
    for _, rule in ipairs(config.replaceText) do result = result:gsub(rule[1], rule[2]) end
    keyCache[text] = result
    return result
end

local function UpdateButtonText(btn)
    if not btn.HotKey then return end

    local barName = get_bar_name_by_button(btn)
    if not barName or not FeatureBars.textHide[barName] then return end
    
    local hideHotkeys = (dodoDB and dodoDB.useActionbarHideHotkeys ~= false)
    local hideMacroNames = (dodoDB and dodoDB.useActionbarHideMacroNames == true)
    
    local RANGE_INDICATOR = "●"
    local text = btn.HotKey:GetText()

    if hideHotkeys then
        btn.HotKey:SetAlpha(text == RANGE_INDICATOR and 1 or 0)
    else
        btn.HotKey:SetAlpha(1)
        if FeatureBars.textShorten[barName] then
            local short = GetShortenedKey(text)
            if text ~= short then btn.HotKey:SetText(short) end
        end
    end
    if btn.Name and not (btn:GetName() or ""):find("Pet") then
        btn.Name:SetAlpha(hideMacroNames and 0 or 1)
    end
end

local function UpdateIconColor(btn)
    if not btn.icon then return end

    local barName = get_bar_name_by_button(btn)
    if not barName or not FeatureBars.color[barName] then
        if btn.__lastR ~= 1 or btn.__lastG ~= 1 or btn.__lastB ~= 1 then
            btn.icon:SetVertexColor(1, 1, 1)
            btn.__lastR, btn.__lastG, btn.__lastB = 1, 1, 1
        end
        if btn.__lastDesat ~= 0 then
            btn.icon:SetDesaturation(0)
            btn.__lastDesat = 0
        end
        return
    end

    local useColor = (dodoDB and dodoDB.useActionbarColor ~= false)
    if not useColor then
        if btn.__lastR ~= 1 or btn.__lastG ~= 1 or btn.__lastB ~= 1 then
            btn.icon:SetVertexColor(1, 1, 1)
            btn.__lastR, btn.__lastG, btn.__lastB = 1, 1, 1
        end
        if btn.__lastDesat ~= 0 then
            btn.icon:SetDesaturation(0)
            btn.__lastDesat = 0
        end
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

    if r ~= btn.__lastR or g ~= btn.__lastG or b ~= btn.__lastB then
        btn.icon:SetVertexColor(r, g, b)
        btn.__lastR, btn.__lastG, btn.__lastB = r, g, b
    end
    if issecretvalue(desat) then
        btn.icon:SetDesaturation(desat)
        btn.__lastDesat = nil
    else
        if desat ~= btn.__lastDesat then
            btn.icon:SetDesaturation(desat)
            btn.__lastDesat = desat
        end
    end
end

local function UpdateState(btn)
    if not btn.action then return end
    local isUsable, notEnoughMana = C_ActionBar.IsUsableAction(btn.action)
    local inRange = C_ActionBar.IsActionInRange(btn.action)
    btn.__isUsable = isUsable
    btn.__isNotEnoughMana = notEnoughMana
    btn.__isOutOfRange = (inRange == false)
    UpdateIconColor(btn)
    UpdateButtonText(btn)
    update_potion_proc(btn)
end

local function UpdateCooldownState(btn)
    if not btn.action then return end
    local dur  = C_ActionBar.GetActionCooldownDuration(btn.action)
    local info = C_ActionBar.GetActionCooldown(btn.action)
    btn.__cdVal = (dur and info and not info.isOnGCD) and dur or nil
    UpdateIconColor(btn)
    update_potion_proc(btn)
end

-- ==============================
-- 기능 2: 단축바 버튼 간격 조절 (패딩)
-- ==============================
local anchorCache = {}
local layoutCache = {}

local function GetCachedAnchor(anchorPoint, frame)
    local key = anchorPoint .. "_" .. frame:GetName()
    if not anchorCache[key] then
        anchorCache[key] = AnchorUtil.CreateAnchor(anchorPoint, frame, anchorPoint)
    end
    return anchorCache[key]
end

local function GetCachedLayout(isHorizontal, stride, pad, xMult, yMult)
    local key = (isHorizontal and "H" or "V") .. "_" .. stride .. "_" .. pad .. "_" .. xMult .. "_" .. yMult
    if not layoutCache[key] then
        if isHorizontal then
            layoutCache[key] = GridLayoutUtil.CreateStandardGridLayout(stride, pad, pad, xMult, yMult)
        else
            layoutCache[key] = GridLayoutUtil.CreateVerticalGridLayout(stride, pad, pad, xMult, yMult)
        end
    end
    return layoutCache[key]
end

local function UpdatePadding(frame)
    if InCombatLockdown() or not frame or not frame.shownButtonContainers then return end

    local frameName = frame:GetName()
    if not frameName or not FeatureBars.padding[frameName] then return end

    local pad = (dodoDB and dodoDB.actionbarPadding) or 0
    local numRows = frame.numRows or 1
    local stride  = math_ceil(#frame.shownButtonContainers / numRows)
    local xMult   = frame.addButtonsToRight and 1 or -1
    local yMult   = frame.addButtonsToTop and 1 or -1
    local anchor  = frame.addButtonsToTop
        and (frame.addButtonsToRight and "BOTTOMLEFT" or "BOTTOMRIGHT")
        or  (frame.addButtonsToRight and "TOPLEFT"    or "TOPRIGHT")

    local layout = GetCachedLayout(frame.isHorizontal, stride, pad, xMult, yMult)
    local anchorObj = GetCachedAnchor(anchor, frame)

    GridLayoutUtil.ApplyGridLayout(frame.shownButtonContainers, anchorObj, layout)
    if frame.Layout then frame:Layout() end
end

-- ==============================
-- 기능 3: 강화효과 오버레이 (CDM)
-- ==============================
local cdmUpdateFrame = CreateFrame("Frame")
local elapsedSinceLastUpdate = 0

local function cdm_updateframe_onupdate(self, elapsed)
    elapsedSinceLastUpdate = elapsedSinceLastUpdate + elapsed
    local interval = inCombat and 0.1 or 1.0
    if elapsedSinceLastUpdate < interval then return end
    elapsedSinceLastUpdate = 0

    local hasActive = false
    local now = GetTime()
    for overlay in pairs(activeOverlays) do
        if overlay.customCDMSpellID and overlay.customCDMEndTime then
            hasActive = true
            local remaining = overlay.customCDMEndTime - now
            if remaining > -0.5 then
                local intVal = math.floor(remaining > 0 and remaining or 0)
                if intVal ~= overlay._lastRemainingInt then
                    overlay.Timer:SetFormattedText("%.0f", intVal)
                    overlay.Timer:Show()
                    overlay._lastRemainingInt = intVal
                end
                overlay.InnerGlow:Show()
                overlay:Show()
            else
                customCDMAuras[overlay.customCDMSpellID] = nil
                overlay:StopCustomCDM()
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
                    if isSecret then
                        overlay.Timer:SetFormattedText("%.0f", remaining)
                        overlay.Timer:Show()
                        overlay._lastRemainingInt = nil
                    else
                        local intVal = math.floor(remaining)
                        if intVal ~= overlay._lastRemainingInt then
                            overlay.Timer:SetFormattedText("%.0f", intVal)
                            overlay.Timer:Show()
                            overlay._lastRemainingInt = intVal
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
    self.Count:SetTextColor(1, 1, 0)
    self:Hide()
end

function CDMOverlayMixin:StartTicker()
    activeOverlays[self] = true
    if not cdmUpdateFrame:GetScript("OnUpdate") then
        cdmUpdateFrame:SetScript("OnUpdate", cdm_updateframe_onupdate)
    end
end

function CDMOverlayMixin:StopTicker()
    activeOverlays[self] = nil
    self._lastRemaining = nil
    self._lastRemainingInt = nil
    self.Timer:Hide()
    self.Count:Hide()
    self.InnerGlow:Hide()
    self:Hide()
    if not next(activeOverlays) then
        cdmUpdateFrame:SetScript("OnUpdate", nil)
    end
end

function CDMOverlayMixin:StartCustomCDM(spellID, duration)
    self.customCDMSpellID = spellID
    self.customCDMEndTime = GetTime() + duration
    self.InnerGlow:Show()
    self.Timer:Show()
    self:Show()

    activeOverlays[self] = true
    if not cdmUpdateFrame:GetScript("OnUpdate") then
        cdmUpdateFrame:SetScript("OnUpdate", cdm_updateframe_onupdate)
    end
end

function CDMOverlayMixin:StopCustomCDM()
    self.customCDMSpellID = nil
    self.customCDMEndTime = nil
    self._lastRemainingInt = nil
    self:StopTicker()
end

function CDMOverlayMixin:Update()
    local isEnabled = (dodoDB and dodoDB.useActionbarCDM ~= false)
    if not isEnabled then self:StopTicker(); return end

    local parent = self:GetParent()
    if not parent then return end
    
    local barName = get_bar_name_by_button(parent)
    if not barName or not FeatureBars.cdm[barName] then self:StopTicker(); return end
    
    if FeatureBars.potion[barName] and parent.action then
        local actionType, id = GetActionInfo(parent.action)
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

        if activeFake and matchedSpellID then
            local remaining = activeFake.duration - (GetTime() - activeFake.startTime)
            if remaining > 0 then
                self:StartCustomCDM(matchedSpellID, remaining)
                return
            else
                customCDMAuras[matchedSpellID] = nil
            end
        end
    end

    local hasAura = self.viewerItem and rawget(self.viewerItem, "auraInstanceID") ~= nil
    if hasAura then
        local item = self.viewerItem
        local auraInstanceID = rawget(item, "auraInstanceID")
        local auraDataUnit   = rawget(item, "auraDataUnit")
        
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
end

local function BuildButtonCache()
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

local function UpdateCDMFromItem(item)
    local isEnabled = (dodoDB and dodoDB.useActionbarCDM ~= false)
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

local function HookViewerItem(item)
    if not item.__AB2Hooked then
        hooksecurefunc(item, "RefreshData", function() UpdateCDMFromItem(item) end)
        item.__AB2Hooked = true
    end
    UpdateCDMFromItem(item)
end

local isCachePending = false
local function BuildSpecialButtonCache()
    if InCombatLockdown() or isCachePending then return end
    isCachePending = true
    C_Timer.After(0.1, function()
        isCachePending = false
        if InCombatLockdown() then return end
        
        local cdmBars = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBar7Button" }
        for _, group in ipairs(cdmBars) do
            for i = 1, 12 do
                local btn = _G[group .. i]
                if btn then
                    local barName = get_bar_name_by_button(btn)
                    if btn.action and barName and FeatureBars.cdm[barName] then
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
        BuildButtonCache()
    end)
end

-- ==============================
-- 기능 4: 차단 강조 오버레이
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
    local isEnabled = (dodoDB and dodoDB.useActionbarInterrupt ~= false)
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
        local barName = get_bar_name_by_button(actionButton)
        if barName and FeatureBars.interrupt[barName] then
            local _, spellID = GetActionInfo(actionButton.action)
            if Interrupts[spellID] then
                local overlay = self.overlayPool:Acquire()
                overlay.spellID = spellID
                overlay:Attach(actionButton)
            end
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
    local isEnabled = (dodoDB and dodoDB.useActionbarInterrupt ~= false)
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

-- ==============================
-- 기능 5: 물약 프록 및 CDM 연동
-- ==============================
-- Potion Overlay Mixin
PotionOverlayMixin = {}
function PotionOverlayMixin:Update(active)
    if active then
        if not self.ProcLoop:IsPlaying() then self.ProcLoop:Play() end
        self:Show()
    else
        if self.ProcLoop:IsPlaying() then self.ProcLoop:Stop() end
        self:Hide()
    end
end

update_potion_proc = function(btn)
    if not btn.action then return end
    
    local isEnabled = (dodoDB and dodoDB.useActionbarPotionProc ~= false)
    if not isEnabled then
        if btn.potionOverlay then btn.potionOverlay:Update(false) end
        return
    end

    local barName = get_bar_name_by_button(btn)
    if not barName or not FeatureBars.potion[barName] then
        if btn.potionOverlay then btn.potionOverlay:Update(false) end
        return
    end

    if btn.__isPotion == nil then
        local actionType, id = GetActionInfo(btn.action)
        btn.__isPotion = (actionType == "item" and POTION_IDS[id] == true)
        btn.__potionItemID = btn.__isPotion and id or nil
    end

    if btn.__isPotion then
        local id = btn.__potionItemID
        if not btn.potionOverlay then
            btn.potionOverlay = CreateFrame("Frame", nil, btn, "PotionOverlayTemplate")
            btn.potionOverlay:SetAllPoints(btn)
            local w, h = btn:GetSize()
            btn.potionOverlay.Proc:SetSize(w * 1.4, h * 1.4)
        end
        
        local count = C_Item.GetItemCount(id)
        local start, duration = C_Container.GetItemCooldown(id)
        local isUsable = inCombat and (count > 0) and (start == 0 or duration == 0)
        btn.potionOverlay:Update(isUsable)
    elseif btn.potionOverlay then
        btn.potionOverlay:Update(false)
    end
end

local function update_all_potion_procs()
    for i = 1, 12 do
        local btn = _G["MultiBar7Button" .. i]
        if btn and btn:IsVisible() then
            update_potion_proc(btn)
        end
    end
end

local function init_custom_cdm_spells()
    for key, itemConfig in pairs(customCDMConfigs) do
        customCDMSpellMap[key] = key
        if itemConfig.matchIDs then
            for _, tID in ipairs(itemConfig.matchIDs) do
                if C_Item.GetItemInfoInstant(tID) then
                    local item = Item:CreateFromItemID(tID)
                    if item and not item:IsItemEmpty() then
                        item:ContinueOnItemLoad(function()
                            local _, spellID = C_Item.GetItemSpell(tID)
                            if spellID then
                                customCDMSpellMap[spellID] = key
                            end
                        end)
                    end
                else
                    customCDMSpellMap[tID] = key
                end
            end
        end
        
        if type(key) == "number" and not itemConfig.matchIDs and C_Item.GetItemInfoInstant(key) then
            local item = Item:CreateFromItemID(key)
            if item and not item:IsItemEmpty() then
                item:ContinueOnItemLoad(function()
                    local _, spellID = C_Item.GetItemSpell(key)
                    if spellID then
                        customCDMSpellMap[spellID] = key
                    end
                end)
            end
        end
    end
end

local function get_matching_buttons(targetSpellID, configKey)
    local matched = {}
    local itemConfig = customCDMConfigs[configKey]
    for i = 1, 12 do
        local btn = _G["MultiBar7Button" .. i]
        if btn and btn.action then
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
                    table_insert(matched, btn)
                end
            elseif actionType == "item" then
                local isMatch = false
                if itemConfig and itemConfig.matchIDs then
                    for _, tID in ipairs(itemConfig.matchIDs) do
                        if id == tID then isMatch = true; break end
                    end
                end
                if isMatch or id == configKey then
                    table_insert(matched, btn)
                else
                    local _, btnSpellID = C_Item.GetItemSpell(id)
                    if btnSpellID and btnSpellID == targetSpellID then
                        table_insert(matched, btn)
                    end
                end
            end
        end
    end
    return matched
end

-- ==============================
-- 이벤트 및 초기화
-- ==============================
local isPotionPending = false
local function do_potion_bag_update()
    isPotionPending = false
    update_all_potion_procs()
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
f:RegisterEvent("ACTION_RANGE_CHECK_UPDATE")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
f:RegisterEvent("UNIT_DIED")
f:RegisterEvent("PLAYER_DEAD")
f:RegisterEvent("BAG_UPDATE")

f:SetScript("OnEvent", function(self, event, ...)
    local arg1 = ...
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
    elseif event == "PLAYER_LOGIN" then
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
                    if btn.Update then hooksecurefunc(btn, "Update", UpdateState) end
                    if btn.UpdateUsable then hooksecurefunc(btn, "UpdateUsable", UpdateState) end
                    if (group == "StanceButton" or group == "PetActionButton") and btn.UpdateState then
                        hooksecurefunc(btn, "UpdateState", UpdateState)
                    end
                    if btn.cooldown then
                        btn.cooldown:HookScript("OnCooldownDone", function()
                            btn.__cdVal = nil
                            UpdateIconColor(btn)
                        end)
                    end
                    UpdateState(btn)
                    UpdateCooldownState(btn)
                end
            end
        end

        -- 쿨다운이 적용된 버튼에만 반응 (전체 순회 없이 영향받은 버튼만 처리)
        hooksecurefunc("ActionButton_ApplyCooldown", function(cd)
            local btn = cd:GetParent()
            if btn and registeredButtons[btn] then
                C_Timer.After(0, function()
                    if btn:IsVisible() then UpdateCooldownState(btn) end
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
                hooksecurefunc(bar, "UpdateGridLayout", UpdatePadding)
                UpdatePadding(bar)
            end
        end

        local cdmHook = function(_, item) HookViewerItem(item) end
        hooksecurefunc(BuffBarCooldownViewer, "OnAcquireItemFrame", cdmHook)
        hooksecurefunc(BuffIconCooldownViewer, "OnAcquireItemFrame", cdmHook)

        init_custom_cdm_spells()
        update_all_potion_procs()

        C_Timer.After(0.5, function()
            BuildSpecialButtonCache()
            for _, item in ipairs(BuffBarCooldownViewer:GetItemFrames()) do HookViewerItem(item) end
            for _, item in ipairs(BuffIconCooldownViewer:GetItemFrames()) do HookViewerItem(item) end
        end)

    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        local slot = ...
        -- CDM 버튼 슬롯(1~72)에 해당할 때만 캐시 재빌드 (불필요한 재빌드 방지)
        if not slot or slot <= 72 then
            BuildSpecialButtonCache()
        end

    elseif event == "ACTION_RANGE_CHECK_UPDATE" then
        local slot = ...
        local slotButtons = ActionBarButtonRangeCheckFrame.actions and ActionBarButtonRangeCheckFrame.actions[slot]
        if slotButtons then
            for _, btn in pairs(slotButtons) do
                if btn:IsVisible() then UpdateState(btn) end
            end
        end

    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        inCombat = (event == "PLAYER_REGEN_DISABLED")
        for overlay in pairs(activeOverlays) do overlay:StartTicker() end
        update_all_potion_procs()
        if not inCombat then BuildSpecialButtonCache() end

    elseif event == "BAG_UPDATE" then
        if not isPotionPending then
            isPotionPending = true
            C_Timer.After(0.1, do_potion_bag_update)
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unitTarget, castGUID, spellID = ...
        local matchedItemID = customCDMSpellMap[spellID]
        if matchedItemID then
            local itemConfig = customCDMConfigs[matchedItemID]
            local duration = itemConfig and itemConfig.duration or 30
            local refreshType = itemConfig and itemConfig.type or 1
            
            local now = GetTime()
            local activeAura = customCDMAuras[spellID]
            
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
                    customCDMAuras[spellID] = { startTime = now, duration = duration }
                end
            else
                customCDMAuras[spellID] = { startTime = now, duration = duration }
            end
            
            local updatedAura = customCDMAuras[spellID]
            local currentRemaining = updatedAura.duration - (now - updatedAura.startTime)
            
            local buttons = get_matching_buttons(spellID, matchedItemID)
            for _, btn in ipairs(buttons) do
                if btn.cdmOverlay then
                    btn.cdmOverlay:StartCustomCDM(spellID, currentRemaining)
                end
            end
        end

    elseif event == "UNIT_DIED" or event == "PLAYER_DEAD" then
        local guid = ...
        if event == "PLAYER_DEAD" or (guid and not issecretvalue(guid) and guid == UnitGUID("player")) then
            wipe(customCDMAuras)
            for overlay in pairs(activeOverlays) do
                if overlay.customCDMSpellID then
                    overlay:StopCustomCDM()
                end
            end
        end
    end
end)

-- ==============================
-- 외부 노출 API
-- ==============================
dodo.ActionbarApplyColor = function()
    for btn in pairs(registeredButtons) do
        if btn:IsVisible() then UpdateIconColor(btn) end
    end
end

dodo.ActionbarApplyText = function()
    for btn in pairs(registeredButtons) do
        if btn:IsVisible() then UpdateButtonText(btn) end
    end
end

dodo.ActionbarApplyPadding = function()
    local bars = {
        MainActionBar, MultiBarBottomLeft, MultiBarBottomRight,
        MultiBarRight, MultiBarLeft, MultiBar5, MultiBar6, MultiBar7,
        StanceBar, PetActionBar
    }
    for _, bar in ipairs(bars) do
        if bar then UpdatePadding(bar) end
    end
end

dodo.ActionbarApplyCDM = function()
    local cdmBars = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBar7Button" }
    for _, group in ipairs(cdmBars) do
        for i = 1, 12 do
            local btn = _G[group .. i]
            if btn and btn.cdmOverlay then btn.cdmOverlay:Update() end
        end
    end
end

dodo.ActionbarApplyInterrupt = function()
    if dodoAB3ControllerMixin.controller then
        dodoAB3ControllerMixin.controller:Update()
    end
end

dodo.ActionbarApplyPotionProc = function()
    update_all_potion_procs()
end

-- ==============================
-- 설정 동적 등록
-- ==============================
local SettingsPanel = SettingsPanel
local CreateSettingsListSectionHeaderInitializer = CreateSettingsListSectionHeaderInitializer
local Checkbox = Checkbox
local Slider = Slider

dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["actionbar"] = dodo.OptionRegistrations["actionbar"] or {}
table.insert(dodo.OptionRegistrations["actionbar"], function(category)
    local layoutActionbar = SettingsPanel:GetLayout(category)
    if not layoutActionbar then return end

    layoutActionbar:AddInitializer(CreateSettingsListSectionHeaderInitializer("색상"))
    Checkbox(category, "useActionbarColor", "색상 변경", "사거리 부족 : 빨강 \n자원 부족 : 파랑 \n사용불가·쿨타임 : 흑백", true, dodo.ActionbarApplyColor)

    layoutActionbar:AddInitializer(CreateSettingsListSectionHeaderInitializer("텍스트"))
    Checkbox(category, "useActionbarHideHotkeys", "단축키 숨기기", "행동단축바 버튼의 단축키 텍스트를 숨깁니다.", true, dodo.ActionbarApplyText)
    Checkbox(category, "useActionbarHideMacroNames", "매크로 이름 숨기기", "행동단축바 버튼의 매크로 이름을 숨깁니다.", true, dodo.ActionbarApplyText)

    layoutActionbar:AddInitializer(CreateSettingsListSectionHeaderInitializer("레이아웃"))
    Slider(category, "actionbarPadding", "버튼 간격", "행동단축바 버튼 사이의 간격을 조절합니다.", -5, 10, 1, 2, "Integer", dodo.ActionbarApplyPadding)

    layoutActionbar:AddInitializer(CreateSettingsListSectionHeaderInitializer("오버레이"))
    Checkbox(category, "useActionbarCDM", "강화효과 오버레이", "추적중인 강화효과를 강조합니다.", true, dodo.ActionbarApplyCDM)
    Checkbox(category, "useActionbarInterrupt", "차단 오버레이", "주시 혹은 대상을 차단가능할 때 버튼을 강조합니다.", true, dodo.ActionbarApplyInterrupt)
    Checkbox(category, "useActionbarPotionProc", "물약 프록 오버레이", "전투 중 물약 사용 가능 시 버튼에 활성 애니메이션을 표시합니다.", true, dodo.ActionbarApplyPotionProc)
end)