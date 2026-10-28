-- ==============================
-- 파티원 주요 기술: 주문 목록 (직업/특성 선택 + 켜기/끄기)
-- ==============================
-- 커서 주문추적 목록(dodoCombat 99 Options Preview.lua dodoCSTSpellListMixin)과 같은 구성.
-- 저장: dodoDB.partyTracker.partyCDs.off = { ["specID:spellID"] = true } (10 PartyCDs.lua ns.PTCSetShown)
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local _, ns = ...
local dodo = _G.dodo

local C_Spell     = C_Spell
local CreateFrame = CreateFrame

local ROW_H    = 26
local HEADER_H = 28 -- 컬럼 헤더 높이 (WhoFrameColumnHeaderTemplate)
local TOP_H    = 36 -- 드롭다운 영역

local COMMON = "race" -- "공용" 선택값 = 엔진 종족특성 목록 키 (10 PartyCDs.lua ns.PTCSpecSpells)

local _class_id, _spec_id = nil, nil -- 편집 중 직업/특성 (세션 한정, 저장 안 함)

local function num_specs(classID)
    if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID then
        return C_SpecializationInfo.GetNumSpecializationsForClassID(classID) or 0
    end
    return 0
end

-- 편집 대상 기본값: 현재 내 직업/특성
local function init_selection()
    if _class_id then return end
    local _, _, classID = UnitClass("player")
    _class_id = classID
    local specIndex = GetSpecialization()
    _spec_id = (specIndex and GetSpecializationInfo(specIndex)) or (GetSpecializationInfoForClassID(classID, 1))
end

-- 특성별 최대 주문 수 → 목록 높이 (스크롤 없음)
local function max_rows()
    local n = 1
    local specs = ns.PTCData and ns.PTCData.specs
    if specs then
        for _, list in pairs(specs) do
            if #list > n then n = #list end
        end
    end
    return n
end

-- 카테고리 표시명 (06 SpellData.lua CAT_ORDER)
local CAT_LABEL = {
    CD = "공격", DEF = "생존기", EXT = "외생기", RAID = "공생기",
    UTIL = "유틸", RES = "부활·블러드", RACE = "종족", ITEM = "장신구",
}

-- 현재 특성 목록(SPECS)에서 주문 카테고리 조회. 공용 = 종특
local function category_of(id)
    if _spec_id == COMMON then return "RACE" end
    local list = ns.PTCData and ns.PTCData.specs[_spec_id]
    for _, e in ipairs(list or {}) do
        if e[1] == id then return e.category end
    end
end

local function on_check_click(self)
    local data = self:GetParent().data
    if data and _spec_id and ns.PTCSetShown then ns.PTCSetShown(_spec_id, data.id, self:GetChecked()) end
end

local function init_row(row, data)
    if not row.check then
        row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.check:SetSize(24, 24)
        row.check:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.check:SetScript("OnClick", on_check_click)

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.name:SetWidth(150)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)

        row.spellid = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.spellid:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
        row.spellid:SetWidth(70)
        row.spellid:SetJustifyH("LEFT")

        row.cd = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.cd:SetPoint("LEFT", row.spellid, "RIGHT", 6, 0)
        row.cd:SetWidth(112)
        row.cd:SetJustifyH("LEFT")

        row.cat = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.cat:SetPoint("LEFT", row.cd, "RIGHT", 6, 0)
        row.cat:SetJustifyH("LEFT")
    end
    row.data = data
    row.check:SetChecked(not data.off)
    row.icon:SetTexture(C_Spell.GetSpellTexture(data.id) or 134400)
    row.name:SetText(C_Spell.GetSpellName(data.id) or "?")
    row.spellid:SetText(data.id)
    row.cd:SetText(data.cd and (data.cd .. "초") or "-")
    row.cat:SetText(CAT_LABEL[category_of(data.id)] or "-")
end

dodoPTSpellListMixin = {}

dodoPTSpellListMixin.GetExtent = function()
    return TOP_H + HEADER_H + max_rows() * ROW_H + 16
end

