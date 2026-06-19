local isAdmin = false 
local isVisible = true
local ADMIN_COMMAND = "관리자" 
local SILVERMOON_MAP_ID = 2393
local HORDE_ONLY_PINS = {11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 26} 

local L = {
    TITLE = "SILVERMOON MAP", ADD = "추가", DELETE = "삭제", EXPORT = "내보내기", IMPORT = "가져오기", APPLY = "데이터 적용", CLOSE = "닫기",
    AUTHOR = "By 아즈샤라-설쁘",
    ADMIN_ON = "|cff00ff00관리자 모드가 활성화되었습니다.|r",
    ADMIN_OFF = "|cffff0000관리자 모드가 비활성화되었습니다.|r",
    SHAPE_PIN = "도형 핀",
}

-- 최신 텍스트 파일 데이터 반영
MyMapNotesDB_V6 = {
    [1] = {["y"] = 0.75461320877075, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 1, [2] = 1, [3] = 1}, ["text"] = "경매장", ["shape"] = "DOT", ["x"] = 0.48159866333008},
    [2] = {["y"] = 0.8052223443985, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 0, [2] = 1, [3] = 0}, ["text"] = "교역소", ["shape"] = "DOT", ["x"] = 0.49205741882324},
    [3] = {["y"] = 0.78887538909912, ["mapID"] = 2393, ["textSize"] = 40, ["color"] = {[1] = 0, [2] = 1, [3] = 0}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.53089863459269},
    [4] = {["y"] = 0.78788523674011, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 0, [2] = 1, [3] = 0}, ["text"] = "구렁 상인", ["shape"] = "DOT", ["x"] = 0.56454435984294},
    [5] = {["y"] = 0.70289940834045, ["mapID"] = 2393, ["textSize"] = 40, ["color"] = {[1] = 1, [2] = 0.5, [3] = 0}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.56081094741821},
    [6] = {["y"] = 0.70614724159241, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 1, [2] = 0.5, [3] = 0}, ["text"] = "여관&요리", ["shape"] = "DOT", ["x"] = 0.59816424051921},
    [7] = {["y"] = 0.79494495391846, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 0, [2] = 1, [3] = 0}, ["text"] = "미용실", ["shape"] = "DOT", ["x"] = 0.39647159576416},
    [8] = {["y"] = 0.76518691778183, ["mapID"] = 2393, ["textSize"] = 40, ["color"] = {[1] = 0, [2] = 1, [3] = 0}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.41790200074514},
    [9] = {["y"] = 0.55738916397095, ["mapID"] = 2393, ["textSize"] = 40, ["color"] = {[1] = 1, [2] = 0, [3] = 0}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.45058193206787},
    [10] = {["y"] = 0.5362377166748, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 1, [2] = 0, [3] = 0}, ["text"] = "주문제작", ["shape"] = "DOT", ["x"] = 0.45261452198029},
    [11] = {["y"] = 0.63158965110779, ["mapID"] = 2393, ["textSize"] = 40, ["color"] = {[1] = 0, [2] = 1, [3] = 0}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.74115794499715},
    [12] = {["y"] = 0.71241192817688, ["mapID"] = 2393, ["textSize"] = 40, ["color"] = {[1] = 0, [2] = 0.8, [3] = 1}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.73352718353271},
    [13] = {["y"] = 0.68459854125977, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 0, [2] = 0.8, [3] = 1}, ["text"] = "(마부,보세,재봉,약초)", ["shape"] = "DOT", ["x"] = 0.73785762786865},
    [14] = {["y"] = 0.82819213867188, ["mapID"] = 2393, ["textSize"] = 40, ["color"] = {[1] = 0, [2] = 0.8, [3] = 1}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.69637858072917},
    [15] = {["y"] = 0.85268840789795, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 0, [2] = 0.8, [3] = 1}, ["text"] = "(무두,가세,채광,대장,기공)", ["shape"] = "DOT", ["x"] = 0.70472988575427},
    [16] = {["y"] = 0.72193307876587, ["mapID"] = 2393, ["textSize"] = 40, ["color"] = {[1] = 1, [2] = 1, [3] = 1}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.67575375239054},
    [17] = {["y"] = 0.74605433940887, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 1, [2] = 1, [3] = 1}, ["text"] = "경매장", ["shape"] = "DOT", ["x"] = 0.67705065409342},
    [18] = {["y"] = 0.62120332717896, ["mapID"] = 2393, ["textSize"] = 40, ["color"] = {[1] = 1, [2] = 0.5, [3] = 0}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.6701745669047},
    [19] = {["y"] = 0.59775166511536, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 1, [2] = 0.5, [3] = 0}, ["text"] = "여관", ["shape"] = "DOT", ["x"] = 0.67225093046824},
    [20] = {["y"] = 0.80099275112152, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 0, [2] = 0.8, [3] = 1}, ["text"] = "티어변환", ["shape"] = "DOT", ["x"] = 0.69521851539612},
    [21] = {["y"] = 0.79494494199753, ["mapID"] = 2393, ["textSize"] = 40, ["color"] = {[1] = 0, [2] = 1, [3] = 0}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.42551445013866},
    [22] = {["y"] = 0.68329064846039, ["mapID"] = 2393, ["textSize"] = 80, ["color"] = {[1] = 1, [2] = 0, [3] = 0}, ["text"] = "", ["shape"] = "UP", ["x"] = 0.50191980985516},
    [23] = {["y"] = 0.515172290802, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 0, [2] = 0.8, [3] = 1}, ["text"] = "(가세,무두,기공,채광,대장)", ["shape"] = "DOT", ["x"] = 0.34351593653361},
    [24] = {["y"] = 0.51387529373169, ["mapID"] = 2393, ["textSize"] = 40, ["color"] = {[1] = 0, [2] = 0.8, [3] = 1}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.43449253638585},
    [25] = {["y"] = 0.58461360931396, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 1, [2] = 1, [3] = 0}, ["text"] = "시간의 길", ["shape"] = "DOT", ["x"] = 0.36852388381958},
    [26] = {["y"] = 0.60531916618347, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 0, [2] = 1, [3] = 0}, ["text"] = "은행", ["shape"] = "DOT", ["x"] = 0.74051831563314},
    [27] = {["y"] = 0.65139222145081, ["mapID"] = 2393, ["textSize"] = 40, ["color"] = {[1] = 0, [2] = 0.8, [3] = 1}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.40654255549113},
    [28] = {["y"] = 0.62763910293579, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 0, [2] = 0.8, [3] = 1}, ["text"] = "티어변환", ["shape"] = "DOT", ["x"] = 0.4057622273763},
    [29] = {["y"] = 0.62298696041107, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 0, [2] = 0.8, [3] = 1}, ["text"] = "차원문", ["shape"] = "DOT", ["x"] = 0.52818164646265},
    [30] = {["y"] = 0.60153503417969, ["mapID"] = 2393, ["textSize"] = 60, ["color"] = {[1] = 1, [2] = 0, [3] = 0}, ["text"] = "", ["shape"] = "DOWN", ["x"] = 0.48431115746498},
    [31] = {["y"] = 0.57885162830353, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 1, [2] = 0, [3] = 0}, ["text"] = "강화", ["shape"] = "DOT", ["x"] = 0.48442384998004},
    [32] = {["y"] = 0.80587482452393, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 0, [2] = 0.8, [3] = 1}, ["text"] = "pvp", ["shape"] = "DOT", ["x"] = 0.31905812505825},
    [33] = {["y"] = 0.84522933959961, ["mapID"] = 2393, ["textSize"] = 40, ["color"] = {[1] = 0, [2] = 0.8, [3] = 1}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.36260517280644},
    [34] = {["y"] = 0.86866679191589, ["mapID"] = 2393, ["textSize"] = 46, ["color"] = {[1] = 0, [2] = 0.8, [3] = 1}, ["text"] = "허수아비", ["shape"] = "DOT", ["x"] = 0.36406491597493},
    [35] = {["y"] = 0.5155793428421, ["mapID"] = 2393, ["textSize"] = 40, ["color"] = {[1] = 0, [2] = 0.8, [3] = 1}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.468851963679},
    [36] = {["y"] = 0.51614718437195, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 0, [2] = 0.8, [3] = 1}, ["text"] = "(주각,연금,약초,마부,재봉,보세)", ["shape"] = "DOT", ["x"] = 0.57137107849121},
    [37] = {["y"] = 0.71493401527405, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 1, [2] = 0, [3] = 0}, ["text"] = "위대한 금고(은행)", ["shape"] = "DOT", ["x"] = 0.50414628982544},
    [38] = {["y"] = 0.75658875703812, ["mapID"] = 2393, ["textSize"] = 40, ["color"] = {[1] = 1, [2] = 1, [3] = 1}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.50700165430705},
    [39] = {["y"] = 0.76631546020508, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 0, [2] = 1, [3] = 0}, ["text"] = "애완동물 상인", ["shape"] = "DOT", ["x"] = 0.36983172098796},
    [40] = {["y"] = 0.59932661056519, ["mapID"] = 2393, ["textSize"] = 40, ["color"] = {[1] = 1, [2] = 1, [3] = 1}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.44812987645467},
    [41] = {["y"] = 0.57895412445068, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 1, [2] = 1, [3] = 1}, ["text"] = "낚시", ["shape"] = "DOT", ["x"] = 0.44861389795939},
    [42] = {["y"] = 0.80879380702972, ["mapID"] = 2393, ["textSize"] = 40, ["color"] = {[1] = 0, [2] = 0.8, [3] = 1}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.34075323740641},
    [43] = {["y"] = 0.78249973058701, ["mapID"] = 2393, ["textSize"] = 40, ["color"] = {[1] = 0, [2] = 1, [3] = 0}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.49001070658366},
    [44] = {["y"] = 0.68592128753662, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 1, [2] = 1, [3] = 0}, ["text"] = "하란다르", ["shape"] = "DOT", ["x"] = 0.33837879697482},
    [45] = {["y"] = 0.66325862407684, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 1, [2] = 1, [3] = 0}, ["text"] = "공허폭풍", ["shape"] = "DOT", ["x"] = 0.32214703758558},
    [46] = {["y"] = 0.66197173595428, ["mapID"] = 2393, ["textSize"] = 40, ["color"] = {[1] = 1, [2] = 1, [3] = 0}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.35350669225057},
    [47] = {["y"] = 0.68236010074615, ["mapID"] = 2393, ["textSize"] = 40, ["color"] = {[1] = 1, [2] = 1, [3] = 0}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.36861009597778},
    [48] = {["y"] = 0.46161780357361, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 0, [2] = 1, [3] = 0}, ["text"] = "암시장", ["shape"] = "DOT", ["x"] = 0.52202769915263},
    [49] = {["y"] = 0.58473796844482, ["mapID"] = 2393, ["textSize"] = 60, ["color"] = {[1] = 1, [2] = 1, [3] = 0}, ["text"] = "", ["shape"] = "RIGHT", ["x"] = 0.40647003450584},
    [50] = {["y"] = 0.64661002159119, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 0, [2] = 0.8, [3] = 1}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.52600304285685},
    [51] = {["y"] = 0.48711585998535, ["mapID"] = 2393, ["textSize"] = 40, ["color"] = {[1] = 0, [2] = 1, [3] = 0}, ["text"] = "", ["shape"] = "DOT", ["x"] = 0.51982169151306},
    [52] = {["y"] = 0.76616358757019, ["mapID"] = 2393, ["textSize"] = 60, ["color"] = {[1] = 0, [2] = 1, [3] = 0}, ["text"] = "", ["shape"] = "RIGHT", ["x"] = 0.29998056093852},
    [53] = {["y"] = 0.76594104766846, ["mapID"] = 2393, ["textSize"] = 50, ["color"] = {[1] = 0, [2] = 1, [3] = 0}, ["text"] = "하우징 장식 결투", ["shape"] = "DOT", ["x"] = 0.24089819590251},
}

