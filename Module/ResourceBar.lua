-- ==============================
-- 설정
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local LibEditMode = LibStub and LibStub("LibEditMode", true)
local module = {}
dodo:RegisterModule("ResourceBar", module)

-- 바 크기
local barConfigs = {
    { name = "ResourceBar1", width = 270, height = 10, y = -220, level = 3000, template = "ResourceBar1Template" },
    { name = "ResourceBar2", width = 270, height = 7, y = -4, level = 3001, template = "ResourceBar2Template" }
}

local classConfig = {
    ["DEATHKNIGHT"] = { [1] = {{barMode = "rune"}}, [2] = {{barMode = "rune"}}, [3] = {{barMode = "rune"}} },
    ["DEMONHUNTER"] = { [2] = {{spellID = 203981, barMode = "stack", maxStack = 6}} }, -- 악탱 영혼파편
    ["DRUID"] = { [3] = {{spellID = 192081, barMode = "ironfur"}} }, -- 수드 무쇠가죽 (특수 트래킹)
    ["MONK"] = { [1] = {{barMode = "stagger"}} }, -- 양조 시간차
    ["SHAMAN"] = { [3] = {{spellID = 51564, barMode = "stack", maxStack = 3}} }, -- 복술 굽이치는물결
    ["WARRIOR"] = {
        [1] = {{spellID = 167105, barMode = "duration"}}, -- 무전 거강
        [2] = {
            {spellID = 12950,  barMode = "stack",    maxStack = 4, requiredSpell = 12950},  -- 분전 소용돌이연마
            {spellID = 184361, barMode = "duration", excludedSpell = 12950},  -- 분전 격노
        },
        [3] = {{spellID = 190456, barMode = "stack", maxStack = 100}} -- 전탱 고통감내
    },
}

local specColors = {
    ["DEATHKNIGHT"] = { [1] = {r=1, g=0, b=0}, [2] = {r=0, g=0.8, b=1}, [3] = {r=0.3, g=0.9, b=0.3} },
    ["DEMONHUNTER"] = { [2] = {r=0.86, g=0.59, b=0.98} },
    ["DRUID"] = { [3] = {r=0, g=0.82, b=1} },
    ["MONK"] = { [1] = {r=0, g=1, b=0.59} },
    ["SHAMAN"] = { [3] = {r=0, g=0.82, b=1} },
    ["WARRIOR"] = { [1] = {r=1, g=0.588, b=0.196}, [2] = {r=0, g=0.82, b=1}, [3] = {r=1, g=0.588, b=0.196} },
}

-- ==============================
-- 캐싱
-- ==============================
local currentSpecBuffs = {}
local cachedPowerType = nil
local cachedSpecColor = { r = 1, g = 1, b = 1 }
local bar2Frame
local runeIndexes = { 1, 2, 3, 4, 5, 6 }
local staggerTicker = nil
local ironfurExpiries = {}
local ironfurDurations = {}
local goeExpiry = 0
local ironfurBaseDuration = 7
local hasGoeTalent = false

local function RefreshIronfurTalents()
    -- 우르속의 인내력 (393611): 지속시간 +2초
    ironfurBaseDuration = C_SpellBook.IsSpellKnown(393611) and 9 or 7
    -- 엘룬의 수호자 (155578): 짓이기기가 다음 무쇠가죽/광재 지속시간 +3초
    hasGoeTalent = C_SpellBook.IsSpellKnown(155578)
end

local function RuneSortComparator(a, b)
    local aS, _, aR = GetRuneCooldown(a)
    local bS, _, bR = GetRuneCooldown(b)
    if aR ~= bR then return aR end
    if aS ~= bS then return (aS or 0) < (bS or 0) end
    return a < b
end

