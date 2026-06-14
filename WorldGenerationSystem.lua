--!strict
--- ============================================================
--- WorldGenerationSystem.lua  (Server System — pure / stateless)
--- Generates random spawn entries for loot chests and mob groups
--- for each match. Uses minimum-distance rejection sampling so
--- spawns are not clustered.
---
--- Usage:
---   local entries = WorldGenerationSystem.generate(seed)
--- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config            = require(ReplicatedStorage.Shared.Constants.GameConfig)
local Types             = require(ReplicatedStorage.Shared.Types.Types)

local WorldGenerationSystem = {}

-- Ordered mob type list for random selection.
local MOB_TYPES: { Types.MobType } = {
    "SnowGoblin",
    "GoblinPolarBear",
    "Skeleton",
    "IceMonster",
}

-- ──────────────────────────────────────────────
-- Private helpers
-- ──────────────────────────────────────────────

--- Check that `pos` is at least `minDist` studs from all entries in `occupied`.
---@param pos       Vector3
---@param occupied  { Vector3 }
---@param minDist   number
---@return boolean
local function isClearOf(pos: Vector3, occupied: { Vector3 }, minDist: number): boolean
    for _, existing in ipairs(occupied) do
        if (pos - existing).Magnitude < minDist then
            return false
        end
    end
    return true
end

--- Return a random flat position within the map bounds (Y = 0).
---@param rng   Random
---@return Vector3
local function randomMapPos(rng: Random): Vector3
    local half = Config.WORLD.MAP_SIZE / 2
    return Vector3.new(
        rng:NextNumber(-half, half),
        Config.WORLD.ITEM_Y_OFFSET,
        rng:NextNumber(-half, half)
    )
end

--- Attempt to place `count` positions with `minSpacing`, giving up after
--- `maxAttempts` per placement to avoid infinite loops.
---@param rng           Random
---@param count         number
---@param minSpacing    number
---@param existing      { Vector3 }
---@return { Vector3 }
local function placePositions(
    rng         : Random,
    count       : number,
    minSpacing  : number,
    existing    : { Vector3 }
): { Vector3 }

    local placed: { Vector3 } = {}
    local combined: { Vector3 } = table.clone(existing)
    local MAX_ATTEMPTS = 50

    for _ = 1, count do
        local found = false
        for _ = 1, MAX_ATTEMPTS do
            local pos = randomMapPos(rng)
            if isClearOf(pos, combined, minSpacing) then
                table.insert(placed, pos)
                table.insert(combined, pos)
                found = true
                break
            end
        end
        if not found then
            warn("[WorldGenerationSystem] Could not place spawn after", MAX_ATTEMPTS, "attempts — skipping.")
        end
    end

    return placed
end

-- ──────────────────────────────────────────────
-- Public API
-- ──────────────────────────────────────────────

--- Generate all spawn entries for a match.
---
---@param seed  number  Random seed derived from matchmaking session ID.
---@return { Types.SpawnEntry }  List of all spawn entries.
function WorldGenerationSystem.generate(seed: number): { Types.SpawnEntry }
    local rng     = Random.new(seed)
    local entries: { Types.SpawnEntry } = {}
    local allPos: { Vector3 } = {}

    -- ── Loot chests ──
    local chestPositions = placePositions(
        rng,
        Config.WORLD.LOOT_CHEST_COUNT,
        Config.WORLD.MIN_CHEST_SPACING,
        allPos
    )
    for _, pos in ipairs(chestPositions) do
        table.insert(allPos, pos)
        table.insert(entries, {
            position    = pos,
            spawnType   = "Loot",
            mobType     = nil,
            lootPool    = nil, -- Populated by LootService at runtime.
        })
    end

    -- ── Mob groups ──
    local mobPositions = placePositions(
        rng,
        Config.WORLD.MOB_GROUP_COUNT,
        Config.WORLD.MIN_MOB_SPACING,
        allPos
    )
    for _, pos in ipairs(mobPositions) do
        local mobType: Types.MobType = MOB_TYPES[rng:NextInteger(1, #MOB_TYPES)]
        table.insert(entries, {
            position    = pos,
            spawnType   = "Mob",
            mobType     = mobType,
            lootPool    = nil,
        })
    end

    return entries
end

return WorldGenerationSystem
