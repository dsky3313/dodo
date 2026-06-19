---@diagnostic disable: undefined-global
local addonName, dodo = ...

---@class DungeonExp
---@field iconID number 확장팩 아이콘 텍스처
---@field category string 확장팩 식별자
---@field name string 표시명

---@type DungeonExp[]
dodo.DungeonExps = {
    { iconID = 135763,  category = "Classic", name = "오리지널" },
    { iconID = 135760,  category = "BC",      name = "불성"     },
    { iconID = 237509,  category = "WoL",     name = "리분"     },
    { iconID = 462340,  category = "CATA",    name = "대격변"   },
    { iconID = 851298,  category = "MoP",     name = "판다"     },
    { iconID = 1535376, category = "WoD",     name = "드레노어" },
    { iconID = 1535374, category = "Legion",  name = "군단"     },
    { iconID = 2176535, category = "BfA",     name = "격아"     },
    { iconID = 3847780, category = "SL",      name = "어둠땅"   },
    { iconID = 4661645, category = "DF",      name = "용군단"   },
    { iconID = 5901551, category = "TWW",     name = "내부전쟁" },
    { iconID = 7294993, category = "MN",      name = "한밤"     },
    { iconID = 132311,  category = "ETC",     name = "기타"     },
}

---@class Dungeon
---@field name string 표시명
---@field type string "spell" | "item" | "housing"
---@field id number 주문/아이템 ID
---@field category string 확장팩 카테고리
---@field faction string? "Alliance" | "Horde"
---@field isSeason boolean? 현 시즌 M+ 던전 여부
---@field mapID number? C_ChallengeMode 맵 ID
---@field lfgID number? LFG 활동 ID
---@field texture number? 던전 아이콘 텍스처