local function UpdateCurrentSpecConfig()
    local _, englishClass = UnitClass("player")
    local spec = C_SpecializationInfo.GetSpecialization()

    cachedSpecColor = (specColors[englishClass] and specColors[englishClass][spec]) or { r = 1, g = 1, b = 1 }

    local baseConfig = (classConfig[englishClass] and classConfig[englishClass][spec]) or {}
    currentSpecBuffs = baseConfig

    -- 조건부 필터링: requiredSpell/excludedSpell 필드로 탤런트 보유 여부에 따라 항목 선택
    -- 새 직업/특성 추가 시 classConfig만 수정하면 되고 이 코드는 변경 불필요
    currentSpecBuffs = {}
    for _, config in ipairs(baseConfig) do
        local ok = true
        if config.requiredSpell and not C_SpellBook.IsSpellKnown(config.requiredSpell) then
            ok = false
        end
        if config.excludedSpell and C_SpellBook.IsSpellKnown(config.excludedSpell) then
            ok = false
        end
        if ok then
            currentSpecBuffs[#currentSpecBuffs + 1] = config
        end
    end

    local bar2 = _G["ResourceBar2"]
    if bar2 then
        bar2:SetViewerItem(nil)
        bar2:SetBuffConfig(nil)
        bar2.currentPriority = nil
        if bar2.countStack then bar2.countStack:SetText("0") end
        bar2:SetValue(0)

        -- 전문화 변경 시 항상 기존 stagger 폴링 중단
        if staggerTicker then staggerTicker:Cancel(); staggerTicker = nil end
        
        -- 무쇠가죽 특성 정보 갱신
        RefreshIronfurTalents()

        if englishClass == "DEATHKNIGHT" then
            bar2:SetBuffConfig({ barMode = "rune" })
            bar2:RegisterEvent("RUNE_POWER_UPDATE")
        elseif englishClass == "MONK" and spec == 1 then
            bar2:SetBuffConfig({ barMode = "stagger" })
            bar2:UnregisterEvent("RUNE_POWER_UPDATE")
            staggerTicker = C_Timer.NewTicker(0.1, function()
                if bar2Frame and bar2Frame.buffConfig and bar2Frame.buffConfig.barMode == "stagger" then
                    bar2Frame:UpdateStaggerSystem()
                end
            end)
        else
            bar2:UnregisterEvent("RUNE_POWER_UPDATE")
        end
        bar2:Update()
    end
end

-- ==============================
-- Bar1 자원바
-- ==============================
local bar1Frame = CreateFrame("StatusBar", "ResourceBar1", UIParent, barConfigs[1].template)
bar1Frame:SetSize(barConfigs[1].width, barConfigs[1].height)
bar1Frame:SetPoint("CENTER", UIParent, "CENTER", 0, barConfigs[1].y)

local function UpdateBar1()
    if not bar1Frame or not bar1Frame:IsShown() then return end
    local pType, pToken = UnitPowerType("player")
    if pType ~= cachedPowerType then
        cachedPowerType = pType
        local c = PowerBarColor[pToken] or PowerBarColor[pType] or { r = 1, g = 1, b = 1 }
        bar1Frame:SetStatusBarColor(c.r, c.g, c.b)
    end
    local current = UnitPower("player", pType)
    local max = UnitPowerMax("player", pType)
    if max and max > 0 then
        bar1Frame:SetMinMaxValues(0, max)
        bar1Frame:SetValue(current, Enum.StatusBarInterpolation.ExponentialEaseOut)
        if bar1Frame.countPower then
            if pType == 0 then
                local pct = UnitPowerPercent("player", 0, false, CurveConstants and CurveConstants.ScaleTo100)
                if pct then
                    bar1Frame.countPower:SetFormattedText("%d", pct)
                else
                    bar1Frame.countPower:SetText("0")
                end
            else
                bar1Frame.countPower:SetText(current)
            end
        end
    end
end

local updateTicker = nil
local function OnCombatChange(inCombat)
    if updateTicker then updateTicker:Cancel(); updateTicker = nil end
    local isEnabled = (dodo.DB and dodo.DB.enableResourceBarModule ~= false)
    local useBar1 = (dodo.DB and dodo.DB.useResourceBar1 ~= false)
    if isEnabled and useBar1 then
        updateTicker = C_Timer.NewTicker(inCombat and 0.1 or 0.5, UpdateBar1)
    end
end

local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function(_, event) OnCombatChange(event == "PLAYER_REGEN_DISABLED") end)
OnCombatChange(false)

