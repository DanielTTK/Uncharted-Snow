--!strict
--- ============================================================
--- Types.lua
--- Centralised Luau type definitions for Uncharted Snow.
--- Import with:  local Types = require(ReplicatedStorage.Shared.Types.Types)
--- ============================================================

local Types = {}

-- ──────────────────────────────────────────────
-- ENUMERATIONS (string unions used as enums)
-- ──────────────────────────────────────────────

export type ClassType     = "Fighter" | "Ranged"
export type WeaponType    = "Sword" | "Axe" | "Bow" | "MagicStaff"
export type AttackType    = "LightAttack" | "HeavyAttack" | "Arrow" | "FireArrow"
                          | "LightningArrow" | "DaggerStrike" | "Fireball"
                          | "LightningBolt" | "StaffStrike"
export type MobType       = "SnowGoblin" | "GoblinPolarBear" | "Skeleton" | "IceMonster"
export type LootRarity    = "Common" | "Uncommon" | "Rare" | "Legendary"
export type LootCategory  = "Weapon" | "Potion" | "Buff" | "Skin" | "WinnerSong"
export type CombatResult  = "Hit" | "Miss" | "CriticalHit" | "CriticalMiss"
export type FleeResult    = "Success" | "Failure"
export type TurnAction    = "Attack" | "UseItem" | "Flee"

-- ──────────────────────────────────────────────
-- STATS
-- ──────────────────────────────────────────────

--- Base stats shared by players and NPCs.
export type CombatStats = {
    maxHp           : number,
    currentHp       : number,
    baseAttack      : number,
    --- Number of consecutive heavy attacks landed (Fighter only).
    heavyHitCount   : number,
    --- Whether this unit is in the Vulnerable state.
    isVulnerable    : boolean,
}

-- ──────────────────────────────────────────────
-- ITEMS & LOOT
-- ──────────────────────────────────────────────

export type ItemData = {
    id          : string,
    name        : string,
    category    : LootCategory,
    rarity      : LootRarity,
    --- Optional numeric value (damage, heal amount, etc.)
    value       : number?,
    description : string,
}

export type LootPool = { ItemData }

-- ──────────────────────────────────────────────
-- COMBAT
-- ──────────────────────────────────────────────

export type AttackResult = {
    roll        : number,
    result      : CombatResult,
    damage      : number,
    attackType  : AttackType,
}

export type FleeAttempt = {
    roll            : number,
    result          : FleeResult,
    partyPosition   : number,
    enemySurplus    : number,
    effectiveNeeded : number,
}

-- ──────────────────────────────────────────────
-- FACTION / PARTY
-- ──────────────────────────────────────────────

export type FactionId = string   -- e.g. "Faction_1"
export type PartyId   = string   -- e.g. "Party_abc123"

-- ──────────────────────────────────────────────
-- WORLD GENERATION
-- ──────────────────────────────────────────────

export type SpawnEntry = {
    position    : Vector3,
    spawnType   : "Loot" | "Mob",
    mobType     : MobType?,
    lootPool    : LootPool?,
}

-- ──────────────────────────────────────────────
-- PLAYER SAVE DATA (DataStore)
-- ──────────────────────────────────────────────

export type PlayerSaveData = {
    userId          : number,
    bank            : { ItemData },
    currency        : number,
    unlockedSkins   : { string },
    unlockedSongs   : { string },
}

return Types
