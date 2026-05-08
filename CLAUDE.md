# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hexfront is a turn-based hex-grid strategy game built in **Godot 4** using **GDScript**. Two players compete on a 5×5 flat-top hex grid, expanding territory, managing three resources (Manpower, Supplies, Materials), and winning by occupying an enemy Residential cell or triggering opponent starvation.

## Running the Game

Open the project in Godot 4 editor and press F5 (or use the MCP Godot tools: `mcp__godot__run_project` / `mcp__godot__stop_project`). There is no CLI build step or test runner — all development happens inside the Godot editor.

To launch the Godot editor via MCP: `mcp__godot__launch_editor`.

## Architecture

### Scene / Script Mapping

| Scene | Script | Role |
|---|---|---|
| `ui/main_menu.tscn` | `scripts/main_menu.gd` | Entry point; routes to Local Versus or Multiplayer lobby |
| `ui/lobby.tscn` | `scripts/lobby.gd` | ENet host/join UI; sets `GameState` multiplayer flags before loading `main.tscn` |
| `main.tscn` | `scripts/main.gd` | Core game loop; owns the hex grid, handles all action logic, economy, and win conditions |
| `scenes/cell.tscn` | `scripts/cell.gd` | Individual hex cell: state machine (type/level/owner), visual updates, 3D mesh |
| `ui/hud.tscn` | `scripts/hud.gd` | Turn/resource display and end-turn button |
| `ui/cell_panel.tscn` | `scripts/cell_panel.gd` | Context panel shown on cell click; emits action signals |

### Autoloads (Singletons)

- **`GameState`** (`scripts/game_state.gd`) — holds `players: Array[PlayerData]`, `current_player_index`, turn flags, and multiplayer identity (`is_multiplayer`, `is_host`, `my_peer_id`).
- **`Config`** (`scripts/config.gd`) — parses `config.json` at startup; all game balance values are accessed via `Config.get_value("section.key")`.
- **`ConsoleController`** — addon (`addons/ahhnold_console/`) providing an in-game debug console. Register commands with `ConsoleController.register_command(name, callable, description)`.

### Networking Layer

`scripts/game_net.gd` (child of `main.tscn`) decouples input from game logic:
- `handle_action(action, cell)` — in singleplayer calls the `_main` handler directly; in multiplayer, clients RPC to host which validates then broadcasts `_apply_*` RPCs to both peers.
- `handle_end_turn()` — same pattern for turn advancement.
- `is_input_blocked()` — returns `true` when it is not the local player's turn (multiplayer only).

### Game Logic (main.gd)

All game logic lives in `main.gd`. Key methods:
- `_can_occupy / _can_raze / _can_upgrade / _can_convert` — gate checks used both by the UI and by `game_net._dispatch` for server-side validation.
- `_apply_turn_effects(player_idx)` — runs economy: two-pass (non-residential first, then residential starvation check).
- `_tick_timers(player_idx)` — decrements raze cooldowns and upgrade cooldowns each turn.
- `_get_connected_positions(player_idx)` — BFS from starting base; only connected owned cells generate income.

### Configuration

All balance values live in `config.json` (flat key paths, dot-separated). Economy, occupation costs, raze costs, upgrade costs, convert costs, and camera settings are all data-driven. Player names, colors, and starting resources are also set here.

### Cell Model

`Cell` (extends `StaticBody3D`) tracks:
- `cell_type`: RESOURCE / INDUSTRY / RESIDENTIAL
- `cell_level`: 1–4 (type-dependent max)
- `owner_index`: index into `GameState.players` (-1 = unowned)
- `raze_turns_remaining`, `raze_player_index`: raze cooldown state
- `upgrade_cooldown`: turns until upgrade completes

Win conditions: occupying an enemy RESIDENTIAL cell triggers immediate game over; starvation (residential cells consuming resources the player can't afford) for `economy.starvation_turns_to_lose` consecutive turns also ends the game.
