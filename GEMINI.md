# GEMINI.md: Project Context & Mandates

## Project Overview
**Mini Space Battle** is a 2D multiplayer space combat game developed using **Godot 4.6**. It features server-authoritative networking where one player acts as the host (server) and others join as clients. The game supports up to 6 active players with an automatic observer system for additional connections.

*   **Project Name:** Mini Space Battle (Godot 4.6)
*   **Core Logic:** GDScript-based, server-authoritative multiplayer.
*   **Visual Aesthetic:** Minimalist 8-bit style using manual `_draw()` calls for ships and projectiles.
*   **UI Strategy:** Godot Editor native UI (`Control` nodes) for maximum layout performance and ease of maintenance.
*   **Networking Strategy:** Native Godot 4 Multiplayer nodes (`MultiplayerSpawner`, `MultiplayerSynchronizer`) preferred over manual RPC state synchronization.

## Technical Mandates
*   **Language:** Use GDScript exclusively. Exhaustive type-hinting is **mandatory** for all functions, variables, and signals.
*   **Naming Conventions:**
    *   **Files/Folders:** `snake_case` (e.g., `ship.tscn`, `ship.gd`).
    *   **Classes:** `PascalCase` (e.g., `ShipNavigation`).
    *   **Functions/Variables:** `snake_case` (e.g., `update_thrust()`).
*   **Node References:** Use `@onready` with unique node names (`%UniqueName`) or typed variables. Avoid deep paths like `$A/B/C`.
*   **Signals:** Use typed signals: `signal health_changed(new_value: int)`.
*   **Composition:** Prefer composition and small reusable components over deep inheritance.

## Project Architecture
*   **Root Directories**:
    *   `/addons/`: For third-party plugins.
    *   `/assets/`: General assets (images, sounds, etc.).
    *   `/demos/`: Compiled executables and packages for testing.
    *   `/scenes/`: Main game scenes.
    *   `/scripts/`: Core logic, networking controllers, and service classes.
    *   `/entities/`: Reusable character/object scenes (`.tscn`) and their specific scripts/components.
    *   `res://`: Root contains the main scene (`main.tscn`) and project configuration (`project.godot`).

*   **Core Logic & Services**:
    - **`main.gd`**: The central orchestrator. Manages the game loop, game rules (scoring, immunity, wrap-around).
    - **`connection_controller.gd`**: Handles the low-level ENet peer creation for hosting and joining.
    - **`main_ui.tscn` / `main_ui.gd`**: The game's UI, including the control panel, player roster, and connection popups.
    - **`peer_roster_service.gd`**: Manages player identities, color assignments, and synchronization of the player list.
    - **`ip_info_service.gd`**: Fetches local and external IP addresses for connection sharing.
    - **`ship.gd`**: The ship entity, extending `CharacterBody2D` (or similar node), utilizing `_draw()` for its visual representation to maintain the 8-bit aesthetic.

*   **Manual Rendering for Aesthetic**: To maintain the old-school 8-bit feel, game entities like Ships and Projectiles must be visually rendered using `_draw()` overrides on their respective nodes. Do not use Sprite2D nodes unless strictly necessary for performance.

*   **Entity Nodes**: Entities like ships should be real Godot Nodes (e.g., `CharacterBody2D`) instantiated into the Scene Tree to leverage Godot's built-in physics (if needed), transform hierarchies, and the high-level multiplayer API.

## Specific Components
*   **`Ship`**: The main ship node/scene (`entities/ship/ship.tscn`).
*   **`PeerRosterService`**: Identity and color management.
*   **`MainUi`**: UI layout and logic.

## Development & Testing
*   **Main Scene:** `res://main.tscn`
*   **Prerequisites:** Godot Engine 4.6 or later.
*   **Running the Project**:
    1. Open Godot and import the project folder.
    2. Press `F5` to run the `main.tscn` scene.
    3. **To Host:** Click "Host". By default, it listens on port `56419`.
    4. **To Join:** Click "Join", enter the host's IP address (use `127.0.0.1` for local testing), and click "Connect".
*   **Multiplayer Testing:** Run multiple instances locally; use `127.0.0.1` for the join IP.
*   **Automated Testing:** 
    *   The project uses the **GUT (Godot Unit Test)** framework.
    *   All tests must be placed in the `/tests/` directory and prefixed with `test_` (e.g., `test_peer_roster_service.gd`).
    *   When implementing new pure data structures, math functions, or isolated logic, corresponding GUT unit tests should be created.
    *   Run tests headlessly by executing the `test_runner.tscn` scene.
*   **Performance:** Favor signals for state changes; avoid polling in `_process` unless necessary for physics/rendering. Use `MultiplayerSynchronizer` to efficiently sync node states.

## Boundaries
*   Do not introduce C# or GDExtension.
*   Do not add external plugins/addons without explicit instruction.
*   **UI:** Transition away from programmatic UI; rely on the Godot Editor to build standard `Control` layouts.
*   **Networking:** Transition away from heavy, manual `@rpc` synchronization in `main.gd`; favor `MultiplayerSpawner` and `MultiplayerSynchronizer` nodes.
*   **Aesthetics:** Retain manual `_draw()` calls for game entities.

## Key Files
- `main.tscn`: The root scene.
- `project.godot`: Project configuration and input map.
- `scripts/main.gd`: Game logic orchestrator.
- `entities/ship/ship.tscn`: Ship entity scene.
- `scenes/main_ui.tscn`: Main UI scene.
- `scripts/peer_roster_service.gd`: Player management.
- `scripts/connection_controller.gd`: Network connection handling.
