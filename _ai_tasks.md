# Network Test App

## Tasks

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

- [ ] 17. Fix Visual Screen-Wrap Glitch in `Ship`
  * Un-rotate the drawing offsets in `entities/ship/ship.gd`'s `_draw()` method so ghost ships wrap correctly along world axes rather than the ship's facing direction.

- [ ] 18. Optimize `O(P * N)` Collision Checks
  * Refactor `_server_rule_checks()` in `main.gd` to fetch active ships and projectiles once per frame instead of scanning the node tree for every projectile.

- [ ] 19. Remove Unnecessary `queue_redraw()` Calls
  * Remove unconditional `queue_redraw()` calls from `_physics_process` and `_process` in `ship.gd` and `projectile.gd` to save CPU overhead. Node position changes update visuals automatically.

- [ ] 20. Clean Up Dead Code
  * Delete the unused `apply_network_state()` function from `ship.gd` since state replication is handled by `MultiplayerSynchronizer`.

- [ ] 21. Clean Up Orphaned Test Metadata
  * Restore the missing `.gd` test files in the `tests/` directory or delete the lingering `.gd.uid` files.

## Notes
* Make sure to update the appropriate documentation when you make changes.
* Make sure `README.md` properly explains the program when changes are made.
  * You do not need to include a summary of the changes made, just make sure it still properly describes the "game."
  * If `README.md` already properly describes the "game," do not make any unecessary changes to it.
* Do not compile the Godot code. I will handle this.
