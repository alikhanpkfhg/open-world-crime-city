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

## Build the APK

Push to GitHub: `.github/workflows/android.yml` exports a debug APK with the `barichello/godot-ci:4.3` image and uploads it as the `crime-city-android-apk` artifact. Locally: open in Godot 4.3 and use Project > Export > Android.

## Asset credits (all CC0)

- Kenney Starter Kits (City Builder, Racing, FPS): buildings, trucks/cars, blasters, engine/impact/blaster sounds. https://kenney.nl
- Poly Haven textures `asphalt_02` and `aerial_grass_rock` (1k diffuse). https://polyhaven.com
- Characters, ragdolls, HUD and all game code are procedural / written for this project.