-- ==============================
-- Bar2 버프트래킹 Mixin
-- ==============================
local ResourceBar2Mixin = {}

function ResourceBar2Mixin:SetViewerItem(viewerItem) self.viewerItem = viewerItem end
function ResourceBar2Mixin:SetBuffConfig(buffConfig) self.buffConfig = buffConfig end

function ResourceBar2Mixin:UpdateIronfurTicks(stackCount, longestIdx, fillPct, barWidth, barHeight)
    if not self.ironfurTicks then self.ironfurTicks = {} end
    local now = GetTime()

    for i = 1, stackCount do
        local tick = self.ironfurTicks[i]
        if not tick then
            tick = self:CreateTexture(nil, "OVERLAY")
            tick:SetAtlas("cast-empowered-pipflare")
            self.ironfurTicks[i] = tick
        end

        local pct
        if i == longestIdx then
            pct = fillPct
        else
            pct = math.max(0, math.min(1, (ironfurExpiries[i] - now) / ironfurDurations[i]))
        end

        tick:SetSize(barHeight * 0.6, barHeight * 1.6)
        tick:ClearAllPoints()
        tick:SetPoint("CENTER", self, "LEFT", pct * barWidth, 0)
        tick:Show()
    end

    for i = stackCount + 1, #self.ironfurTicks do
        self.ironfurTicks[i]:Hide()
    end
end

local function UpdateIronfurSystem(f)
    local now = GetTime()
    while #ironfurExpiries > 0 and ironfurExpiries[1] <= now do
        table.remove(ironfurExpiries, 1)
        table.remove(ironfurDurations, 1)
    end

    local stackCount = #ironfurExpiries
    if stackCount == 0 then
        f:SetValue(0)
        if f.countStack then f.countStack:SetText("0") end
        if f.ironfurTicks then for _, t in ipairs(f.ironfurTicks) do t:Hide() end end
        f:SetScript("OnUpdate", nil)
        f._hasIronfurUpdate = false
        return
    end

    local longestIdx = 1
    local maxRem = 0
    for i = 1, stackCount do
        local rem = ironfurExpiries[i] - now
        if rem > maxRem then
            maxRem = rem
            longestIdx = i
        end
    end

    local fillPct = math.max(0, maxRem / ironfurDurations[longestIdx])
    f:SetValue(fillPct, Enum.StatusBarInterpolation.Immediate)
    if f.countStack then f.countStack:SetText(stackCount) end

    f:UpdateIronfurTicks(stackCount, longestIdx, fillPct, f:GetWidth(), f:GetHeight())
end

