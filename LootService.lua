--!strict
--- ============================================================
--- LootService.lua  (Server Service — singleton)
--- Manages loot pool generation and distribution after encounters.
---
--- Distribution rules:
---  • All living party members split the loot equally.
---  • The leader receives an additional 25% bonus on top
---    of their standard share (Config.LOOT.LEADER_BONUS_FRACTION).
---  • If the leader chose KeepLoot, followers receive nothing;
---    the leader takes everything.
---
--- Usage:
---   LootService.init()
---   LootService.awardMobLoot(party, mobs)
--- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config            = require(ReplicatedStorage.Shared.Constants.GameConfig)
local Types             = require(ReplicatedStorage.Shared.Types.Types)

-- Re-use the internal type aliases to avoid circular requires.
type Party = {
    partyId         : string,
    members         : { any },
    lootShareMode   : string,
    getLeader       : (self: any) -> any,
    livingCount     : (self: any) -> number,
}

type NpcMob = {
    lootTier    : string,
    isAlive     : boolean,
}

-- ──────────────────────────────────────────────
-- Loot table data
-- Hard-coded here; expand iteratively as content grows.
-- ──────────────────────────────────────────────

--- Pool entries by rarity tier.
local LOOT_TABLE: { [string]: { Types.ItemData } } = {
    COMMON = {
        { id = "item_wood_bow",      name = "Worn Bow",           category = "Weapon",  rarity = "Common",    value = 5,  description = "A cracked but functional bow." },
        { id = "item_health_potion", name = "Health Potion",      category = "Potion",  rarity = "Common",    value = 15, description = "Restores 15 HP." },
        { id = "item_speed_buff",    name = "Haste Powder",       category = "Buff",    rarity = "Common",    value = 0,  description = "+20% movement speed for 30s." },
    },
    UNCOMMON = {
        { id = "item_fire_bow",      name = "Fire Bow",           category = "Weapon",  rarity = "Uncommon",  value = 12, description = "Arrows deal bonus fire damage." },
        { id = "item_steel_sword",   name = "Steel Sword",        category = "Weapon",  rarity = "Uncommon",  value = 12, description = "A well-balanced sword." },
        { id = "item_frost_skin",    name = "Frost Cloak",        category = "Skin",    rarity = "Uncommon",  value = 0,  description = "A shimmering icy appearance." },
    },
    RARE = {
        { id = "item_lightning_bow", name = "Lightning Bow",      category = "Weapon",  rarity = "Rare",      value = 20, description = "Arrows crackle with lightning." },
        { id = "item_magic_staff",   name = "Ancient Staff",      category = "Weapon",  rarity = "Rare",      value = 20, description = "Channels fire and lightning." },
        { id = "item_winner_song_1", name = "Victory Fanfare",    category = "WinnerSong", rarity = "Rare",   value = 0,  description = "A triumphant tune for the victors." },
    },
    LEGENDARY = {
        { id = "item_blizzard_axe",  name = "Blizzard Axe",       category = "Weapon",  rarity = "Legendary", value = 35, description = "Summons a mini-blizzard on heavy crits." },
        { id = "item_legend_skin",   name = "Frozen Crown",       category = "Skin",    rarity = "Legendary", value = 0,  description = "Only the mightiest wear this." },
    },
}

-- ──────────────────────────────────────────────
-- Service singleton table
-- ──────────────────────────────────────────────

--- @class LootService
local LootService = {}

-- ──────────────────────────────────────────────
-- Private helpers
-- ──────────────────────────────────────────────

--- Pick a random rarity tier using weighted random selection.
---@return string  One of "COMMON" | "UNCOMMON" | "RARE" | "LEGENDARY".
local function pickRarity(): string
    local weights = Config.LOOT.RARITY_WEIGHTS
    local total   = weights.COMMON + weights.UNCOMMON + weights.RARE + weights.LEGENDARY
    local roll    = math.random(1, total)

    if roll <= weights.COMMON then
        return "COMMON"
    elseif roll <= weights.COMMON + weights.UNCOMMON then
        return "UNCOMMON"
    elseif roll <= weights.COMMON + weights.UNCOMMON + weights.RARE then
        return "RARE"
    else
        return "LEGENDARY"
    end
