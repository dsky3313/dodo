---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local dodo = _G.dodo

dodo._ptc = dodo._ptc or {}
local ptc = dodo._ptc

local tsort, tconcat = table.sort, table.concat
local floor = math.floor

-- ==============================
-- SPELLS — { [spellID] = { cd, buff?, cast?, short?, zone?, others? } }
-- KiraUI-Plugin_PartyCDs.lua 직접 이식
-- ==============================
ptc.SPELLS = {
    [49028] = { cd = 120, buff = { 81256 } },
    [48792] = { cd = 120 },
    [48707] = { cd = 60,  buff = { 48707, 444741 } },
    [51271] = { cd = 45  },
    [42650] = { cd = 90  },
    [51052] = { cd = 240, buff = { 51052, 145629 }, zone = true },

    [191427] = { cd = 120, buff = { 162264 }, short = 10 },
    [198589] = { cd = 60,  buff = { 212800 } },
    [196718] = { cd = 300, buff = { 209426 } },

    [194223] = { cd = 180, buff = { 194223, 102560, 390414 }, cast = { 102560, 390414 } },
    [106951] = { cd = 180, buff = { 106951, 102543 }, cast = { 102543 } },
    [740]    = { cd = 180, buff = { 740, 157982, 1264623 } },
    [22812]  = { cd = 60  },
    [61336]  = { cd = 180 },

    [375087] = { cd = 120 },
    [363534] = { cd = 240 },
    [403631] = { cd = 120, cast = { 442204 } },
    [363916] = { cd = 90  },

    [19574]   = { cd = 90,  buff = { 19574, 186254, 1235388, 1285912 } },
    [288613]  = { cd = 120 },
    [1250646] = { cd = 90,  buff = { 1250646, 1251703 } },
    [186265]  = { cd = 180 },
    [264735]  = { cd = 90  },

    [365350] = { cd = 90,  buff = { 365350, 365362 } },
    [190319] = { cd = 120, short = 8 },
    [45438]  = { cd = 240, buff = { 45438, 414658 }, cast = { 414658 } },
    [342245] = { cd = 60,  buff = { 342246 } },

    [132578] = { cd = 120 },
    [123904] = { cd = 120, buff = { 123904, 1248992 } },
    [115203] = { cd = 360, buff = { 115203, 120954 } },
    [122783] = { cd = 90  },
    [122470] = { cd = 90,  buff = { 125174 } },

    [31884] = { cd = 120, buff = { 31884, 231895, 454351, 216331, 389539 }, cast = { 231895, 216331, 389539 } },
    [642]   = { cd = 300 },
    [498]   = { cd = 60,  buff = { 498, 403876 }, cast = { 403876 } },
    [31850] = { cd = 90  },

    [62618]  = { cd = 180, buff = { 81782 } },
    [200183] = { cd = 120 },
    [228260] = { cd = 120, buff = { 194249 } },
    [19236]  = { cd = 90  },
    [47585]  = { cd = 120 },

    [360194] = { cd = 120, buff = { 1249810 } },
    [121471] = { cd = 90  },
    [31224]  = { cd = 120 },
    [5277]   = { cd = 120 },

    [114050] = { cd = 180, buff = { 114050, 1219480 }, short = 10 },
    [114051] = { cd = 180, short = 10 },
    [98008]  = { cd = 180, buff = { 325174 } },
    [108271] = { cd = 120 },
    [198103] = { cd = 180, buff = { 198103, 381755 } },

    [265187] = { cd = 60,  buff = { 1276767 } },
    [205180] = { cd = 120 },
    [1122]   = { cd = 120, buff = { 111685, 266087, 417282 } },
    [104773] = { cd = 180 },
    [108416] = { cd = 60  },

    [1719]  = { cd = 90  },
    [118038] = { cd = 120 },
    [184364] = { cd = 120 },
    [97462]  = { cd = 180, buff = { 97463 } },
    [23920]  = { cd = 25  },

    -- 외부 CD (zone = true)
    [33206]  = { cd = 180, zone = true },
    [47788]  = { cd = 180, zone = true, others = true },
    [102342] = { cd = 90,  zone = true },
    [116849] = { cd = 120, zone = true },
    [6940]   = { cd = 120, zone = true, others = true },
    [357170] = { cd = 60,  zone = true },

    -- 종족특성
    [20594]  = { cd = 120, buff = { 65116 },          race = 'Dwarf',         raceID = 3  },
    [265221] = { cd = 120, buff = { 265226, 273104 }, race = 'DarkIronDwarf', raceID = 34 },
    [58984]  = { cd = 120,                            race = 'NightElf',      raceID = 4  },
}

-- ==============================
-- 전처리 — sig, include, filters, casts
-- ==============================
for id, sp in pairs(ptc.SPELLS) do
    sp.id = id
    sp.buff = sp.buff or { id }
    tsort(sp.buff)
    sp.sig = tconcat(sp.buff, ',')
    sp.include = {}
    for _, b in ipairs(sp.buff) do sp.include[b] = true end
    sp.filters = { includeSpellIDs = sp.include }
    if sp.short then
        sp.shortSig = sp.sig .. '<' .. sp.short
        sp.shortFilters = { includeSpellIDs = sp.include, maxDuration = sp.short }
    end
    sp.casts = { [id] = true }
    if sp.cast then
        for _, c in ipairs(sp.cast) do sp.casts[c] = true end
    end
end

