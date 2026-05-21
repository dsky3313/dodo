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
    table.insert(registeredSettings[categoryName], settingItems)
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
            if _G.dodoEditModePanel and _G.dodoEditModePanel.UpdateDisabledStates then
                _G.dodoEditModePanel:UpdateDisabledStates()
            end
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
                        if _G.dodoEditModePanel and _G.dodoEditModePanel.UpdateDisabledStates then
                            _G.dodoEditModePanel:UpdateDisabledStates()
                        end
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
            formatters[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
            MinimalSliderWithSteppersMixin.Label.Right, function(value)
                return string.format("%.2f", value)
            end)

            local steps = (maxVal - minVal) / step
            frame.Slider:Init(getFunc(), minVal, maxVal, steps, formatters)

            -- 조작 시 콜백
            frame.Slider.Slider:SetScript("OnValueChanged", function(slider, value)
                frame.Slider:FormatValue(value)
                setFunc(value)
                if _G.dodoEditModePanel and _G.dodoEditModePanel.UpdateDisabledStates then
                    _G.dodoEditModePanel:UpdateDisabledStates()
                end
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

    -- 와우 순정 편집모드 스타일의 ScrollFrameTemplate 적용
    local scrollFrame = CreateFrame("ScrollFrame", "$parentScrollFrame", frame, "ScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)
    
    scrollFrame.scrollBarHideIfUnscrollable = true
    scrollFrame.scrollBarX = 6
    scrollFrame.scrollBarTopY = -4

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(310, 1) -- 세로 길이는 내부 콘텐츠에 따라 자동 계산
    scrollFrame:SetScrollChild(scrollChild)

    -- 최소화/최대화 버튼 추가
    local maxMinFrame = CreateFrame("Frame", nil, frame, "MaximizeMinimizeButtonFrameTemplate")
    maxMinFrame:SetPoint("RIGHT", frame.CloseButton, "LEFT", 0, 0)

    maxMinFrame:SetOnMinimizedCallback(function()
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", EditModeManagerFrame, "TOPRIGHT", Settings.positionX, Settings.positionY)
        frame:SetWidth(200)
        frame:SetHeight(64)
        scrollFrame:Hide()
        if dodo.DB then dodo.DB.editModeMinimized = true end
    end)

    maxMinFrame:SetOnMaximizedCallback(function()
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", EditModeManagerFrame, "TOPRIGHT", Settings.positionX, Settings.positionY)
        frame:SetPoint("BOTTOMLEFT", EditModeManagerFrame, "BOTTOMRIGHT", Settings.positionX, -Settings.positionY)
        frame:SetWidth(360)
        scrollFrame:Show()
        if dodo.DB then dodo.DB.editModeMinimized = false end
    end)
    frame.maxMinFrame = maxMinFrame

    -- 순정 카테고리를 반영한 메뉴 및 체크박스 정의.
    local defaultMenuItems = {
        { isHeader = true, text = "전투" },
        { isHeader = true, text = "인터페이스" },
        { isHeader = true, text = "음성" },
        { isHeader = true, text = "편의기능" },
        { isHeader = true, text = "일반" },
        { isHeader = true, text = "설정 & 프로필" },
    }

    local menuItems = {}
    for _, headerItem in ipairs(defaultMenuItems) do
        table.insert(menuItems, headerItem)
        if headerItem.isHeader then
            local category = headerItem.text
            local groups = registeredSettings[category]
            if groups then
                -- 1단계: 카테고리 내의 모든 아이템들을 평탄화(Flatten)
                local flatItems = {}
                for g = 1, #groups do
                    local groupItems = groups[g]
                    for i = 1, #groupItems do
                        table.insert(flatItems, groupItems[i])
                    end
                end

                -- 2단계: 체크박스와 설정(드롭다운/슬라이더)을 세트(Set) 단위로 구조화
                local sets = {}
                local idx = 1
                while idx <= #flatItems do
                    local item = flatItems[idx]
                    if item.isSpacer then
                        idx = idx + 1 -- 스페이서는 정렬 레이아웃에서 무시
                    else
                        local nextItem = flatItems[idx + 1]
                        if nextItem and (nextItem.type == "dropdown" or nextItem.type == "slider") and (not item.type) then
                            -- 체크박스 + 설정(드롭다운/슬라이더) 세트
                            table.insert(sets, {
                                cb = item,
                                setting = nextItem,
                                name = item.name or "",
                                hasSetting = true
                            })
                            idx = idx + 2
                        else
                            -- 단독 아이템 (체크박스이거나 개별 설정 등)
                            table.insert(sets, {
                                cb = item,
                                name = item.name or "",
                                hasSetting = (item.type == "dropdown" or item.type == "slider")
                            })
                            idx = idx + 1
                        end
                    end
                end

                -- 3단계: 정렬 수행
                -- 설정이 없는 단독 토글을 위로(hasSetting == false), 설정이 있는 토글을 아래로(hasSetting == true) 배치
                -- 동일 그룹 내에서는 이름(name)을 기준으로 가나다(알파벳) 오름차순 정렬
                table.sort(sets, function(a, b)
                    if a.hasSetting ~= b.hasSetting then
                        return not a.hasSetting
                    end
                    return a.name < b.name
                end)

                -- 4단계: 정렬된 세트를 평탄화하고 자동 비활성화(disabled) 조건 래핑
                for _, set in ipairs(sets) do
                    table.insert(menuItems, set.cb)
                    if set.setting then
                        local cbItem = set.cb
                        local originalDisabled = set.setting.disabled
                        -- 드롭다운/슬라이더의 비활성화 조건을 좌측 체크박스의 활성 상태와 자동으로 바인딩
                        set.setting.disabled = function()
                            if originalDisabled and originalDisabled() then
                                return true
                            end
                            if cbItem then
                                if cbItem.get and not cbItem.get() then
                                    return true
                                end
                                if cbItem.disabled and cbItem.disabled() then
                                    return true
                                end
                            end
                            return false
                        end
                        table.insert(menuItems, set.setting)
                    end
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

    for i, item in ipairs(menuItems) do
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
                local slider = CreateSlider(scrollChild, item.get, item.set, item.minVal or 0, item.maxVal or 100,
                    item.step or 1)
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
                -- 지능형 세트 정렬 보정: 다음 항목이 드롭다운이나 슬라이더면 반드시 좌측(col = 0) 시작
                local nextItem = menuItems[i + 1]
                if nextItem and (nextItem.type == "dropdown" or nextItem.type == "slider") then
                    if col == 1 then
                        currentY = currentY - 26
                        col = 0
                    end
                end

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
    frame:HookScript("OnShow", function()
        if dodo.DB and dodo.DB.editModeMinimized then
            frame.maxMinFrame:Minimize(true)
        else
            frame.maxMinFrame:Maximize(true)
        end
        UpdateDisabledStates()
    end)

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
            if dodo.DB and dodo.DB.editModeMinimized then
                panel:SetWidth(200)
                panel:SetHeight(64)
            else
                panel:SetPoint("BOTTOMLEFT", EditModeManagerFrame, "BOTTOMRIGHT", Settings.positionX, -Settings
                .positionY)
                panel:SetWidth(360)
            end
            panel:Show()
        end
    end)

    EventRegistry:RegisterCallback("EditMode.Exit", function()
        if frame then
            frame:Hide()
        end
    end)
end