local colorPalette = {
    {r = 1, g = 0, b = 0}, {r = 0, g = 0.4, b = 1}, {r = 0, g = 1, b = 0},
    {r = 1, g = 1, b = 0}, {r = 0, g = 0.8, b = 1}, {r = 1, g = 1, b = 1},
    {r = 1, g = 0.4, b = 0.7}, {r = 1, g = 0.5, b = 0}, {r = 0.6, g = 0.2, b = 1} 
}
local pinPool, rowPool = {}, {}
local activePins, activeRows = {}, {}
local rowMap = {} 

local function ApplyStyle(f)
    f:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.9); f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
end

local MapToggleButton = CreateFrame("Button", nil, WorldMapFrame, "UIPanelButtonTemplate")
MapToggleButton:SetSize(110, 30)
MapToggleButton:SetPoint("TOPRIGHT", WorldMapFrame:GetCanvasContainer(), "TOPRIGHT", -50, -5)
MapToggleButton:SetFrameStrata("FULLSCREEN_DIALOG")
MapToggleButton:SetText("지도 숨기기")
MapToggleButton:SetScript("OnClick", function()
    isVisible = not isVisible
    RefreshEverything()
    MapToggleButton:SetText(isVisible and "지도 숨기기" or "지도 보이기")
end)