---@type Dungeon[]
dodo.Dungeons = {
    -- Classic
    { name = "기공 얼",  type = "item",  id = 18984,  category = "Classic" },
    { name = "기공 호",  type = "item",  id = 18986,  category = "Classic" },

    -- BC
    { name = "검사",     type = "item",  id = 151016, category = "BC" },
    { name = "기공 얼",  type = "item",  id = 30544,  category = "BC" },
    { name = "기공 호",  type = "item",  id = 30542,  category = "BC" },

    -- WoL
    { name = "기공",     type = "item",  id = 48933,   category = "WoL" },
    { name = "사론",     type = "spell", id = 1254555, category = "WoL", isSeason = true, mapID = 556, lfgID = 1770, texture = 343641  },

    -- CATA
    { name = "누각",     type = "spell", id = 410080,  category = "CATA" },
    { name = "파도",     type = "spell", id = 424142,  category = "CATA" },
    { name = "그림바톨", type = "spell", id = 445424,  category = "CATA" },

    -- MoP
    { name = "기공",     type = "item",  id = 87215,   category = "MoP" },
    { name = "옥룡사",   type = "spell", id = 131204,  category = "MoP" },
    { name = "양조장",   type = "spell", id = 131205,  category = "MoP" },
    { name = "음영파",   type = "spell", id = 131206,  category = "MoP" },
    { name = "모구샨",   type = "spell", id = 131222,  category = "MoP" },
    { name = "석양문",   type = "spell", id = 131225,  category = "MoP" },
    { name = "사원",     type = "spell", id = 131228,  category = "MoP" },
    { name = "붉수도원", type = "spell", id = 131229,  category = "MoP" },
    { name = "전당",     type = "spell", id = 131231,  category = "MoP" },
    { name = "스칼로",   type = "spell", id = 131232,  category = "MoP" },

    -- WoD
    { name = "기공",     type = "item",  id = 112059,  category = "WoD" },
    { name = "상록숲",   type = "spell", id = 159901,  category = "WoD" },
    { name = "어둠달",   type = "spell", id = 159899,  category = "WoD" },
    { name = "정비소",   type = "spell", id = 159900,  category = "WoD" },
    { name = "선착장",   type = "spell", id = 159896,  category = "WoD" },
    { name = "피망치",   type = "spell", id = 159895,  category = "WoD" },
    { name = "아킨둔",   type = "spell", id = 159897,  category = "WoD" },
    { name = "하늘탑",   type = "spell", id = 159898,  category = "WoD", isSeason = true, mapID = 161, lfgID = 182,  texture = 1002596 },
    { name = "검바탑",   type = "spell", id = 159902,  category = "WoD" },

    -- Legion
    { name = "기공",     type = "item",  id = 151652,  category = "Legion" },
    { name = "삼두정",   type = "spell", id = 1254551, category = "Legion", isSeason = true, mapID = 239, lfgID = 486,  texture = 1711340 },
    { name = "용맹",     type = "spell", id = 393764,  category = "Legion" },
    { name = "넬둥",     type = "spell", id = 410078,  category = "Legion" },
    { name = "별궁",     type = "spell", id = 393766,  category = "Legion" },
    { name = "카라잔",   type = "spell", id = 373262,  category = "Legion" },
    { name = "검떼",     type = "spell", id = 424153,  category = "Legion" },
    { name = "어숲",     type = "spell", id = 424163,  category = "Legion" },

    -- BfA
    { name = "기공 얼",  type = "item",  id = 168807,  category = "BfA" },
    { name = "기공 호",  type = "item",  id = 168808,  category = "BfA" },
    { name = "자유지대", type = "spell", id = 410071,  category = "BfA" },
    { name = "썩은굴",   type = "spell", id = 410074,  category = "BfA" },
    { name = "메카곤",   type = "spell", id = 373274,  category = "BfA" },
    { name = "저택",     type = "spell", id = 424167,  category = "BfA" },
    { name = "아탈",     type = "spell", id = 424187,  category = "BfA" },
    { name = "보랄",     type = "spell", id = 445418,  category = "BfA", faction = "Alliance" },
    { name = "보랄",     type = "spell", id = 464256,  category = "BfA", faction = "Horde"    },
    { name = "왕노",     type = "spell", id = 467553,  category = "BfA", faction = "Alliance" },
    { name = "왕노",     type = "spell", id = 467555,  category = "BfA", faction = "Horde"    },

    -- SL
    { name = "기공",     type = "item",  id = 172924,  category = "SL" },
    { name = "죽상",     type = "spell", id = 354462,  category = "SL" },
    { name = "역병",     type = "spell", id = 354463,  category = "SL" },
    { name = "티르너",   type = "spell", id = 354464,  category = "SL" },
    { name = "속죄",     type = "spell", id = 354465,  category = "SL" },
    { name = "승천",     type = "spell", id = 354466,  category = "SL" },
    { name = "고투",     type = "spell", id = 354467,  category = "SL" },
    { name = "저편",     type = "spell", id = 354468,  category = "SL" },
    { name = "핏빛",     type = "spell", id = 354469,  category = "SL" },
    { name = "타자베쉬", type = "spell", id = 367416,  category = "SL" },
    { name = "나스리아", type = "spell", id = 373190,  category = "SL" },
    { name = "지배",     type = "spell", id = 373191,  category = "SL" },
    { name = "태존매",   type = "spell", id = 373192,  category = "SL" },

    -- DF
    { name = "기공",     type = "item",  id = 198156,  category = "DF" },
    { name = "노쿠드",   type = "spell", id = 393262,  category = "DF" },
    { name = "담쟁이",   type = "spell", id = 393267,  category = "DF" },
    { name = "대학",     type = "spell", id = 393273,  category = "DF", isSeason = true, mapID = 402, lfgID = 1160, texture = 4578414 },
    { name = "루비",     type = "spell", id = 393256,  category = "DF" },
    { name = "넬타",     type = "spell", id = 393276,  category = "DF" },
    { name = "보관소",   type = "spell", id = 393279,  category = "DF" },
    { name = "주입",     type = "spell", id = 393283,  category = "DF" },
    { name = "울다만",   type = "spell", id = 393222,  category = "DF" },
    { name = "여명",     type = "spell", id = 424197,  category = "DF" },
    { name = "금고",     type = "spell", id = 432254,  category = "DF" },
    { name = "아베루스", type = "spell", id = 432257,  category = "DF" },
    { name = "아미",     type = "spell", id = 432258,  category = "DF" },

    -- TWW
    { name = "기공",     type = "item",  id = 221966,  category = "TWW" },
    { name = "바금",     type = "spell", id = 445269,  category = "TWW" },
    { name = "부화장",   type = "spell", id = 445443,  category = "TWW" },
    { name = "새인호",   type = "spell", id = 445414,  category = "TWW" },
    { name = "수도원",   type = "spell", id = 445444,  category = "TWW" },
    { name = "수문",     type = "spell", id = 1216786, category = "TWW" },
    { name = "실타래",   type = "spell", id = 445416,  category = "TWW" },
    { name = "아라카라", type = "spell", id = 445417,  category = "TWW" },
    { name = "양조장",   type = "spell", id = 445440,  category = "TWW" },
    { name = "어불동",   type = "spell", id = 445441,  category = "TWW" },
    { name = "알다니",   type = "spell", id = 1237215, category = "TWW" },
    { name = "언더마인", type = "spell", id = 1226482, category = "TWW" },
    { name = "마괴종",   type = "spell", id = 1239155, category = "TWW" },

    -- MN
    { name = "기공",     type = "item",  id = 248485,  category = "MN" },
    { name = "동굴",     type = "spell", id = 1254559, category = "MN", isSeason = true, mapID = 560, lfgID = 1764, texture = 7322719 },
    { name = "마정",     type = "spell", id = 1254572, category = "MN", isSeason = true, mapID = 558, lfgID = 1760, texture = 7439625 },
    { name = "제나스",   type = "spell", id = 1254563, category = "MN", isSeason = true, mapID = 559, lfgID = 1768, texture = 7553062 },
    { name = "첨탑",     type = "spell", id = 1254400, category = "MN", isSeason = true, mapID = 557, lfgID = 1542, texture = 7266215 },

    -- ETC
    { name = "하우징",   type = "housing", id = 1263273, category = "ETC" },
    { name = "도르노갈", type = "item",    id = 243056,  category = "ETC" },
    { name = "여관",     type = "item",    id = 253629,  category = "ETC" },
}
