# Changelog

All notable changes to Uncharted Snow will be documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

## [0.1.0] — Initial Scaffold
### Added
- Full project architecture and directory structure
- Core OOP class system (Player, Mob, Item, Party, Faction)
- D20 DiceSystem with critical hit and fumble support
- CombatService: turn-based combat engine, Fighter & Ranged class logic
- FleeSystem: positional and size-based flee modifiers
- WorldGenerationService: procedural loot chest & mob placement
- SnowTrailService: trail stamping and faction-coloured path rendering
- FactionService: faction assignment and party formation
- LootService: loot distribution with leader bonus
- InventoryManager: session and persistent (DataStore) inventory
- SessionManager: match lifecycle management
- LobbyService: Bank NPC and Trader NPC framework
- ExtractionService: extraction point detection and loot transfer
- VisibilityController (client): 2-metre fog/culling system
- TrailController (client): local trail rendering
- CombatUIController (client): turn-based combat UI
- GameConfig constants file
- Types definitions (strict Luau)
- README, ARCHITECTURE docs, COMBAT_RULES docs
