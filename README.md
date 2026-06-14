# ❄️ Uncharted Snow

> A faction-based survival exploration game set in a vast, fog-shrouded snowfield.

---

## Table of Contents

- [Overview](#overview)
- [Core Gameplay Loop](#core-gameplay-loop)
- [Game Systems](#game-systems)
  - [Exploration & Visibility](#exploration--visibility)
  - [Faction & Party System](#faction--party-system)
  - [Combat System](#combat-system)
  - [Loot & Progression](#loot--progression)
  - [Lobby & Economy](#lobby--economy)
- [Classes & Abilities](#classes--abilities)
- [NPC Mobs](#npc-mobs)
- [Project Structure](#project-structure)
- [Architecture](#architecture)
- [Setup & Development](#setup--development)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Team](#team)

---

## Overview

**Uncharted Snow** is a Roblox game in which players join factions and explore a massive, procedurally generated snow-covered map. Visibility is limited to 2 metres, forcing players to navigate carefully, follow paths left by allies, and make split-second decisions when stumbling into enemies. Turn-based combat with a D20 dice system (inspired by *Baldur's Gate 3*) governs every fight against other factions and roaming NPC mobs.

---

## Core Gameplay Loop

```
Matchmaking → Spawn in Snowfield → Explore → Find Loot/Mobs/Enemies
     ↓                                                      ↓
 Lobby ← Extraction Point ← Survive → Fight or Flee ← Encounter
     ↓
  Bank / Trade with NPC Traders → Buy Upgrades, Skins, Potions
```

---

## Game Systems

### Exploration & Visibility

- The snowfield is a large, flat-ish terrain tiled with snow voxels.
- Each player's visibility radius is **2 metres** (enforced via FogService and per-character LocalScript culling).
- When a player walks through snow, a **snow trail** is stamped in the world, persisting for the match duration.
- Trails are faction-coloured so allies can follow them.
- **Loot chests** and **mob spawn points** are randomly seeded per matchmaking session by `WorldGenerationService`.

### Faction & Party System

- Players are assigned to one of N factions at matchmaking.
- Within a faction, players can **form a party** by following a trail and the **leader** accepting them.
- Party mechanics:
  - Leader decides to **share loot** or **keep loot**.
  - The **leader always receives a 25% bonus** on top of the group's total loot share.
  - Position in the queue (1 = leader) affects flee chance (see Combat).

### Combat System

Turn-based, D20-style. See [Combat System](#combat-system) below for full rules.

### Loot & Progression

Loot is distributed at the end of each encounter:
- Loot types: weapons, potions, buffs, skins, winner songs.
- Loot is stored in the player's **session inventory** until extraction.
- After extraction it moves to the **permanent bank** (DataStore).

### Lobby & Economy

The **Lobby** is a persistent place separate from the snowfield:
- **NPC Traders** — sell/buy items.
- **Bank NPC** — access permanent storage.
- *Planned: player-to-player trading, pets, armour.*

---

## Classes & Abilities

### Ranged

| Weapon | Abilities | Hit Roll | Damage |
|--------|-----------|----------|--------|
| Bow    | Arrow Shot, Fire Arrow, Lightning Arrow, Dagger Strike | D20 | Standard |
| Magic Staff | Fireball, Lightning Bolt, Staff Strike | D20 | Standard |

- Critical hit (roll 20): +10% damage.

### Fighter

| Weapon | Abilities | Hit Roll | Damage |
|--------|-----------|----------|--------|
| Sword / Axe | Light Attack | 7+ vs Fighter, 4+ vs Ranged (close) | Low–Med |
| Sword / Axe | Heavy Attack | 12+ (−2 per prior hit; resets on miss) | High |

- Light Attack crit (20): +10% damage.
- Heavy Attack crit (20): +10% damage **and** target becomes **Vulnerable** (future heavy attacks gain advantage).

---

## NPC Mobs

| Mob | Group Behaviour | Loot Type |
|-----|-----------------|-----------|
| Snow Goblin (foot) | Solo groups, no alliances | Common |
| Snow Goblin (Polar Bear) | Solo groups, no alliances | Uncommon |
| Skeleton | Solo groups, no alliances | Common |
| Ice Monster | Solo groups, no alliances | Rare |

Mobs **never** team up with each other across types.

---

## Combat System — Full Rules

### Turn Order
1. Leader → party member 2 → … → last member.
2. NPCs act after all players in the round.

### Actions per Turn
- **Attack** (class-specific)
- **Use Item** (potion / buff)
- **Flee** (see Flee rules)

### Flee Mechanics
| Condition | Modifier |
|-----------|----------|
| Position in party (leader = 0 bonus, last = max bonus) | +5% per position behind leader |
| Enemy group larger than yours | +10% per enemy beyond your count |
| Base flee roll | D20 ≥ 12 to succeed |

*Example: 2-person party vs 10 enemies → +80% effective bonus. Very likely to escape.*

### D20 Reference
| Roll Range | Outcome |
|------------|---------|
| 1          | Critical miss (fumble) |
| 2–6        | Miss |
| 7–11       | Miss (vs Fighter) / Possible hit (vs Ranged) |
| 12–19      | Hit (standard) |
| 20         | Critical hit |

---

## Project Structure

```
UnchartedSnow/
├── README.md
├── CHANGELOG.md
├── .gitignore
├── docs/
│   ├── ARCHITECTURE.md
│   ├── COMBAT_RULES.md
│   └── API_REFERENCE.md
├── tests/
│   └── *.spec.lua
└── src/
    ├── ReplicatedStorage/
    │   └── Shared/
    │       ├── Classes/          -- OOP class definitions (Player, Mob, Item…)
    │       ├── Utilities/        -- Pure helper functions
    │       ├── Constants/        -- Game constants & config
    │       ├── Types/            -- Type definitions (Luau strict types)
    │       └── Modules/          -- Reusable cross-boundary modules
    ├── ServerScriptService/
    │   ├── Services/             -- Singleton server services (init on server start)
    │   ├── Systems/              -- Stateless system logic (combat, generation…)
    │   └── Managers/             -- Stateful managers (session, inventory…)
    └── StarterPlayerScripts/
        ├── Controllers/          -- Client-side input & local logic
        └── UI/                   -- UI controllers & view models
```

---

## Architecture

Uncharted Snow follows a **Service-Oriented Architecture** with strict OOP conventions:

- **Services** (`ServerScriptService/Services/`) — singletons that own a domain (e.g., `CombatService`, `WorldGenerationService`). Bootstrapped once on server start.
- **Systems** (`ServerScriptService/Systems/`) — pure/stateless logic modules called by services (e.g., `DiceSystem`, `FleeSystem`).
- **Managers** (`ServerScriptService/Managers/`) — stateful per-session objects (e.g., `SessionManager`, `InventoryManager`).
- **Shared Classes** (`ReplicatedStorage/Shared/Classes/`) — reusable OOP classes replicated to both server and client.
- **Controllers** (`StarterPlayerScripts/Controllers/`) — client-only input handling, local visibility culling, trail rendering.

All modules use **metatables** for OOP (`__index`, `:new()` constructors). No global state — all state lives in service instances or passed explicitly.

---

## Setup & Development

### Prerequisites
- Roblox Studio (latest)
- [Rojo](https://rojo.space/) 7.x (file sync)
- (Optional) [Wally](https://wally.run/) for package management

### Getting Started

```bash
# Clone the repo
git clone https://github.com/your-org/uncharted-snow.git
cd uncharted-snow

# Sync with Roblox Studio via Rojo
rojo serve default.project.json
```

Then open Roblox Studio and connect the Rojo plugin.

### Coding Standards
- All scripts use **Luau strict mode** (`--!strict`) where possible.
- Every public function has a **JSDoc-style comment block**.
- No magic numbers — use `Constants/GameConfig.lua`.
- `PascalCase` for classes and constructors, `camelCase` for methods and variables.
- Remote events/functions are declared in `ReplicatedStorage/Shared/Remotes`.

---

## Roadmap

### v0.1 — Foundation ✅ (current)
- [x] Project scaffold & architecture
- [x] World generation (random loot & mob placement)
- [x] Snow trail system
- [x] Faction & party system (follow, accept, loot sharing)
- [x] D20 combat engine (Fighter & Ranged classes)
- [x] NPC mob AI (Goblin, Goblin+Bear, Skeleton, Ice Monster)
- [x] Flee system with positional modifiers
- [x] Lobby with Bank NPC & Trader NPC
- [x] Extraction point & DataStore persistence

### v0.2 — Content Pass
- [ ] Additional loot types (skins, winner songs, potions)
- [ ] Expanded mob variety & behaviours
- [ ] More class abilities

### v0.3 — Economy
- [ ] Player-to-player trading
- [ ] Pets system
- [ ] Armour system

### v1.0 — Launch
- [ ] Polish, balance pass
- [ ] Anti-cheat hardening
- [ ] Monetisation (cosmetics only)

---

## Contributing

1. Branch from `main` — name your branch `feature/your-feature` or `fix/your-fix`.
2. Follow the coding standards above.
3. Add tests in `tests/` for any new system logic.
4. Open a PR with a clear description referencing the relevant roadmap item.

---

## Team

| Role | Handle |
|------|--------|
| Lead Developer | — |
| Game Designer | — |
| Artist | — |

---

*Uncharted Snow is an independent project. Not affiliated with Roblox Corporation.*
