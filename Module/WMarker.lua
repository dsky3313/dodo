local CreateFrame  = CreateFrame
local CURSOR_LABEL = "Cursor"
local format       = format

-- 설정창 제목 (XML의 header="WMB"와 매칭)
_G["BINDING_HEADER_WMB"] = "dodo WMarker"

local function Binding(name, label, macrotext)
    -- XML의 name 문자열과 정확히 일치해야 설정창에 이름이 뜹니다.
    _G["BINDING_NAME_CLICK " .. name .. ":LeftButton"] = label
    
    -- 보안 버튼 생성 (name은 WMB_WM1CURSOR 형식이 됩니다)
    local btn = CreateFrame("Button", name, nil, "SecureActionButtonTemplate")
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", macrotext)
    btn:RegisterForClicks("AnyUp", "AnyDown")
end

-- 1번부터 8번까지 반복 생성
for i = 1, 8 do
    local internalName = "WMB_WM" .. i .. "CURSOR"
    local markerName = _G["WORLD_MARKER" .. i] or ("마커 " .. i)
    
    -- 직접 /wm [@cursor] 번호 매크로 작성
    Binding(internalName, 
            markerName .. " @ " .. CURSOR_LABEL, 
            format("/wm [@cursor] %d", i))
end