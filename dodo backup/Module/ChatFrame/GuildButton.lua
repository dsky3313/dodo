-- ==============================
-- Inspired
-- ==============================
-- Guild Button (https://wago.io/Cx_wsXks4)

-- ==============================
-- 설정 및 테이블
-- ==============================
local addonName, dodo = ...
dodoDB = dodoDB or {}
dodo.DB = dodo.DB or dodoDB

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local GetClassColor = GetClassColor
local GetGuildInfo = GetGuildInfo
local GetGuildRosterInfo = GetGuildRosterInfo
local GetGuildRosterMOTD = GetGuildRosterMOTD
local GetNumGuildMembers = GetNumGuildMembers
local GuildRoster = C_GuildInfo and C_GuildInfo.GuildRoster or function() end
local IsInGuild = IsInGuild
local ToggleGuildFrame = ToggleGuildFrame
local UIParent = UIParent
local ipairs = ipairs
local pcall = pcall
local table_insert = table.insert
local table_sort = table.sort
local type = type
local _G = _G

-- ==============================
-- 기능 구현
-- ==============================
local guild_button = nil
local function escape_member_note(note)
    return note == nil and "" or "(" .. note .. ")"
end

local function sort_by_name(a, b)
    local name_a = GetGuildRosterInfo(a) or ""
    local name_b = GetGuildRosterInfo(b) or ""
    return name_a < name_b
end

local function hide_tooltip()
    GameTooltip:Hide()
end

local function show_tooltip()
    if not guild_button then return end
    local guild_name = GetGuildInfo('player')
    if not guild_name then return end
    local total, online = GetNumGuildMembers()
    local text_r, text_g, text_b, text_a = 1, 1, 1, 1
    GameTooltip:SetOwner(guild_button, "ANCHOR_RIGHT")

    -- 타이틀 및 온라인 수 표시
    GameTooltip:AddDoubleLine(guild_name, online .. '/' .. total, text_r, text_g, text_b, text_r, text_g, text_b)
    GameTooltip:AddLine(' ')

    -- 길드 오늘의 메시지(MOTD) 출력
    local guild_message = GetGuildRosterMOTD()
    if guild_message ~= '' then
        GameTooltip:AddLine(guild_message, text_r, text_g, text_b, text_a)
        GameTooltip:AddLine(' ')
    end

    -- 접속 중인 멤버 목록 필터링 및 정렬
    local temp_members = {}
    for i = 1, total do
        local member_name, _, _, _, _, _, _, _, is_connected = GetGuildRosterInfo(i)
        if member_name and is_connected then
            table_insert(temp_members, i)
        end
    end

    table_sort(temp_members, sort_by_name)

    local shown_count = 0
    for _, i in ipairs(temp_members) do
        shown_count = shown_count + 1
        if shown_count > 50 then
            GameTooltip:AddLine('...', online - 50, text_r, text_g, text_b, text_a)
            break
        end

        local member_name, _, _, _, _, member_zone, member_note, _, _, _, member_class = GetGuildRosterInfo(i)
        local cr, cg, cb = GetClassColor(member_class)
        GameTooltip:AddDoubleLine(member_name .. " " .. escape_member_note(member_note), member_zone, cr, cg, cb, text_r, text_g, text_b)
    end
    GameTooltip:Show()
end

local function set_guild_button_text()
    if not guild_button then return end
    local _, num_online = GetNumGuildMembers()
    if guild_button.text then
        guild_button.text:SetText(num_online or 0)
    end
end

local function on_guild_button_enter(self)
    show_tooltip()
end

local function on_guild_button_leave(self)
    hide_tooltip()
    if self.texture then
        self.texture:SetAtlas("quickjoin-button-friendslist-up")
        self.texture:SetVertexColor(0, 1, 0)
    end
end

local function on_guild_button_down(self, button)
    if button == "LeftButton" and self.texture then
        self.texture:SetAtlas("quickjoin-button-friendslist-down")
        self.texture:SetVertexColor(0, 1, 0)
    end
end

local function on_guild_button_up(self, button)
    if self.texture then
        self.texture:SetAtlas("quickjoin-button-friendslist-up")
        self.texture:SetVertexColor(0, 1, 0)
    end
    if button == "LeftButton" and IsInGuild() then
        ToggleGuildFrame()
    end
end

local function on_guild_button_event(self, event, ...)
    if event == "GUILD_ROSTER_UPDATE" then
        set_guild_button_text()
    end
end

local function get_or_create_guild_button()
    if not guild_button then
        -- UIParent 아래에 순정 규격(32x32)으로 생성
        local btn = CreateFrame("Button", "SmartMicroMenuGuildButton", UIParent)
        btn:SetFrameStrata("HIGH")
        btn:SetSize(32, 32)
        btn:EnableMouse(true)

        local QuickJoinToastButton = _G.QuickJoinToastButton
        if QuickJoinToastButton then
            btn:SetFrameLevel(QuickJoinToastButton:GetFrameLevel() + 10)
        end

        -- 순정 아틀라스 텍스처 적용 및 녹색 피팅 (기본 Up 상태)
        local tex = btn:CreateTexture(nil, "BACKGROUND")
        tex:SetAtlas("quickjoin-button-friendslist-up")
        tex:SetAllPoints(btn)
        tex:SetVertexColor(0, 1, 0)
        btn.texture = tex

        -- 블리자드 순정 마우스오버 하이라이트 이펙트 적용 (UI-Common-MouseHilight, ADD)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        hl:SetBlendMode("ADD")
        hl:SetAllPoints(btn)
        btn:SetHighlightTexture(hl)

        -- 정적 참조 핸들러 바인딩 (2dodo 가비지 프리 만족)
        btn:SetScript("OnMouseDown", on_guild_button_down)
        btn:SetScript("OnMouseUp", on_guild_button_up)
        btn:SetScript("OnEnter", on_guild_button_enter)
        btn:SetScript("OnLeave", on_guild_button_leave)
        btn:SetScript("OnEvent", on_guild_button_event)

        -- 온라인 인원수 텍스트 표시 (순정 GameFontHighlightSmall 상속 및 위치 x=0, y=4 정밀 정렬)
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("BOTTOM", btn, "BOTTOM", 0, 4)
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 0.8)
        btn.text = fs

        -- 비활성화 시 Chattynator에 의한 강제 노출 방지용 가드 재정의
        local orig_SetShown = btn.SetShown
        btn.SetShown = function(self, show)
            if self.isDisabledByDodo then
                orig_SetShown(self, false)
            else
                orig_SetShown(self, show)
            end
        end

        local orig_Show = btn.Show
        btn.Show = function(self)
            if not self.isDisabledByDodo then
                orig_Show(self)
            end
        end

        guild_button = btn

        -- ====================================================================
        -- Chattynator ButtonsBar 자동 연동 (물리 겹침 차단 및 오토 레이아웃 위임)
        -- ====================================================================
        if QuickJoinToastButton then
            local parent = QuickJoinToastButton:GetParent()
            if parent and type(parent.buttons) == "table" and type(parent.Update) == "function" then
                btn:SetParent(parent)
                local exists = false
                for _, b in ipairs(parent.buttons) do
                    if b == btn then
                        exists = true
                        break
                    end
                end
                if not exists then
                    table_insert(parent.buttons, btn)
                end
                -- 즉시 레이아웃 동기화
                pcall(function() parent:Update() end)
            else
                -- 순정 환경일 경우 기본 앵커 적용
                btn:SetPoint("TOP", QuickJoinToastButton, "BOTTOM", 0, -2)
            end
        end
    end
    return guild_button
