# GEMINI.md: Project Context & Mandates

## Project Overview
**Mini Space Battle** is a 2D multiplayer space combat game developed using **Godot 4.6**. It features server-authoritative networking where one player acts as the host (server) and others join as clients. The game supports up to 6 active players with an automatic observer system for additional connections.

*   **Project Name:** Mini Space Battle (Godot 4.6)
*   **Core Logic:** GDScript-based, server-authoritative multiplayer.
*   **UI Strategy:** Programmatic construction via `main_ui.gd` (minimal use of Editor Scenes for UI).

## Technical Mandates
*   **Language:** Use GDScript exclusively. Exhaustive type-hinting is **mandatory** for all functions, variables, and signals.
*   **Naming Conventions:**
    *   **Files/Folders:** `snake_case` (e.g., `ship_navigation.gd`).
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
    *   `/scripts/`: Core logic, networking controllers, and service classes (typically `RefCounted`).
    *   `/entities/`: Reusable character/object scenes and their specific scripts/components.
    *   `res://`: Root contains the main scene (`main.tscn`) and project configuration (`project.godot`).

*   **Core Logic & Services**:
    - **`main.gd`**: The central orchestrator. Manages the game loop, physics synchronization via RPCs, custom rendering of the play area, and game rules (scoring, immunity, wrap-around).
    - **`connection_controller.gd`**: Handles the low-level ENet peer creation for hosting and joining.
    - **`main_ui.gd`**: Programmatically constructs the game's UI, including the control panel, player roster, and connection popups.
    - **`peer_roster_service.gd`**: Manages player identities, color assignments, and synchronization of the player list.
    - **`ip_info_service.gd`**: Fetches local and external IP addresses for connection sharing.
    - **`ship_navigation.gd`**: Encapsulates ship movement logic, including thrust, rotation, and screen-wrapping.

*   **Manual Rendering**: Game entities in the "Play Area" are rendered via `_draw()` calls in `main.gd` for coordinate wrapping/clipping.

## Specific Components
*   **`ShipNavigation`**: Physics and movement logic.
*   **`PeerRosterService`**: Identity and color management.
*   **`MainUi`**: Runtime UI generation.

## Development & Testing
*   **Main Scene:** `res://main.tscn`
*   **Prerequisites:** Godot Engine 4.6 or later.
*   **Running the Project**:
    1. Open Godot and import the project folder.
    2. Press `F5` to run the `main.tscn` scene.
    3. **To Host:** Click "Host". By default, it listens on port `56419`.
    4. **To Join:** Click "Join", enter the host's IP address (use `127.0.0.1` for local testing), and click "Connect".
*   **Multiplayer Testing:** Run multiple instances locally; use `127.0.0.1` for the join IP.
*   **Performance:** Favor signals for state changes; avoid polling in `_process` unless necessary for physics/rendering.

## Boundaries
*   Do not introduce C# or GDExtension.
*   Do not add external plugins/addons without explicit instruction.
*   Follow the "Programmatic UI" pattern established in `main_ui.gd` when adding new interface elements.

## Key Files
- `main.tscn`: The root scene.
- `project.godot`: Project configuration and input map.
- `scripts/main.gd`: Game logic and networking hub.
- `scripts/ship_navigation.gd`: Ship physics and movement.
- `scripts/main_ui.gd`: UI construction logic.
- `scripts/peer_roster_service.gd`: Player management.
- `scripts/connection_controller.gd`: Network connection handling.