local function isHordeOnly(id)
    for _, v in ipairs(HORDE_ONLY_PINS) do if v == id then return true end end
    return false
end

local function GetPin()
    local canvas = WorldMapFrame:GetCanvas()
    if not canvas then return nil end
    local pin = table.remove(pinPool)
    if not pin then
        pin = CreateFrame("Frame", nil, canvas)
        pin:SetFrameStrata("HIGH"); pin:SetFrameLevel(5000)
        pin:EnableMouse(true); pin:SetMovable(true)
        pin.text = pin:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        pin.text:SetJustifyH("CENTER"); pin.text:SetPoint("CENTER", pin, "CENTER", 0, 0)
        pin:RegisterForDrag("LeftButton")
        pin:SetScript("OnEnter", function(self) self:SetAlpha(0.05) end)
        pin:SetScript("OnLeave", function(self) self:SetAlpha(1.0) end)
    end
    pin:SetParent(canvas); table.insert(activePins, pin); return pin
end

local function GetRow(parent)
    local row = table.remove(rowPool)
    if not row then
        row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        row:SetSize(265, 120); ApplyStyle(row)
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.name:SetPoint("TOPLEFT", 10, -8)
        row.del = CreateFrame("Button", nil, row, "BackdropTemplate"); row.del:SetSize(40, 18); row.del:SetPoint("TOPRIGHT", -5, -5); ApplyStyle(row.del); row.del.t = row.del:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); row.del.t:SetPoint("CENTER"); row.del.t:SetText(L.DELETE)
        row.sizeTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); row.sizeTxt:SetPoint("TOPRIGHT", -55, -25)
        row.mBtn = CreateFrame("Button", nil, row, "BackdropTemplate"); row.mBtn:SetSize(18, 18); row.mBtn:SetPoint("TOPRIGHT", -30, -23); ApplyStyle(row.mBtn); row.mBtn.t = row.mBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal"); row.mBtn.t:SetPoint("CENTER"); row.mBtn.t:SetText("-")
        row.pBtn = CreateFrame("Button", nil, row, "BackdropTemplate"); row.pBtn:SetSize(18, 18); row.pBtn:SetPoint("TOPRIGHT", -10, -23); ApplyStyle(row.pBtn); row.pBtn.t = row.pBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal"); row.pBtn.t:SetPoint("CENTER"); row.pBtn.t:SetText("+")
        row.colorBtns = {}
        for ci, c in ipairs(colorPalette) do
            local cb = CreateFrame("Button", nil, row, "BackdropTemplate")
            cb:SetSize(18, 18); cb:SetPoint("TOPLEFT", ((ci-1) % 8) * 26 + 10, ci > 8 and -67 or -45)
            cb:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"}); cb:SetBackdropColor(c.r, c.g, c.b); row.colorBtns[ci] = cb
        end
        row.shapeBtns = {}
        local icons = {"●", "▲", "▼", "◀", "▶"}
        for si = 1, 5 do
            local sb = CreateFrame("Button", nil, row, "BackdropTemplate")
            sb:SetSize(40, 22); sb:SetPoint("TOPLEFT", (si-1)*45 + 10, -92); ApplyStyle(sb); sb.t = sb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); sb.t:SetPoint("CENTER"); sb.t:SetText(icons[si]); row.shapeBtns[si] = sb
        end
    end
    row:SetParent(parent); table.insert(activeRows, row); return row
