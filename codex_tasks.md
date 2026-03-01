# Network Test App

## Tasks

1. Default the window to full screen when the demo is loaded.
2. Remove the IP and port fields.
  * Default to port `56419`.
  * Show a pop-up window with an IP field and a `Connect` button when the `Join` button is clicked.
    * Close the pop-up window when the `Connect` button is clicked.
    * Use the IP provided and the default port `56419` to connect to the host.
3. Change the `Host` and `Join` buttons to a single `Disconnect` button after the user hosts or joins.
  * When a host disconnects, all clients should be disconnected too.
  * When a client disconnects, only they should be disconnected, not all clients.
  * Status should change to "Not connected" in their local display when the user disconnects.

4. Add a quit button that closes the "game."

5. Divide the window vertically into two sections.
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

6. Update the program to have an icon (ship) that moves around the screen.
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
    * Maximum speed of the ship should be equivalent to 50 pixels per second or the total length of the ship icon.
    * Increment 1 pixel per second at a time.
  * Movement constraints:
    * The right section of the window (as defined in task #5) is the field of play.
      * T
  * Pass the location that the dot is in the screen to the clients and update their display of the dot accordingly.
    * Make sure to 
  * 

## Notes
* Make sure to update the appropriate documentation when you make changes.
* Make sure `README.md` properly explains the program when changes are made.
  * You do not need to include a summary of the changes made, just make sure it still properly describes the "game."
  * If `README.md` already properly describes the "game," do not make any unecessary changes to it.
* Do not compile the Godot code. I will handle this.