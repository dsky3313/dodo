-- ==============================
-- 설정 및 테이블
-- ==============================
local dodo = _G.dodo

-- ==============================
-- 캐싱
-- ==============================
local C_XMLUtil = C_XMLUtil
local ContainerFrameCombinedBags = ContainerFrameCombinedBags
local ContainerFrameSettingsManager = ContainerFrameSettingsManager
local IsAccountSecured = IsAccountSecured
local hooksecurefunc = hooksecurefunc

-- ==============================
-- 상수
-- ==============================
local COLS = 10
local ITEM_SPACING_X = 5
local ITEM_SPACING_Y = 5
local ANCHOR_Y = 4  -- GetInitialItemAnchor y offset (MoneyFrame TOPRIGHT 기준)

-- ==============================
-- 기능: 가방별 줄바꿈 레이아웃
-- ==============================

-- 블리자드 UpdateItemSort 복사 (정렬 순서 맞춤)
local function sort_items(items)
    if not IsAccountSecured() and ContainerFrameSettingsManager:IsUsingCombinedBags() then
        table.sort(items, function(a, b)
            local ea, eb = a:IsExtended(), b:IsExtended()
            if ea ~= eb then return not ea end
            local ba, bb = a:GetBagID(), b:GetBagID()
            if ba ~= bb then return ba > bb end
            return a:GetID() < b:GetID()
        end)
    end
end

local function do_bag_break_layout(frame)
    if not frame:IsCombinedBagContainer() then return end

    local tpl_info = C_XMLUtil.GetTemplateInfo(frame.itemButtonPool:GetTemplate())
    local ITEM_W = tpl_info and tpl_info.width or 37
    local ITEM_H = tpl_info and tpl_info.height or 37
    local step_x = ITEM_W + ITEM_SPACING_X
    local step_y = ITEM_H + ITEM_SPACING_Y

    -- 블리자드와 동일 정렬
    local items = {}
    for _, btn in frame:EnumerateValidItems() do
        items[#items + 1] = btn
    end
    sort_items(items)

    -- 가방별 그룹화 (정렬 순서 유지)
    local groups = {}
    local gmap = {}
    for _, btn in ipairs(items) do
        local bid = btn:GetBagID()
        if not gmap[bid] then
            gmap[bid] = #groups + 1
            groups[#groups + 1] = { bid, {} }
        end
        local t = groups[gmap[bid]][2]
        t[#t + 1] = btn
    end

    -- 배치: BOTTOMLEFT of frame.MoneyFrame TOPLEFT 기준, 오른쪽→위쪽
    local row, col = 0, 0
    for _, g in ipairs(groups) do
        if col > 0 then
            row = row + 1
            col = 0
        end
        for _, btn in ipairs(g[2]) do
            btn:ClearAllPoints()
            btn:SetPoint("BOTTOMLEFT", frame.MoneyFrame, "TOPLEFT",
                col * step_x, ANCHOR_Y + row * step_y)
            col = col + 1
            if col >= COLS then
                col = 0
                row = row + 1
            end
        end
    end

    -- 프레임 높이 재계산 (break로 늘어난 줄 수 반영)
    local orig_rows = frame:GetRows()
    local new_rows = (col == 0) and row or (row + 1)
    if new_rows < 1 then new_rows = 1 end
    local orig_items_h = orig_rows * ITEM_H + math.max(0, orig_rows - 1) * ITEM_SPACING_Y
    local new_items_h  = new_rows  * ITEM_H + math.max(0, new_rows  - 1) * ITEM_SPACING_Y
    if new_items_h ~= orig_items_h then
        frame:SetSize(frame:GetWidth(), frame:GetHeight() + (new_items_h - orig_items_h))
    end
end

-- ==============================
-- 초기화
-- ==============================
if ContainerFrameCombinedBags then
    hooksecurefunc(ContainerFrameCombinedBags, "UpdateItemLayout", do_bag_break_layout)
end