function ResourceBar2Mixin:OnEvent(event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        UpdateCurrentSpecConfig()
        RefreshIronfurTalents()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if spellID == 192081 then -- 무쇠가죽
            local now = GetTime()
            local bonus = (hasGoeTalent and now < goeExpiry) and 3 or 0
            if bonus > 0 then goeExpiry = 0 end 
            local duration = ironfurBaseDuration + bonus
            local n = #ironfurExpiries + 1
            ironfurExpiries[n] = now + duration
            ironfurDurations[n] = duration
            if not self._hasIronfurUpdate and self.buffConfig and self.buffConfig.barMode == "ironfur" then
                self:SetScript("OnUpdate", UpdateIronfurSystem)
                self._hasIronfurUpdate = true
            end
        elseif spellID == 33917 then -- 짓이기기
            if hasGoeTalent then
                goeExpiry = GetTime() + 15
            end
        end
    end
end

function ResourceBar2Mixin:GetSpecColor()
    return cachedSpecColor
end

local function Bar2DurationOnUpdate(f)
    local item = f.viewerItem
    if not item then return end
    
    local auraDataUnit = rawget(item, "auraDataUnit")
    local auraInstanceID = rawget(item, "auraInstanceID")
    if not auraDataUnit or not auraInstanceID then return end

    local durObj = C_UnitAuras.GetAuraDuration(auraDataUnit, auraInstanceID)
    if durObj and f.countStack then
        local rem = durObj:GetRemainingDuration()
        f.countStack:SetFormattedText("%.0f", rem)
    end
end

function ResourceBar2Mixin:UpdateStackTicks(maxStack)
    if not self.ticks then self.ticks = {} end

    for _, tick in ipairs(self.ticks) do tick:Hide() end

    if not maxStack or maxStack <= 1 or maxStack > 10 then
        self._lastMaxStack = nil
        return
    end

    if self._lastMaxStack == maxStack then
        for i = 1, maxStack - 1 do
            if self.ticks[i] then self.ticks[i]:Show() end
        end
        return
    end
    self._lastMaxStack = maxStack

    local barWidth = self:GetWidth()
    local barHeight = self:GetHeight()
    local scale = self:GetEffectiveScale()

    for i = 1, maxStack - 1 do
        if not self.ticks[i] then
            local tick = self:CreateTexture(nil, "OVERLAY")
            tick:SetColorTexture(0, 0, 0, 0.8)
            self.ticks[i] = tick
        end

        local tick = self.ticks[i]
        tick:ClearAllPoints()
        PixelUtil.SetSize(tick, 1, barHeight)
        local xOffset = (barWidth / maxStack) * i
        PixelUtil.SetPoint(tick, "LEFT", self, "LEFT", xOffset, 0)
        tick:Show()
    end
end

local function OnUpdateRuneBar(rb)
    if not rb.start or not rb.ctimer then return end
    local currTime = GetTime()
    local elapsed = currTime - rb.start
    if elapsed < rb.duration then
        rb:SetValue(elapsed, Enum.StatusBarInterpolation.ExponentialEaseOut)
    else
        rb:SetValue(rb.duration, Enum.StatusBarInterpolation.ExponentialEaseOut)
        rb.start = nil
        if rb.ctimer then rb.ctimer:Cancel(); rb.ctimer = nil end
    end
end

function ResourceBar2Mixin:UpdateRuneSystem()
    self:SetSize(barConfigs[2].width, barConfigs[2].height)

    if not self.runebars then
        self.runebars = {}
        local spacing = 0
        local barWidth = barConfigs[2].width - 2  -- 270
        local runeWidth = barWidth / 6  -- = 45px * 6 = 270px 정확
        for i = 1, 6 do
            local rb = CreateFrame("StatusBar", nil, self, "ResourceBar2Template")
            rb:SetSize(runeWidth, self:GetHeight())
            rb:SetPoint("LEFT", self, "LEFT", (i - 1) * runeWidth, 0)
            self.runebars[i] = rb
        end
    end
    if self.countStack then self.countStack:Hide() end
    self:SetStatusBarColor(0, 0, 0, 0)
    table.sort(runeIndexes, RuneSortComparator)
    local c = self:GetSpecColor()
    for i, index in ipairs(runeIndexes) do
        local start, duration, ready = GetRuneCooldown(index)
        local rb = self.runebars[i]
        rb:Show()
        rb:SetMinMaxValues(0, ready and 1 or duration)
        if ready then
            rb.start = nil
            if rb.ctimer then rb.ctimer:Cancel(); rb.ctimer = nil end
            rb:SetStatusBarColor(c.r, c.g, c.b)
            rb:SetValue(1)
        else
            rb:SetStatusBarColor(1, 1, 1)
            rb.start    = start
            rb.duration = duration
            if not rb.ctimer or rb.ctimer:IsCancelled() then
                rb.ctimer = C_Timer.NewTicker(0.1, function() OnUpdateRuneBar(rb) end)
            end
        end
    end
end

function ResourceBar2Mixin:UpdateStaggerSystem()
    if not self:IsShown() then return end
    if self.runebars then for _, rb in ipairs(self.runebars) do rb:Hide() end end
    if self.countStack then self.countStack:Show() end

    local stagger = UnitStagger("player") or 0
    local maxHealth = UnitHealthMax("player") or 1
    self:SetMinMaxValues(0, maxHealth)
    self:SetValue(stagger, Enum.StatusBarInterpolation.ExponentialEaseOut)

    local pct = 0
    local isSecret = issecretvalue(stagger) or issecretvalue(maxHealth)
    
    if not isSecret then
        pct = (stagger / maxHealth) * 100
        if pct >= 60 then
            self:SetStatusBarColor(1, 0, 0)
        elseif pct >= 30 then
            self:SetStatusBarColor(1, 0.8, 0)
        else
            local c = self:GetSpecColor()
            self:SetStatusBarColor(c.r, c.g, c.b)
        end
        if self.countStack then
            if stagger == 0 then
                self.countStack:SetText("0")
            else
                self.countStack:SetFormattedText("%.0f", pct)
            end
        end
    else
        -- 12.0.0 인스턴스 제한 상황 (비밀 값)
        -- 산술 연산이 불가능하므로 전용 API와 오라를 사용하여 처리
        local sPct = C_PaperDollInfo.GetStaggerPercentage("player")
        
        -- 오라를 통해 색상 결정 (Light/Moderate/Heavy)
        if C_UnitAuras.GetPlayerAuraBySpellID(124273) then -- Heavy
            self:SetStatusBarColor(1, 0, 0)
        elseif C_UnitAuras.GetPlayerAuraBySpellID(124274) then -- Moderate
            self:SetStatusBarColor(1, 0.8, 0)
        else -- Light or None
            local c = self:GetSpecColor()
            self:SetStatusBarColor(c.r, c.g, c.b)
        end
        
        if self.countStack then
            -- SetText는 비밀 값을 지원함
            if sPct == 0 then
                self.countStack:SetText("0")
            else
                self.countStack:SetText(sPct)
            end
        end
    end
end

function ResourceBar2Mixin:Update()
    if not self:IsShown() then return end
    if self.buffConfig and self.buffConfig.barMode == "rune" then
        self:UpdateRuneSystem(); self:Show(); return
    end
    if self.buffConfig and self.buffConfig.barMode == "stagger" then
        self:UpdateStaggerSystem(); self:Show(); return
    end

    -- 룬바 숨기기
    if self.runebars then for _, rb in ipairs(self.runebars) do rb:Hide() end end
    if self.countStack then self.countStack:Show() end

    local maxValue = 100
    if self.buffConfig then
        if self.buffConfig.barMode == "duration" then
            maxValue = self.buffConfig.duration or 20
            if self.ticks then for _, tick in ipairs(self.ticks) do tick:Hide() end end -- 지속시간 모드에선 틱 숨김
        elseif self.buffConfig.barMode == "stack" then
            maxValue = self.buffConfig.maxStack or 100
            self:UpdateStackTicks(maxValue) -- 스택 모드일 때 틱 생성
        end
    end

    self:SetMinMaxValues(0, maxValue)
    local c = self:GetSpecColor()
    self:SetStatusBarColor(c.r, c.g, c.b)

    if not self.viewerItem or not self.viewerItem.auraInstanceID then
        if self.countStack then self.countStack:SetText("0") end
        self:SetValue(0, Enum.StatusBarInterpolation.ExponentialEaseOut)
        if self._hasDurationUpdate then self:SetScript("OnUpdate", nil); self._hasDurationUpdate = false end
        return
    end

    local unit, auraID = self.viewerItem.auraDataUnit, self.viewerItem.auraInstanceID
    local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraID)
    if auraData then
        if self.buffConfig and self.buffConfig.barMode == "duration" then
            local durObj = C_UnitAuras.GetAuraDuration(unit, auraID)
            if durObj then
                self:SetTimerDuration(durObj, Enum.StatusBarInterpolation.ExponentialEaseOut, Enum.StatusBarTimerDirection.RemainingTime)
                if not self._hasDurationUpdate then
                    self:SetScript("OnUpdate", Bar2DurationOnUpdate)
                    self._hasDurationUpdate = true
                end
            end
        elseif self.buffConfig and self.buffConfig.barMode == "ironfur" then
            self:SetMinMaxValues(0, 1)
            if not self._hasIronfurUpdate then
                self:SetScript("OnUpdate", UpdateIronfurSystem)
                self._hasIronfurUpdate = true
            end
        else
            if self._hasDurationUpdate then self:SetScript("OnUpdate", nil); self._hasDurationUpdate = false end
            if self._hasIronfurUpdate then self:SetScript("OnUpdate", nil); self._hasIronfurUpdate = false end
            local countBar = auraData.applications or 0
            if self.countStack then self.countStack:SetText(countBar) end
            self:SetValue(countBar, Enum.StatusBarInterpolation.ExponentialEaseOut)
        end
        self:Show()
    end
