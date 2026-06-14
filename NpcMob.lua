--!strict
--- ============================================================
--- NpcMob.lua  (Shared Class)
--- Represents a single NPC mob unit in combat.
--- Mobs are instantiated per-encounter by CombatService.
---
--- Usage:
---   local NpcMob = require(...)
---   local goblin = NpcMob.new("SnowGoblin", 1)
---   goblin:takeDamage(12)
--- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config            = require(ReplicatedStorage.Shared.Constants.GameConfig)
local Types             = require(ReplicatedStorage.Shared.Types.Types)

-- Convenience alias.
type NpcConfig = {
    HP          : number,
    DAMAGE      : number,
    HIT_ROLL    : number,
    LOOT_TIER   : string,
    GROUP_SIZE  : { MIN: number, MAX: number },
}

-- ──────────────────────────────────────────────
-- Class definition
-- ──────────────────────────────────────────────

--- @class NpcMob
local NpcMob   = {}
NpcMob.__index = NpcMob

-- ──────────────────────────────────────────────
-- Constructor
-- ──────────────────────────────────────────────

--- Create a new NpcMob instance.
---
---@param mobType   Types.MobType  Which type of mob this is.
---@param index     number         Unique index within its group (for display).
---@return NpcMob
function NpcMob.new(
    mobType : Types.MobType,
    index   : number
): typeof(setmetatable({} :: any, NpcMob))

    local self = setmetatable({}, NpcMob)

    --- The mob variety.
    self.mobType = mobType

    --- Display name (e.g. "Snow Goblin #3").
    self.displayName = mobType .. " #" .. tostring(index)

    -- Pull NPC config from GameConfig.
    local npcData: NpcConfig = (Config.NPC :: any)[mobType]
    assert(npcData, "[NpcMob] Unknown mob type: " .. mobType)

    --- Minimum D20 roll needed for this mob to hit a target.
    self.hitRoll        = npcData.HIT_ROLL

    --- Loot tier this mob drops.
    self.lootTier       = npcData.LOOT_TIER

    --- Combat stats.
    self.stats: Types.CombatStats = {
        maxHp           = npcData.HP,
        currentHp       = npcData.HP,
        baseAttack      = npcData.DAMAGE,
        heavyHitCount   = 0,
        isVulnerable    = false,
    }

    --- Whether this mob is still alive.
    self.isAlive = true

    return self
end

-- ──────────────────────────────────────────────
-- HP methods
-- ──────────────────────────────────────────────

--- Apply damage, clamp to 0, mark as dead if HP reaches 0.
---@param amount number
function NpcMob:takeDamage(amount: number): ()
    self.stats.currentHp = math.max(0, self.stats.currentHp - amount)
    if self.stats.currentHp <= 0 then
        self.isAlive = false
    end
end

--- Returns true if the mob has > 0 HP.
---@return boolean
function NpcMob:isLiving(): boolean
    return self.stats.currentHp > 0
end

-- ──────────────────────────────────────────────
-- Factory: build a full mob group
-- ──────────────────────────────────────────────

--- Construct a random-sized group of mobs of the given type.
---
---@param mobType   Types.MobType
---@param rng       Random  Seeded RNG from the match session.
---@return { NpcMob }
function NpcMob.createGroup(mobType: Types.MobType, rng: Random): { typeof(setmetatable({} :: any, NpcMob)) }
    local npcData: NpcConfig = (Config.NPC :: any)[mobType]
    local size = rng:NextInteger(npcData.GROUP_SIZE.MIN, npcData.GROUP_SIZE.MAX)
    local group = {}
    for i = 1, size do
        table.insert(group, NpcMob.new(mobType, i))
    end
    return group
end

return NpcMob
