# CLAUDE.md — mario-clone

Projekteigene Ergänzungen zur globalen
`~/GodotDev/learn_2d_gamedev_godot_4_0.57.0_linux/CLAUDE.md` (gilt zusätzlich,
nicht ersetzend). Genrevorbild: Super Mario Bros. / Super Mario World —
**alle Grafiken, Musikstücke und Soundeffekte sind eigene Arbeiten**, nichts
davon ist aus Nintendo-Spielen übernommen (Figuren nur „im Stil von“).

## Historie in Kurzform

- Tag `pixellab-test`: PixelLab-Evaluierung (Sprites per PixelLab Tier 1 via
  Aseprite). Vom Nutzer als unbrauchbar bewertet (2026-09-26): Artefakte in
  Animationen, Füße nicht auf den Tiles, uneinheitliche Größe zwischen
  Animationen, Hintergrund nicht freigestellt, Farben inkonsistent.
- Ab v0.2.0: kompletter Neuaufbau mit **prozedural/handgezeichneter
  Pixel-Art aus Python-Generatoren** (siehe „Grafik“).

## Design-Entscheidungen

- **16:9 Querformat, Design-Canvas 480×270** (×4 = 1080p, ×3 = 810p).
  `window_width_override=1440`/`height=810` → Fenster öffnet ohne Resize-
  Sprung. Orientierung Landscape fest (Projekt-Default 0), NIE `SENSOR*`
  (globale Vorgabe 2). Bewusste Ausnahme vom Hochkant-Standard: ein
  Side-Scroller ist konzeptbedingt Querformat — auch auf Mobile/Web.
- **`CONTENT_SCALE_ASPECT_EXPAND` immer** (statt KEEP/KEEP_WIDTH): die Höhe
  bleibt 270 Design-px, breitere Geräte (2,2:1-Phones, Ultrawide) sehen
  einfach mehr vom Level. Kein Letterbox. HUD-/Touch-Elemente sind an den
  Viewport-Rändern verankert (Anchors bzw. `TouchControls.relayout()`).
- **Kamera**: eigene Nachführung in `game.gd::_update_camera()` (kein
  `position_smoothing`): horizontal kleine Totzone (±12 px), vertikal
  „setzt sich“ auf die Bodenlinie und folgt nur größeren Höhenwechseln;
  Grenzen = aktueller Bereich („main“/„bonus“) aus den Level-Daten.
- **Touch-Steuerung = virtuelle Buttons** (◀ ▼ ▶ unten links, X/A unten rechts,
  `touch_controls.gd`, `TouchScreenButton` mit `action`-Bindung → Multitouch
  gratis). Abweichung von globaler Vorgabe 4/5 (Swipe + Touch-Elemente nur
  oben): ein Plattformer braucht gehaltene Richtungen und zwei Daumen
  gleichzeitig; Buttons überlagern die unteren Ecken. Pause/Mute bleiben wie
  vorgeschrieben oben rechts.
- **UI-Schrift**: eigene 5×7-Pixelschrift `assets/ui/pixel_font.ttf`
  (`tools/gen_font.py`, fontTools), als Projekt-Standardschrift gesetzt
  (`gui/theme/custom_font`). Pixelgenau bei Größe 8/16/24/32; Import mit
  `antialiasing=0`, `hinting=0`, `subpixel_positioning=0`.
- **Menü-Maße** (Canvas ist nur 270 hoch, die 56-px-Regel der Hochkant-
  Projekte ist hier umgerechnet): Buttons 22 Design-px hoch (= 88 echte px
  auf 1080p), Schrift 16, Überschriften 24/32, HUD 8.

## Steuerung (tools/setup_input.gd schreibt die InputMap)

| Aktion | Tastatur | Gamepad |
|---|---|---|
| move_left/right | A/D, ←/→ | D-Pad, linker Stick |
| move_down (ducken, Röhre) | S, ↓ | D-Pad ↓ |
| jump | Space, Z, K, W, ↑ | A (0), B (1) |
| run (rennen, Feuerball, Zunge) | Shift, J, X, Ctrl | X (2), Y (3) |
| pause | Esc, P | Start (6) |
| mute | M | Back/Select (4) |
| screenshot | F12 | — |

Absteigen vom Drachen: ↓ + Sprung. `[input]` nie von Hand editieren, sondern
`godot --headless --path . --script res://tools/setup_input.gd`.

