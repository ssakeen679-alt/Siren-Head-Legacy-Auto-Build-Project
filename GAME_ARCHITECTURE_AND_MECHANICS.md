# SIREN HEAD: LEGACY - Comprehensive Master Architecture & Systems Documentation

## 1. Executive Summary & Design Overview
- **Title**: SIREN HEAD: LEGACY
- **Genre**: Asymmetrical Multiplayer Survival Horror / Defense Sandbox
- **Core Game Loop**:
  1. **Scavenge & Forage**: Survivors spawn at dusk across scattered safehouses. They loot 189 supply crates for ammo/scrap, pick berry bushes to manage hunger, and loot bank vaults for score.
  2. **Fortify**: Players use the modular building system to board up windows, erect multi-level wall defenses, barricade choke points, set up lighting (lanterns/flood lights), and deploy automated sentries ($200 Basic Turrets).
  3. **Combat & Survive**: As night progresses, monsters (Siren Head, Cartoon Cat, Mega Horn, Long Horse) stalk survivors using active abilities, environmental destruction, and dimension shifts (Dreamscape). Survivors defend using 11 firearms with procedural aim/recoil mechanics.
  4. **Extraction / Dawn**: Survive until `workspace.time_left` reaches 0 to win the round (`workspace.Win = true`).

---

## 2. World Hierarchy & Map Layout

### Objectives & Safehouses (`workspace.objectives`)
- **Mystery Shack**: Forest lodge with multiple defensive entry points.
- **Mansion**: Large multi-story stronghold with extensive window placement opportunities.
- **Barn**: Agricultural outpost with open floor plan and high rafters.
- **House**: Standard suburban bunker. Features dynamic indoor ambient dimming via ceiling raycasts (`world_handler`).
- **Tree**: Colossal central landmark in the dense wilderness.
- **Watchtowers (`workspace.towers`)**: 10 elevated sniper platforms scattered around the perimeter, accessible via ladder snapping.

### Environmental & Interactive Elements
- **Crates (`workspace.crates`)**: 189 loot containers requiring a 1-second interaction hold to receive random rewards.
- **Harvest (`workspace.harvest.berry`)**: 41 foraging nodes requiring a 2-second hold to replenish player hunger.
- **Money Vaults (`workspace.money`)**:
  - `vault` ($500)
  - `vault2` ($1000)
  - `vault3` ($1500)
- **Combat Drones (`workspace.combat_drone`)**: Automated flying combat escorts with prompt activation.
- **Dream Dimension (`dream_tp`, `dream_box`, `long_horse_tp`)**: Sub-level realm used when Long Horse pulls survivors into the dream state, altering ambient lighting to pitch black (`Haze = 10`) and playing custom narration.

---

## 3. Survivor Systems & Mechanics

### Hunger & Vitality (`PlayerGui.survival.Main`)
- `stats.hunger`: Drains continuously. Reaching 0 depletes health.
- `blood_overlay`: Dynamic full-screen vignette that scales opacity based on remaining health percentage (`Humanoid.Health / Humanoid.MaxHealth + 0.5`).

### Stamina & Locomotion (`PlayerGui.sprint.LocalScript`)
- **Classes**:
  - `default`: 100 Stamina, 9 drain/sec, 12 regen/sec, 1.5x speed multiplier (WalkSpeed 24).
  - `Soldier`: 150 Stamina, 6 drain/sec, 15 regen/sec, 1.75x speed multiplier (WalkSpeed 28).
- **Camera Shake (`CameraShaker.luau`)**: Procedural 6-DOF camera headbobbing synchronized to footstep velocity.
- **Fatigue Recovery**: Depleting the stamina bar locks sprinting until reaching at least 35% stamina.

### Night Vision (`PlayerGui.night_vision.LocalScript`)
- Unlocked with `night_vision` gear item; hotkey `T`.
- Applies a smooth 2-second transition to Lighting ColorCorrection:
  - `Brightness`: `0.1`
  - `Saturation`: `-1` (monochromatic)
  - `TintColor`: `Color3.fromRGB(176, 255, 192)` (phosphor green phosphor tube look)

### Lighting & Weather Engine (`PlayerScripts.world_handler`)
- Evaluates `lighting_values`: `ClockTime`, `Density`, `Brightness`, `ColorShift_Top`, `Haze`, `Color`.
- Storm System (`workspace.raining`): Dynamic precipitation increases atmospheric density (`Atmosphere.Density = Density.Value + rain_density`).
- Thunder/Lightning: Random flash sequences momentarily elevate `Lighting.ExposureCompensation` from `0.5` to `1.0` before decaying.

---

## 4. Weapon Arsenal & Combat Engine (`gun_system` & `shop/main`)

### Arsenal Tiers
| Weapon | Price (Score) | Type | Base Notes |
| :--- | :--- | :--- | :--- |
| **Glock 17** | $100 | Pistol | Sidearm with reliable semi-auto fire. |
| **Deagle** | $500 | Heavy Pistol | High single-shot stopping power. |
| **Remington 870** | $1,000 | Shotgun | Shell-by-shell reload cycle, high close-range spread. |
| **Bizon** | $1,500 | SMG | High magazine capacity budget submachine gun. |
| **MP7** | $2,000 | SMG | Fast cycling rate and manageable recoil. |
| **P90** | $2,500 | SMG | Military-grade armor-piercing high fire rate SMG. |
| **AK-47** | $3,000 | Assault Rifle | Heavy recoil with 7.62mm high base damage. |
| **M4A1** | $3,500 | Assault Rifle | Controllable burst/full-auto weapon. |
| **AUG A1** | $4,000 | Scoped Rifle | Integrated 1.5x optical scope for medium-range precision. |
| **Scout** | $4,500 | Sniper Rifle | Bolt-action lightweight marksman rifle. |
| **Barrett M82** | $5,000 | Anti-Material | 1-hit elimination potential with extreme muzzle report. |

