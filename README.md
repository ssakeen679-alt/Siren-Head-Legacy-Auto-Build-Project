# SIREN HEAD: LEGACY - Research & Building System Documentation

## Game Metadata
- **Game Title**: SIREN HEAD: LEGACY
- **Place ID**: `118734928855510`
- **Universe ID**: `10745315844`
- **Developer / Creator**: Middleways Studio (`CreatorId: 454007053`)
- **Place Version**: 230
- **Platform**: PC (Windows), Console (Gamepad), Mobile (Touch)

---

## 1. Building System Architecture

### DataModel Locations
- **Templates**: `ReplicatedStorage.builds`
- **Active Placed Structures**: `Workspace.builds`
- **Client Building Controller**: `Players.LocalPlayer.PlayerGui.build_gui.main`
- **Building Network Remotes**:
  - `ReplicatedStorage.remotes.build` (RemoteEvent: Request to place structure)
  - `ReplicatedStorage.remotes.delete` (RemoteEvent: Request to dismantle/relocate structure)
  - `ReplicatedStorage.remotes.save_setting` (RemoteEvent: Persist auto-snap and control preferences)

---

## 2. Structure Catalog & Properties

| Structure | Cost (Score) | Primary Part | Description & Special Features |
| :--- | :--- | :--- | :--- |
| **Wall** | Free ($0) | `build_root` | Standard 10-stud wide by 9-stud high barrier; snaps horizontally, vertically, and as flat floors/ceilings. |
| **Window Wall** | Free ($0) | `build_root` | Wall structure with framed glass panes allowing visibility and shooting angles. |
| **Door** | Free ($0) | `build_root` | Interactive door with prompt on `leaf.slab.prompt`. Rotates on hinge (`open_angle: 100`). |
| **Wood Barricade** | Free ($0) | `build_root` | Low barricade obstacle designed to obstruct and delay entities. |
| **Fence** | Free ($0) | `build_root` | Modular perimeter picket fence with posts and caps (52 parts). |
| **Ladder** | Free ($0) | `build_root` | 11-stud vertical climbing structure. Snaps to wall surfaces and stacks vertically. |
| **Table** | Free ($0) | `build_root` | Interior/exterior barricade piece. |
| **Chair** | Free ($0) | `build_root` | Seating entity. Self-disables if rotated past 1 degree tilt to prevent invalid states. |
| **Lantern** | Free ($0) | `build_root` | Portable dynamic point light source with interaction prompt on `bulb.prompt`. |
| **Flood Light** | Free ($0) | `build_root` | High-intensity directional area illumination. |
| **Basic Turret** | 200 Score | `build_root` | Autonomous defense sentry equipped with server targeting script and `fire_point`. |

---

## 3. Placement Mechanics & Controls

### Ghost Preview
- Uses `_G.ghost` as a client-side replica of the target template model with `Transparency += 0.5`.
- A 3D axis gizmo (`ReplicatedStorage.rotate_gizmo`) attaches to the preview root showing colored axes (Red = X, Green = Y, Blue = Z).
- Raycasts along the camera's look vector up to placement distance (clamped between 4 and 16 studs).
- Boundary Validation: Parts tagged `CollectionService:GetTagged("no_build")` within proximity turn the ghost red (`Color3.fromRGB(190, 60, 60)`) and reject placement. Valid spots show green (`Color3.fromRGB(0, 255, 0)`).

### Modular Snapping Engine (`snap_slots`)
- **Horizontal**: Snaps at `(±10, 0, 0)` relative to adjacent walls.
- **Vertical**: Snaps at `(0, ±9, 0)` for multi-floor structures.
- **Corners**: Rotates 90° (`π/2`) at `(±5, 0, ±5)` to create square enclosures.
- **Floors / Ceilings**: When pitched horizontally, walls snap to create flat platforms.
- **Ladders**: Snaps vertically at `(0, ±11, 0)` or mounts to wall faces at `(0, 1, ±0.65)`.
- **Anti-Overlap**: Prevents placement if another structure's root exists within 1.5 studs (`slot_taken`).

### Controls

| Action | PC Keyboard/Mouse | Console Gamepad | Mobile Touch |
| :--- | :--- | :--- | :--- |
| **Place Structure** | `E` | `ButtonB` | `Place` Context Button |
| **Rotate 45°** | `R` | `ButtonY` | `Rotate` Context Button |
| **Select Axis (X, Y, Z)** | `1`, `2`, `3` | `DPadLeft` / `DPadRight` | UI Buttons (`x`, `y`, `z`) |
| **Reset Rotation** | `F` | `ButtonX` | UI Button (`reset`) |
| **Toggle Auto-Snap** | `T` | `DPadDown` | UI Button (`auto_snap`) |
| **Adjust Distance** | Mouse Scroll Wheel | `ButtonL2` / `ButtonR2` | `Near` / `Far` UI Buttons |
| **Move Structure** | Hold `E` (aimed at build) | Hold `Circle` / `ButtonB` | Hold `Edit` Button |

---

## 4. Dismantle & Relocation System
- Aiming at any owned structure in `workspace.builds` within 10 studs (when not holding a Repair Hammer) displays `Hold [E] to move.`
- Holding `E` fills a circular progress bar.
- Upon completion, `Delete:FireServer(structure)` removes the placed instance and immediately enters placement mode (`start_build`) with the template and orientation preserved, allowing free repositioning.

---

## 5. Construction Animation & Network Events
- **Place Remote**: `ReplicatedStorage.remotes.build:FireServer(structureName, targetCFrame)`
- **Dismantle Remote**: `ReplicatedStorage.remotes.delete:FireServer(modelInstance)`
- **Client Assembly Effect**: `Build.OnClientEvent` triggers `assemble_build(model)`:
  - Disassembles parts, sinks them 1.3 studs, shrinks them to 78% scale, and plays a staggered pop-in animation using `Quint` and `Back` easing styles.
  - Applies a temporary neon highlight that fades out over 1 second.
