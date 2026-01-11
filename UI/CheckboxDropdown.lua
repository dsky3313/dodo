------------------------------
-- 테이블
------------------------------
local addonName, ns = ...

------------------------------
-- 체크박스 드롭다운
------------------------------
function CheckBoxDropDown(category, varNameCB, varNameDD, label, tooltip, options, defaultCB, defaultDD, func)
    local varID_CB = "hodo_" .. varNameCB
    local varID_DD = "hodo_" .. varNameDD

    local cbSetting = Settings.GetSetting(varID_CB) or Settings.RegisterAddOnSetting(category, varID_CB, varNameCB, hodoDB, Settings.VarType.Boolean, label, defaultCB or false)

    local fallbackValue = (options and options[1]) and options[1].value or ""
    local ddSetting = Settings.GetSetting(varID_DD) or Settings.RegisterAddOnSetting(category, varID_DD, varNameDD, hodoDB, Settings.VarType.String, label, defaultDD or fallbackValue)
    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        if options then
            for _, option in ipairs(options) do
                container:Add(option.value, option.label)
            end
        end
        return container:GetData()
    end

    -- 4. 템플릿 데이터 구성
    local data = {name = label,
        tooltip = tooltip,
        cbSetting = cbSetting,           -- 체크박스 설정 객체
        dropdownSetting = ddSetting,     -- ★ 핵심: 'setting'이 아니라 'dropdownSetting'이어야 함
        dropdownOptions = GetOptions,    -- ★ 핵심: 'options'가 아니라 'dropdownOptions'여야 함
        cbLabel = label,
        cbTooltip = tooltip,
        dropDownLabel = label,
        dropDownTooltip = tooltip,
    }

    local initializer = Settings.CreateSettingInitializer("hodoCheckboxDropdownTemplate", data)

    local function OnValueChanged()

        if ns.NewLFG then ns.NewLFG() end

    end
    cbSetting:SetValueChangedCallback(OnValueChanged)
    ddSetting:SetValueChangedCallback(OnValueChanged)

    local layout = SettingsPanel:GetLayout(category)
    if layout then
        layout:AddInitializer(initializer)
    end
end