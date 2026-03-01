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
- The left panel shows local/external IP, port, controls, connection status, instructions, and the host/client IP roster.
  - Roster format is `[internal_ip]/[external_ip]`.
  - Host is listed first in bold; clients follow in connection order.
- Everyone sees the same symbol centered in the right section.
- It starts as a dot.
- When the **host** holds **W/A/S/D** keys, the dot becomes an arrow pointing in that direction on every connected machine. Releasing the key returns the shared symbol to a dot.

## Run

1. Open this folder as a Godot project.
2. Run the main scene.
3. On one machine, click **Host** (port `56419`).
4. On other machines, click **Join**, enter the host IP, then click **Connect**.
5. Hold **W/A/S/D** on the host to broadcast direction updates, then release to reset to the dot.
6. Click **Disconnect** to leave the session and return local status to `Not connected`.
7. Click **Quit** to close the game.