end

-- ==============================
-- Bar2 Updater
-- ==============================
local ResourceBar2UpdaterMixin = {}

function ResourceBar2UpdaterMixin:OnLoad()
    self.bar2Frame = bar2Frame
    local hook = function(_, item) self:HookViewerItem(item) end
    hooksecurefunc(BuffBarCooldownViewer, 'OnAcquireItemFrame', hook)
    hooksecurefunc(BuffIconCooldownViewer, 'OnAcquireItemFrame', hook)
    UpdateCurrentSpecConfig()
end

function ResourceBar2UpdaterMixin:UpdateFromItem(item)
    if not item or not item.cooldownID then return end

    local cdInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(item.cooldownID)
    if not cdInfo or not cdInfo.spellID then return end

    local spellID = C_Spell.GetBaseSpell(cdInfo.spellID)

    for i, config in ipairs(currentSpecBuffs) do
        if spellID == config.spellID then
            if self.bar2Frame.buffConfig and self.bar2Frame.currentPriority and i > self.bar2Frame.currentPriority then
                local curItem = self.bar2Frame.viewerItem
                if curItem and rawget(curItem, "auraDataUnit") and rawget(curItem, "auraInstanceID") then
                    local curAura = C_UnitAuras.GetAuraDataByAuraInstanceID(curItem.auraDataUnit, curItem.auraInstanceID)
                    if curAura then return end -- 더 높은 우선순위 버프가 유지 중이면 무시
                end
            end

            local hasAuraData = rawget(item, "auraDataUnit") ~= nil and rawget(item, "auraInstanceID") ~= nil

            if hasAuraData then
                self.bar2Frame:SetViewerItem(item)
                self.bar2Frame:SetBuffConfig(config)
                self.bar2Frame.currentPriority = i
                self.bar2Frame:Update()
            else
                if self.bar2Frame.viewerItem == item then
                    self.bar2Frame:SetViewerItem(nil)
                    self.bar2Frame:SetBuffConfig(nil)
                    self.bar2Frame.currentPriority = nil
                    self.bar2Frame:Update()
                end
            end
            return
        end
    end
