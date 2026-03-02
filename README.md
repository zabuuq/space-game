# space-game

Simple Godot 4 multiplayer demo using GDScript.

## What it does

- The window starts in full screen.
- One computer can host on port `56419`.
- Other computers can join by clicking **Join**, entering the host IP in a pop-up, and clicking **Connect**.
- After hosting or joining, **Host** and **Join** are replaced with **Disconnect**.
- Clicking **Disconnect** disconnects only that local user.
  - If the host disconnects, all connected clients are disconnected.
- A **Quit** button closes the game window.
- The window is split vertically:
  - Left quarter: dark gray control panel
  - Right three-quarters: black play area
- The left panel shows local/external IP, port, name entry, controls, connection status, instructions, and the host/client roster.
  - If a player has entered a name, the roster shows that name; otherwise it shows `[internal_ip]/[external_ip]`.
  - Roster order remains host first, then clients in connection order.
- Up to six players can control ships at once.
  - Additional connected peers are observers and show `Connection Status: Observer`.
  - If a controlling client disconnects, the next observer in queue takes over that ship, and the ship resets to its starting position.
- Each controlled ship has a unique color.
- Player roster entries are color-matched to controlled ship color.
  - Each user sees only their own roster line in bold on their local instance.
- Ship starting slots use a `3 x 2` grid in this order:
  - Player 1 (host): upper left
  - Player 2: upper right
  - Player 3: lower right
  - Player 4: lower left
  - Player 5: upper middle
  - Player 6: lower middle
- A connected controller can fly their own ship with:
  - `W` increase speed
  - `S` decrease speed
  - `A` turn counter-clockwise
  - `D` turn clockwise
  - `X` full stop
- Ships only appear for connected controllers (host starts with ship after hosting).
- Ships wrap around the field of play in the right section.
- Ship position/rotation/speed is synchronized from host/server to all clients.

## Run

1. Open this folder as a Godot project.
2. Run the main scene.
3. On one machine, click **Host** (port `56419`).
4. On other machines, click **Join**, enter the host IP, then click **Connect**.
5. Control your assigned ship with **W/A/S/D** and **X**.
6. Connect more than six peers to see observer mode and automatic observer promotion when a controller disconnects.
7. Click **Disconnect** to leave the session.
8. Click **Quit** to close the game.
