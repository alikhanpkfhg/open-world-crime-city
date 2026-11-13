# Crime City

A small open-world, GTA-style crime sandbox for Android, made with Godot 4.3 (GL Compatibility renderer, 3D).

## Play

- Walk the streets, shoot pedestrians (they die as physics ragdolls and drop cash), steal any car (walk close, press ENTER), run people over, and outrun the police.
- Wanted level (stars) rises with crimes; cops chase, shoot and ram you. Survive until the stars fade, or wreck cop cars for cash.
- Deliver cars to the yellow beacon for money. Pick up red health crates and cash on the sidewalks.
- Cars that are shot or crashed to zero health catch fire and explode.

### Touch controls
- Left half of the screen: floating move stick (steer/throttle in a car)
- Right half: drag to look
- FIRE / GUN (switch weapon) / JUMP (BRAKE in a car) / ENTER-EXIT

### Keyboard (editor testing)
WASD move, Space jump/brake, E enter/exit, Q switch weapon, F fire, Shift brake. Mouse drag = look (touch emulation is on).

## Characters

The player and the pedestrians are real rigged, skinned 3D characters with
idle / walk / run animation (Mixamo models, shipped with the three.js assets):
`models/chars/soldier.glb` is the armoured "Vanguard" soldier, `models/chars/xbot.glb`
is the "X Bot" robot. Both are imported at their authored human size (about 1.8 m),
facing -Z, feet at the origin.

- Player: the soldier. His gun is mounted on the `mixamorig_RightHand` bone and
  aimed where he faces (`_mount_gun()` in `scripts/player.gd`).
- Pedestrians: a random mix of both models, scaled 0.94-1.06, with the armour
  tinted per pedestrian so the crowd varies.
- Deaths: the body becomes a physics corpse (the real model frozen mid-stride
  inside a tumbling rigid body). If a GLB is missing, `scripts/char_model.gd`
  falls back to the old blocky humanoid and its jointed box ragdoll.

Swap in another model by adding its `.glb` and pointing `char_model.gd`'s
`SOLDIER` / `ROBOT` constants (or `C.pick()`'s pool) at it. `scripts/char_model.gd`
picks the idle/walk/run clips by name, so any Mixamo-rigged GLB works.

## Build the APK

Push to GitHub: `.github/workflows/android.yml` exports a debug APK with the `barichello/godot-ci:4.3` image and uploads it as the `crime-city-android-apk` artifact. Locally: open in Godot 4.3 and use Project > Export > Android.

## Asset credits

- Kenney Starter Kits (City Builder, Racing, FPS): buildings, trucks/cars, blasters, engine/impact/blaster sounds (CC0). https://kenney.nl
- Poly Haven textures `asphalt_02` and `aerial_grass_rock` (1k diffuse, CC0). https://polyhaven.com
- Characters: Mixamo "Vanguard" soldier and "X Bot" (free to use from Mixamo), taken from the three.js example assets (`examples/models/gltf/Soldier.glb`, `Xbot.glb`, MIT-licensed repository). https://www.mixamo.com https://threejs.org
- HUD, city layout, ragdoll corpse physics and all game code are written for this project.
