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
- [x] 17. Fix Visual Screen-Wrap Glitch in Ship by un-rotating drawing offsets.
- [x] 18. Optimize O(P * N) Collision Checks by caching active entities in main.gd.
- [x] 19. Remove Unnecessary queue_redraw() Calls from ship and projectile process loops.
- [x] 20. Clean Up Dead Code by deleting the unused apply_network_state() function from ship.gd.
- [x] 21. Halve initial rendering size of ships/projectiles.

- [ ] 22. Phase 1: UI and Instructions Updates
  - Change the label of the "Instructions" section to "Ship Controls".
  - Add a section after it labelled "Turret Controls" and display the turret controls there.
  - Ensure both sets of control instructions are always visible regardless of whether the player is in a turret or not.

- [ ] 23. Phase 2: Implement visual Turret on the Ship, inputs, and firing mechanics
  - Add a small circle with a line extending from it centered on the ship.
  - Implement Turret controls (`A`, `D`, `Space`) for the operator. The pilot cannot control the turret.
  - The operator cannot control the ship's speed, direction, or ship firing.
  - Ensure the Turret rotates relative to the screen (not the ship's rotation) and can rotate a full 360 degrees.
  - Set Turret turning speed to 50% of the normal ship turn rate, and firing rate to 50% of normal ship firing rate.
  - Ensure the Turret has no separate collision hitbox, and its projectiles cannot hit its own ship from the inside.
  - Make the turret in a way that it can be hidden on the ship.
    - In task #25, turrets will only appear when a team is formed.
    - For now, they should always be visible for testing purposes.

- [ ] 24. Phase 3: Roster UI and Team State Management
  - Add a small "Join" button to the left of each player's name in the roster.
  - Add logic to ask for confirmation when a player joins or leaves a team.
  - Enforce team constraints: Max 2 players (1 pilot, 1 operator). A player must leave their current team before teaming up with another.
  - Update Roster buttons based on team state:
    - Pilot sees "Kick" (visible only to pilot). When clicked, the operator is removed from the team.
    - Operator sees "Leave" (visible only to operator). When clicked, they leave the team.
    - The teammate's button changes to "Team" and is unclickable.
    - Non-teammate's buttons change to "Locked" and are unclickable.
    - All players not a team see "Locked" for buttons of members in a team and they are unclickable.
    - When a team is disbanded, buttons revert to their default "Join" state.
  - This task is only for team state management. Task #25 will ensure turret and turret ship operations and visibility.

- [ ] 25. Phase 4: Gameplay Integration (Pilot/Operator effects)
  - When a team forms: Remove the turret operator's old ship from play, if they have one, assign Turret control to operator, assign Ship control to pilot.
    - Forfeit their ship slot, allowing observers to operate a ship.
  - Update turret to only display on a ship when the ship has a turret operator.
  - Set Turret color to match the operator's color, and Ship color to match the pilot's color.
  - Give the pilot's ship a temporary immunity phase.
  - Apply pilot ship debuffs: Reduce acceleration rate by 75% (keep max speed the same), reduce turning speed by 50%, reduce firing rate by 50%.
  - When a team ends (kicked or left):
    - Remove the turret and restore the pilot's ship stats to normal. Give the pilot's ship a temporary immunity phase.
    - Respawn the operator's ship at their starting point with respawn immunity. If there are no empty ship slots, the operator becomes an observer.
  - Allow observers to join as turret operators.
  - Ensure task #23 turret operations work for turret operators.

- [ ] 26. Phase 5: Scoring and Respawning Updates
  - Update scoring: No one loses points in the game under any circumstances.
    - This should already be the case, but ensure it is and update if it is not.
  - If a player shoots a teamed ship, they should get two points instead of one.
  - When a teamed ship is destroyed, the team stays together and the ship respawns at the pilot's respawn location.

- [ ] 27. Observer Options
  - When an empty slot opens up, the first observer in the list should be given a pop-up option to have a ship.
    - The pop-up should ask the player if they want to operate a ship and have a ten-second countdown.
    - If they do not answer after ten seconds or if they choose no, they should drop to the end of the observer list.
    - If they choose yes, they should be given a ship and spawn at that ship's default location.
  - If all observers decline to operate a ship, all observers should see an [Empty Ship] with a "Join" button. Joining will be, first come, first serve at that point.
    - If someone takes the last available empty slot, by either joining the game or clicking the "Join" button on the empty slot, that option should go away for all observers and the logic should revert to the pop-up when a new empty slot opens.

## Notes

- When you mark a task as finished, update it to a one line summary and group it with the finished tasks.
