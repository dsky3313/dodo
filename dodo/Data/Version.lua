-- ========================================================================
-- dodo Version
-- Description: WoW Forever(camelot, TOC 16xxx) 여부 판별. 분기는 WOW_PROJECT_ID가 아닌 dodo.IS_FOREVER로.
-- ========================================================================

---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...

local iface = select(4, GetBuildInfo())
dodo.IS_FOREVER = type(iface) == "number" and iface >= 16000 and iface < 20000
