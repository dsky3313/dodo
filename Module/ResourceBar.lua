---@diagnostic disable: lowercase-global, undefined-field
---@diagnostic disable: redundant-parameter, param-type-mismatch
local addonName, dodo = ...
dodoDB = dodoDB or {}

local barConfigs = {
    { name = "ResourceBar1", width = 270, height = 10, y = -220, level = 3000, template = "ResourceBar1Template" },
    { name = "ResourceBar2", width = 270, height = 7, y = -4, level = 3001, template = "ResourceBar2Template" }
}

-- 요청하신 대로 소문자로 수정
local classConfig = {
    ["DEATHKNIGHT"] = { [1] = {{barMode = "rune"}}, [2] = {{barMode = "rune"}}, [3] = {{barMode = "rune"}} },
    ["DEMONHUNTER"] = { [2] = {{spellName = "영혼 파편", barMode = "stack", maxStack = 6}} },
    ["DRUID"] = { [3] = {{spellName = "무쇠가죽", barMode = "duration", duration = 7}} },
    ["MONK"] = { [1] = {{barMode = "stagger"}} },
    ["SHAMAN"] = { [3] = {{spellName = "응축되는 물", barMode = "stack", maxStack = 2}} },
    ["WARRIOR"] = { 
        [1] = {{spellName = "투신", barMode = "duration", duration = 20}}, 
        [2] = {{spellName = "소용돌이 연마", barMode = "stack", maxStack = 4}, {spellName = "격노", barMode = "duration", duration = 4}}, 
        [3] = {{spellName = "고통 감내", barMode = "stack", maxStack = 100}} 
    },
}

local specColors = {
    ["DEATHKNIGHT"] = { [1] = {r=1, g=0, b=0}, [2] = {r=0, g=0.8, b=1}, [3] = {r=0.3, g=0.9, b=0.3} },
    ["DEMONHUNTER"] = { [2] = {r=0.86, g=0.59, b=0.98} },
    ["DRUID"] = { [3] = {r=1, g=0.49, b=0.04} },
    ["MONK"] = { [1] = {r=0, g=1, b=0.59} },
    ["SHAMAN"] = { [3] = {r=0, g=0.82, b=1} },
    ["WARRIOR"] = { [1] = {r=1, g=0.588, b=0.196}, [2] = {r=0, g=0.82, b=1}, [3] = {r=1, g=0.588, b=0.196} },
}

local currentSpecBuffs = {}
local cachedPowerType = nil
local runeIndexes = { 1, 2, 3, 4, 5, 6 }
local curve = C_CurveUtil.CreateCurve()
curve:SetType(Enum.LuaCurveType.Linear); curve:AddPoint(0, 0); curve:AddPoint(1, 100)

local function UpdateCurrentSpecConfig()
    local _, englishClass = UnitClass("player")
    local spec = C_SpecializationInfo.GetSpecialization()
    
    -- 기본값으로 해당 직업/특성의 전체 테이블을 가져옴
    local baseConfig = (classConfig[englishClass] and classConfig[englishClass][spec]) or {}
    currentSpecBuffs = baseConfig

    -- ✅ 전사 분노(2) 특성일 때만 조건부로 필터링
    if englishClass == "WARRIOR" and spec == 2 then
        -- 소용돌이 연마(ID: 12950)를 배웠는지 확인
        if C_SpellBook.IsSpellKnown(12950) then
            -- 배웠다면: 첫 번째 데이터(소용돌이 연마)만 들어있는 새로운 테이블 생성
            currentSpecBuffs = { baseConfig[1] }
        else
            -- 안 배웠다면: 두 번째 데이터(격노)만 들어있는 새로운 테이블 생성
            currentSpecBuffs = { baseConfig[2] }
        end
    end

    -- 바 초기화 및 업데이트 (기존과 동일)
    local bar2 = _G["ResourceBar2"]
    if bar2 then
        bar2:SetViewerItem(nil)
        bar2:SetBuffConfig(nil)
        bar2.currentPriority = nil
        if bar2.countStack then bar2.countStack:SetText("0") end
        bar2:SetValue(0)
        
        -- 이벤트 등록/해제 처리
        if englishClass == "DEATHKNIGHT" then
            bar2:SetBuffConfig({ barMode = "rune" })
            bar2:RegisterEvent("RUNE_POWER_UPDATE")
        elseif englishClass == "MONK" and spec == 1 then
            bar2:SetBuffConfig({ barMode = "stagger" })
            bar2:UnregisterEvent("RUNE_POWER_UPDATE")
        else
            bar2:UnregisterEvent("RUNE_POWER_UPDATE")
        end
        bar2:Update()
    end
end

-- ==============================
-- ResourceBar2 Mixin 설명
-- ==============================
local ResourceBar2Mixin = {}

