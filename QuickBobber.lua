------------------------------
-- 테이블
------------------------------
local addonName, ns = ...

local function isIns() -- 인스확인
    local _, instanceType, difficultyID = GetInstanceInfo()
    return (difficultyID == 8 or instanceType == "raid") -- 1 일반 / 8 쐐기
end

local BobberTable = {
    { label = "재활용 가능한 심하게 큰 낚시찌", value = 202207 },
}

------------------------------
-- 디스플레이
------------------------------
local BobberButton = CreateFrame("Button", "BobberButton", UIParent, "ActionButtonTemplate, SecureActionButtonTemplate")
BobberButton:SetSize(40, 40)
BobberButton:Hide()

local function updateBobberButton()
    local itemID = BobberTable[1].value
    local itemName, _, _, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemID)

    -- 1. 쿨타임 프레임 생성 (최초 1회)
    if not BobberButton.myCooldown then
        local cd = CreateFrame("Cooldown", "BobberButtonMyCD", BobberButton, "CooldownFrameTemplate")
        cd:SetPoint("TOPLEFT", BobberButton.icon, "TOPLEFT", 0, 0)
        cd:SetPoint("BOTTOMRIGHT", BobberButton.icon, "BOTTOMRIGHT", 0, 0)
        cd:SetFrameLevel(BobberButton:GetFrameLevel() + 20)
        BobberButton.myCooldown = cd
    end

    -- 2. 루프 대상 (쿨타임은 루프에서 제외)
    local ActionButtonObject = {
        BobberButton.icon, -- 아이콘
        BobberButton.NormalTexture,  -- 기본 테두리
        BobberButton.Name, -- 이름
        BobberButton.HighlightTexture, -- 마우스오버 하이라이트
        BobberButton.PushedTexture, -- 눌렀을 때
        -- BobberButton.Count, -- 갯수
        -- BobberButton.HotKey, -- 단축키
        -- BobberButton.CheckedTexture, -- 토글
        -- BobberButton.Flash,
        -- BobberButton.Border, -- 희귀도 테두리
        -- BobberButton.cooldown, -- 쿨다운 (작동안됨)
    }

    -- 3. UI 디자인 루프
    for _, obj in ipairs(ActionButtonObject) do
        if obj then
            obj:ClearAllPoints()

            if obj == BobberButton.icon then
                obj:SetTexture(itemTexture or 134400)
                obj:SetPoint("TOPLEFT", BobberButton, "TOPLEFT", 2, -2)
                obj:SetPoint("BOTTOMRIGHT", BobberButton, "BOTTOMRIGHT", -2, 2)

            elseif obj == BobberButton.NormalTexture or obj == BobberButton.PushedTexture then
                local atlas = (obj == BobberButton.NormalTexture) and "UI-HUD-ActionBar-IconFrame" or "UI-HUD-ActionBar-IconFrame-Down"
                obj:SetAtlas(atlas, false)
                obj:SetPoint("TOPLEFT", BobberButton, "TOPLEFT", 0, 0)
                obj:SetPoint("BOTTOMRIGHT", BobberButton, "BOTTOMRIGHT", 0, 0)
                if not obj.isFixed then
                    obj:SetSize(40, 40)
                    obj.SetSize = function(...) end
                    obj.isFixed = true
                end

            elseif obj == BobberButton.Name then
                obj:SetPoint("BOTTOM", BobberButton, "TOP", 0, 5)
                obj:SetWidth(200)
                obj:SetText(itemName or "아이템 로딩중...")
            end
        end
    end

    -- 4. 쿨타임 로직 (루프 밖에서 별도 실행)
    local cd = BobberButton.myCooldown
    local start, duration, enable = C_Container.GetItemCooldown(itemID)

    if start and start > 0 and duration > 0 then
        cd:SetAlpha(1)
        cd:SetDrawSwipe(true)
        cd:SetHideCountdownNumbers(false)
        cd:SetCooldown(start, duration)

        if BobberButton.icon then
            BobberButton.icon:SetDesaturated(true)
            BobberButton.icon:SetAlpha(0.6)
        end
    else
        cd:Clear()
        cd:SetAlpha(0)
        if BobberButton.icon then
            BobberButton.icon:SetDesaturated(false)
            BobberButton.icon:SetAlpha(1.0)
        end
    end
end

------------------------------
-- 동작
------------------------------
BobberButton:RegisterForClicks("AnyUp", "AnyDown")
BobberButton:SetAttribute("type", "item")
BobberButton:SetAttribute("item", "item:" ..BobberTable[1].value)

BobberButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(BobberTable[1].value)
    GameTooltip:Show()
end)
BobberButton:SetScript("OnLeave", GameTooltip_Hide)

function QuickBobber()
    if isIns() then
        BobberButton:Hide()
        return
    end

    local isEnabled = hodoDB.useQuickBobber ~= false -- 기본값 true
    local useQuickBobber = not (hodoDB and hodoDB.useQuickBobber == false)
    local professionsBookFrameShown = ProfessionsBookFrame and ProfessionsBookFrame:IsShown()

    if isEnabled and professionsBookFrameShown then
        if SecondaryProfession2SpellButtonLeftNameFrame then
            BobberButton:SetParent(ProfessionsBookFrame)
            BobberButton:ClearAllPoints()
            BobberButton:SetPoint("LEFT", SecondaryProfession2SpellButtonLeftNameFrame, "RIGHT", 50, 0)
            BobberButton:SetFrameLevel(ProfessionsBookFrame:GetFrameLevel() + 10)
            updateBobberButton() -- 아이콘 및 개수 최신화
            BobberButton:Show()
        end
    else
        BobberButton:Hide()
    end
end

------------------------------
-- 이벤트
------------------------------
local initBobberButton = CreateFrame("Frame")
initBobberButton:RegisterEvent("ADDON_LOADED")
initBobberButton:RegisterEvent("PLAYER_ENTERING_WORLD")
initBobberButton:RegisterEvent("BAG_UPDATE_COOLDOWN")

initBobberButton:SetScript("OnEvent", function (self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, function()
            if isIns() then
                BobberButton:Hide()
                initBobberButton:UnregisterEvent("BAG_UPDATE_COOLDOWN")
            else
                initBobberButton:RegisterEvent("BAG_UPDATE_COOLDOWN")
                QuickBobber()
            end
        end)

    elseif event == "ADDON_LOADED" and arg1 == "Blizzard_ProfessionsBook" then
        if ProfessionsBookFrame then
            
            ProfessionsBookFrame:HookScript("OnShow", QuickBobber)
            ProfessionsBookFrame:HookScript("OnHide", QuickBobber)
        end

    elseif event == "BAG_UPDATE_COOLDOWN" then
        if BobberButton and BobberButton:IsShown() then
            updateBobberButton()
        end
    end
end)

ns.QuickBobber = QuickBobber