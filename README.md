# space-game

Simple Godot 4 multiplayer demo using GDScript.

## What it does

- One computer can host on a port.
- Other computers can connect by entering the host IP + port.
- Everyone sees the same symbol in the center of the screen.
- It starts as a dot.
- When the **host** holds **W/A/S/D**, the dot becomes an arrow pointing in that direction on every connected machine. Releasing the key returns the shared symbol to a dot.

## Run

1. Open this folder as a Godot project.
2. Run the main scene.
3. On one machine, enter a port and click **Host**.
4. On other machines, enter the host IP + port and click **Join**.
5. Hold **W/A/S/D** on the host to broadcast direction updates, then release to reset to the dot.
