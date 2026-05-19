local addonName, dodo = ...

local ModuleMixin = {}
function ModuleMixin:Print(...) print("|cffaaffaadodo [" .. self.Name .. "]:|r", ...) end

function dodo:RegisterModule(name, module)
    module = module or {}
    for k, v in pairs(ModuleMixin) do module[k] = v end
    module.Name = name
    dodo.Modules[name] = module
    table.insert(dodo.ModuleRegistry, module)
    return module
end

function dodo:EnableModules()
    for _, module in ipairs(dodo.ModuleRegistry) do
        if module.OnEnable then
            local ok, err = xpcall(function()
                module:OnEnable()
            end, geterrorhandler())
            if not ok then
                print("|cffff0000dodo 모듈 실행 실패 (" .. module.Name .. "):|r", err)
            end
        end
    end
end

-- Hook into Engine
local originalInit = dodo.OnInitialize
function dodo:OnInitialize()
    if originalInit then originalInit(self) end
    -- Initialization logic for modules if needed
end

local originalEnable = dodo.OnEnable
function dodo:OnEnable()
    if originalEnable then originalEnable(self) end
    self:EnableModules()
end