**Umbelegen (v0.7)**: Settings → Controls. `controls_config.gd`
(`ControlsConfig`) legt Overrides aus settings.cfg `[controls]`
(`<aktion>.key` = physical keycode, `<aktion>.pad` = Button-Index) über die
Defaults aus project.godot: `apply()` beim Start und nach jeder Änderung
(`InputMap.load_from_project_settings()` + Overrides). Taste = zusätzlich
(Default-Tasten bleiben), Gamepad-Button = ersetzt die Buttons der Aktion;
beides wird anderen Aktionen weggenommen (Tausch statt Doppelbelegung).
D-Pad/Stick-Bewegung ist fest. Dort auch „Touch keys“ Auto/On/Off.
`ui_accept`/`ui_cancel` (Menüs: A/B) bleiben unverändert.

## Physik (player.gd, px/s bei 16-px-Tiles)

Laufen 90, Rennen 155, Sprung 270 (+50 bei Vollgas), Schwerkraft 560 solange
Sprungtaste gehalten und aufwärts, sonst 1400; Coyote 0,08 s, Sprungpuffer
0,12 s. Ergebnis: Stand-Sprung ≈ 4,1 Tiles, Renn-Sprung ≈ 5,7 Tiles hoch;
Weite ≈ 4,4 (gehend) / ≈ 7,8 Tiles (rennend) — Level-Design danach richten
(z. B. 4er-Röhren sind aus dem Stand knapp machbar).
**Sprung-Hilfen (v0.11, Nutzerwunsch „auch alte Männer sollen es
schaffen“)**: die leichte Schwerkraft gilt mindestens `JUMP_MIN_HOLD` =
0,15 s, auch wenn die Taste sofort losgelassen wird (kurzes Antippen ≈
2,9 Tiles statt 1,6). Bodenbremse 560 (vorher 280), Gegenlenken 900,
Aufsetzen ohne Richtungstaste halbiert das Tempo (`LAND_BRAKE`) → nach
der Landung rutscht der Held nur noch 1–5 px nach (Eis bleibt glatt:
`DECEL_ICE` 80). Luftsteuerung 340, Luftbremse ohne Richtung 130.
**Doppelsprung**: in der Luft einmal erneut springen (235 px/s, gleiche
Halte-Logik; Stampfen füllt ihn wieder auf) — Wölkchen `jump_puff.gd`,
Sound `jump2`; abschaltbar in Settings „Double jump“ (Standard an).
Gemessen (`playtest jumpfeel`): Tipp 2,9 / gehalten 3,9 / doppelt getippt
5,2 / doppelt gehalten 6,3 Tiles.
Ursprung JEDER Figur = Füße (unten Mitte); Sprite-Offset = −Zellhöhe/2.
Kopfstoß wählt den Block, dessen Mitte dem Spieler am nächsten ist.
Klein→Groß (Pilz), Groß/Feuer→Feuer (Blume); Treffer: Feuer→Groß→Klein→Tod
(wie SMB3, verzeihender als SMB1). Beim Wachsen/Schrumpfen friert die Welt
0,7 s ein (`game.gd::_set_world_active()` — **per `set_deferred`**, weil oft
aus einem Physik-Callback ausgelöst; direkt gesetzt gab es „Disabling a
CollisionObject node during a physics callback“).

## Physik-Layer

1 Welt (Tiles, Blöcke) · 2 Spieler · 3 (Wert 4) Gegner · 4 (Wert 8) Items ·
5 (Wert 16) Münzen · 6 (Wert 32) Drache. Gegner kollidieren physisch nur mit
der Welt; Spieler-/Gegner-Kontakt läuft über die Hitbox-`Area2D` des Gegners.

## Level

- Level werden in **`tools/make_levels.py`** mit Hilfsfunktionen gebaut
  (`ground`, `pit`, `pipe`, `blocks`, `coin_arc`, `stairs`, `enemy`, …) und als
  `levels/level_<id>.gd` ausgegeben (ASCII-Raster + Metadaten START/FLAG/
  CASTLE/CHECKPOINTS/AREAS/WARPS). **Nie die generierte Datei editieren.**
  Legende im Docstring von `make_levels.py`.
- `python3 tools/make_levels.py --preview` rendert das komplette Level mit den
  echten Tiles/Sprites als PNG (PREVIEW_DIR) — so wird das Design geprüft.
- 20 Zeilen hoch, Boden-Oberkante Zeile 17. Bonusräume liegen als eigener
  Spaltenbereich hinter dem Hauptlevel (`AREAS`), mind. 40 Spalten breit
  (sonst sieht man auf 2,2:1-Geräten über die Kamera-Grenze hinaus).
