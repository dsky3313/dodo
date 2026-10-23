-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

local C_EquipmentSet                   = C_EquipmentSet
local CreateFrame                      = CreateFrame
local EquipmentManager_GetLocationData = EquipmentManager_GetLocationData
local hooksecurefunc                   = hooksecurefunc
local ipairs                           = ipairs
local pairs                            = pairs

-- ==============================
-- 상태
-- ==============================
-- slot_to_set[bagID][slotID] = { name, iconTexture }
local slot_to_set = {}

-- ==============================
-- 캐시 재빌드
-- ==============================
local function rebuild_cache()
    for k in pairs(slot_to_set) do slot_to_set[k] = nil end

    for _, setID in ipairs(C_EquipmentSet.GetEquipmentSetIDs()) do
        local name, iconTexture = C_EquipmentSet.GetEquipmentSetInfo(setID)
        for _, locID in pairs(C_EquipmentSet.GetItemLocations(setID) or {}) do
            if locID ~= -1 and locID ~= 0 and locID ~= 1 then
                local d = EquipmentManager_GetLocationData(locID)
                if d and d.isBags and d.bag ~= nil and d.slot ~= nil then
                    if not slot_to_set[d.bag] then slot_to_set[d.bag] = {} end
                    if not slot_to_set[d.bag][d.slot] then
                        slot_to_set[d.bag][d.slot] = { name = name, iconTexture = iconTexture }
                    end
                end
            end
        end
    end
end

-- ==============================
-- 버튼 오버레이
-- ==============================
local function get_widgets(button)
    if button.__dodo_set_icon then
        return button.__dodo_set_icon, button.__dodo_set_text
    end
    local tex = button:CreateTexture(nil, "OVERLAY", nil, 7)
    tex:SetSize(12, 12)
    tex:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -2, 0)
    tex:SetAtlas("RaidFrame-Icon-MainTank", false)
    button.__dodo_set_icon = tex

    local fs = button:CreateFontString(nil, "OVERLAY")
    local font, size = GameFontNormalTiny:GetFont()
    fs:SetFont(font, size - 1)
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetPoint("LEFT", tex, "RIGHT", 0, 0)
    fs:SetTextColor(1, 1, 1, 0.9)
    button.__dodo_set_text = fs

    return tex, fs
end

local function update_button(button)
    if not dodoDB or dodoDB.enableBagSetIcon == false then
        if button.__dodo_set_icon then button.__dodo_set_icon:Hide() end
        if button.__dodo_set_text then button.__dodo_set_text:Hide() end
        return
    end

    local bagID  = button:GetBagID()
    local slotID = button:GetID()
    if bagID == nil or not slotID or slotID == 0 then
        if button.__dodo_set_icon then button.__dodo_set_icon:Hide() end
        if button.__dodo_set_text then button.__dodo_set_text:Hide() end
        return
    end

    local setInfo = slot_to_set[bagID] and slot_to_set[bagID][slotID]
    if setInfo then
        local tex, fs = get_widgets(button)
        tex:Show()
        fs:SetText(setInfo.name)
        fs:Show()
    else
        if button.__dodo_set_icon then button.__dodo_set_icon:Hide() end
        if button.__dodo_set_text then button.__dodo_set_text:Hide() end
    end
end

-- ContainerFrameMixin:UpdateItems 훅 콜백 — frame 인수 직접 수신
local function update_frame(frame)
    if not frame or not frame.Items then return end
    for _, btn in ipairs(frame.Items) do
        update_button(btn)
    end
end

local function update_all_visible()
    for i = 1, 13 do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame:IsShown() then update_frame(frame) end
    end
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
        update_frame(ContainerFrameCombinedBags)
    end
end

-- ==============================
-- 이벤트
-- ==============================
local f = CreateFrame("Frame")

f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "dodoQOL" then
        dodoDB = dodoDB or {}
        if dodoDB.enableBagSetIcon == nil then dodoDB.enableBagSetIcon = true end
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        local function hook_frame(frame)
            if frame and frame.UpdateItems then
                hooksecurefunc(frame, "UpdateItems", update_frame)
            end
        end
        for i = 1, 13 do hook_frame(_G["ContainerFrame" .. i]) end
        hook_frame(ContainerFrameCombinedBags)
        rebuild_cache()
        self:UnregisterEvent("PLAYER_LOGIN")

    elseif event == "EQUIPMENT_SETS_CHANGED" then
        rebuild_cache()
        update_all_visible()

    elseif event == "BAG_UPDATE_DELAYED" then
        rebuild_cache()
        update_all_visible()
    end
end)

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("EQUIPMENT_SETS_CHANGED")
f:RegisterEvent("BAG_UPDATE_DELAYED")

-- ==============================
-- 설정 등록
-- ==============================
dodo.RegisterOption("가방", function(cat)
    dodo.UI:SettingsCheckbox(cat, "enableBagSetIcon",
        "장비세트 아이콘 표시",
        "장비 프리셋에 등록된 아이템 위에 세트 아이콘을 표시합니다.",
        true,
        function() update_all_visible() end)
end, 50)
