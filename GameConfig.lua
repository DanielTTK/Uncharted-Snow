--!strict
--- ============================================================
--- GameConfig.lua
--- Central configuration for Uncharted Snow.
--- All magic numbers live here. Reference via require().
---
--- Usage:
---   local Config = require(ReplicatedStorage.Shared.Constants.GameConfig)
---   local vis = Config.VISIBILITY.RADIUS_STUDS
--- ============================================================

local GameConfig = {}

-- ──────────────────────────────────────────────
-- WORLD / MAP
-- ──────────────────────────────────────────────
GameConfig.WORLD = {
    --- Width and depth of the snowfield in studs.
    MAP_SIZE            = 2000,
    --- Number of loot chests spawned per match.
    LOOT_CHEST_COUNT    = 80,
    --- Number of mob groups spawned per match.
    MOB_GROUP_COUNT     = 40,
    --- Minimum studs between two loot chests.
    MIN_CHEST_SPACING   = 30,
    --- Minimum studs between two mob spawn clusters.
    MIN_MOB_SPACING     = 25,
    --- Y offset above terrain for item placement.
    ITEM_Y_OFFSET       = 1,
}

-- ──────────────────────────────────────────────
-- VISIBILITY / FOG
-- ──────────────────────────────────────────────
GameConfig.VISIBILITY = {
    --- Radius in studs that a player can see.
    RADIUS_STUDS        = 2,
    --- How often (seconds) the client refreshes visible objects.
    CULL_INTERVAL       = 0.1,
}

-- ──────────────────────────────────────────────
-- SNOW TRAIL
-- ──────────────────────────────────────────────
GameConfig.TRAIL = {
    --- How far a player must move before stamping a new trail segment.
    STAMP_DISTANCE      = 1.5,
    --- Width of a trail segment in studs.
    SEGMENT_WIDTH       = 1,
    --- Depth of the trail depression in studs.
    SEGMENT_DEPTH       = 0.15,
    --- Seconds a trail persists (0 = entire match).
    LIFETIME_SECONDS    = 0,
}

-- ──────────────────────────────────────────────
-- FACTIONS
-- ──────────────────────────────────────────────
GameConfig.FACTION = {
    --- Maximum number of distinct factions in a match.
    MAX_FACTIONS        = 6,
    --- Maximum party size within a faction.
    MAX_PARTY_SIZE      = 10,
    --- Studs within which a player can request to join a party leader.
    JOIN_PROXIMITY      = 5,
    --- Faction trail colours (BrickColor names, cycled by faction index).
    TRAIL_COLORS        = {
        "Bright blue",
        "Bright red",
        "Bright green",
        "Bright yellow",
        "Bright orange",
        "Hot pink",
    },
}

-- ──────────────────────────────────────────────
-- COMBAT — DICE
-- ──────────────────────────────────────────────
GameConfig.DICE = {
    SIDES               = 20,
    CRITICAL_HIT_VALUE  = 20,
    CRITICAL_MISS_VALUE = 1,
}

-- ──────────────────────────────────────────────
-- COMBAT — HIT THRESHOLDS
-- ──────────────────────────────────────────────
GameConfig.HIT = {
    --- Fighter light attack vs Fighter.
    FIGHTER_VS_FIGHTER          = 7,
    --- Fighter attack vs Ranged (close quarters).
    FIGHTER_VS_RANGED           = 4,
    --- Fighter heavy attack base threshold.
    HEAVY_BASE                  = 12,
    --- Reduction to heavy threshold per consecutive heavy hit landed.
    HEAVY_HIT_REDUCTION         = 2,
    --- Ranged / magic hit threshold (same for all ranged weapons).
    RANGED_BASE                 = 7,
}

-- ──────────────────────────────────────────────
-- COMBAT — DAMAGE
-- ──────────────────────────────────────────────
GameConfig.DAMAGE = {
    --- Base damage for all standard attacks.
    BASE                        = 10,
    --- Light attack damage multiplier.
    LIGHT_MULTIPLIER            = 1.0,
    --- Heavy attack damage multiplier.
    HEAVY_MULTIPLIER            = 1.8,
    --- Critical hit bonus (additive multiplier, e.g. 0.1 = +10%).
    CRITICAL_BONUS              = 0.10,
    --- Vulnerable state: multiplier applied to incoming heavy attacks.
    VULNERABLE_MULTIPLIER       = 1.25,
}

-- ──────────────────────────────────────────────
-- COMBAT — FLEE
-- ──────────────────────────────────────────────
GameConfig.FLEE = {
    --- Base D20 roll needed to flee successfully.
    BASE_ROLL_NEEDED            = 12,
    --- Bonus flee chance (%) per position behind the leader (position 2 = +5%, etc.).
    POSITION_BONUS_PERCENT      = 5,
    --- Bonus flee chance (%) per extra enemy beyond the party's own size.
    ENEMY_SURPLUS_BONUS_PERCENT = 10,
}

-- ──────────────────────────────────────────────
-- LOOT
-- ──────────────────────────────────────────────
GameConfig.LOOT = {
    --- Fraction of loot the leader receives as a bonus on top of the group share.
    LEADER_BONUS_FRACTION       = 0.25,
    --- Loot rarity weights (higher = more common).
    RARITY_WEIGHTS = {
        COMMON      = 60,
        UNCOMMON    = 25,
        RARE        = 12,
        LEGENDARY   = 3,
    },
}

-- ──────────────────────────────────────────────
-- PLAYER STATS — BASE VALUES
-- ──────────────────────────────────────────────
GameConfig.PLAYER_STATS = {
    BASE_HP             = 100,
    BASE_MOVE_SPEED     = 16,
}

-- ──────────────────────────────────────────────
-- NPC STATS
-- ──────────────────────────────────────────────
GameConfig.NPC = {
    SNOW_GOBLIN = {
        HP          = 30,
        DAMAGE      = 8,
        HIT_ROLL    = 6,
        LOOT_TIER   = "COMMON",
        GROUP_SIZE  = { MIN = 2, MAX = 5 },
    },
    GOBLIN_POLAR_BEAR = {
        HP          = 55,
        DAMAGE      = 14,
        HIT_ROLL    = 5,
        LOOT_TIER   = "UNCOMMON",
        GROUP_SIZE  = { MIN = 1, MAX = 3 },
    },
    SKELETON = {
        HP          = 40,
        DAMAGE      = 10,
        HIT_ROLL    = 7,
        LOOT_TIER   = "COMMON",
        GROUP_SIZE  = { MIN = 2, MAX = 4 },
    },
    ICE_MONSTER = {
        HP          = 90,
        DAMAGE      = 20,
        HIT_ROLL    = 9,
        LOOT_TIER   = "RARE",
        GROUP_SIZE  = { MIN = 1, MAX = 2 },
    },
}

-- ──────────────────────────────────────────────
-- EXTRACTION
-- ──────────────────────────────────────────────
GameConfig.EXTRACTION = {
    --- Number of extraction points per match.
    POINT_COUNT         = 3,
    --- Studs radius a player must stand within to trigger extraction.
    TRIGGER_RADIUS      = 4,
    --- Seconds to stand in the zone before extraction completes.
    EXTRACTION_TIME     = 5,
}

-- ──────────────────────────────────────────────
-- DATA STORE KEYS
-- ──────────────────────────────────────────────
GameConfig.DATASTORE = {
    PLAYER_DATA_KEY     = "PlayerData_v1",
}

return GameConfig