end

function ResourceBar2UpdaterMixin:HookViewerItem(item)
    if not item.cdmHooked then
        hooksecurefunc(item, 'RefreshData', function() self:UpdateFromItem(item) end)
        item.cdmHooked = true
    end
    self:UpdateFromItem(item)
end

-- ==============================
-- 초기화 / 이벤트
-- ==============================
bar2Frame = CreateFrame("StatusBar", "ResourceBar2", UIParent, barConfigs[2].template)
Mixin(bar2Frame, ResourceBar2Mixin)
bar2Frame:SetSize(barConfigs[2].width, barConfigs[2].height)
bar2Frame:SetPoint("TOP", bar1Frame, "BOTTOM", 0, barConfigs[2].y)

local function ToggleBar2Events(enable)
    if enable then
        bar2Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        bar2Frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        bar2Frame:RegisterEvent("PLAYER_TALENT_UPDATE")
        bar2Frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        local _, class = UnitClass("player")
        if class == "DEATHKNIGHT" then
            bar2Frame:RegisterEvent("RUNE_POWER_UPDATE")
        end
    else
        bar2Frame:UnregisterAllEvents()
    end
end

bar2Frame:SetScript("OnEvent", function(self, event, ...)
    -- Mixin된 OnEvent 호출
    self:OnEvent(event, ...)
    
    -- 룬 시스템 특수 처리
    if event == "RUNE_POWER_UPDATE" and self.UpdateRuneSystem then
        self:UpdateRuneSystem()
    end
end)