function ResourceBar2Mixin:SetViewerItem(viewerItem) self.viewerItem = viewerItem end
function ResourceBar2Mixin:SetBuffConfig(buffConfig) self.buffConfig = buffConfig end

function ResourceBar2Mixin:GetSpecColor()
    local _, englishClass = UnitClass("player")
    local spec = C_SpecializationInfo.GetSpecialization()
    return (specColors[englishClass] and specColors[englishClass][spec]) or { r = 1, g = 1, b = 1 }
end

function ResourceBar2Mixin:UpdateStackTicks(maxStack)
    if not self.ticks then self.ticks = {} end
    
    -- 기존 틱 숨기기
    for _, tick in ipairs(self.ticks) do tick:Hide() end

    -- 10스택 이하만 표시
    if not maxStack or maxStack <= 1 or maxStack > 10 then return end

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

        -- ✅ 1. 두께 설정: PixelUtil.SetSize를 사용하여 1물리 픽셀로 강제 고정
        -- 첫 번째 인자는 논리적 크기(1), 두 번째는 높이입니다.
        PixelUtil.SetSize(tick, 1, barHeight)

        -- ✅ 2. 위치 설정: PixelUtil.SetPoint를 사용하여 좌표 오차 보정
        -- (너비 / 스택수 * 인덱스)를 계산한 후 가장 가까운 픽셀 그리드에 배치합니다.
        local xOffset = (barWidth / maxStack) * i
        PixelUtil.SetPoint(tick, "LEFT", self, "LEFT", xOffset, 0)
        
        tick:Show()
    end
end

local function OnUpdateRuneBar(rb)
    if not rb.start then return end
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
    if not self.runebars then
        self.runebars = {}
        local spacing = 2
        local barWidth = barConfigs[2].width  -- 270
        local runeWidth = (barWidth - (spacing * 5)) / 6
        for i = 1, 6 do
            local rb = CreateFrame("StatusBar", nil, self, "ResourceBar2Template")
            rb:SetSize(runeWidth, self:GetHeight())
            rb:SetPoint("LEFT", self, "LEFT", (i - 1) * (runeWidth + spacing), 0)
            self.runebars[i] = rb
        end
    end
    if self.countStack then self.countStack:Hide() end
    self:SetStatusBarColor(0, 0, 0, 0)
    table.sort(runeIndexes, function(a, b)
        local aS, aD, aR = GetRuneCooldown(a); local bS, bD, bR = GetRuneCooldown(b)
        if aR ~= bR then return aR end
        if aS ~= bS then return (aS or 0) < (bS or 0) end
        return a < b
    end)
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
            rb.start = start; rb.duration = duration
            if not rb.ctimer or rb.ctimer:IsCancelled() then
                rb.ctimer = C_Timer.NewTicker(0.1, function() OnUpdateRuneBar(rb) end)
            end
        end
    end
end

function ResourceBar2Mixin:UpdateStaggerSystem()
    if self.runebars then for _, rb in ipairs(self.runebars) do rb:Hide() end end
    if self.countStack then self.countStack:Show() end
    local stagger = tonumber(tostring(UnitStagger("player") or 0)) or 0
    local maxHealth = tonumber(tostring(UnitHealthMax("player") or 1)) or 1
    self:SetMinMaxValues(0, maxHealth)
    self:SetValue(stagger, Enum.StatusBarInterpolation.ExponentialEaseOut)
    local pct = (stagger / maxHealth) * 100
    if pct >= 60 then self:SetStatusBarColor(1, 0, 0)
    elseif pct >= 30 then self:SetStatusBarColor(1, 0.8, 0)
    else 
        local c = self:GetSpecColor()
        self:SetStatusBarColor(c.r, c.g, c.b)
    end
    if self.countStack then
        if stagger == 0 then self.countStack:SetText("0")
        else self.countStack:SetFormattedText("%.1f만", stagger / 10000) end
    end
end

function ResourceBar2Mixin:Update()
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
            self:UpdateStackTicks(maxValue) -- ✅ 스택 모드일 때 틱 생성
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
            -- ... 지속시간 로직 (기본과 동일) ...
            if not self._hasDurationUpdate then
                self:SetScript("OnUpdate", function(f)
                    local durObj = C_UnitAuras.GetAuraDuration(unit, auraID)
                    if durObj then
                        local rem = durObj:GetRemainingDuration()
                        f:SetValue(rem, Enum.StatusBarInterpolation.ExponentialEaseOut)
                        if f.countStack then f.countStack:SetFormattedText("%d", rem) end
                    end
                end)
                self._hasDurationUpdate = true
            end
        else
            if self._hasDurationUpdate then self:SetScript("OnUpdate", nil); self._hasDurationUpdate = false end
            local countBar = auraData.applications or 0
            if self.countStack then self.countStack:SetText(countBar) end
            self:SetValue(countBar, Enum.StatusBarInterpolation.ExponentialEaseOut)
        end
        self:Show()
    end