### First-Person Viewmodel Engine (`vm_functions.luau`)
- **Procedural Walk Sway**: Evaluates character velocity and gait frequency to calculate sinusoidal arm swing.
- **Strafe Sway**: Applies lateral roll angles based on movement direction and camera right-vector.
- **Mouse Look Sway**: Translates mouse delta inputs into inertia lag on weapon position.
- **Aim-Down-Sights (ADS)**: Interpolates viewmodel camera offsets directly to `AimPart.CFrame` while adjusting field-of-view (`zoom_amount`).

### Survivor Upgrades Station (`ReplicatedStorage.remotes.upgrade_survivor`)
- **Damage**: +10% damage multiplier per node (up to +100% at Tier 10). Cost: `(level + 1) * 100` Score.
- **Fire Rate**: +5% fire rate multiplier per node (up to +50% at Tier 10). Cost: `(level + 1) * 50` Score.
- **Max Health**: +20 maximum health per node (up to +200 HP at Tier 10). Cost: `(level + 1) * 100` Score.

---

## 5. Monster Systems, Morphs & Skill Trees (`skill_tree.luau`)

### Playable Monsters & Archetypes
1. **Siren Head** (Giant Brute):
   - `THROW BOULDER` (Offence, Slot 1): Hurls a high-velocity projectile dealing 70 AoE damage (6s cooldown). Remote: `throw`.
   - `SIREN SCREAM` (Defence, Slot 3): Regenerates 2% maximum health per second for 15s (40s cooldown). Remote: `scream_ability`.
2. **Cartoon Cat** (Elastic Assassin):
   - `POUNCE` (Offence, Slot 1): High-velocity forward leap dealing 50 damage on contact (5s cooldown). Remote: `pounce`, `pounce_hit`.
   - `SCREAM` (Defence, Slot 2): Stuns and knocks down all survivors within 100 studs, restoring 15% health (25s cooldown). Remote: `shake`.
   - `STRETCH` (Offence, Slot 3): Extends elastic arm mesh across distance to snare and reel players back. Remotes: `create_stretch`, `stretch_update`, `cancel_stretch`.
3. **Long Horse** (Nightmare Juggernaut):
   - `DASH` (Offence, Slot 1): Forward charge dealing 200 base damage to all entities in path (8s cooldown). Remote: `dash`.
   - `HEALING SCREAM` (Defence, Slot 2): Restores HP to all nearby friendly entities within 100 studs (15s cooldown). Remote: `healing_scream`.
   - `DREAM` (Offence, Slot 3): Pulls all survivors within 100 studs into the Dream Realm (90s cooldown). Remote: `dream`, `long_horse_release`.
4. **Mega Horn** (Sonic Brawler):
   - `ROAR` (Defence, Slot 1): Deals 15 damage and vacuums all players within 40 studs inward (14s cooldown). Remote: `megahorn_roar`.
   - `SONIC WAVE` (Offence, Slot 3): Piercing acoustic shockwave dealing 8 damage per tick (8s cooldown). Remote: `megahorn_sonic_wave`.
   - Melee Attacks: `megahorn_slash`, `megahorn_bite`.

### Monster Progression Tree Architecture
- **Root Node**: `UNLOCK POTENTIAL` ($100 Score). Unlocks branch access.
- **Defence Branch ("MARROW")**:
  - `Health` (Stat nodes scale up to +50% total HP)
  - `Stamina` (Stat nodes scale up to +100% total endurance)
- **Offence Branch ("FEROCITY")**:
  - `Damage` (Stat nodes scale up to +50% total damage output)
  - `Sprint Speed` (Stat nodes scale up to +50% movement velocity)
- **Ability Spurs**: Branching sub-nodes cost $1,000 Score to unlock signature monster active abilities.

---

## 6. Defensive Building Engine (`build_gui/main`)
- **11 Structures**: Wall, Window Wall, Door, Wood Barricade, Fence, Ladder, Table, Chair, Lantern, Flood Light, Basic Turret.
- **Snapping (`snap_slots`)**:
  - 10-stud horizontal wall pitch, 9-stud vertical wall pitch, 90° corner offsets `(±5, 0, ±5)`, and horizontal flat ceiling/floor snaps.
  - 11-stud vertical ladder stacking with wall surface snapping `(0, 1, ±0.65)`.
  - 1.5-stud anti-overlap detection (`slot_taken`).
- **Relocation**: Aiming within 10 studs and holding `E` fills a dismantle bar, firing `Delete:FireServer(model)` and seamlessly re-opening placement with full refund.
- **Prohibited Tags**: `CollectionService:GetTagged("no_build")` parts restrict unauthorized base placement.

---

## 7. Horror Effects & Audiovisual Polish
- **Cutscenes (`PlayerGui.cutscenes`)**: 32 KB scripted cinematic system orchestrating monster introductions, dramatic focal camera angles, and depth-of-field blurs.
- **Jumpscares (`PlayerGui.jumpscare`)**: Triggered upon lethal melee capture; snaps camera focal point directly to the attacker's facial rig with high-frequency audio.
- **Screen Tentacles (`PlayerGui.tentacles`)**: Screen-edge procedural limb creep during high-sanity drain or proximity to Long Horse / Cartoon Cat.
- **Noise & Grain (`PlayerGui.noise`)**: Randomized UV grain shift on every render frame for a vintage horror atmosphere.
