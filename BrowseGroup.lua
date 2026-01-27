local addonName, ns = ...
local LFGHelper = CreateFrame("Frame")
local env = {} 

-- [해석 반영] 버튼 상태 업데이트 함수
local function RefreshButtons()
    local f = _G.LFGListFrame
    if not f then return end
    
    local active      = C_LFGList.GetActiveEntryInfo() ~= nil
    local leader      = UnitIsGroupLeader("player") == true
    local appShown    = f.ApplicationViewer and f.ApplicationViewer:IsShown()
    local searchShown = f.SearchPanel       and f.SearchPanel:IsShown()
    
    -- 탐색하기 버튼: 내 파티 창을 보고 있고 + 내가 파티장이 아닐 때 표시
    if env.BrowseGroupsButton then
        if appShown and (not leader) and active then
            env.BrowseGroupsButton:Show()
        else
            env.BrowseGroupsButton:Hide()
        end
    end
    
    -- 돌아가기 버튼: 검색 창을 보고 있고 + 등록된 파티가 있을 때 표시
    if env.ReturnGroupsButton then
        if searchShown and active then
            env.ReturnGroupsButton:Show()
        else
            env.ReturnGroupsButton:Hide()
        end
    end
end

-- [해석 반영] 버튼 생성 및 초기화 함수
local function Initialize()
    local f = _G.LFGListFrame
    if not f or env.initialized then return end

    -- 1. BrowseGroupsButton (파티 탐색하기)
    env.BrowseGroupsButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    env.BrowseGroupsButton:SetSize(144, 22)
    env.BrowseGroupsButton:SetText("파티 탐색하기")
    env.BrowseGroupsButton:ClearAllPoints()
    env.BrowseGroupsButton:SetPoint("TOP", f, "BOTTOM", -100, 26)
    env.BrowseGroupsButton:Hide()
    
    env.BrowseGroupsButton:SetScript("OnClick", function()
        if f.ApplicationViewer then
            local b = f.ApplicationViewer.BrowseGroupsButton
            if b and b:IsEnabled() then b:Click() end
        end
    end)

    -- 2. ReturnGroupsButton (파티로 돌아가기)
    env.ReturnGroupsButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    env.ReturnGroupsButton:SetSize(144, 22)
    env.ReturnGroupsButton:SetText("파티로 돌아가기")
    env.ReturnGroupsButton:ClearAllPoints()
    env.ReturnGroupsButton:SetPoint("TOP", f, "BOTTOM", -100, 26)
    
    local backBtn = f.SearchPanel and f.SearchPanel.BackButton
    if backBtn then
        env.ReturnGroupsButton:SetFrameStrata(backBtn:GetFrameStrata())
        env.ReturnGroupsButton:SetFrameLevel(backBtn:GetFrameLevel() + 10)
    end
    env.ReturnGroupsButton:Hide()
    
    env.ReturnGroupsButton:SetScript("OnClick", function()
        if not C_LFGList.GetActiveEntryInfo() then return end
        if f.ApplicationViewer then
            C_Timer.After(0, function() 
                LFGListFrame_SetActivePanel(f, f.ApplicationViewer) 
            end)
        end
    end)

    -- 스크립트 훅 설정
    f.ApplicationViewer:HookScript("OnShow", RefreshButtons)
    f.SearchPanel:HookScript("OnShow", RefreshButtons)
    f:HookScript("OnHide", function()
        if env.BrowseGroupsButton then env.BrowseGroupsButton:Hide() end
        if env.ReturnGroupsButton  then env.ReturnGroupsButton:Hide()  end
    end)

    env.initialized = true
    RefreshButtons()
end

-- [에러 해결] 이벤트 감시자 설정
LFGHelper:RegisterEvent("ADDON_LOADED")
LFGHelper:RegisterEvent("GROUP_ROSTER_UPDATE")
LFGHelper:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")

LFGHelper:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_GroupFinder" then
        Initialize()
    elseif event == "GROUP_ROSTER_UPDATE" or event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
        RefreshButtons()
    end
end)

-- [핵심 수정] 구버전 API(IsAddOnLoaded)를 최신 API(C_AddOns.IsAddOnLoaded)로 교체
if C_AddOns and C_AddOns.IsAddOnLoaded("Blizzard_GroupFinder") then
    Initialize()
end