function dodoPTSpellListMixin:OnLoad()
    init_selection()

    -- 직업 → 특성 하위 드롭다운 (커서 주문추적 목록과 동일)
    local function is_spec_selected(id) return _spec_id == id end
    local function select_spec(id)
        _spec_id = id
        self:Update()
    end

    self.specDD = CreateFrame("DropdownButton", nil, self, "WowStyle2DropdownTemplate")
    self.specDD:SetSize(140, 25)
    self.specDD:SetPoint("TOPLEFT", self, "TOPLEFT", 37, -4)
    self.specDD:SetupMenu(function(_, root)
        for i = 1, GetNumClasses() do
            local className, classFile, classID = GetClassInfo(i)
            if classID then
                local color = C_ClassColor.GetClassColor(classFile)
                local sub = root:CreateButton(color and color:WrapTextInColorCode(className) or className)
                for j = 1, num_specs(classID) do
                    local specID, specName = GetSpecializationInfoForClassID(classID, j)
                    if specID then
                        sub:CreateRadio(specName, is_spec_selected, select_spec, specID)
                    end
                end
            end
        end
        -- 최하단: 공용 (종족특성)
        root:CreateDivider()
        root:CreateRadio("공용", is_spec_selected, select_spec, COMMON)
    end)
    -- 버튼 표시: "직업 - 특성" (직업 색상)
    self.specDD:SetSelectionText(function()
        if not _spec_id then return "직업/특성 선택" end
        if _spec_id == COMMON then return "공용" end
        local _, specName, _, _, _, classFile, className = GetSpecializationInfoByID(_spec_id)
        local color = classFile and C_ClassColor.GetClassColor(classFile)
        local text = (className or "?") .. " - " .. (specName or "?")
        return color and color:WrapTextInColorCode(text) or text
    end)
    self.specDD:GenerateMenu()

    -- 목록 박스 + 컬럼 헤더 (dodo.UI:CreateListBox)
    self.listBG, self.content = dodo.UI:CreateListBox(self, TOP_H, {
        { "주문명", 220 }, { "spellID", 78 }, { "재사용 대기시간", 120 }, { "카테고리", 90 },
    })

    self.rows = {}
end

function dodoPTSpellListMixin:Update()
    if not self.content then return end
    local rows = (_spec_id and ns.PTCSpecSpells) and ns.PTCSpecSpells(_spec_id) or {}
    for i, data in ipairs(rows) do
        local row = self.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, self.content)
            row:SetHeight(ROW_H)
            row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -(i - 1) * ROW_H)
            row:SetPoint("RIGHT", self.content, "RIGHT")
            self.rows[i] = row
        end
        init_row(row, data)
        row:Show()
    end
    for i = #rows + 1, #self.rows do
        self.rows[i]:Hide()
    end
end

-- 설정창 initializer (99 Options.lua dodo.PTBuildPartyCDOptions에서 사용)
function dodo.PTCreateSpellListInitializer(category)
    return dodo.UI:SettingsPanelList(category, dodoPTSpellListMixin)
end

-- ==============================
-- 파티 주문 추적: 주문 목록 (드롭다운: 차단기 / 군중제어 / 공생기, 켜기/끄기)
-- ==============================
-- 저장: 차단기 dodoDB.partyTracker.interrupts.off (12 Interrupts ns.IKSetShown)
--       군중제어 dodoDB.partyTracker.partyCC.spells1 (13 CC ns.CCSetShown)
--       공생기 dodoDB.partyTracker.partyDefensives.off (11 Defensives ns.PDFSetShown)
local TRACK_TABS = { "차단기", "군중제어", "공생기" }
local TRACK_NAME_W = 160 -- 주문명 폭 (파티원 주요 기술 목록 150 + 10)

local _track_tab = 1 -- 선택 종류 (세션 한정)

