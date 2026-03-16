# Task List

## To Do

## In Progress

## Done

- [x] 1. Default the window to full screen.
- [x] 2. Remove IP/port fields, default port to 56419, add connect popup.
- [x] 3. Consolidate host/join to a single disconnect button.
- [x] 4. Add quit button.
- [x] 5. Split window vertically into left/right sections with UI layout.
- [x] 6. Implement moving, screen-wrapping Asteroids-style ship icon.
- [x] 7. Add multiplayer with up to 6 ships and observer system.
- [x] 8. Add spacebar shooting with projectiles.
- [x] 9. Allow continuous fire with brief pause.
- [x] 10. Implement projectile collision, reset, and scoring system.
- [x] 11. Refine connection process with visual connecting state and retries.
- [x] 12. Refactor Ship into a dedicated scene.
- [x] 13. Transition networking to MultiplayerSpawner and MultiplayerSynchronizer.
- [x] 14. Refactor Projectiles into node entities.
- [x] 15. Rebuild UI visually in the Godot Editor.
- [x] 16. Decouple main.gd to pure game rule orchestrator.
- [x] 17. Fix Visual Screen-Wrap Glitch in Ship by un-rotating drawing offsets.
- [x] 18. Optimize O(P * N) Collision Checks by caching active entities in main.gd.
- [x] 19. Remove Unnecessary queue_redraw() Calls from ship and projectile process loops.
- [x] 20. Clean Up Dead Code by deleting the unused apply_network_state() function from ship.gd.
- [x] 21. Halve initial rendering size of ships/projectiles.
- [x] 22. Renamed Instructions to Ship Controls and added Turret Controls section.
- [x] 23. Implemented visual Turret on the Ship, absolute rotation logic, and firing mechanics.
- [x] 24. Implemented Roster UI and Team State Management
- [x] 25. Phase 4: Gameplay Integration for Pilot/Operator effects
- [x] 26. Phase 5: Scoring and Respawning Updates for Teams
- [x] 27. Observer Options
- [x] 28. Add a settings popup when hosting to choose play area size (Small vs Large) and an edge wrap toggle.
- [x] 29. Implement Camera2D logic to center on the player's ship (or the operator's attached ship) when using the Large play area.
- [x] 30. Implement edge wrapping logic updates based on toggle.
- [x] 31. Add scattered starfield background.
- [x] 32. Implement seamless visual wrapping by drawing duplicates of players/objects on opposite edges.
- [x] 33. Create off-screen pointer UI icons for other players matching team colors.
- [x] 34. Optimize World Rendering: Refactor the game view to use `SubViewport`.
- [x] 35. Optimize Collisions: Replace manual collision math with Godot's `Area2D` physics system.
- [x] 36. Optimize Starfield: Rewrite the starfield to use a custom Shader or Parallax node instead of manual drawing.
- [x] 39. Clean up Constants & Architecture: Consolidate duplicated constants like `SHIP_HIT_RADIUS` and begin breaking `main.gd` logic into smaller managers.
- [x] 37. Abstract Wrap Logic: Create a shared utility for Asteroids-style screen wrapping.
- [x] 38. Fix RPC Flooding: Debounce player name input to only update on submit or focus loss.
- [x] 40. Unified Ship Colors: Operators inherit pilot color and update with pilot; get next available when leaving.
- [x] 41. Reserved Observer Color: Reserved white exclusively for observers.
- [x] 42. Team Scoring: Award point to both the Pilot and the Operator when a kill is achieved by either.
- [x] 43. Expanded Controls: Added arrow keys support for ship and turret movement.
- [x] 44. Square Large Map: Updated the Large play area dimensions to a 4800x4800 square arena.
- [x] 45. Create an Obstacle entity (Asteroid style using manual `_draw()`) that is solid and indestructible.
- [x] 46. Implement collision handling so obstacles stop projectiles and bring ships to a dead stop on impact, without causing damage.
- [x] 47. Implement a randomized Obstacle Spawner that populates the map with obstacles only when the "Large" play area is selected.

## Notes

- When you mark a task as finished, update it to a one line summary and add it to the end of the `## Done` list.
