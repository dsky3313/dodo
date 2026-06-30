-- ==============================
-- WorldMap Custom Icon Module (Pure Lua)
-- ==============================

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local PinConfig = {
    size       = 20,
    scaleStart = 1.0,
    scaleEnd   = 1.5,
}

local PinIcon = {
    auction  = { atlas = "Auctioneer",                        name = "경매장" },
    bank     = { atlas = "Banker",                            name = "은행" },
    crafting = { atlas = "Professions-Crafting-Orders-Icon",  name = "주문제작" },
    dummy    = { atlas = "Tormentors-Event",                  name = "허수아비" },
    inn      = { atlas = "Innkeeper",                         name = "여관" },
    portal_t = { atlas = "TaxiNode_Continent_Alliance_Timed", name = "차원문" },
    tier     = { atlas = "CreationCatalyst-32x32",            name = "티어변환" },
    upgrade  = { atlas = "UpgradeItem-32x32",                 name = "아이템 강화" },
}

local PinDefs = {
    [84] = { -- 스톰윈드
        { x=0.6208, y=0.7622, icon=PinIcon.bank },
        { x=0.7928, y=0.6380, icon=PinIcon.dummy },
        { x=0.6116, y=0.7453, icon=PinIcon.inn },
        { x=0.7474, y=0.1749, icon=PinIcon.portal_t, name="대격변 차원문" },
    },
    [2393] = { -- 실버문 (한밤)
        { x=0.5031, y=0.7489, icon=PinIcon.auction },
        { x=0.4511, y=0.5558, icon=PinIcon.crafting },
        { x=0.5537, y=0.7040, icon=PinIcon.inn },
        { x=0.3621, y=0.8469, icon=PinIcon.dummy },
        { x=0.4038, y=0.6496, icon=PinIcon.tier },
        { x=0.4834, y=0.6175, icon=PinIcon.upgrade },
    },
}

-- ==============================
-- 캐싱
-- ==============================
local C_Map         = C_Map
local C_SuperTrack  = C_SuperTrack
local C_Timer       = C_Timer
local CreateFrame   = CreateFrame
local GameTooltip   = GameTooltip
local ipairs        = ipairs
local Lerp          = Lerp
local pairs         = pairs
local Saturate      = Saturate
local UiMapPoint    = UiMapPoint
local WorldMapFrame = WorldMapFrame

-- ==============================
-- 상태 관리
-- ==============================
local init_frame  = CreateFrame("Frame")
local scale_frame = CreateFrame("Frame")  -- 단일 공유 OnUpdate 프레임
local pins = {}
local last_canvas_scale = 0
local last_zoom_pct     = 0

-- ==============================
-- 기능 1: 핀 크기 스케일 보정 (공유 OnUpdate)
-- ==============================
-- 핀별 OnUpdate 대신 단일 scale_frame에서 일괄 처리.
-- WorldMap이 닫혀 있으면 scale_frame도 Hide → 전투 중 비용 0.
-- last_canvas_scale / last_zoom_pct 비교로 실제 변경 시에만 SetSize 호출.
local function update_pin_sizes()
    local canvas = WorldMapFrame:GetCanvas()
    if not canvas then return end
    local canvasScale = canvas:GetScale()
    if canvasScale <= 0 then return end
    local zoomPercent = WorldMapFrame:GetCanvasZoomPercent()
    if canvasScale == last_canvas_scale and zoomPercent == last_zoom_pct then return end
    last_canvas_scale = canvasScale
    last_zoom_pct     = zoomPercent
    local size = (PinConfig.size / canvasScale) * Lerp(PinConfig.scaleStart, PinConfig.scaleEnd, Saturate(zoomPercent))
    for _, mapPins in pairs(pins) do
        for _, pin in ipairs(mapPins) do
            if pin:IsShown() then
                pin:SetSize(size, size)
            end
        end
    end
end

scale_frame:SetScript("OnUpdate", update_pin_sizes)
scale_frame:Hide()

-- ==============================
-- 기능 2: 핀 마우스 호버 툴팁
-- ==============================
local function pin_on_enter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip_SetTitle(GameTooltip, self.pinName)
    GameTooltip:Show()