end

function RefreshEverything()
    local currentMapID = WorldMapFrame:GetMapID()
    if not currentMapID then return end
    local faction = UnitFactionGroup("player")
    
    if currentMapID == SILVERMOON_MAP_ID then MapToggleButton:Show() else MapToggleButton:Hide() end

    for _, p in ipairs(activePins) do p:Hide(); table.insert(pinPool, p) end activePins = {}
    for _, r in ipairs(activeRows) do r:Hide(); table.insert(rowPool, r) end activeRows = {}
    rowMap = {} 

    if isAdmin then SilvermoonmapListFrame:Show() else SilvermoonmapListFrame:Hide() end
    if not isVisible then return end

    local rowIdx = 0
    for i, data in ipairs(MyMapNotesDB_V6) do
        local hideForAlliance = (faction ~= "Horde" and isHordeOnly(i))
        if not hideForAlliance then
            if data.mapID == currentMapID then 
                local pin = GetPin()
                if pin then
                    pin.data = data; pin.id = i; pin:SetAlpha(1.0)
                    if isAdmin then pin:SetPassThroughButtons() else pin:SetPassThroughButtons("LeftButton", "RightButton") end
                    local size = data.textSize or 40
                    pin.text:SetFont(ChatFontNormal:GetFont(), size, "OUTLINE")
                    
                    local displayText = data.text or ""
                    if displayText:gsub("%s+", "") == "" then displayText = "" end
                    
                    if displayText == "" then
                        displayText = (({DOT="●", UP="▲", DOWN="▼", LEFT="◀", RIGHT="▶"})[data.shape or "DOT"])
                    end
                    
                    pin.text:SetText(displayText)
                    pin.text:SetTextColor(unpack(data.color or {1,1,1}))
                    pin:SetSize(pin.text:GetStringWidth() + 5, pin.text:GetStringHeight() + 5)
                    local currentListPos = rowIdx 
                    pin:SetScript("OnMouseDown", function(self, button)
                        if isAdmin and not IsShiftKeyDown() then
                            SilvermoonmapInputFrame.mode = "EDIT"; SilvermoonmapInputFrame.targetIdx = i; SilvermoonmapInputEditBox:SetText(data.text or ""); SilvermoonmapInputFrame:Show()
                        elseif isAdmin and IsShiftKeyDown() then
                            local scrollMax = SilvermoonmapScrollFrame:GetVerticalScrollRange()
                            SilvermoonmapScrollFrame:SetVerticalScroll(math.min(currentListPos * 125, scrollMax))
                        end
                    end)
                    pin:SetScript("OnDragStart", function(self) if isAdmin and IsShiftKeyDown() then self.isDragging = true; self:StartMoving() end end)
                    pin:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); self.isDragging = false; if self.data then local canvas = WorldMapFrame:GetCanvas(); local w, h = canvas:GetSize(); local left, top = self:GetCenter(); local cL, cT = canvas:GetLeft(), canvas:GetTop(); self.data.x = (left - cL) / w; self.data.y = (cT - top) / h end end)
                    pin:SetScript("OnUpdate", function(self) if not self.isDragging and self.data and self.data.mapID == WorldMapFrame:GetMapID() and WorldMapFrame:IsVisible() then local canvas = WorldMapFrame:GetCanvas(); local cw, ch = canvas:GetSize(); if cw > 0 and ch > 0 then self:ClearAllPoints(); self:SetPoint("CENTER", canvas, "TOPLEFT", self.data.x * cw, -self.data.y * ch); self:Show() end elseif not self.isDragging then self:Hide() end end)
                    pin:Show()
                end
            end
            if isAdmin then
                local row = GetRow(SilvermoonmapListFrame.Content)
                row:SetPoint("TOPLEFT", 0, -rowIdx*125); row:Show()
                rowMap[i] = row
                
                local rowText = data.text or ""
                if rowText:gsub("%s+", "") == "" then rowText = "" end
                
                row.name:SetText("["..i.."] "..(rowText ~= "" and rowText:gsub("\n", " ") or L.SHAPE_PIN))
                row.sizeTxt:SetText("Size: " .. (data.textSize or 40))
                row.del:SetScript("OnClick", function() table.remove(MyMapNotesDB_V6, i); RefreshEverything() end)
                row.mBtn:SetScript("OnClick", function() data.textSize = math.max(10, (data.textSize or 40) - 10); RefreshEverything() end)
                row.pBtn:SetScript("OnClick", function() data.textSize = (data.textSize or 40) + 10; RefreshEverything() end)
                for ci, cb in ipairs(row.colorBtns) do local c = colorPalette[ci]; cb:SetScript("OnClick", function() data.color = {c.r, c.g, c.b}; RefreshEverything() end) end
                for si, sb in ipairs(row.shapeBtns) do sb:SetScript("OnClick", function() data.shape = ({"DOT", "UP", "DOWN", "LEFT", "RIGHT"})[si]; data.text = ""; RefreshEverything() end) end
                rowIdx = rowIdx + 1
            end
        end
    end
     SilvermoonmapListFrame.Content:SetHeight(rowIdx * 125)