end

-- ==============================
-- 초기화 로직
-- ==============================
local bar1Frame = CreateFrame("StatusBar", "ResourceBar1", UIParent, barConfigs[1].template)
bar1Frame:SetSize(barConfigs[1].width, barConfigs[1].height)
bar1Frame:SetPoint("CENTER", UIParent, "CENTER", 0, barConfigs[1].y)

local function UpdateBar1()
    if not bar1Frame then return end
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
            if pType == 0 then bar1Frame.countPower:SetFormattedText("%d", UnitPowerPercent("player", 0, false, curve))
            else bar1Frame.countPower:SetText(current) end
        end
    end
    if _G["ResourceBar2"] and _G["ResourceBar2"].Update then _G["ResourceBar2"]:Update() end
end

local updateTicker = nil
local function OnCombatChange(inCombat)
    if updateTicker then updateTicker:Cancel() end
    updateTicker = C_Timer.NewTicker(inCombat and 0.1 or 0.5, UpdateBar1)
end

local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function(_, event) OnCombatChange(event == "PLAYER_REGEN_DISABLED") end)
OnCombatChange(false)

local ResourceBar2UpdaterMixin = {}
function ResourceBar2UpdaterMixin:OnLoad()
    self.bar2Frame = _G["ResourceBar2"]
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:SetScript("OnEvent", function() UpdateCurrentSpecConfig() end)
    local hook = function(_, item) self:HookViewerItem(item) end
    hooksecurefunc(BuffBarCooldownViewer, 'OnAcquireItemFrame', hook)
    hooksecurefunc(BuffIconCooldownViewer, 'OnAcquireItemFrame', hook)
    UpdateCurrentSpecConfig()
end

function ResourceBar2UpdaterMixin:UpdateFromItem(item)
    if not item or not item.cooldownID then return end
    
    local cdInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(item.cooldownID)
    if not cdInfo or not cdInfo.spellID then return end
    
    local sName = C_Spell.GetSpellName(cdInfo.spellID)
    if not sName then return end

    for i, config in ipairs(currentSpecBuffs) do
        if sName == config.spellName then
            -- 1. 우선순위 체크 (에러 방지 강화)
            if self.bar2Frame.buffConfig and self.bar2Frame.currentPriority and i > self.bar2Frame.currentPriority then
                local curItem = self.bar2Frame.viewerItem
                -- ✅ rawget을 사용하여 데이터가 실제로 존재할 때만 아우라 정보를 가져옵니다.
                if curItem and rawget(curItem, "auraDataUnit") and rawget(curItem, "auraInstanceID") then
                    local curAura = C_UnitAuras.GetAuraDataByAuraInstanceID(curItem.auraDataUnit, curItem.auraInstanceID)
                    if curAura then return end -- 더 높은 우선순위 버프가 유지 중이면 무시
                end
            end
            
            -- 2. 데이터 업데이트 (보안 체크 우회)
            -- item.isActive는 보안상 직접 if문으로 검사하면 안 되므로, 데이터 존재 여부로 판단합니다.
            local hasAuraData = rawget(item, "auraDataUnit") ~= nil and rawget(item, "auraInstanceID") ~= nil
            
            if hasAuraData then
                self.bar2Frame:SetViewerItem(item)
                self.bar2Frame:SetBuffConfig(config)
                self.bar2Frame.currentPriority = i
                self.bar2Frame:Update()
            else
                -- 현재 표시 중인 버프였는데 데이터가 사라진 경우 초기화
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

local bar2Frame = CreateFrame("StatusBar", "ResourceBar2", UIParent, barConfigs[2].template)
Mixin(bar2Frame, ResourceBar2Mixin)
bar2Frame:SetSize(barConfigs[2].width, barConfigs[2].height)
bar2Frame:SetPoint("TOP", bar1Frame, "BOTTOM", 0, barConfigs[2].y)
bar2Frame:SetScript("OnEvent", function(self) if self.UpdateRuneSystem then self:UpdateRuneSystem() end end)

local updater = CreateFrame("Frame"); Mixin(updater, ResourceBar2UpdaterMixin)
local init = CreateFrame("Frame"); init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self)
    updater:OnLoad()
    if dodoDB.useResourceBar1 ~= false then bar1Frame:Show() else bar1Frame:Hide() end
    if dodoDB.useResourceBar2 ~= false then bar2Frame:Show() else bar2Frame:Hide() end
    self:UnregisterEvent("PLAYER_LOGIN")
end)

local traitEventFrame = CreateFrame("Frame")
traitEventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
traitEventFrame:SetScript("OnEvent", UpdateCurrentSpecConfig)