- `level.gd` baut das TileSet **zur Laufzeit** aus `tiles.png` (Physik-
  Polygone, Einweg-Kollision für die Holzbrücke), autotiled Gras/Erde und
  Höhle über eine 4-Bit-Nachbarmaske (1 oben offen, 2 unten, 4 links,
  8 rechts), wählt Innen-Erde-Varianten deterministisch per Zell-Hash.
  Röhren wachsen vom `P`/`W`-Kopf nach unten bis zum nächsten festen Feld.

### Biome (seit v0.4)
Das Aussehen von `#` (Boden), `w` (Ziegelwand) und Deko-Zeichen hängt vom
**Thema des Bereichs** ab (`level.gd::THEME_BIOME`: `cavern`/`cave` → Höhle,
`desert` → Sand, `snow` → Schnee, sonst Gras) — dieselben Bau-Helfer
funktionieren in jeder Welt. `*` wird z. B. Busch / Saguaro / Tanne /
Kristall. Atlas-Reihen: 4 Sand-, 5 Schnee-Autotile, 6 Extras (Innenvarianten,
Eis `I` 8, Lava `L` 9–12 animiert + 13, Sandstein 14, Eisziegel 15).
Eis: `player.gd::_on_ice()` → nur 28 % Grip (Beschleunigen/Bremsen).
Lava liegt wie Wasser auf dem Vordergrund-Layer ohne Kollision (= Grube).

### Themen / Stimmungen (`backdrop.gd::THEMES`)
`grass` (Tag), `sunset` (Abend: violett-orange Himmel, warm getönte
Ebenen), `night` (Nacht: Sterne + Mond im Himmel-Shader, blau getönte
Ebenen), `cave` (Bonusraum). Jede Ebene bekommt ihren eigenen Farbton
(`self_modulate`), die Welt (Tiles + Figuren) einen `CanvasModulate`. Die
Parallax-Ebenen liegen deshalb in einem eigenen `CanvasLayer`
(`follow_viewport_enabled`), sonst würde der Welt-Ton sie doppelt abdunkeln.
Thema pro Bereich in `AREAS` des Levels. Neue Themen haben eigene Ebenen
(`"layers"`) statt der Gras-Ebenen: `cavern` (Stalaktiten, Säulen,
Kristallhügel, schwebende Leuchtpartikel), `desert` (Sonne im Himmel-
Shader, Pyramiden, Dünen, Kakteen, Sandwehen), `snow` (Berge, Tannen,
Schneehügel, Schneefall). Partikel: `CPUParticles2D` auf eigenem
CanvasLayer 5 (Bildschirmraum). Musik je Thema: `game.gd::THEME_MUSIC`.

### 2-1 „Crystal Caverns“, 3-1 „Dune Drift“, 4-1 „Frosty Peaks“ (v0.4)
2-1: Decke (`L.ceiling`, `L.top = 6` damit `surface()` unter der Decke
sucht), Lavagruben mit Pfeilern, Panzer-Gasse (eine Schildkröte vor vier
Pilzlingen → Kick-Kombo), niedriger Gang mit verstecktem 1-UP; Ausgang über
eine Röhre in den Bereich `exit` (Abendwiese mit Fahne + Burg).
3-1: Sandstein-Ruinen, Oase mit Brücke, Sims-Kette, Pyramiden-Stufen.
4-1: Eisflächen am Boden, zugefrorener See mit Eisschollen, Eisblock-
Brücke, Eisziegel-Treppe.

### 2-2 „Lava Depths“, 3-2 „Sunset Ruins“, 4-2 „Starlight Glacier“ (v0.6)
2-2: Lavafluss mit Pfeilern (rote Schildkröte obenauf), Ziegeldecke,
Holzbrücken über einem Lavasee, Hartblock-Treppe über Lava; Ausgang in
eine Nachtwiese. 3-2 (Thema `desert_dusk`: tiefe Sonne `sky[7]` =
`sun_uv`): geflügelte Schildkröten über Gruben, Sandstein-Tempel mit
Dach, Schildkröten-Reihe auf einem Sims (Kombo), Stufenpyramide mit Tunnel.
4-2 (Thema `snow_night`: Sterne + Mond, blaue Tönung): lange Eisbahn,
Eisziegel-Türme, See mit Eisschollen, Eisbrücke über Wasser.
Reihenfolge in `game.gd::LEVELS`: 1-1 … 1-4, 2-1 … 2-3, 3-1 … 3-3,
4-1 … 4-3, 5-1 … 5-3 (x-4/x-3 = Burg); nach der letzten Burg
Siegerbildschirm.

