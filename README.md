# HITMAN: NIGHTCITY 13+ — Stage 1 build

A 2D neon-deco noir crime game for iPhone and Android, built in **Godot 4.3** (GDScript), landscape, touch-first.

## Engine decision

| | Unity 2D | Godot 4.3 |
|---|---|---|
| Installed on your Mac | No | No (free download, no account needed) |
| Runs in Claude's build environment | No (licensed editor, can't run headless here) | **Yes** — every screen was run, screenshotted and tested |
| iOS / Android export | Yes | Yes (Xcode / Android SDK) |

Godot was chosen so the game could actually be built **and tested** rather than written blind. All art is drawn in code as layered 2D vector shapes, so there are no external art files to break.

## Run it on your Mac (5 minutes)

1. Download **Godot 4.3 stable** (Standard, not .NET) from https://godotengine.org/download/archive/4.3-stable/
2. Open Godot → **Import** → choose `project.godot` in this folder → **Import & Edit**.
3. Press **▶ (F5)** to play.

Desktop controls (mouse clicks also act as touches):
`A / D` or arrows = walk · `E / Space` = action · `C / Shift` = hide · `Esc` = pause

## Play it on your iPhone

1. Install **Xcode** from the App Store and sign in with your Apple ID (free accounts can install on your own phone).
2. In Godot: **Editor → Manage Export Templates → Download and Install**.
3. **Project → Export → iOS**: set *App Store Team ID* and *Bundle Identifier* (e.g. `com.yourname.nightcity`) → **Export Project**.
4. Open the exported `.xcodeproj` in Xcode, select your iPhone, press Run.

Android: install Android Studio (SDK) + JDK 17, set paths in **Editor Settings → Export → Android**, then **Project → Export → Android**.

> Expo Go can't run this — it only runs React Native apps. A Godot game needs the Xcode step above.

## What's in Stage 1

| # | Feature | Status |
|---|---|---|
| 1 | Main menu (rooftop, skyline, rain) | Done |
| 2 | New Game / Continue (with overwrite confirm) | Done, tested |
| 3 | Cinematic intro: black → piano → rain → skyline pan → street → jazz club → black car at Moretti's | Done, skippable |
| 4 | Adrian Cross introduction + phone call from Vincent Moretti (with a dialogue choice) | Done |
| 5 | Interactive city map, 6 districts, 1 unlocked | Done |
| 6 | First district — The Velvet Quarter (walkable street, 6 doors) | Done |
| 7 | First mission — *The Ledger* (stealth: cover, guard vision, detection, 3-strike system, takedowns, safe-cracking, escape) | Done, tested |
| 8 | Cash rewards ($250 found + $3,000 payout on delivery) | Done, tested |
| 9 | Inventory (bag) | Done |
| 10 | Wardrobe: preview / try on / buy / wear / remove / 3 outfit presets | Done, tested |
| 11 | Safehouse — Calloway Apt 4B ($2,000) | Done, tested |
| 12 | Save & load (JSON, autosave + manual save) | Done, tested |

Also: 3 separate volume channels (Music / SFX / Dialogue), police heat meter, multi-touch controls, pause menu, wide-phone (19.5:9) layouts.

### Character customisation
Skin tone (8), hairstyle (8), hair colour (8), facial hair (6), eyes (5), scars (4), build (3) — and 55 clothing pieces across 14 slots (suits, shirts, trousers, waistcoats, coats, ties, pocket squares, shoes, gloves, hats, eyewear, watches, rings, necklaces). Each piece is drawn as its own layer on the character, so every combination looks different, and the look carries through the street, mission, safehouse and saves.

### Music
An original placeholder score, synthesised from scratch by `tools/gen_audio.py` (piano, upright bass, brushes, ride cymbal, sax), so there are no licensing issues: intro piano, menu ballad, Velvet Quarter minor blues, mission tension, safehouse lo-fi with vinyl crackle. Each district/screen sets its own track with crossfades. Replace the `.ogg` files in `audio/` with the final soundtrack when ready.

## Testing

```
godot --path . -- --test=logic     # 79 functional checks (economy, wardrobe, save/load, stealth, mission, payout, safehouse, touch, audio buses)
godot --path . -- --test=shots     # screenshot tour of every screen -> /tmp/shots
```
Last run: **79 passed, 0 failed**.

## Not done yet (honest list)
- Not yet run on a physical iPhone/Android — needs the export step above on your Mac.
- Weapons and combat, other 5 districts, rival families, courtroom/arrest system, voice acting.
- Jazz club interior and restaurant interior (doors give dialogue for now).
- Final hand-painted art and recorded soundtrack (current art is procedural vector; music is synthesised).

## Project layout
```
scripts/autoload/   game_state (save/load, money, wardrobe), catalog (all data), audio_manager
scripts/art/        nc (palette+helpers), adrian (character rig), skyline, rain, velvet_street, car, pedestrian
scripts/ui/         theme, dialogue box, touch controls, HUD
scripts/screens/    menu, intro, city_map, district, mission, wardrobe, inventory, safehouse
audio/              original score + SFX (.ogg)     fonts/  OFL / Apache licensed fonts
tests/              automated tests                tools/  music generator
```

Fonts: Limelight, Josefin Sans, Bebas Neue (SIL OFL), Special Elite (Apache 2.0) — licences in `fonts/`.
