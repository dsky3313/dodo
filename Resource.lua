local addonName, dodo = ...;

-- 1. 설정값 (항상 보이도록 알파값을 1로 고정)
dodo.configs = {
    font        = STANDARD_TEXT_FONT,
    fontSize    = 12,
    fontOutline = "OUTLINE",
    width       = 238,
    height      = 8,
    comboheight = 6,
    xpoint      = 0,
    ypoint      = -180,
    -- 항상 100% 농도로 보이게 설정
    combatalpha = 1,
    normalalpha = 1, 
    framelevel  = 9000,
    -- ID 설정
    shieldBlockID = 2565,
    ignorePainID  = 190456,
}

-- 2. 메인 프레임 (분노/자원 바)
local main_frame = CreateFrame("StatusBar", "ResourceBar", UIParent)
main_frame:SetSize(dodo.configs.width, dodo.configs.height)
main_frame:SetPoint("CENTER", UIParent, "CENTER", dodo.configs.xpoint, dodo.configs.ypoint)
main_frame:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
main_frame:SetFrameLevel(dodo.configs.framelevel)
main_frame:SetMovable(true)
main_frame:SetClampedToScreen(true)

local bg = main_frame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(true)
bg:SetColorTexture(0, 0, 0, 0.7)

local text = main_frame:CreateFontString(nil, "OVERLAY")
text:SetFont(dodo.configs.font, dodo.configs.fontSize, dodo.configs.fontOutline)
text:SetPoint("CENTER", main_frame, "CENTER", 0, 0)

-- 3. 고통 감내 바 (전투 중에도 즉시 갱신되도록 설정)
local ipBar = CreateFrame("StatusBar", nil, main_frame)
ipBar:SetSize(dodo.configs.width, dodo.configs.comboheight)
ipBar:SetPoint("BOTTOMLEFT", main_frame, "TOPLEFT", 0, 2)
ipBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
ipBar:SetStatusBarColor(1, 0.8, 0, 1) -- 금색
ipBar:Hide()

local ipText = ipBar:CreateFontString(nil, "OVERLAY")
ipText:SetFont(dodo.configs.font, dodo.configs.fontSize - 1, dodo.configs.fontOutline)
ipText:SetPoint("CENTER", ipBar, "CENTER", 0, 0)

-- 4. 업데이트 함수
local function UpdateIgnorePain()
    -- C_UnitAuras를 사용하여 전투 중에도 실시간 중첩 체크
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(dodo.configs.ignorePainID)
    
    if aura and aura.applications then
        local stacks = aura.applications
        if stacks > 0 then
            ipBar:Show()
            ipBar:SetMinMaxValues(0, 100)
            ipBar:SetValue(stacks)
            ipText:SetText(string.format("고감: %d", stacks))
            -- 고감 바 자체 알파도 1로 고정
            ipBar:SetAlpha(1)
        else
            ipBar:Hide()
        end
    else
        ipBar:Hide()
    end
end

local function UpdateResource()
    local powerType, powerToken = UnitPowerType("player")
    local current = UnitPower("player", powerType)
    local max = UnitPowerMax("player", powerType)
    
    if max and max > 0 then
        main_frame:SetMinMaxValues(0, max)
        main_frame:SetValue(current)
        text:SetText(current)
    end

    local color = PowerBarColor[powerToken] or PowerBarColor[powerType] or {r = 1, g = 1, b = 1}
    main_frame:SetStatusBarColor(color.r, color.g, color.b)
end

-- 5. 실시간 갱신 및 항상 표시 설정
C_Timer.NewTicker(0.1, function()
    UpdateResource()
    UpdateIgnorePain()
    
    -- [수정] 전투 여부와 상관없이 항상 normalalpha(1)를 유지하도록 강제 설정
    main_frame:SetAlpha(dodo.configs.normalalpha)
end)

-- 이동 기능 (Alt + 드래그)
main_frame:EnableMouse(true)
main_frame:RegisterForDrag("LeftButton")
main_frame:SetScript("OnDragStart", function(self) if IsAltKeyDown() then self:StartMoving() end end)
main_frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)