### 1-1 „Green Hills“ (312 Spalten, davon 262 Hauptlevel)
Start-Wiese mit ?-Blöcken → Röhrenfeld (Warp-Röhre Spalte 53 → Münzhöhle,
Rückkehr aus Röhre Spalte 203) → Hügel mit verstecktem 1-UP → Grube mit
Münzbogen → Ziegelreihen (Mehrfachmünz-Ziegel, Stern-Ziegel) → Dracheneier-
Block (Spalte 129) + lange Wiese mit Gegnergruppen, Checkpoint (142),
Teich mit Holzbrücke → Doppeltreppe mit Lücke → Zieltreppe (8 hoch),
Fahnenstange (252), Burg (256).

### 1-2 „Sunset Meadows“ (Abend) und 1-3 „Moonlit Heights“ (Nacht)
1-2: Hügel mit Schnapp-Pflanze, Teiche mit Wasser + Holzbrücke,
geflügelte Pilzlinge, Stufengelände, Ei-Block (gibt 1-UP, wenn man schon
einen Drachen hat), Checkpoint, Plattform-Treppe mit Stern, Münzhöhle.
1-3: Plattform-Überquerung eines breiten Teichs, lange Brücke über Wasser,
Stufenhügel mit Pflanze auf dem Plateau, Ziegelbrücke, Münzhöhle,
hohe Plattformen mit Stern, Doppeltreppe. Nach 1-3: „THANK YOU!“ +
Siegerbildschirm mit Hall-of-Fame-Eintrag.

### Gegner
- `shroom.gd`: Pilzling (Stampfen = platt, sonst Umkippen); `winged`-
  Variante (`G`) hüpft, erster Stampfer reißt nur die Flügel ab.
- `chomper.gd`: Schnapp-Pflanze in Röhren (`Q`), hinter den Röhren-Tiles
  (z −1), bleibt unten, solange der Spieler < 26 px neben der Röhre steht;
  nur Feuerball/Stern/Drachenzunge besiegen sie.
- Wasser (`v`): eigener `TileMapLayer` VOR den Figuren (z 2), animierte
  Oberfläche als Tile-Animation (4 Frames), keine Kollision (= Grube).
- `turtle.gd` (v0.4): `k` grün (läuft über Kanten), `K` rot (dreht an Kanten
  via `test_move`), `J` geflügelt. Zustände WALK → (Stampfen) SHELL → (Berühren
  oder Stampfen) SPIN (210 px/s, prallt an Wänden ab, stößt Blöcke seitlich
  an — Ziegel zerbrechen, `Block.bump(player, true)`) → Stampfen stoppt ihn.
  Nach 6 s schaut sie heraus (Wackeln) und läuft wieder. Kick 400, Panzer-
  Kette 500/800/1000/2000/4000/5000/8000, dann 1UP. Feuerball/Zunge/Stern
  behandeln alle Gegner generisch (`has_method("kill_flip")`).

## Punkte

Münze: einstellbar (Standard 200), alle N Münzen ein Leben (Standard 100,
einstellbar, „Off“ möglich). Stampf-Kette 100, 200, 400, 500, 800, 1000,
2000, 4000, 5000, 8000, dann 1UP (Reset bei Bodenkontakt). Feuerball 200,
Block-von-unten 100, Ziegel 50, Item 1000, Zunge 200. Fahnenstange nach
Höhe über dem Sockel: ≥128 px 5000, ≥96 2000, ≥64 800, ≥32 400, sonst 100.
Zeitbonus 50 pro Zeiteinheit (Zeit tickt alle 0,4 s, „HURRY UP!“ bei 100 →
Musik +20 % Tempo).

## Einstellungen (Start-Screen + Pause)

Leben (1–9), Schwierigkeit (Gegnertempo ×0,8/1,0/1,25; Easy +100 Zeit),
Timer (Off/Level/Short = 75 %), Münzpunkte (0/100/200/500), 1-UP-Münzen
(Off/50/100/200), „Start big“. Sound-Unterseite: Regler pro Sound (30 Stück,
scrollbar), Mute. Persistenz `user://settings.cfg` wie global vorgegeben.

## Grafik (tools/, Python + Pillow)

- `pixelart.py` — Toolkit: Pixel-Maps (Strings + Palette) → Bild, automatische
  1-px-Outline (`#1a1018`), Palettentausch, Streifen-Sheets.