local function track_rows(tab)
    if tab == 1 then return ns.IKSpells and ns.IKSpells() or {} end
    if tab == 2 then return ns.CCSpells and ns.CCSpells() or {} end
    local out = {}
    local spells = ns.PTCData and ns.PTCData.spells
    for _, e in ipairs(ns.PDFSpells and ns.PDFSpells() or {}) do
        local sp = spells and spells[e.id]
        out[#out + 1] = { id = e.id, class = e.class, cd = sp and sp.cooldown, off = e.off }
    end
    return out
end

local function track_max_rows()
    local n = 1
    for tab = 1, #TRACK_TABS do
        local c = #track_rows(tab)
        if c > n then n = c end
    end
    return n
end

local function on_track_check_click(self)
    local data = self:GetParent().data
    if not data then return end
    local on = self:GetChecked()
    if _track_tab == 1 then
        if ns.IKSetShown then ns.IKSetShown(data.id, on) end
    elseif _track_tab == 2 then
        if ns.CCSetShown then ns.CCSetShown(data.id, on) end
    elseif ns.PDFSetShown then
        ns.PDFSetShown(data.id, on)
    end
end

-- 열 구성: 체크 / 아이콘 / 주문명 / spellID / 직업 (재사용 대기시간은 주문명 뒤 회색)
local function init_track_row(row, data)
    if not row.check then
        row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.check:SetSize(24, 24)
        row.check:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.check:SetScript("OnClick", on_track_check_click)

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.name:SetWidth(TRACK_NAME_W)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)

        row.spellid = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.spellid:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
        row.spellid:SetWidth(70)
        row.spellid:SetJustifyH("LEFT")

        row.class = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.class:SetPoint("LEFT", row.spellid, "RIGHT", 6, 0)
        row.class:SetJustifyH("LEFT")
    end
    row.data = data
    row.check:SetChecked(not data.off)
    row.icon:SetTexture(C_Spell.GetSpellTexture(data.id) or 134400)
    local name = C_Spell.GetSpellName(data.id) or "?"
    row.name:SetText(data.cd and (name .. " |cff888888" .. data.cd .. "초|r") or name)
    row.spellid:SetText(data.id)
    local className = data.class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[data.class] or data.class or "-"
    local color = data.class and C_ClassColor.GetClassColor(data.class)
    row.class:SetText(color and color:WrapTextInColorCode(className) or className)
end

dodoPTTrackListMixin = {}

dodoPTTrackListMixin.GetExtent = function()
    return TOP_H + HEADER_H + track_max_rows() * ROW_H + 16
end

function dodoPTTrackListMixin:OnLoad()
    -- 종류 드롭다운 (파티원 주요 기술 목록의 직업/특성 드롭다운과 같은 템플릿/위치)
    local function is_kind_selected(i) return _track_tab == i end
    local function select_kind(i)
        _track_tab = i
        self:Update()
    end
    self.kindDD = CreateFrame("DropdownButton", nil, self, "WowStyle2DropdownTemplate")
    self.kindDD:SetSize(140, 25)
    self.kindDD:SetPoint("TOPLEFT", self, "TOPLEFT", 37, -4)
    self.kindDD:SetupMenu(function(_, root)
        for i, label in ipairs(TRACK_TABS) do
            root:CreateRadio(label, is_kind_selected, select_kind, i)
        end
    end)

    -- 목록 박스 + 컬럼 헤더 (dodo.UI:CreateListBox)
    self.listBG, self.content = dodo.UI:CreateListBox(self, TOP_H, {
        { "주문명", 220 + 10 }, { "spellID", 78 }, { "직업", 120 }, -- 주문명 폭 +10
    })

    self.rows = {}
end

function dodoPTTrackListMixin:Update()
    if not self.content then return end
    local rows = track_rows(_track_tab)
    for i, data in ipairs(rows) do
        local row = self.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, self.content)
            row:SetHeight(ROW_H)
            row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -(i - 1) * ROW_H)
            row:SetPoint("RIGHT", self.content, "RIGHT")
            self.rows[i] = row
        end
        init_track_row(row, data)
        row:Show()
    end
    for i = #rows + 1, #self.rows do
        self.rows[i]:Hide()
    end
end

-- 설정창 initializer (99 Options.lua dodo.PTBuildOptions에서 사용)
function dodo.PTCreateTrackListInitializer(category)
    return dodo.UI:SettingsPanelList(category, dodoPTTrackListMixin)
end
