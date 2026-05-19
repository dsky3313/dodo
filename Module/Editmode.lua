-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("Editmode", module)

local Settings = {
    positionX = -3,
    positionY = -6,
}

-- ==============================
-- 캐싱
-- ==============================
local ButtonFrameTemplate_HidePortrait = ButtonFrameTemplate_HidePortrait
local CreateFrame = CreateFrame
local EditModeManagerFrame = EditModeManagerFrame
local EventRegistry = EventRegistry
local frame;
local ipairs = ipairs
local math_abs = math.abs
local UIParent = UIParent

-- ==============================
-- 동적 설정 등록 API
-- ==============================
local registeredSettings = {}
function dodo.RegisterEditModeSetting(categoryName, settingItems) -- 비시각적 설정
    if not registeredSettings[categoryName] then
        registeredSettings[categoryName] = {}
    end
    for _, item in ipairs(settingItems) do
        table.insert(registeredSettings[categoryName], item)
    end
end

-- ==============================
-- 기능 1 - 편집 모드 설정 패널 구성
-- ==============================
local function CreateEditModePanel()
    if frame then return frame end

    frame = CreateFrame("Frame", "dodoEditModePanel", UIParent, "PortraitFrameTemplate")
    ButtonFrameTemplate_HidePortrait(frame)

    -- 블리자드 HUD 창과 잘 어우러지는 최적의 크기로 조정 (2열 지원을 위해 너비 확장)
    frame:SetWidth(360)
    frame:SetPoint("TOPLEFT", EditModeManagerFrame, "TOPRIGHT", Settings.positionX, Settings.positionY)
    frame:SetPoint("BOTTOMLEFT", EditModeManagerFrame, "BOTTOMRIGHT", Settings.positionX, -Settings.positionY)
    frame:Hide()

    if EditModeManagerFrame then
        frame:SetFrameStrata(EditModeManagerFrame:GetFrameStrata())
        frame:SetFrameLevel(EditModeManagerFrame:GetFrameLevel())
    end

    if frame.TitleContainer and frame.TitleContainer.TitleText then
        frame.TitleContainer.TitleText:SetText("dodo 모듈 설정")
    end

    if frame.Bg then
        frame.Bg:SetVertexColor(0.08, 0.08, 0.08, 0.8)
    end

    -- 컴포넌트 활성/비활성 처리 헬퍼 함수
    local function SetComponentEnabled(comp, enabled)
        if enabled then
            comp:SetAlpha(1.0)
            comp:Enable()
            if comp.Text then comp.Text:SetTextColor(1, 0.82, 0) end
        else
            comp:SetAlpha(0.35)
            comp:Disable()
            if comp.Text then comp.Text:SetTextColor(0.5, 0.5, 0.5) end
        end
    end

    local function SetSliderEnabled(sliderFrame, enabled)
        if enabled then
            sliderFrame:SetAlpha(1.0)
            if sliderFrame.Slider and sliderFrame.Slider.Slider then
                sliderFrame.Slider.Slider:Enable()
            end
        else
            sliderFrame:SetAlpha(0.35)
            if sliderFrame.Slider and sliderFrame.Slider.Slider then
                sliderFrame.Slider.Slider:Disable()
            end
        end
    end

    local function SetDropdownEnabled(dd, enabled)
        if enabled then
            dd:SetAlpha(1.0)
            dd:Enable()
        else
            dd:SetAlpha(0.35)
            dd:Disable()
        end
    end

    -- 체크박스 컴포넌트 빌더 함수 (순정 스타일)
    local function CreateCheckbox(parent, label, getFunc, setFunc)
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        
        cb.Text = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        cb.Text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        cb.Text:SetText(label)
        
        cb:SetChecked(getFunc())
        cb:SetScript("OnClick", function(self)
            setFunc(self:GetChecked())
        end)
        
        return cb
    end

    -- 드롭다운 컴포넌트 빌더 함수 (순정 WowStyle1DropdownTemplate 적용)
    local function CreateDropdown(parent, getFunc, setFunc, values)
        local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
        dropdown:SetSize(130, 22)
        
        local function RefreshText()
            local currentVal = getFunc()
            local foundText = "선택"
            for _, item in ipairs(values) do
                if item.value == currentVal then
                    foundText = item.text
                    break
                end
            end
            dropdown:SetText(foundText)
        end
        
        dropdown:SetupMenu(function(owner, rootDescription)
            for _, item in ipairs(values) do
                rootDescription:CreateRadio(
                    item.text,
                    function()
                        return getFunc() == item.value
                    end,
                    function()
                        setFunc(item.value)
                        RefreshText()
                    end
                )
            end
        end)
        
        RefreshText()
        return dropdown
    end

    -- 슬라이더 컴포넌트 빌더 함수 (블리자드 순정 EditModeSettingSliderTemplate 및 LibEditMode 설계 차용)
    local function CreateSlider(parent, getFunc, setFunc, minVal, maxVal, step)
        local frame = CreateFrame("Frame", nil, parent, "EditModeSettingSliderTemplate")
        frame:SetSize(150, 32)
        frame:Show()
        
        if frame.Label then
            frame.Label:Hide()
        end
        
        -- 슬라이더 위치 및 크기 보정 (2열 우측 격자에 최적화)
        if frame.Slider then
            frame.Slider:ClearAllPoints()
            frame.Slider:SetPoint("LEFT", frame, "LEFT", -15, 7)
            frame.Slider:SetSize(115, 32)
            frame.Slider:Show()
            
            -- 증감 텍스트 표시 설정
            local formatters = {}
            formatters[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
                return string.format("%.2f", value)
            end)
            
            local steps = (maxVal - minVal) / step
            frame.Slider:Init(getFunc(), minVal, maxVal, steps, formatters)
            
            -- 조작 시 콜백
            frame.Slider.Slider:SetScript("OnValueChanged", function(slider, value)
                frame.Slider:FormatValue(value)
                setFunc(value)
            end)
            
            local function UpdateValue()
                local val = getFunc()
                frame.Slider:SetValue(val)
                frame.Slider:FormatValue(val)
            end
            
            UpdateValue()
            frame.UpdateValue = UpdateValue
        end
        
        return frame
    end

    -- 블리자드 스크롤 컨테이너 스타일의 ScrollFrame 생성 (많은 모듈 수용 가능)
    local scrollFrame = CreateFrame("ScrollFrame", "$parentScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -25)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 15)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(340, 1) -- 세로 길이는 내부 콘텐츠에 따라 자동 계산
    scrollFrame:SetScrollChild(scrollChild)

    -- 순정 카테고리를 반영한 메뉴 및 체크박스 정의. 
    local defaultMenuItems = {
        { isHeader = true, text = "일반" },
        
        { isHeader = true, text = "인터페이스" },
        {
            name = "난이도 설정창",
            get = function()
                if dodo.DB and dodo.DB.enableInsDifficultyModule ~= nil then
                    return dodo.DB.enableInsDifficultyModule
                end
                return true
            end,
            set = function(checked)
                if dodo.DB then
                    dodo.DB.enableInsDifficultyModule = checked
                end
                if dodo.UpdateInsDifficultyModuleState then
                    dodo.UpdateInsDifficultyModuleState()
                end
            end
        },
        {
            name = "대화창",
            get = function()
                if dodo.DB and dodo.DB.enableChatModule ~= nil then
                    return dodo.DB.enableChatModule
                end
                return true
            end,
            set = function(checked)
                if dodo.DB then
                    dodo.DB.enableChatModule = checked
                end
                if dodo.UpdateChatModuleState then
                    dodo.UpdateChatModuleState()
                end
            end
        },
        {
            name = "미니맵",
            get = function()
                if dodo.DB and dodo.DB.enableMinimapModule ~= nil then
                    return dodo.DB.enableMinimapModule
                end
                return true
            end,
            set = function(checked)
                if dodo.DB then
                    dodo.DB.enableMinimapModule = checked
                end
                if dodo.UpdateMinimapModuleState then
                    dodo.UpdateMinimapModuleState()
                end
            end
        },
        {
            name = "유닛프레임",
            get = function()
                if dodo.DB and dodo.DB.enableUnitframeModule ~= nil then
                    return dodo.DB.enableUnitframeModule
                end
                return true
            end,
            set = function(checked)
                if dodo.DB then
                    dodo.DB.enableUnitframeModule = checked
                end
                if dodo.UpdateUnitframeModuleState then
                    dodo.UpdateUnitframeModuleState()
                end
            end
        },
        {
            name = "툴팁",
            get = function()
                if dodo.DB and dodo.DB.enableTooltipModule ~= nil then
                    return dodo.DB.enableTooltipModule
                end
                return true
            end,
            set = function(checked)
                if dodo.DB then
                    dodo.DB.enableTooltipModule = checked
                end
                if dodo.UpdateTooltipModuleState then
                    dodo.UpdateTooltipModuleState()
                end
            end
        },
        {
            name = "플레이어 디버프",
            get = function()
                if dodo.DB and dodo.DB.enableDebuffModule ~= nil then
                    return dodo.DB.enableDebuffModule
                end
                return true
            end,
            set = function(checked)
                if dodo.DB then
                    dodo.DB.enableDebuffModule = checked
                end
                if dodo.UpdateDebuffModuleState then
                    dodo.UpdateDebuffModuleState()
                end
            end
        },
        {
            name = "행동단축바",
            get = function()
                if dodo.DB and dodo.DB.enableActionBarModule ~= nil then
                    return dodo.DB.enableActionBarModule
                end
                return true
            end,
            set = function(checked)
                if dodo.DB then
                    dodo.DB.enableActionBarModule = checked
                end
                if dodo.UpdateActionBarModuleState then
                    dodo.UpdateActionBarModuleState()
                end
            end
        },
        { isHeader = true, text = "전투" },
        {
            name = "개인 자원바",
            get = function()
                if dodo.DB and dodo.DB.enableResourceBarModule ~= nil then
                    return dodo.DB.enableResourceBarModule
                end
                return true
            end,
            set = function(checked)
                if dodo.DB then
                    dodo.DB.enableResourceBarModule = checked
                end
                if dodo.UpdateResourceBarModuleState then
                    dodo.UpdateResourceBarModuleState()
                end
            end
        },
        {
            name = "블러드 & 전투부활",
            get = function()
                if dodo.DB and dodo.DB.enableBloodBrezModule ~= nil then
                    return dodo.DB.enableBloodBrezModule
                end
                return true
            end,
            set = function(checked)
                if dodo.DB then
                    dodo.DB.enableBloodBrezModule = checked
                end
                if dodo.UpdateBloodBrezModuleState then
                    dodo.UpdateBloodBrezModuleState()
                end
            end
        },
        {
            name = "피해량 측정기",
            get = function()
                if dodo.DB and dodo.DB.enableDamageMeterModule ~= nil then
                    return dodo.DB.enableDamageMeterModule
                end
                return true
            end,
            set = function(checked)
                if dodo.DB then
                    dodo.DB.enableDamageMeterModule = checked
                end
                if dodo.UpdateDamageMeterModuleState then
                    dodo.UpdateDamageMeterModuleState()
                end
            end
        },
        { isHeader = true, text = "파티" },
        { isHeader = true, text = "음성" },
        { isHeader = true, text = "설정 & 프로필" },
    }

    local menuItems = {}
    for _, item in ipairs(defaultMenuItems) do
        table.insert(menuItems, item)
        if item.isHeader then
            local category = item.text
            local extra = registeredSettings[category]
            if extra then
                for _, subItem in ipairs(extra) do
                    table.insert(menuItems, subItem)
                end
            end
        end
    end

    local updateQueue = {}

    -- 순정 레이아웃 엔진과 유사하게 2열 정렬 계산 수행
    local startY = -5
    local currentY = startY
    local hasDivider = false
    local col = 0 -- 0: 좌측, 1: 우측

    for _, item in ipairs(menuItems) do
        if item.isHeader then
            if col == 1 then -- 이전 카테고리 홀수 개 마감 시 줄바꿈 보정
                currentY = currentY - 26
                col = 0
            end

            -- 구분선 추가 (두 번째 카테고리부터)
            if hasDivider then
                local divider = scrollChild:CreateTexture(nil, "BACKGROUND")
                divider:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
                divider:SetSize(310, 8)
                divider:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, currentY + 12)
                divider:SetAlpha(0.35)
                currentY = currentY - 14
            end

            -- 카테고리 타이틀 프레임 생성 (Blizzard TitleStyle)
            local titleFrame = CreateFrame("Frame", nil, scrollChild)
            titleFrame:SetSize(310, 24)
            titleFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 2, currentY)

            local text = titleFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            text:SetPoint("LEFT", titleFrame, "LEFT", 0, 0)
            text:SetText(item.text)

            currentY = currentY - 28
            hasDivider = true
        else
            if item.isSpacer then -- spacer를 만나면 우측 열을 빈 공간으로 비워두고 줄바꿈
                if col == 1 then
                    currentY = currentY - 26
                    col = 0
                end
            elseif item.type == "dropdown" then -- 드롭다운 컴포넌트 생성 (우측 2열에만 배치)
                local dd = CreateDropdown(scrollChild, item.get, item.set, item.values)
                local posX = 165
                dd:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", posX, currentY + 2)
                
                if item.disabled then
                    table.insert(updateQueue, { comp = dd, type = "dropdown", check = item.disabled })
                end

                if col == 1 then
                    currentY = currentY - 26
                    col = 0
                end
            elseif item.type == "slider" then -- 슬라이더 컴포넌트 생성 (우측 2열에 배치)
                local slider = CreateSlider(scrollChild, item.get, item.set, item.minVal or 0, item.maxVal or 100, item.step or 1)
                local posX = 165
                slider:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", posX, currentY - 4)
                
                if item.disabled then
                    table.insert(updateQueue, { comp = slider, type = "slider", check = item.disabled })
                end

                if col == 1 then
                    currentY = currentY - 26
                    col = 0
                end
            else -- 개별 체크박스 생성 및 2열 정렬
                local cb = CreateCheckbox(scrollChild, item.name, item.get, item.set)
                local posX = (col == 0) and 8 or 165
                cb:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", posX, currentY)

                if item.disabled then
                    table.insert(updateQueue, { comp = cb, type = "checkbox", check = item.disabled })
                end

                if col == 0 then
                    col = 1
                else
                    currentY = currentY - 26
                    col = 0
                end
            end
        end
    end

    if col == 1 then -- 마지막 카테고리 홀수 개 마감 보정
        currentY = currentY - 26
    end

    scrollChild:SetHeight(math_abs(currentY) + 15) -- 자식 프레임 세로 공간 동적 결정 (스크롤 활성화용)

    local function UpdateDisabledStates()
        for _, q in ipairs(updateQueue) do
            local disabled = q.check()
            local enabled = not disabled
            if q.type == "slider" then
                SetSliderEnabled(q.comp, enabled)
            elseif q.type == "dropdown" then
                SetDropdownEnabled(q.comp, enabled)
            else
                SetComponentEnabled(q.comp, enabled)
            end
        end
    end
    frame.UpdateDisabledStates = UpdateDisabledStates
    frame:HookScript("OnShow", UpdateDisabledStates)

    return frame
end

-- ==============================
-- 모듈 생명주기
-- ==============================
function module:OnEnable()
    EventRegistry:RegisterCallback("EditMode.Enter", function()
        local panel = CreateEditModePanel()
        if panel then
            panel:ClearAllPoints()
            panel:SetPoint("TOPLEFT", EditModeManagerFrame, "TOPRIGHT", Settings.positionX, Settings.positionY)
            panel:SetPoint("BOTTOMLEFT", EditModeManagerFrame, "BOTTOMRIGHT", Settings.positionX, -Settings.positionY)
            panel:Show()
        end
    end)

    EventRegistry:RegisterCallback("EditMode.Exit", function()
        if frame then
            frame:Hide()
        end
    end)
end