- `gen_sprites.py` — Held klein (16×16-Raster) / groß (16×28) / Feuer
  (Palettentausch), Drache (26×28) inkl. Maul-offen-Frames, Ei, Pilz-Gegner,
  Münze (Spin), Pilz/1-UP/Feuerblume/Stern, Feuerball. Erzeugt PNG-Streifen +
  `SpriteFrames`-.tres (`spriteframes.py`).
- `gen_tiles.py` — Autotile-Atlas `tiles.png`, Blöcke (`blocks.png/.tres`),
  Deko (`decor.png` + generiertes `decor_index.gd`), Fahnenstange, Burg,
  Checkpoint-Fahne, Ziegelsplitter.
- `gen_backgrounds.py` — 5 nahtlos kachelnde Parallax-Ebenen (640 px breit,
  alle Sinus-Perioden teilen 640). Himmel = Shader `assets/ui/sky.gdshader`.
  Parallax NICHT über `Parallax2D`, sondern `backdrop.gd`: ein Sprite pro
  Ebene klebt am linken Kamerarand, `region_rect.x = Kamera·Faktor` bei
  `texture_repeat` — einfach und nahtlos.
- `gen_ui.py` — Touch-Buttons (Splash siehe „Splash-Screen“).
- `gen_font.py` — Pixelschrift.
Vorschau-Bilder: jeweils `--preview` (Ausgabe nach `PREVIEW_DIR`).
Qualitätsregel: jedes Sprite-Set in EINEM Raster, Füße auf der letzten Zeile,
Outline programmatisch — genau die Punkte, an denen PixelLab scheiterte.

## Sound (tools/gen_audio.py, numpy + ffmpeg)

Eigener kleiner NES-artiger Synth (Puls mit Duty, Dreieck, Rauschen,
Hüllkurven, Glissando, Vibrato). 23 Effekte → `assets/sounds/*.wav`; Musik
(Oberwelt 150 bpm C-Dur, Höhle 118 bpm a-Moll mit Echo, Stern 184 bpm,
Titel 112 bpm, Wüste „Dune Drift“ 132 bpm D-phrygisch-dominant, Schnee
„Frosty Peaks“ 138 bpm F-Dur-Walzer mit Glocken-Lead) + Jingles.
**Deterministisch** (v0.10): Rausch-Seed pro Stück (`reseed(name)`),
ffmpeg mit `-fflags +bitexact` (feste Ogg-Seriennummern) — ein erneuter
Lauf ändert unveränderte Dateien nicht mehr (Ziel, Tod, Game Over) → `assets/music/*.ogg`.
**Eigenkompositionen** in Tracker-Notation im Skript — bewusst nicht die
Nintendo-Themen. Loops werden mit umgeklapptem Nachhall gerendert (nahtlos);
`sound_manager.gd` setzt `AudioStreamOggVorbis.loop = true` zur Laufzeit.

## Testen

- `_selftest.gd` (headless): parst alle Skripte, prüft 16:9, InputMap
  (inkl. `device=-1` bei allen Joypad-Bindungen), Level-Konsistenz,
  Punktetabellen.
- **Vor jedem Build/Commit `_selftest.gd` laufen lassen und mit `&&`
  verketten**: `build.sh` exportiert auch bei GDScript-Parse-Fehlern
  klaglos (v0.9.1 ging so mit kaputtem `menus.gd` raus — doppelte
  Anführungszeichen in einem String-Literal).
- `tools/playtest.gd`: startet das echte Spiel **im Fenster**, simuliert
  Eingaben per `Input.action_press()` und speichert Screenshots + Zustands-
  zeilen. Szenarien: basic, powerup, stomp, pipe, flag, dino, title, fire,
  star, gameover, dinohit, checkpoint, levels, card, ridebig, pause, worlds,
  turtle (Stampfen/Kick/Kombo/rote Kante), exitpipe, ice, jumpfeel
  (Sprunghöhen, Nachrutschen, Säulen in 1-4), mutebtn (Mute-Anzeige im
  Sound-Menü).
  `godot --path . --script res://tools/playtest.gd -- <szenario> <ordner>`
  — schneller als der MCP-Editor-Weg und ohne offenen Editor nutzbar.
- `build.sh`: Editor-Check prüft nur echte `godot`-Prozesse (`pgrep -x`),
  NICHT `ps | grep` (das traf die eigene Shell-Kommandozeile);
  `tools/fix_mcp_autoloads.py` stellt danach nur die drei MCP-Autoload-Zeilen
  wieder her (sicher auch bei uncommitteten project.godot-Änderungen).
- Android-Paket: `com.example.marioclone` (nicht per `grep -i mario` suchen —
  auf dem Testgerät gibt es eine fremde `com.thg.de.thg.mario`-App).
