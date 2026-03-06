# Network Test App

## Tasks

- [x] 1. Default the window to full screen when the demo is loaded.
- [x] 2. Remove the IP and port fields.
  * Default to port `56419`.
  * Show a pop-up window with an IP field and a `Connect` button when the `Join` button is clicked.
    * Close the pop-up window when the `Connect` button is clicked.
    * Use the IP provided and the default port `56419` to connect to the host.
- [x] 3. Change the `Host` and `Join` buttons to a single `Disconnect` button after the user hosts or joins.
  * When a host disconnects, all clients should be disconnected too.
  * When a client disconnects, only they should be disconnected, not all clients.
  * Status should change to "Not connected" in their local display when the user disconnects.

- [x] 4. Add a quit button that closes the "game."

- [x] 5. Divide the window vertically into two sections.
  * Left section:
    * Background: dark gray
    * Size: One quarter of the window
    * Display items:
      * `Quit` button
      * Computer's local IP address
      * Computer's external IP address
      * Port: 56419
      * `Host` and `Join` buttons
      * Connection Status
      * Instructions
        * "Host can press W/A/S/D keys to display directional arrow."
      * List the internal/external IP addresses of host and everyone connected to host.
        * No labels are needed, just the IP addresses like this: [internal_ip]/[external_ip]
        * Always display the host first and make it bold. No other labels needed.
        * Display clients in the order they connected.
  * Right section:
    * Background: black
    * Size: Three quarters of the window
    * Display item:
      * The directional "dot," centered in the right section.

- [x] 6. Update the program to have an icon (ship) that moves around the screen.
  * Ship design specs:
    * It should be triangular in shape, similar to the ship icon of the game Asteroids.
      * Use these dot coordinates as a guide:
        * (0,24) - forward "nose" point
        * (18,-24) - back right "wing" point
        * (0,-18) - back middle "engine" point
        * (-18,-24) - left back "wing" point
        * then connect back to the forward "nose" point
  * Ship movement:
    * `A` rotates the ship counter-clockwise.
    * `D` rotates the ship clockwise.
    * `W` increases the ship's speed.
    * `S` decreases the ship's speed.
    * Minimum speed of the ship is 0 pixels per second, or no movement. The ship cannot go backwards.
    * Maximum speed of the ship should be equivalent to 200 pixels per second.
    * Increment 28 pixel per second at a time.
  * Movement constraints:
    * The right section of the window is the field of play.
      * When the ship reaches an edge of the field of play it should continue to the opposite edge of the field.
        * This should act similar to the game of Asteroids where the ship crosses from one side to the other.
        * Make sure it is a smooth transition from one side to the other. The ship will be partially visible on both sides as it passes across the edge of the field of play until it is completely crossed.
  * Host/Client requirements:
    * Pass the ships location and direction to the clients' applications.
    * The client application should render the ship icon based on the information shared.
    * Be sure to keep screen size and resolution in mind when displaying the ship on the client screens. Everyone should see the ship in the same relative location on their respective screens.

- [x] 7. Make the game a multiplayer game with multiple ships.
  * Allow a maximum of six ships.
    * Connections beyond six players are allowed, but will be observers only.
      * If connected as an observer, the Connection status should read "Observer."
    * If a client who is controlling a ship disconnects, the next observer in line will take over the ship.
      * When this happens, the ship should reset to its starting position.
  * A client controlled ship should not appear until the client connects.
    * The ship should be visible and controllable by that client as soon as they join.
  * The host can still control their ship as soon as they start hosting.
  * Ship starting positions:
    * Player 1 (host): upper left
    * Player 2 (client): upper right
    * Player 3 (client): lower right
    * Player 4 (client): lower left
    * Player 5 (client): upper middle
    * Player 6 (client): lower middle
    * Imagine the space broken into a 3 x 2 grid and have each ship start in the center of that grid's space.

- [x] 8. Add the ability to shoot
  * Space bar fires a small projectile represented by a dot.
  * The projectile should only travel the equivalent of a quarter of the world-space before disappearing.
  * The speed of the projectile should be a little faster than the maximum ship speed.

- [x] 9. Allow continuous fire when the spacebar is held down.
  * Add a brief pause in between shots so it is not a solid stream of projectiles.

- [x] 10. Allow ships to get hit with projectiles.
  * If a ship is hit by a projectile, reset it to its starting position.
  * Add a points system.
    * Give a point to the player whose projectile hit the ship.
      * Do not award a point if the player is hit by one of their own projectiles.
    * Display the score to the right of the player's name.
      * Justify the score to the right of the left panel section with some padding on the right.
  * There is no need for an end of game scoring goal. Allow the scores to continue to increment without a cap.
  * Remember a person's score if they disconnect and reconnect to the same session.
    * Reset all scores to zero when host starts hosting.

- [x] 11. Update connection process
  * There should be checks in place to not mark a client as connected until they are actually connected to a host.       
  * Should also make sure the host is actually hosting and not just running the program.
  * The connection status should read "Connecting" while trying to connect.
    * To show action, add periods after the "Connecting"
      * Add one period at a time up to five periods and then start over.
      * Add slight pauses between adding periods.
  * If a client fails to connect to a host, the connection status should read "Failed to Connect"
    * The client app should attempt to connect three times before failing to connect.

- [x] 12. Refactor the Ship into a Scene (`entities/ship/ship.tscn`)
  * Create a dedicated `ship.tscn` scene with a `CharacterBody2D` (or `Area2D`/`Node2D`) root.
  * Move the `_draw()` logic out of `main.gd` and directly into the new `ship.gd` script.
  * Move the physics and screen-wrapping logic directly into the ship's `_physics_process()`.

- [x] 13. Transition Networking to `MultiplayerSpawner` and `MultiplayerSynchronizer`
  * Add a `MultiplayerSynchronizer` node to the new `ship.tscn` to automatically replicate the ship's `position`, `rotation`, and `speed` from the server to the clients.
  * Add a `MultiplayerSpawner` node to `main.tscn`. When a player joins, the server instantiates `ship.tscn`, assigns it to the player, and adds it to the tree. The Spawner automatically replicates that node to all clients.

- [x] 14. Refactor Projectiles into Node Entities
  * Create a `projectile.tscn` scene with its own `_draw()` method to maintain the 8-bit look.
  * Use a `MultiplayerSpawner` to handle projectile instantiation across the network.

- [x] 15. Rebuild the UI Visually (`scenes/main_ui.tscn`)
  * Build the UI visually in the Godot Editor using a `.tscn` file.
  * Update `main_ui.gd` to use `@onready` variables to reference the visual nodes created in the editor.

- [x] 16. Decouple `main.gd`
  * Remove physics updates, networking RPCs, and entity drawing loops.
  * Reduce `main.gd` to its proper role as the game rule orchestrator (handling score, tracking who is in the game, and managing the initial server start/join commands).

## Notes
* Make sure to update the appropriate documentation when you make changes.
* Make sure `README.md` properly explains the program when changes are made.
  * You do not need to include a summary of the changes made, just make sure it still properly describes the "game."     
  * If `README.md` already properly describes the "game," do not make any unecessary changes to it.
* Do not compile the Godot code. I will handle this.
