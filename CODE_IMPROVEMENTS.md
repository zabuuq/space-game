I have completed an initial investigation of the codebase and found several excellent opportunities for improvement, optimization, and bug prevention. 

Here is a summary of my findings:

### 1. Godot-Specific Optimizations
*   **World Rendering & Scaling:** `main.gd` manually calculates scale and position to fit the game world into the UI. This can be optimized by using a `SubViewportContainer` and `SubViewport`, allowing Godot to handle internal resolution and aspect-ratio automatically.
*   **Collision Detection:** The `_server_rule_checks` function in `main.gd` performs manual point-in-polygon math for every projectile against every ship. Using Godot's built-in physics (`Area2D` and `CollisionPolygon2D`) would offload this to the highly optimized C++ engine, significantly improving performance as entity counts grow.
*   **Starfield Rendering:** `starfield.gd` currently draws over 150 individual rectangles 9 times per frame to create the wrap-around effect. This is highly inefficient. We can replace this with a single `ColorRect` using a simple Starfield Shader or by using a `ParallaxBackground`.
*   **Screen Wrapping Logic:** The logic to draw entities 9 times for the seamless edge-wrapping effect is duplicated across `Ship`, `Projectile`, and `Starfield`. This should be abstracted into a shared utility or handled entirely via a screen-space shader.

### 2. Potential Bugs & Refinements
*   **RPC Flooding (Network Spike):** In `main_ui.gd` / `main.gd`, it appears that changing the player name triggers a network update on every single keystroke. This should be debounced or only sent when the user finishes typing (e.g., triggering on `text_submitted` or focus lost) to prevent network flooding.
*   **Hardcoded Constants:** The `_get_hit_ship` function uses hardcoded collision values (e.g., `16.5`, `3.0`). If the ship's visual asset changes, the collision will silently break. These should be tied directly to the entity's properties.
*   **"God Object" Architecture:** `main.gd` handles a massive amount of logic, from game loop and world scaling to slot offers and team management. We could refactor slot and team logic into a dedicated `SessionManager` node to improve maintainability.

### 3. Duplicated Variables
*   **`SHIP_HIT_RADIUS` Duplication:** A constant representing the ship's hit radius is defined in both `main.gd` and `ship.gd`, which could easily lead to a desync if one is updated without the other.

---

### Suggested Tasks List
Based on these findings, we could add any of the following to our task list:

1.  **Optimize World Rendering:** Refactor the game view to use `SubViewport`.
2.  **Optimize Collisions:** Replace manual collision math with Godot's `Area2D` physics system.
3.  **Optimize Starfield:** Rewrite the starfield to use a custom Shader or Parallax node instead of manual drawing.
4.  **Abstract Wrap Logic:** Create a shared utility or shader for the Asteroids-style screen wrapping.
5.  **Fix RPC Flooding:** Debounce the player name input so it only sends updates on submit/unfocus.
6.  **Clean up Constants & Architecture:** Consolidate duplicated constants like `SHIP_HIT_RADIUS` and begin breaking `main.gd` logic into smaller managers.