- Web-Testserver: `.claude/launch.json` → Port **8096**.

## Hilfeseiten

`tools/gen_help.py` rendert 6 bebilderte Seiten (+ „Turtles & Worlds“ seit v0.4) (Steuerung Tastatur +
Gamepad inkl. D-Pad/A/B/X/Y/Start/Select und Mute-/Pause-Knopf, Touch,
Blöcke & Items, Drache, Ziel & Punkte) mit den echten Sprites und der
Pixelschrift, 1:1 in Design-Pixeln (340×170) → im Menü mit NEAREST-Filter.
Kein SVG/Inkscape nötig (Abweichung von Centipede, bewusst: so sehen die
Seiten aus wie das Spiel selbst).

## Touch-Tasten

◀ ▼ ▶ unten links (▼ = ducken, Röhre, mit A vom Drachen absteigen),
X / A unten rechts. Der ▼-Knopf kam in v0.3 dazu — ohne ihn waren Röhren,
Ducken und Absteigen auf Touch unmöglich.

## Bewegliche Plattformen + Boss-Varianten (v0.10)

- `~` / `^` im Level-Raster = 3 Kacheln breiter Lift (`moving_platform.gd`,
  `AnimatableBody2D` mit `sync_to_physics`, Einweg-Kollision von unten),
  linke obere Ecke an der Zelle; `~` fährt 64 px nach rechts und zurück,
  `^` 72 px hoch und zurück (Sinus, 3,6 s), Phase nach Spalte versetzt.
  Nicht Teil von `surface()` im Level-Generator. Grafik `lift.png`
  (`gen_tiles.py`). **Vorsicht beim Platzieren von `^`**: über dem Lift
  darf in Hubhöhe + Heldengröße kein fester Block liegen (sonst wird der
  Held eingeklemmt).
- Boss-Angriff je Welt (`boss.gd::_breathe()`, Geschosse `boss_flame.gd`
  mit `kind`): 1 gezielte Flamme, 2 Fächer aus drei Flammen, 3 gezielte
  Flamme + bei jeder Landung zwei Sand-Schockwellen über den Boden
  (`_jumping`-Flag, nicht am Animationsnamen erkennen — das Brüllen
  überschreibt ihn), 4 zwei springende Eisbälle (`ice_ball.png`, prallen
  bis zu 4× vom Arenaboden ab).
- Playtests: `lifts`, `bossvariants`, `bossstress` (Arena-Einmauern
  wiederholt, `RUNS=`).

## Welt 5 „Sky“ (v0.12)

- Levels 5-1 „Cloud Kingdom“ (Thema `sky`, Münzraum), 5-2 „Sunset Skyway“
  (`sky_dusk`), Burg 5-3 „Storm Citadel“ (dort ist der erste Sims über dem
  Lavasee eine fallende Platte). Wolkeninseln über bodenlosem Himmel.
- Biom `sky`: `#` = Wolken-Autotile (Atlas-Reihe 9, weiche blaue Kontur,
  bogige Ränder), Reihe 10: Wolkenbrücke L/M/R (`=` im Himmel, Einweg),
  Marmorziegel (`w`), zwei Wolken-Innenvarianten. Deko: rosa Blütenbüsche,
  Himmelsblume, Wolkenbüschel, Marmorfels.
- Hintergrund (`backdrop.gd` Thema `sky`/`sky_dusk`): Wolken, schwebende
  Inseln mit Wasserfall, zwei Wolkenmeer-Bänder (leicht bläulich getönt,
  damit sie sich vom Wolkenboden abheben), Sonne; Partikel `wind`.
  Musik `music_sky` „Cloud Nine“ (D-Dur mit lydischem G#, 124 bpm, Harfen-
  Arpeggien).
- `D` = fallende Platte (`falling_platform.gd`, 3 Kacheln, `drop.png`):
  0,5 s nach dem Betreten wackelt sie, fällt dann (nimmt den Helden mit) und
  erscheint 3,5 s später wieder (nicht, solange der Held dort steht).
- `T` = Kippplanke (`tip_platform.gd`, 4 Kacheln, Drehpunkt in der Mitte,
  `tipper.png`): kippt zur belasteten Seite (je weiter außen, desto
  schneller, max. 75°), ohne Last zurück. „Steht drauf“ wird über die
  Position erkannt, NICHT über `is_on_floor()` (auf steiler Planke gilt der
  Held kurz als nicht am Boden → die Planke pendelte sonst bei 45°).
