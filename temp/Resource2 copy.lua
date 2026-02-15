local _, ns = ...;

-- 1. 트래킹 설정
local SPELL_ID_IP = 190456 -- 고통 감내
local SPELL_ID_MSW = 344179 -- 소용돌이 무기

local bar = CreateFrame("StatusBar", "ArcResourceBar", UIParent)
bar:SetSize(238, 12)
bar:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
bar:SetFrameStrata("HIGH")
bar:Hide()

bar.bg = bar:CreateTexture(nil, "BACKGROUND")
bar.bg:SetAllPoints()
bar.bg:SetColorTexture(0, 0, 0, 0.6)

bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
bar.text:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
bar.text:SetPoint("CENTER")

-- 2. 업데이트 함수 (ArcUI_Resources 로직 적용)
local function UpdateValue()
    local _, class = UnitClass("player")
    local spellID = (class == "WARRIOR") and SPELL_ID_IP or SPELL_ID_MSW
    
    -- [핵심] aura 단어를 쓰지 않고 GetPlayerAuraBySpellID로 직접 접근
    local data = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
    
    if data then
        -- 매크로에서 확인했던 applications(중첩) 값을 사용
        local val = data.applications or 0
        if class == "WARRIOR" and val == 0 then val = 1 end
        
        bar:SetMinMaxValues(0, (class == "SHAMAN" and 10 or 100))
        bar:SetValue(val)
        bar.text:SetText((class == "WARRIOR" and "고감: " or "소용: ")..val)
        bar:Show()
    else
        bar:Hide()
    end
end

-- 3. [중요] 전투 중 멈춤 방지를 위한 이벤트 등록
-- ArcUI_Resources.lua가 사용하는 이벤트들입니다.
bar:RegisterEvent("UNIT_AURA")
bar:RegisterEvent("UNIT_POWER_UPDATE")
bar:RegisterEvent("PLAYER_REGEN_DISABLED") -- 전투 시작
bar:RegisterEvent("PLAYER_REGEN_ENABLED")  -- 전투 종료

bar:SetScript("OnEvent", function(self, event, unit)
    if unit == "player" or event:find("PLAYER_REGEN") then
        UpdateValue()
    end
end)

-- 4. OnUpdate 보조 (Display.lua 로직)
local lastUpdate = 0
bar:SetScript("OnUpdate", function(self, elapsed)
    lastUpdate = lastUpdate + elapsed
    if lastUpdate > 0.1 then -- 0.1초마다 강제 갱신
        UpdateValue()
        lastUpdate = 0
    end
end)