end

local function pin_on_leave()
    GameTooltip:Hide()
end

-- ==============================
-- 기능 3: 핀 클릭 → 웨이포인트 설정
-- ==============================
local function pin_on_click(self, button)
    if button ~= "LeftButton" then return end
    local uiMapPoint = UiMapPoint.CreateFromCoordinates(self.pinMapID, self.pinX, self.pinY)
    C_Map.SetUserWaypoint(uiMapPoint)
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
end

-- ==============================
-- 기능 4: 핀 위치 및 표시 업데이트
-- ==============================
local function update_pins()
    local is_enabled = (dodoDB and dodoDB.enableWorldMapIcon ~= false)
    local map_id     = WorldMapFrame:GetMapID()
    local visible    = WorldMapFrame:IsVisible()
    local canvas     = WorldMapFrame:GetCanvas()

    for mapID, mapPins in pairs(pins) do
        for j, pin in ipairs(mapPins) do
            if is_enabled and map_id == mapID and visible then
                local cw, ch = canvas:GetSize()
                if cw > 0 and ch > 0 then
                    local def = PinDefs[mapID][j]
                    pin:ClearAllPoints()
                    pin:SetPoint("CENTER", canvas, "TOPLEFT", def.x * cw, -def.y * ch)
                    pin:Show()
                else
                    C_Timer.After(0.05, update_pins)
                end
            else
                pin:Hide()
            end
        end
    end
end

-- ==============================
-- 기능 5: UI 프레임 생성
-- ==============================
local function create_pins()
    local canvas = WorldMapFrame:GetCanvas()
    if not canvas then return end

    for mapID, defs in pairs(PinDefs) do
        pins[mapID] = pins[mapID] or {}
        for j, def in ipairs(defs) do
            if not pins[mapID][j] then
                local pin = CreateFrame("Button", "dodoWorldMapPin"..mapID.."_"..j, canvas)
                pin:SetSize(PinConfig.size, PinConfig.size)
                pin:SetFrameLevel(2200)
                pin.pinName  = def.name or def.icon.name
                pin.pinMapID = mapID
                pin.pinX     = def.x
                pin.pinY     = def.y

                pin.texture = pin:CreateTexture(nil, "ARTWORK")
                pin.texture:SetAllPoints(pin)
                pin.texture:SetAtlas(def.icon.atlas)

                pin:SetScript("OnEnter", pin_on_enter)
                pin:SetScript("OnLeave", pin_on_leave)
                pin:SetScript("OnClick", pin_on_click)

                pin:Hide()
                pins[mapID][j] = pin
            end
        end
    end
end

local function update_visual()
    local is_enabled = (dodoDB and dodoDB.enableWorldMapIcon ~= false)
    if is_enabled then
        create_pins()
        update_pins()
    else
        for _, mapPins in pairs(pins) do
            for _, pin in ipairs(mapPins) do
                pin:Hide()
            end
        end
    end
end

local function initialize()
    if dodoDB and dodoDB.enableWorldMapIcon == nil then
        dodoDB.enableWorldMapIcon = true
    end
    update_visual()
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
    elseif event == "PLAYER_LOGIN" then
        initialize()

        WorldMapFrame:HookScript("OnShow", function()
            last_canvas_scale = 0  -- 강제 갱신 트리거
            last_zoom_pct     = 0
            scale_frame:Show()
            update_pins()
        end)
        WorldMapFrame:HookScript("OnHide", function()
            scale_frame:Hide()
        end)
        hooksecurefunc(WorldMapFrame, "OnMapChanged", update_pins)

        self:UnregisterEvent("PLAYER_LOGIN")
    end
end

init_frame:RegisterEvent("ADDON_LOADED")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("지도", {
        {
            name = "월드맵 커스텀 아이콘 활성화",
            get  = function() return dodoDB and dodoDB.enableWorldMapIcon ~= false end,
            set  = function(checked)
                if dodoDB then dodoDB.enableWorldMapIcon = checked end
                update_visual()
            end,
        },
    })
end