local updater = CreateFrame("Frame"); Mixin(updater, ResourceBar2UpdaterMixin)
function dodoUpdateResourceBarOption()
    if not bar1Frame or not bar2Frame then return end

    local width = (dodo.DB and dodo.DB.resourceBarWidth) or 270
    local height = (dodo.DB and dodo.DB.resourceBarHeight) or 10
    local height2 = math.max(height - 3, 5)

    bar1Frame:SetSize(width, height)
    bar2Frame:SetSize(width, height2)

    local fontSize = (dodo.DB and dodo.DB.resourceBarFontSize) or 12
    if bar1Frame.countPower then
        local font, _, flags = bar1Frame.countPower:GetFont()
        bar1Frame.countPower:SetFont(font, fontSize, flags)
    end
    if bar2Frame.countStack then
        local font, _, flags = bar2Frame.countStack:GetFont()
        bar2Frame.countStack:SetFont(font, fontSize, flags)
    end

    if dodo.DB and dodo.DB.resourceBarX and dodo.DB.resourceBarY then
        bar1Frame:ClearAllPoints()
        bar1Frame:SetPoint(dodo.DB.resourceBarPoint or "CENTER", UIParent, dodo.DB.resourceBarPoint or "CENTER", dodo.DB.resourceBarX, dodo.DB.resourceBarY)
    else
        bar1Frame:ClearAllPoints()
        bar1Frame:SetPoint("CENTER", UIParent, "CENTER", 0, -220)
    end

    bar2Frame:ClearAllPoints()
    bar2Frame:SetPoint("TOP", bar1Frame, "BOTTOM", 0, -4)
end

local function UpdateResourceBarVisibility()
    dodoUpdateResourceBarOption()

    local isEnabled = (dodo.DB and dodo.DB.enableResourceBarModule ~= false)
    if not isEnabled then
        bar1Frame:Hide()
        bar2Frame:Hide()
        if staggerTicker then staggerTicker:Cancel(); staggerTicker = nil end
        if updateTicker then updateTicker:Cancel(); updateTicker = nil end
        ToggleBar2Events(false)
        return
    end

    if dodo.DB and dodo.DB.useResourceBar1 ~= false then
        bar1Frame:Show()
        UpdateBar1()
        OnCombatChange(UnitAffectingCombat("player"))
    else
        bar1Frame:Hide()
        if updateTicker then updateTicker:Cancel(); updateTicker = nil end
    end

    if dodo.DB and dodo.DB.useResourceBar2 ~= false then
        bar2Frame:Show()
        ToggleBar2Events(true)
        UpdateCurrentSpecConfig()
    else
        bar2Frame:Hide()
        ToggleBar2Events(false)
        if staggerTicker then staggerTicker:Cancel(); staggerTicker = nil end
    end
end

dodo.UpdateResourceBarModuleState = function()
    UpdateResourceBarVisibility()
end