- Gegner: `u` Wolkenkobold (`cloud_imp.gd`: folgt dem Helden hoch oben,
  wirft alle 3,4 s einen Stachelball, max. 3; nach 110 Spalten fliegt er
  weg; stampfbar von oben), `x` Stachi (`spiky.gd`, `extends Shroom`: nicht
  stampfbar; vom Kobold geworfen als Kugel, entrollt sich bei der Landung),
  `y` Möwe (`gull.gd`: gleitet mit Wellenbewegung auf den Helden zu).
- Boss Welt 5 (gold): gezielte Flamme + drei Blitze um den Helden
  (`boss_flame.gd` Art `bolt`: 0,6 s blinkende Warnung oben, dann Einschlag).
- Hilfeseite „Sky World“; Playtests `sky` (Platte, Planke, Kobold, Möwe,
  Blitze) und `selects` (Level-/Weltauswahl passen auf 270 px).

## Biom-Gegner (v0.9)

- `a` Fledermaus (`bat.gd`, Höhle; `L.bat(c)` setzt sie direkt unter die
  Decke): schläft kopfüber, stürzt sich auf Heldenhöhe herab, fliegt dann
  wellenförmig weiter (durch Wände). Stampfbar.
- `p` Kaktusturm (`cactus.gd`, Wüste): 3 (Welt 4: 4) schwankende Stachel-
  kugeln, kriecht zum Helden. Stachelig: Stampfen verletzt! Jeder Feuerball
  schlägt eine Kugel ab (`fire_hit()`, +200); Panzer/Stern/Zunge/Block von
  unten erledigen den ganzen Turm.
- `q` Pinguin (`penguin.gd`, `extends Shroom`, Schnee): schneller Läufer,
  rutscht alle paar Sekunden 1,1 s bäuchlings mit 2,6-fachem Tempo.
Feuerball ruft zuerst `fire_hit()` auf, falls vorhanden (Boss, Kaktus).

## Burgen + Boss (v0.8)

Letzter Kurs jeder Welt: 1-4, 2-3, 3-3, 4-3 (`make_levels.py::castle_level`,
mit der Welt steigende Schwierigkeit). Thema `fortress` (Biom `castle`:
Steinquader-Autotile Atlas-Reihe 7, Reihe 8 Innen/rissig/Burgziegel `w`;
Hintergrund Ziegelwand mit Bogenfenstern + Säulen mit Bannern, Glut-
Partikel, Musik `music_castle`). Deko: `*` Banner, `+`/`t` Fackel
(flackert), `f` Schädel.
- `F` = Hartblock mit Feuerstab (`firebar.gd`, 5–6 Kugeln, Richtung nach
  Spaltenparität, schneller je Welt). `b` = Lavablase (`lava_bubble.gd`,
  in der obersten Lava-Zeile einer Grube, springt periodisch).
- `Z` = Boss (`boss.gd`), Arena = Level-Konstante `ARENA` (≥ 38 Spalten).
  Betritt der Held die Arena: `game.start_boss()` sperrt Kamera + Spieler-
  Grenzen auf die Arena, mauert die linke Spalte zu, HUD-Boss-Leiste.
  Boss (eigenes Design: gehörnter Drachen-Oger-König, 32×34 Pixel, 2×
  gezeichnet, je Welt andere Farbe `boss_<welt>.png`): läuft, springt,
  speit gezielte Flammen (`boss_flame.gd`); 3 HP (ab Welt 3: 4), Stampfen/
  Stern = 1, 5 Feuerbälle = 1; danach 1,2 s unverwundbar, wird schneller.
  Kein `kill_flip()` → immun gegen Panzer, Blöcke, Zunge. Sieg:
  `boss_defeated()` → „WORLD n CLEAR!“, `jingle_world`, +5000, **1UP**
  (v0.9.4), Zeitbonus, nächste Welt.
- Vor jeder Arena (v0.9.4, Nutzerwunsch — sonst frustrierend): eigener
  Checkpoint (Arena−7) + `N`-Block (immer Feuerblume, Block-Inhalt
  `flower`). Wer vor der Arena (re)spawnt — Tod nach dem Boss-Checkpoint
  oder „Boss“-Direktstart — beginnt immer als Feuer-Held
  (`game.gd::_is_boss_spawn()`: Spawn in Spalten [Arena−10, Arena)). Burg-Level haben `FLAG`/`CASTLE` = (-1, -1).

## Levelauswahl-Cheat (v0.8)