end

local MainFrame = CreateFrame("Frame", "SilvermoonmapListFrame", WorldMapFrame, "BackdropTemplate")
MainFrame:SetSize(305, 600); MainFrame:SetPoint("RIGHT", WorldMapFrame, "LEFT", -15, 0); ApplyStyle(MainFrame); MainFrame:Hide()
local Title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); Title:SetPoint("TOP", 0, -15); Title:SetText(L.TITLE)
local ScrollFrame = CreateFrame("ScrollFrame", "SilvermoonmapScrollFrame", MainFrame, "UIPanelScrollFrameTemplate")
ScrollFrame:SetPoint("TOPLEFT", 10, -50); ScrollFrame:SetPoint("BOTTOMRIGHT", -30, 90)
MainFrame.Content = CreateFrame("Frame", nil, ScrollFrame); MainFrame.Content:SetSize(260, 1); ScrollFrame:SetScrollChild(MainFrame.Content)

local InputFrame = CreateFrame("Frame", "SilvermoonmapInputFrame", UIParent, "BackdropTemplate")
InputFrame:SetSize(350, 220); InputFrame:SetPoint("CENTER"); InputFrame:SetFrameStrata("FULLSCREEN_DIALOG"); ApplyStyle(InputFrame); InputFrame:Hide()
local InputScroll = CreateFrame("ScrollFrame", nil, InputFrame, "UIPanelScrollFrameTemplate")
InputScroll:SetPoint("TOPLEFT", 15, -40); InputScroll:SetPoint("BOTTOMRIGHT", -35, 60)
local InputEditBox = CreateFrame("EditBox", "SilvermoonmapInputEditBox", InputScroll)
InputEditBox:SetMultiLine(true); InputEditBox:SetFontObject("ChatFontNormal"); InputEditBox:SetWidth(290); InputEditBox:SetAutoFocus(true); InputScroll:SetScrollChild(InputEditBox)