function module:OnEnable()
    updater:OnLoad()
    dodoUpdateResourceBarOption()
    UpdateResourceBarVisibility()

    -- LibEditMode 등록
    bar1Frame.editModeName = "dodo 개인 자원바"
    if LibEditMode then
        LibEditMode:AddFrame(
            bar1Frame,
            function(frame, layoutName, point, x, y)
                if dodo.DB then
                    dodo.DB.resourceBarX = x
                    dodo.DB.resourceBarY = y
                    dodo.DB.resourceBarPoint = point
                end
            end,
            {
                point = "CENTER",
                x = 0,
                y = -220,
            },
            "dodo 개인 자원바"
        )

        LibEditMode:AddFrameSettings(bar1Frame, {
            {
                kind = LibEditMode.SettingType.Checkbox,
                name = "플레이어 자원바",
                desc = "마나/분노 등의 자원을 나타내는 기본 자원바를 활성화합니다.",
                default = true,
                get = function()
                    return (dodo.DB and dodo.DB.useResourceBar1 ~= false)
                end,
                set = function(_, newValue)
                    if dodo.DB then dodo.DB.useResourceBar1 = newValue end
                    UpdateResourceBarVisibility()
                end,
            },
            {
                kind = LibEditMode.SettingType.Checkbox,
                name = "버프 추적 바",
                desc = "특성에 따른 주요 버프를 나타내는 트래킹 바를 활성화합니다.",
                default = true,
                get = function()
                    return (dodo.DB and dodo.DB.useResourceBar2 ~= false)
                end,
                set = function(_, newValue)
                    if dodo.DB then dodo.DB.useResourceBar2 = newValue end
                    UpdateResourceBarVisibility()
                end,
            },
            {
                kind = LibEditMode.SettingType.Slider,
                name = "바 가로 크기",
                desc = "자원바와 버프트래킹 바의 가로 너비를 조절합니다.",
                default = 268,
                minValue = 200,
                maxValue = 300,
                valueStep = 2,
                get = function()
                    return (dodo.DB and dodo.DB.resourceBarWidth) or 268
                end,
                set = function(_, newValue)
                    if dodo.DB then dodo.DB.resourceBarWidth = newValue end
                    dodoUpdateResourceBarOption()
                end,
            },
            {
                kind = LibEditMode.SettingType.Slider,
                name = "바 세로 크기",
                desc = "자원바의 세로 두께를 조절합니다. (버프바는 자동 비례 조절됩니다.)",
                default = 10,
                minValue = 6,
                maxValue = 20,
                valueStep = 1,
                get = function()
                    return (dodo.DB and dodo.DB.resourceBarHeight) or 10
                end,
                set = function(_, newValue)
                    if dodo.DB then dodo.DB.resourceBarHeight = newValue end
                    dodoUpdateResourceBarOption()
                end,
            },
            {
                kind = LibEditMode.SettingType.Slider,
                name = "글씨 크기",
                desc = "자원바/버프바의 수치 글씨 크기를 조절합니다.",
                default = 12,
                minValue = 8,
                maxValue = 18,
                valueStep = 1,
                get = function()
                    return (dodo.DB and dodo.DB.resourceBarFontSize) or 12
                end,
                set = function(_, newValue)
                    if dodo.DB then dodo.DB.resourceBarFontSize = newValue end
                    dodoUpdateResourceBarOption()
                end,
            },
        })

        LibEditMode:RegisterCallback("enter", function()
            local moduleEnabled = (dodo.DB and dodo.DB.enableResourceBarModule ~= false)
            if not moduleEnabled then return end

            local isEnabled1 = (dodo.DB and dodo.DB.useResourceBar1 ~= false)
            local isEnabled2 = (dodo.DB and dodo.DB.useResourceBar2 ~= false)
            if isEnabled1 or isEnabled2 then
                bar1Frame:Show()
                bar2Frame:Show()
                bar1Frame:SetMinMaxValues(0, 100)
                bar1Frame:SetValue(80)
                if bar1Frame.countPower then bar1Frame.countPower:SetText("80") end
                
                bar2Frame:SetMinMaxValues(0, 100)
                bar2Frame:SetValue(60)
                if bar2Frame.countStack then bar2Frame.countStack:SetText("3") end
            end
        end)

        LibEditMode:RegisterCallback("exit", function()
            UpdateResourceBarVisibility()
        end)
    end
end

-- ==============================
-- 설정
-- ==============================
function module:CreateOptions()
    -- 별도 설정 없음 (편집 모드에 통합)
end

local traitEventFrame = CreateFrame("Frame")
traitEventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
traitEventFrame:SetScript("OnEvent", UpdateCurrentSpecConfig)

local specEventFrame = CreateFrame("Frame")
specEventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
specEventFrame:SetScript("OnEvent", UpdateCurrentSpecConfig)