-- ==============================
-- SPECS — { [specID] = { spellID or {spellID, cdOverride}, ... } }
-- ==============================
ptc.SPECS = {
    [250] = { { 49028, 90 }, 48792, 51052 },
    [251] = { 51271, 48792, { 48707, 40 }, 51052 },
    [252] = { 42650, 48792, { 48707, 40 }, 51052 },

    [577]  = { 191427, 198589, { 196718, 180 } },
    [581]  = { { 196718, 180 } },
    [1480] = { 198589, { 196718, 180 } },

    [102] = { { 194223, 120 }, 22812 },
    [103] = { { 106951, 90 }, 22812, 61336 },
    [104] = { { 22812, 34 }, { 61336, 137 } },
    [105] = { { 102342, 70 }, 740, 22812 },

    [1467] = { 375087, 363916 },
    [1468] = { 357170, 363534, 363916 },
    [1473] = { 403631, 363916 },

    [253] = { { 19574, 30 }, { 186265, 120 }, 264735 },
    [254] = { 288613, { 186265, 120 }, 264735 },
    [255] = { 1250646, { 186265, 120 }, 264735 },

    [62] = { 365350, { 45438, 150 }, { 342245, 55 } },
    [63] = { { 190319, 60 }, { 45438, 150 }, { 342245, 50 } },
    [64] = { { 45438, 120 }, { 342245, 50 } },

    [268] = { 132578 },
    [269] = { 123904, 122470, { 115203, 90 } },
    [270] = { { 116849, 75 }, { 115203, 90 }, 122783 },

    [65] = { 6940, { 31884, 60 }, { 642, 210 }, { 498, 42 } },
    [66] = { { 31884, 60 }, { 31850, 63 } },
    [70] = { { 31884, 60 }, { 642, 210 }, { 498, 63 } },

    [256] = { 33206, 62618, 19236 },
    [257] = { 47788, 200183, { 19236, 70 } },
    [258] = { 228260, 47585, { 19236, 70 } },

    [259] = { 360194, 31224, 5277 },
    [260] = { 31224, 5277 },
    [261] = { 121471, 31224, 5277 },

    [262] = { { 114050, 120 }, { 108271, 90 }, 198103 },
    [263] = { { 114051, 120 }, { 108271, 90 }, 198103 },
    [264] = { 98008, { 108271, 90 }, 198103 },

    [265] = { 205180, 104773, { 108416, 45 } },
    [266] = { 265187, 104773, { 108416, 45 } },
    [267] = { 1122, 104773, { 108416, 45 } },

    [71] = { { 118038, 108 }, 97462, { 23920, 23 } },
    [72] = { 1719, { 184364, 108 }, 97462, { 23920, 23 } },
    [73] = { 97462, { 23920, 23 } },
}

-- ==============================
-- CLASSES
-- ==============================
ptc.CLASSES = {
    { token = 'DEATHKNIGHT', specs = { 250, 251, 252 } },
    { token = 'DEMONHUNTER', specs = { 577, 581, 1480 } },
    { token = 'DRUID',       specs = { 102, 103, 104, 105 } },
    { token = 'EVOKER',      specs = { 1467, 1468, 1473 } },
    { token = 'HUNTER',      specs = { 253, 254, 255 } },
    { token = 'MAGE',        specs = { 62, 63, 64 } },
    { token = 'MONK',        specs = { 268, 269, 270 } },
    { token = 'PALADIN',     specs = { 65, 66, 70 } },
    { token = 'PRIEST',      specs = { 256, 257, 258 } },
    { token = 'ROGUE',       specs = { 259, 260, 261 } },
    { token = 'SHAMAN',      specs = { 262, 263, 264 } },
    { token = 'WARLOCK',     specs = { 265, 266, 267 } },
    { token = 'WARRIOR',     specs = { 71, 72, 73 } },
}

-- ==============================
-- spec_list(spec) → { {id, cd, spell, show}, ... }
-- ==============================
local CD_MIN, CD_MAX = 5, 900

local function spec_list(spec)
    local src = ptc.SPECS[spec]
    if not src then return nil end
    local out = {}
    for _, e in ipairs(src) do
        local id         = type(e) == 'table' and e[1] or e
        local cd_override = type(e) == 'table' and e[2] or nil
        local sp = ptc.SPELLS[id]
        if sp then
            local cd = floor(math.max(CD_MIN, math.min(CD_MAX, cd_override or sp.cd)))
            out[#out + 1] = { id = id, show = id, cd = cd, spell = sp }
        end
    end
    return out
end

ptc.spec_list = spec_list

-- class_token → 해당 클래스 전체 스펙 스펠 합집합 (스펙 미확인 시 사용)
local function class_list(class_token)
    local out, seen = {}, {}
    for _, cls in ipairs(ptc.CLASSES) do
        if cls.token == class_token then
            for _, spec in ipairs(cls.specs) do
                local list = spec_list(spec)
                if list then
                    for _, def in ipairs(list) do
                        if not seen[def.id] then
                            seen[def.id] = true
                            out[#out + 1] = def
                        end
                    end
                end
            end
            break
        end
    end
    return out
end

ptc.class_list = class_list

-- ==============================
-- 종족특성 — race_token → spellID, 목록 끝에 1개 추가
-- ==============================
ptc.RACIAL = {}
for id, sp in pairs(ptc.SPELLS) do
    if sp.race then ptc.RACIAL[sp.race] = id end
end

local function racial_add(list, race)
    local id = race and ptc.RACIAL[race]
    local sp = id and ptc.SPELLS[id]
    if not sp then return list end
    list = list or {}
    local cd = floor(math.max(CD_MIN, math.min(CD_MAX, sp.cd)))
    list[#list + 1] = { id = id, show = id, cd = cd, spell = sp }
    return list
end

ptc.racial_add = racial_add