local function MyMapNotesSave()
    local text = InputEditBox:GetText()
    if InputFrame.mode == "ADD" then table.insert(MyMapNotesDB_V6, { mapID = WorldMapFrame:GetMapID(), x = 0.5, y = 0.5, text = text, textSize = 40, color = {1,1,1}, shape = "DOT" })
    else MyMapNotesDB_V6[InputFrame.targetIdx].text = text end
    InputFrame:Hide(); RefreshEverything()
end
InputEditBox:SetScript("OnEnterPressed", function(self) if IsControlKeyDown() then MyMapNotesSave() else self:Insert("\n") end end)
InputEditBox:SetScript("OnEscapePressed", function() InputFrame:Hide() end)

local ApplyBtn = CreateFrame("Button", nil, InputFrame, "BackdropTemplate"); ApplyBtn:SetSize(100, 30); ApplyBtn:SetPoint("BOTTOMLEFT", 50, 15); ApplyStyle(ApplyBtn); ApplyBtn.t = ApplyBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal"); ApplyBtn.t:SetPoint("CENTER"); ApplyBtn.t:SetText(L.APPLY); ApplyBtn:SetScript("OnClick", MyMapNotesSave)
local CloseBtn = CreateFrame("Button", nil, InputFrame, "BackdropTemplate"); CloseBtn:SetSize(100, 30); CloseBtn:SetPoint("BOTTOMRIGHT", -50, 15); ApplyStyle(CloseBtn); CloseBtn.t = CloseBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal"); CloseBtn.t:SetPoint("CENTER"); CloseBtn.t:SetText(L.CLOSE); CloseBtn:SetScript("OnClick", function() InputFrame:Hide() end)

local function serializeTable(val)
    if type(val) == "table" then local res = "{"; for k, v in pairs(val) do local key = type(k) == "string" and string.format("[%q]", k) or string.format("[%d]", k); res = res .. key .. "=" .. serializeTable(v) .. "," end; return res .. "}"
    elseif type(val) == "string" then return string.format("%q", val) else return tostring(val) end