Auf dem Titelbildschirm: Gamepad **B, Y, X, A** (A zuletzt, wird abgefangen,
damit es nicht „Play“ drückt), Tastatur **L E V E L S** oder den Titel 5×
antippen → „LEVEL SELECT“ mit allen Kursen. Kurse jenseits des weitesten
erreichten (`[progress] level`, ID-basiert) sind orange; wer so einen
startet, spielt einen „cheated“ Lauf: kein Hall-of-Fame-Eintrag (Hinweis
statt Namensfeld), kein Fortschritt gespeichert, „Play Again“ bleibt
cheated. Hilfeseite „Castles & Secrets“.
Pro Welt zusätzlich ein Knopf **„Boss“** (v0.9.1): startet die Burg mit
`checkpoint_pos` 3 Spalten vor `ARENA` (`_start_game(i, cheat, at_boss)`),
Tod im Bosskampf → Neustart ebenda. Orange = Burg noch nicht erreicht.

## Splash-Screen (v0.9.3)

`splash-screen.png` (Boot-Splash, 1920×1080, schwarzer Rand/Hintergrund,
2 s) ist die **vom Nutzer gelieferte** Grafik — Original in
`art_src/mario-clone-splashscreen.jpeg` (`art_src/` hat `.gdignore`, wird
nicht importiert/exportiert). Neu erzeugen:
`magick art_src/mario-clone-splashscreen.jpeg -resize 1920x1080 -background black -gravity center -extent 1920x1080 -strip splash-screen.png`.
`tools/gen_ui.py` erzeugt den Splash NICHT mehr (hat ihn früher überschrieben).
Godot-Boot-Splash kann nur PNG.
**Fake-Ladebalken (v0.9.6, wie Galaga)**: `splash.gd` (CanvasLayer 50) zeigt
nach dem kurzen nativen Boot-Splash (0,5 s) dasselbe Bild weiter + goldenen
Ladebalken unten mittig über `Splash.TIME` = 3 s, danach Titelbildschirm
(`game.gd`: `splash.done` → `_to_title`). Taste/Pad-Button/Klick/Tipp
überspringt (nach 0,3 s). `tools/playtest.gd` ruft `game.skip_splash()`.
**Android**: im Android-Preset muss `splash_screen/disable_godot_boot_splash=false`
stehen (aus der Tetris-Vorlage kam `true` → Android zeigte nur den System-
Splash mit Icon, nie `splash-screen.png`; seit v0.9.5 behoben, auf dem RG552
per `screenrecord` verifiziert). Der vorgeschaltete Android-12-System-Splash
(Icon) hat weißen Hintergrund — `splash_screen/background_color` greift
nur bei Gradle-Builds. Seit 2026-09-27 (Nutzerwunsch, kein Gradle) zeigt er
nur reines Weiß: `splash_screen/icon` = transparentes
`assets/icon/android_splash_blank.png`, `branding_image` leer.

## App-Icon (v0.5)

`tools/gen_icon.py` baut das Icon aus den Spiel-Sprites (Held springt gegen
einen ?-Block, Münze): `icon.png` 256 (Projekt-Icon, Desktop/Web) und
`assets/icon/android_{main,fg,bg,mono}.png` (192er Legacy + 432er
Adaptive-Ebenen + Monochrom für Android-13-Themen-Icons), in
`export_presets.cfg` unter `launcher_icons/*` eingetragen. Nur ganzzahlig
skaliert (NEAREST). Adaptive-Vordergrund bleibt im sichtbaren Kreis (~61 %).

## Weltauswahl + Touch-Tasten-Schalter (v0.5)

- `GameSettings.reached_world()` (Abschnitt `[progress]` in settings.cfg)
  wird in `_begin_level()` hochgezählt. Play öffnet ab Welt 2 den Screen
  „SELECT WORLD“ (gesperrte Welten „???“). „Play Again“ nach Game Over
  startet am ersten Level der aktuellen Welt, nach dem Sieg bei 1-1.
- Settings „Touch keys“ Auto/On/Off (`GameSettings.touch_buttons_visible`):
  Auto = nur auf Touch-Geräten OHNE verbundenes Gamepad (RG552 → aus).
  `Input.joy_connection_changed` schaltet live um. Die Hilfe zeigt die
  Touch-only-Seitenliste nur ohne Gamepad.
- Achtung Playtests: `worldselect` setzt den Fortschritt auf dem
  Entwicklungsrechner — danach `[progress]` in
  `~/.local/share/godot/app_userdata/mario-clone/settings.cfg` prüfen.

## Offen / nächste Schritte

Siehe **`TODO.md`** (offene Punkte sammeln + abhaken, gilt über
Kontextwechsel hinaus).