end

--- Draw a random item from the loot table for the given rarity tier.
--- Falls back to COMMON if the tier is empty.
---@param tier  string
---@return Types.ItemData
local function drawItem(tier: string): Types.ItemData
    local pool = LOOT_TABLE[tier] or LOOT_TABLE["COMMON"]
    return pool[math.random(1, #pool)]
end

--- Generate a loot pool for a given mob loot tier.
---@param tier  string   e.g. "COMMON", "RARE".
---@param count number   How many items to draw.
---@return { Types.ItemData }
local function generatePool(tier: string, count: number): { Types.ItemData }
    local pool: { Types.ItemData } = {}
    for _ = 1, count do
        -- Tier acts as a floor: always pick at/above the mob's tier.
        local rarity = pickRarity()
        -- Enforce minimum tier (primitive comparison via fixed order).
        local tierOrder = { COMMON = 1, UNCOMMON = 2, RARE = 3, LEGENDARY = 4 }
        if (tierOrder[rarity] or 1) < (tierOrder[tier] or 1) then
            rarity = tier
        end
        table.insert(pool, drawItem(rarity))
    end
    return pool
end

-- ──────────────────────────────────────────────
-- Public API
-- ──────────────────────────────────────────────

--- Bootstrap the service. Call once from the server init script.
function LootService.init(): ()
    print("[LootService] Initialised.")
end

--- Award loot to a party after defeating a mob group.
--- Distributes items to each living member; leader gets bonus share.
---
---@param party Party           The victorious party.
---@param mobs  { NpcMob }      Defeated mobs (used to determine loot pool).
function LootService.awardMobLoot(party: Party, mobs: { NpcMob }): ()
    -- Collect loot from all defeated mobs.
    local allLoot: { Types.ItemData } = {}
    for _, mob in ipairs(mobs) do
        if not mob.isAlive then
            local pool = generatePool(mob.lootTier, 1)
            for _, item in ipairs(pool) do
                table.insert(allLoot, item)
            end
        end
    end

    if #allLoot == 0 then
        print("[LootService] No loot to distribute.")
        return
    end

    local leader     = party:getLeader()
    local aliveCount = party:livingCount()

    if party.lootShareMode == "KeepLoot" then
        -- Leader takes everything.
        for _, item in ipairs(allLoot) do
            if leader.addItem then
                (leader :: any):addItem(item)
            end
        end
        print(string.format("[LootService] KeepLoot: leader %d received %d items.", leader.userId, #allLoot))
        return
    end

    -- Share mode: split evenly, then award leader bonus.
    local share     = math.floor(#allLoot / math.max(1, aliveCount))
    local itemIndex = 1

    for _, member in ipairs(party.members) do
        if not (member :: any).isAlive then continue end

        local toGive = share
        if member.userId == leader.userId then
            -- Leader bonus: 25% more items on top of base share.
            toGive = math.ceil(share * (1 + Config.LOOT.LEADER_BONUS_FRACTION))
        end

        for _ = 1, toGive do
            if itemIndex > #allLoot then break end
            if (member :: any).addItem then
                (member :: any):addItem(allLoot[itemIndex])
            end
            itemIndex += 1
        end

        print(string.format("[LootService] User %d received %d item(s).", member.userId, toGive))
    end
end

--- Generate a loot pool for a chest spawn in the world.
---@param rarity    string  Forced rarity tier for the chest.
---@param count     number  Number of items in the chest.
---@return { Types.ItemData }
function LootService.generateChestPool(rarity: string, count: number): { Types.ItemData }
    return generatePool(rarity, count)
end

return LootService