end

local IOFrame = CreateFrame("Frame", "SilvermoonmapIOFrame", UIParent, "BackdropTemplate"); IOFrame:SetSize(450, 450); IOFrame:SetPoint("CENTER"); ApplyStyle(IOFrame); IOFrame:Hide(); IOFrame:SetFrameStrata("FULLSCREEN_DIALOG")
local IOScroll = CreateFrame("ScrollFrame", nil, IOFrame, "UIPanelScrollFrameTemplate"); IOScroll:SetPoint("TOPLEFT", 20, -20); IOScroll:SetPoint("BOTTOMRIGHT", -35, 70)
local IOEditBox = CreateFrame("EditBox", nil, IOScroll); IOEditBox:SetMultiLine(true); IOEditBox:SetWidth(380); IOEditBox:SetFontObject("ChatFontNormal"); IOScroll:SetScrollChild(IOEditBox)
local IOSaveBtn = CreateFrame("Button", nil, IOFrame, "BackdropTemplate"); IOSaveBtn:SetSize(120, 35); IOSaveBtn:SetPoint("BOTTOMLEFT", 60, 20); ApplyStyle(IOSaveBtn); IOSaveBtn.t = IOSaveBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal"); IOSaveBtn.t:SetPoint("CENTER"); IOSaveBtn.t:SetText(L.APPLY); IOSaveBtn:SetScript("OnClick", function() local func, err = loadstring("return " .. IOEditBox:GetText()); if func then MyMapNotesDB_V6 = func(); RefreshEverything(); IOFrame:Hide() end end)
local IOCloseBtn = CreateFrame("Button", nil, IOFrame, "BackdropTemplate"); IOCloseBtn:SetSize(120, 35); IOCloseBtn:SetPoint("BOTTOMRIGHT", -60, 20); ApplyStyle(IOCloseBtn); IOCloseBtn.t = IOCloseBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal"); IOCloseBtn.t:SetPoint("CENTER"); IOCloseBtn.t:SetText(L.CLOSE); IOCloseBtn:SetScript("OnClick", function() IOFrame:Hide() end)

local function CreateActionButton(text, pos)
    local b = CreateFrame("Button", nil, MainFrame, "BackdropTemplate"); b:SetSize(85, 40); b:SetPoint("BOTTOMLEFT", pos, 20); ApplyStyle(b); b.t = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.t:SetPoint("CENTER"); b.t:SetText(text); return b
end
local addBtn = CreateActionButton(L.ADD, 15); addBtn:SetScript("OnClick", function() SilvermoonmapInputEditBox:SetText(""); SilvermoonmapInputFrame.mode = "ADD"; SilvermoonmapInputFrame:Show() end)
local exportBtn = CreateActionButton(L.EXPORT, 105); exportBtn:SetScript("OnClick", function() IOFrame:Show(); IOSaveBtn:Hide(); IOEditBox:SetText(serializeTable(MyMapNotesDB_V6)); IOEditBox:HighlightText() end)
local importBtn = CreateActionButton(L.IMPORT, 195); importBtn:SetScript("OnClick", function() IOFrame:Show(); IOSaveBtn:Show(); IOEditBox:SetText("") end)

SLASH_SILVERMOONMAP1 = "/smm"
SlashCmdList["SILVERMOONMAP"] = function(msg)
    if msg == ADMIN_COMMAND then isAdmin = not isAdmin; RefreshEverything(); print(isAdmin and L.ADMIN_ON or L.ADMIN_OFF)
    elseif msg == "켜기" then isVisible = true; RefreshEverything(); print("|cff00ff00맵 메모 켜짐|r")
    elseif msg == "끄기" then isVisible = false; RefreshEverything(); print("|cffff0000맵 메모 꺼짐|r")
    else RefreshEverything() end
end

WorldMapFrame:HookScript("OnShow", RefreshEverything)
hooksecurefunc(WorldMapFrame, "OnMapChanged", RefreshEverything)

local isFirstLogin = true
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function(self, event)
    if RefreshEverything then RefreshEverything() end
    if isFirstLogin then
        -- 수정된 제작자 표시 형식 적용
        print("|cffffff00Silvermoonmap|r |cffaaaaaaBy|r |cff00ccff아즈샤라-설쁘|r")
        isFirstLogin = false
    end
end)