end

local function update_state()
    if dodo.DB.useGuildButton == nil then dodo.DB.useGuildButton = true end
    
    local is_enabled = (dodo.DB and dodo.DB.enableChatModule ~= false and dodo.DB.useGuildButton ~= false)
    if is_enabled then
        get_or_create_guild_button()
        if guild_button then
            guild_button.isDisabledByDodo = false
            guild_button:Show()
            guild_button:RegisterEvent("GUILD_ROSTER_UPDATE")
            GuildRoster() -- 즉시 로스터 갱신 요청
            set_guild_button_text()

            -- Chattynator 레이아웃 강제 동적 업데이트
            local parent = guild_button:GetParent()
            if parent and type(parent.Update) == "function" then
                pcall(function() parent:Update() end)
            end
        end
    else
        if guild_button then
            guild_button.isDisabledByDodo = true
            guild_button:Hide()
            guild_button:UnregisterEvent("GUILD_ROSTER_UPDATE")

            -- Chattynator 레이아웃 강제 동적 업데이트 (숨긴 영역을 제거하고 정렬 복원)
            local parent = guild_button:GetParent()
            if parent and type(parent.Update) == "function" then
                pcall(function() parent:Update() end)
            end
        end
    end
end

dodo.UpdateChatGuildButtonState = update_state

local init_frame = CreateFrame("Frame")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", function(self, event)
    update_state()
    self:UnregisterAllEvents()
end)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.ChatFrame, {
        {
            name = "길드원 버튼 표시",
            get = function() return dodo.DB and dodo.DB.useGuildButton ~= false end,
            set = function(checked)
                if dodo.DB then dodo.DB.useGuildButton = checked end
                update_state()
            end,
            disabled = function() return dodo.DB and dodo.DB.enableChatModule == false end,
        }
    })
end
