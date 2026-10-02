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
- **v1.0.0 (2026-09-27): finales Release** — 6 Welten (Wiese, Höhle,
  Wüste, Schnee, Himmel, Meer), 19 Kurse inkl. 6 Burgen mit Boss.
  Weitere Ideen stehen in `TODO.md` unter „Offen“.
- v1.1.0 Weltkarte, v1.2.0 Spielstand/Continue + Quit-Dialog mit
  Highscore-Eintrag, v1.2.1 Feinschliff (Highscore-Liste, Panzer-Limit,
  zehn eigene Bonusräume, Boss je Schwierigkeit), v1.3.0 Becken +
  Strömungen, geflutete Burg 6-3, v1.4.0 Welt 7 Geisterhaus (Türen,
  Geister, Knochen-Schildkröten, Phantom-König), v1.5.0 Welt 8 Vulkan
  (letzte Welt, Endboss). Damit ist die letzte Erweiterungsrunde (Nutzer
  2026-09-28) abgeschlossen — weitere Ideen nur, wenn der Nutzer welche
  hat. Stand: 8 Welten, 25 Kurse, 8 Bosse. v1.6.0 zwei Spieler
  abwechselnd (Mario + Luigi), v1.7.0 Coop, v1.8.0 Wi-Fi-Coop, v1.9.0
  Online-Coop über einen Vermittlungsdienst auf Uberspace (2026-10-02).

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
- **Bonusräume (v1.2.1, Nutzer: „immer gleich, etwas öde“)**: jeder Kurs
  hat seinen eigenen, `coin_room(L, B0, B1, style)` → (Ausgang, Thema),
  genau 40 Spalten, gemeinsamer Rahmen `_bonus_frame()` (Einstieg fällt in
  Spalte B0+3 aus Zeile 4, Ausgang Seitenröhre unten rechts bei B1-6,
  Decke optional). Stil + Thema (Aussehen, Hintergrund, Musik): 1-1
  classic (Höhle, das Original), 1-2 heaven (Abendwolken, Münzherz,
  Wolkenstufen), 1-3 blocks (Kristallhöhle voller ?-Blöcke), 2-1 pillars
  (Säulen mit Münztürmen), 2-2 lifts (Lifte + Hochregal), 3-1 pyramid
  (offener Wüstenhof, Stufenpyramide), 3-2 grotto (Unterwasser, Münz-
  welle zwischen Korallen), 4-1 ice (Eisbahn unter freiem Himmel), 4-2
  zigzag (Nacht-Turm aus Eisregalen, Jackpot oben), 5-1 slabs (fallende
  Wolkenplatten + Kippplanke über Wolkenboden). Keine Gegner, kein
  tödlicher Abgrund; teils versteckte 1-UPs (`h`) und 10-Münz-Ziegel.
  Deko nie in die Zellen der Ausgangsröhre setzen (B1-6..B1-2, Zeilen
  15/16) — die Röhre wächst nur durch leere Zellen.- `level.gd` baut das TileSet **zur Laufzeit** aus `tiles.png` (Physik-
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
4-1 … 4-3, 5-1 … 5-3, 6-1 … 6-3, 7-1 … 7-3, 8-1 … 8-3 (x-4/x-3 =
Burg); nach dem letzten Kurs (8-3) Siegerbildschirm.

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
- **Stampfen** (v0.14, Nutzer: „zu penibel“, „zwei überlappende Gegner
  kosten ein Leben“): jeder Gegner fragt `Player.can_stomp(top, h)`. Zählt,
  wenn der Held fällt ODER vor < 0,12 s noch fiel (`_fall_t`) und seine Füße
  in den letzten 3 Frames (`_feet_hist`) im oberen ~60 % der Hitbox waren.
  Grund: Area2D-Überlappungen kommen einen Physik-Frame zu spät an — wer
  auf der Schulter eines Pilzes landet, steht beim Prüfen oft schon mit
  vy = 0 am Boden (vorher: nur oberste 4–5 px, nur Vorframe → Leben weg).
  Nach einem Stampfer (`stomp_grace` 0,12 s) wird ein zweiter berührter
  Gegner ebenfalls gestampft statt zu verletzen.
- Überlappende Läufer (Pilz/Schildkröte, eine fällt auf die andere) laufen
  jeden Frame auseinander (`_separate_walkers()` in shroom.gd/turtle.gd);
  vorher liefen exakt deckungsgleiche Gegner für immer im Gleichschritt —
  die Schildkröte verdeckte den Pilz.
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
  Kette 500/800/1000/2000/4000/5000/8000, dann 1UP. **Auszahlungs-Limit
  (v1.2.1, Nutzer: eingeklemmter Panzer zwischen zwei Röhren = endlos
  Punkte/Leben)**: `paid` zählt Stampf- und Kick-Punkte einer Schildkröte
  (ein 1UP zählt als ganzes Limit); ab `PAYOUT_LIMIT` 10000 zerbricht sie
  (`kill_flip`). Feuerball/Zunge/Stern
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

Leben (1–9), Schwierigkeit (Gegnertempo ×0,8/1,0/1,25 — alle Gegner,
auch Meteorfelder; Easy +100 Zeit), „Boss fight“ (v1.5.1: As game / Easy /
Normal / Hard — Boss-Schwierigkeit unabhängig vom Rest,
`GameSettings.boss_difficulty(cfg)`; „As game“ folgt Difficulty),
Timer (Off/Level/Short = 75 %), Münzpunkte (0/100/200/500), 1-UP-Münzen
(Off/50/100/200), 1-UP-Punkte (v0.15: Off/2500/5000/10000/20000 —
`game.gd::add_score` zählt überschrittene Schwellen, zustandslos), „Start
big“, „Double jump“. Die Zeilen scrollen (`ScrollContainer`,
`follow_focus`), die Knöpfe darunter bleiben sichtbar. Sound-Unterseite: Regler pro Sound (30 Stück,
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

- `_selftest.gd` (headless): sammelt ALLE Skripte selbst (`_all_scripts()`)
  und verlangt `can_instantiate()` — `load() != null` allein meldete in
  v1.1 einen Kompilierfehler nicht (Exit 0!). Prüft außerdem 16:9, InputMap
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
  Sound-Menü), fixes (Stampfen am Rand, Läufer-Überlappung, Doppel-
  Stampfer, Fledermaus-Warnung/-Flughöhe, Burg-Stimmungen), cheatpick
  (Levelauswahl per Pad-Code + Pad/Tipp), bossfair (Ankündigung, Stun,
  Verpuffen, kein Feuer nach oben, Blumen-Abwurf), bossanim (Bildstreifen
  der Boss-Animation), lifepoints (Extraleben nach Punkten, Scrollen der
  Settings), save (v1.2: Autosave, Quit-Dialog mit Name, Continue, Game
  Over löscht, New-Game-Rückfrage, Levelauswahl lässt den Spielstand in
  Ruhe), polish (v1.2.1: Panzer-Limit, Boss je Schwierigkeit + nichts nach
  oben, alle zehn Bonusräume mit Screenshot, Drache an der Grotte,
  benannter Lauf ohne Namensfeld, „Clear list“), water (v1.3), ghost
  (v1.4), volcano (v1.5), turns (v1.6), coop (v1.7), nethost/netguest +
  netshow/netwatch (v1.8, zwei Fenster), onlinehost/onlineguest (v1.9,
  + lokaler Relay). **Jedes Szenario sichert `savegame.cfg`, `hall_of_fame.cfg` und
  `settings.cfg` vorher und stellt sie danach wieder her** (Autosave/Game
  Over schreiben sonst in die echten Dateien des Entwicklungsrechners).
  Synthetische Mausklicks zählen in
  Godot nur, solange der ECHTE Zeiger über dem Testfenster ist — daher nur
  Pad und Touch automatisch prüfen.
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

## Welt 6 „Sea“ (v0.13)

- 6-1 „Coral Reef“ (Thema `sea`), 6-2 „Deep Trench“ (`sea_deep`, dunkler),
  Burg 6-3 „Tide Fortress“ mit dem Endboss. Die Unterwasser-Bereiche enden
  mit einer Seitenröhre in der Riffwand → Bereich `exit` Thema `beach`
  (Sandstrand mit Palmen, Fahne + Burg; `make_levels.py::beach_exit`).
- **Schwimmen** (`player.gd::_swim`, `swimming` setzt `game.gd::_enter_area`
  für `Level.WATER_THEMES`): Schwerkraft 300, max. Sinken 90 px/s, jeder
  Sprung-Druck = Schwimmzug (−150 px/s, Sound `swim`), 75 / 105 (Rennen)
  px/s, am Grund 55; Kopf bleibt unter der Wasseroberfläche `SWIM_TOP`
  (44 px). Animation `swim` (Frames climb/jump). Kein Doppelsprung nötig.
  Oberfläche = `v`-Kacheln in Zeile 2 (`add_surface()` NACH dem Graben der
  Gruben aufrufen — `pit()` löscht die ganze Spalte).
- Der Drache kann nicht schwimmen: in einem Unterwasser-Kurs wartet er
  (`game.gd::_dino_parked`) und ist im nächsten Kurs wieder da — außer der
  Held verliert ein Leben. Seit v1.2.1/v1.3 allgemein
  (`game.gd::_update_dino_water()`, jeden Physik-Frame in PLAYING): sobald
  der Held auf dem Drachen schwimmt (Wasser-Bereich, Bonus-Grotte 3-2,
  Burgbecken), bleibt der Drache zurück (`Player.park_dino()`); steht der
  Held wieder auf trockenem Boden (kein Schwimmen, kein Wasser-Bereich),
  steigt er wieder auf — auch am Strand-Ausgang von 6-1/6-2.
- Biom `sea`: `#` = Riff-Autotile (Atlas-Reihe 11, Sand mit Korallenkappe),
  `w` = Korallenziegel (10/6), Innenvarianten (10/7–9); Deko Seetang
  (wiegt sich: `Level.SWAYING`, Tween auf `skew`, Drehpunkt am Fuß),
  Koralle, Seestern, Seegras, Fels. Biom `beach`: Sand-Autotile, `*` Palme.
- Hintergrund `sea`/`sea_deep`: Lichtstrahlen, Riffhügel, Kelpwald, nahe
  Felsen, Partikel `bubbles`, Welt-Tönung bläulich; `beach`: Meer mit
  Glitzern + Palmen. Musik `music_sea` „Coral Waltz“ (Es-Dur-Walzer 100 bpm).
- Gegner: `e` gelber Fisch (langsam, Wellen), `E` roter Fisch (schnell,
  steuert auf die Tiefe des Helden) — beim Schwimmen nicht stampfbar;
  `j` Qualle (`jellyfish.gd`: sinkt, stößt schräg zum Helden hoch);
  `z` Krabbe (`crab.gd`, `extends Shroom`, stampfbar); `i` Seeigel
  (`urchin.gd`, Hindernis, unbesiegbar, nicht in `enemies`).
- Boss Welt 6 „Tide King“ (türkis, 5 HP): wählt jedes Mal Fächer / Eisbälle /
  Blitze, bei jeder zweiten Landung Schockwellen.
- Hilfeseite „Sea World“; Playtest `sea`.

## Becken + Strömungen (v1.3)

- **Becken** (`L.pools` in make_levels.py → Level-Konstante `POOLS`,
  Rect2i in Zellen): schwimmbares Wasser in einem trockenen Bereich. Als
  Rechteck-Metadaten statt Rasterzeichen, damit Münzen/Seeigel mitten im
  Wasser liegen können. `level.gd::in_pool(p)`, eigene, hellere
  Wasserebene `PoolWater` (modulate α 0,55 — der Held muss sichtbar
  bleiben; das Gruben-Wasser `v` der frühen Welten bleibt trüb).
- `player.gd`: `swimming = area_water or in_pool(Körpermitte)`
  (`area_water` setzt game.gd für ganze Unterwasser-Bereiche, nur dort
  gilt der `SWIM_TOP`-Deckel). Im Becken: Sprung, solange der Kopf ≤ 12 px
  unter der Oberfläche ist → echter Sprung heraus (`_leap_t` 0,35 s
  Trockenland-Physik, reicht auf einen Rand in Oberflächenhöhe).
- **Strömungen** (`L.currents` → `CURRENTS`, [Rect2i, dir]): schieben den
  Schwimmer mit `CURRENT_PUSH` 45 px/s (Schwimmen 75 / Rennen 105
  dagegen). Sichtbar als wandernde Streifen (`current_fx.gd`, `CurrentFx`,
  z 3). Vorschau (`--preview`) zeichnet Becken + Pfeile.
- Burg 6-3 „Tide Fortress“ ist teilweise geflutet: `_sec_moat` (Graben
  mit Rand, zwei Steinzähne bis unter die Oberfläche → durchtauchen,
  Gegenströmung unter dem zweiten) und `_sec_tank` (Treppe hoch auf einen
  8 hohen Tank, Strömung quer durch die Mitte — oben oder unten
  schwimmen, Seeigel am Grund, am rechten Rand herausspringen).
  Fische kommen NICHT in Becken (sie schwimmen kollisionsfrei geradeaus
  und würden das Becken verlassen).
- 6-1/6-2: je eine helfende Strömung weit oben (über Riff bzw. Graben)
  und eine Gegenströmung (über den Gruben bzw. im niedrigen Tunnel).
- Hilfeseite „Pools & Currents“; Playtest `water`.

## Welt 7 „Ghost House“ (v1.4)

- 7-1 „Haunted Hall“ (Thema `ghost`: Villa innen, Tapete + Vorhänge +
  Ahnenbilder, Decke), 7-2 „Moonlit Graveyard“ (`ghost_yard`: Friedhof
  bei Nacht, Villa am Horizont), Burg 7-3 „Phantom Keep“
  (`fortress_ghost`, violett, Nebel). Musik `music_ghost` „Haunted Waltz“
  (e-Moll, 92 bpm); Burg wie immer `music_castle`.
- Biome: `ghost` (`#` = Dielenboden, Atlas-Reihe 12, `w` = violette
  Ziegel), `grave` (Friedhofserde-Autotile Reihe 13, `w` = Gruftziegel
  `CRYPT_BRICK`); Reihe 14 Extras (Holzvertäfelung `GHOST_PANEL`,
  Innenvarianten). Deko `ghost`: `*` Kandelaber, `+` Sessel, `f` Kürbis,
  `t` Kerze (flackert), `r` Knochen; `grave`: `*` toter Baum, `+`
  Grabstein, `t` Grasbüschel, `r` Kreuz.
- **Türen** (`H` im Raster = Bodenzelle VOR der Tür, `door.gd`, `Door`):
  Paare über `WARPS` mit `kind`/`arrive_kind` „door“ (`make_levels.py`:
  `L.door(c, r=None)` + `L.link(a, b, area_a, area_b, both=True)`).
  `warp_zone.gd` Art „door“: **just_pressed** ↓ (oder `ui_up`) innerhalb
  8 px — gehaltenes ↓ nach der Ankunft darf nicht sofort zurückführen.
  `game.gd::enter_warp`/`_arrive`: Tür öffnet, Held blendet aus/ein
  (`modulate:a`), Ton `door`. Im Biom `grave` sitzt die Tür in einer Gruft
  (`crypt.png`, 48×44). Selbsttest: Tür-Einstieg = `H` auf festem Boden,
  Ziel ebenfalls `H`.
- 7-1: erste Wand (Tür davor/dahinter), Türraum mit drei Türen (die unter
  den Münzen führt weiter, links zurück zur ersten Wand, rechts in eine
  Münzkammer `closet`), einstürzender Boden (`D`-Bretter über einer
  Grube; `L.ceiling` nach `pit()` erneut setzen — `pit()` räumt die ganze
  Spalte), Hintertür in der Endwand → Friedhof `exit` mit Fahne.
  7-2: offene Gräber, Grabhügel, eine zu breite Kluft, die nur die zwei
  verbundenen Grüfte überbrücken, lose Grabplatten (`D`), geheime Gruft
  zu einem Sims mit Münzen (219, 8).
- Gegner: `l` Geist (`ghost.gd`: schwebt durch Wände auf den Helden zu,
  solange der wegschaut; schaut er hin, erstarrt er halb durchsichtig
  „schüchtern“; Feuer wirkungslos, Stern/Panzer/Zunge vertreiben ihn),
  `O` Knochen-Schildkröte (`bone_turtle.gd`: läuft, dreht an Kanten;
  Stampfen/Feuer → Knochenhaufen, nach 4 s (1 s Klappern) steht sie
  wieder auf; nur Stern/Panzer/Zunge erledigen sie). Burg 7-3: Abschnitte
  `_sec_haunt` (Geister-Halle, Knochen-Schildkröten auf zwei Simsen) +
  `_sec_doors` (drei Türen vor einer Wand: die mittlere unter den Münzen
  führt dahinter, die äußeren tauschen nur die Plätze), Gegner-Halle mit
  Knochen-Schildkröten.
- Boss Welt 7 „Phantom-König“ (blass violett, 5 HP): Fächer aus drei
  Flammen wie Welt 2, dazu `_phase()` — blendet aus (0,4 s), taucht auf
  der anderen Seite des Helden wieder auf und holt aus; währenddessen
  unberührbar und harmlos (`_phase_t`).
- Hilfeseite „Ghost House“; Playtest `ghost` (Geist schüchtern/jagt,
  alle Türen in 7-1/7-2, Knochenhaufen steht wieder auf, Phasen des
  Bosses ohne Feuer nach oben, Karte Region 7).

## Welt 8 „Volcano“ (v1.5) — letzte Welt, Endboss

- 8-1 „Ashen Slopes“ (Thema `volcano`: brennender Himmel, rauchender
  Vulkan mit Lavaströmen, Lavafelder, Basaltspitzen, Partikel `ash` —
  graue Flocken, manche glühen noch), 8-2 „Magma Core“ (`volcano_core`:
  rote Höhle mit Lavafällen, Partikel `embers`; Ausgang per Röhre auf den
  Kraterrand `exit` mit Fahne), Burg 8-3 „Inferno Keep“
  (`fortress_volcano`, die längste Burg: 7 Abschnitte). Musik
  `music_volcano` „Magma March“ (c-Moll, 144 bpm); Burg `music_castle`.
  Bonusraum 8-1: eigener Stil `forge` (Obsidian-Ambosse mit Münztürmen,
  Thema `volcano_core`).
- Biom `volcano`: `#` = Basalt unter Asche (Atlas-Reihe 15, glühende
  Glutpunkte in der Kruste), Innenvarianten Reihe 14 Spalten 10–13 (mit
  glühenden Adern), `w` = Obsidian mit Magmafugen (`OBSIDIAN` 9/14).
  Deko: `*` Lavafels, `+` Schlot (flackert), `f` Glutblume, `t`
  Flämmchen (flackert), `r` Basaltbrocken.
- **Magma-Klecks** `m` (`magma_blob.gd`, `MagmaBlob`): hüpft auf den
  Helden zu. Gestampft erstarrt er für `COOL` 5 s zu einem Fels (Welt-
  Layer 1 → man kann draufstehen, Stufe zu hohen Simsen), glüht die
  letzte 1,2 s und schmilzt zurück — nie, solange der Held darauf steht.
  **Lava ist sein Element**: Klecks und Fels liegen auf der Lava-
  Oberfläche (`_rest_on_lava()`, 1 px eingesunken) → ein über Lava
  gestampfter Klecks wird zur schwimmenden Trittfläche. Feuer wirkungslos
  (`fire_hit()` leer), Stern/Panzer/Zunge erledigen ihn.
- **Salamander** `d` (`salamander.gd`, `extends Shroom`): läuft, dreht an
  Kanten; steht der Held vor ihm auf ähnlicher Höhe (< 190 px), bleibt er
  0,5 s mit offenem Maul stehen (Warnung) und spuckt eine kleine Flamme
  waagrecht über den Boden (`BossFlame` Art `spit`). Stampfbar, Feuer
  wirkt.
- **Meteorfelder** (`L.meteors` → Level-Konstante `METEORS` =
  [Vector2i(c0, c1)], `meteor_field.gd`, `MeteorField`): solange der Held
  in den Spalten ist, fällt alle 1,5–2,3 s (Schwierigkeit skaliert) ein
  brennender Fels nahe seiner Laufrichtung (`BossFlame` Art `meteor`,
  fällt `METEOR_FALL` 1 s schräg auf einen blinkenden Ring am Boden,
  `MeteorMark`; Ton `meteor` = Pfeifen + Einschlag genau bei der
  Landung). 8-1 hat zwei Felder. Selbsttest prüft die Grenzen.
- **Endboss Welt 8 „Volcano Lord“** (Lava-Farben, 6 HP): wählt jedes Mal
  Fächer / zwei Magmakugeln (`magma` = springt wie `ice`, orange) /
  gezielte Flamme + Meteorregen (drei Meteore um den Helden, `_meteors()`),
  Schockwellen bei jeder zweiten Landung, ab und zu `_phase()` wie der
  Phantom-König. Nie nach oben (Magmakugeln waagrecht ausgespuckt).
  Danach „YOU WIN!“ (Siegerbildschirm).
- Hilfeseite „Volcano“; Playtest `volcano` (Spucke, Fels + Draufstehen +
  nicht schmelzen + Schmelzen, Fels auf Lava, Feuer-Immunität, Meteore
  + Treffer + nichts außerhalb des Felds, 8-2-Ausgang, Boss mit allen
  Angriffen, Sieg nach 8-3, Karte Region 8).

## Zwei Spieler: Mario + Luigi (v1.6 abwechselnd, v1.7 Coop)

Nutzerwunsch 2026-10-02 (angeregt von Mario Bros. 1983): auf Geräten mit
zwei Controllern oder Tastatur gleichzeitig im Coop, sonst abwechselnd.
Entscheidungen des Nutzers: **jeder hat eigene Leben**; **Luigi sieht
anders aus und springt minimal höher, rutscht aber NICHT mehr** (schlechte
Erfahrung mit Rutschen — Bodenbremse also identisch); **Coop trägt sich
als Team** in die Bestenliste ein. Umsetzung in zwei Stufen: v1.6.0
abwechselnd (läuft überall), v1.7.0 Coop (siehe `TODO.md`).
- **Luigi**: Palettentausch derselben Pixel-Maps (`gen_sprites.py`
  `LUIGI_SWAP`: grüne Mütze/Hemd, dunkelblaue Latzhose; `LUIGI_FIRE_SWAP`:
  weiß mit grüner Hose) → `luigi_{small,big,fire,small_fire}.tres`.
  `Player.hero` (0/1), `Player.frames_for(hero, power)`, Sprung- und
  Doppelsprung-Tempo × `JUMP_MUL[1]` = 1,035 (≈ +7 % Höhe, gemessen
  63 → 67 px). `HERO_NAMES`/`HERO_COLORS` für HUD/Karte/Menüs.
- **Abwechselnd (SMB1-Regel)**: der Zug wechselt, wenn ein Spieler ein
  Leben verliert. `game.gd` hält immer die Werte des AKTIVEN Spielers
  (score, coins, lives, power, has_dino, level_index, `_run_reach`,
  `_run_best`, run_id, run_name, checkpoint_pos, `_in_course` =
  `SLOT_FIELDS`), der wartende liegt in `_other`; `_swap_turn()` tauscht.
  Wer im Kurs starb, macht beim nächsten Zug direkt dort am Checkpoint
  weiter (Karte „MARIO/LUIGI WORLD x-y“), Luigis erster Zug beginnt auf
  der Karte („LUIGI'S TURN“). Eigene Karte/Fortschritt pro Spieler.
  Ohne Leben: Karte „MARIO GAME OVER“, der andere spielt allein weiter;
  Game Over erst, wenn beide raus sind. Kurse geschafft → wie bisher
  zurück zur Karte desselben Spielers (kein Wechsel).
- Titel „Play“ / „New Game“ → Bildschirm `PLAYERS` („1 Player“ / „2
  Players - take turns“, `menus.take_players()`). Levelauswahl immer 1
  Spieler. „Play Again“ behält die Spielerzahl.
- HUD: Spaltentitel SCORE → Name in Spielerfarbe (`Hud.set_player`),
  Kurs-Karte mit Name + Luigi-Symbol; Karten-Banner „LUIGI:  1-1 …“
  (`WorldMap.hero_index`/`player_label`).
- **Spielstand**: `SaveGame.OPT_KEYS` players/turn/reach/other (alte
  Spielstände laden weiter als 1 Spieler); `Game._slot_to_save()` /
  `_slot_from_save()`. Titel zeigt beide Punktestände.
- **Bestenliste abwechselnd: ein Eintrag pro Spieler** (eigene run_id,
  unbenannt „MARIO“/„LUIGI“ statt „YOU“); Game Over zeigt beide mit je
  einem Namensfeld (`_build_gameover_2p`, A springt zum nächsten Feld).
- Hilfeseite „Two Players“ (beide Modi + Tastenaufteilung); Playtests
  `turns`, `coop`.

### Coop (v1.7, `players == Game.COOP` = 3)
- **Beitreten** (`Menus.Screen.JOIN`, auch beim „Continue“ eines Coop-
  Spielstands): jeder drückt Sprung auf SEINEM Gerät — Pad A, Tastatur
  Space/W/Z/Enter (Mario) bzw. ↑/K/Num0 (Luigi), Mario kann auch tippen
  (= Touch-Tasten). Grund: das RG552 meldet eingebautes D-Pad und Knöpfe
  unter verschiedenen Geräte-IDs — darum bekommt **Luigi genau sein
  Gerät, Mario alle anderen**. Angeboten nur, wenn möglich
  (`Menus.coop_possible()`: nicht auf Handy/Handy-Browser ohne Pad).
- **`CoopInput`** (`coop_input.gd`): baut aus den normalen Aktionen (inkl.
  Umbelegungen) `p1_*`/`p2_*` (left/right/down/up/jump/run) mit
  aufgeteilten Geräten; `Player.act` zeigt darauf. Tastatur zu zweit:
  Mario A D S + W/Space/Z + Shift/J/X/Ctrl, Luigi Pfeile + ↑/K/Num0 +
  L/Num. (K gehört dann Luigi). `ControlsConfig.apply()` lädt die InputMap
  neu → nach Pause/Settings/Pad-Anschluss `CoopInput.build()` erneut.
  Normale Aktionen bleiben für Menüs/Karte/Pause/Mute (alle Geräte).
- **Spiel**: `heroes` [Mario, Luigi], `co_lives`/`co_power`, Punkte und
  Münzen gemeinsam (HUD „TEAM“, Leben „M2 L1“, „-“ = raus). Die Helden
  kollidieren miteinander (`Player.base_mask` 3): aufeinander stehen,
  vom Kopf abprallen (`_check_partner_bounce`), kein Schaden. Gegner
  zielen über `Game.target_for(pos)` auf den nächsten Helden; Plattformen,
  Magma-Fels, Meteorfeld, Flammen prüfen `all_heroes()`. Feuerbälle max. 2
  pro Held (Meta `hero`).
- **Kamera** (`_update_camera_coop`): Mitte beider, solange der Abstand
  < Breite − 80 px, sonst folgt sie dem Vorderen. Der linke Bildrand
  schiebt den Hinteren mit (`left_limit`, Verschieben per
  `move_and_collide` — nie in eine Wand teleportieren); hängt er hinter
  einer Wand fest (0,5 s außerhalb des Bilds) → **Blase**
  (`Player.Mode.BUBBLE`, `start_bubble`/`pop_bubble`, `_draw`): schwebt
  zum Partner, platzt auf dessen Kopf bzw. daneben, wenn dort frei ist
  (`_free_spot`, `_side_spot` — **nie in den Partner setzen**: zwei
  überlappende Helden schoben sich gegenseitig durch Wände bis zur Fahne).
- **Tod**: lebt der Partner, fällt nur dieser Held heraus (kein Einfrieren)
  und kommt mit Restleben als Blase zurück, ohne Leben „IS OUT“ (ein 1UP
  bringt ihn zurück, `_revive`; 1UPs ohne Empfänger gehen an den mit
  weniger Leben). Stirbt der letzte → normale Todessequenz, Kurs neu am
  Checkpoint (Game Over, wenn beide 0). Schweben alle in Blasen → „TRY
  AGAIN!“, Neustart ohne weiteren Lebensverlust. Zeit abgelaufen → alle.
- **Röhren/Türen/Fahne**: der Partner wird mitgenommen (`_carry_partner`,
  `_place_carried`, `_release_carried`), Drache: einer, wer zuerst
  aufsteigt; im Wasser geparkt für seinen letzten Reiter (`_dino_rider`).
- **Bestenliste**: ein Team-Eintrag, unbenannt „MARIO+LUIGI“, Namensfeld
  bis 12 Zeichen. Spielstand: `co` = {lives, power}; Karte mit Luigi
  neben Mario (`WorldMap.coop`/`partner`).
- `tools/playtest.gd` sichert die echten Spielstand-Dateien seit v1.7
  zusätzlich nach `user://_playtest_backup/` und spielt sie beim nächsten
  Start zurück, falls ein Lauf mit Skriptfehler abbrach (so waren Test-
  Einträge in die echte Bestenliste geraten).

## Wi-Fi-Coop (v1.8, Stufe 1 von 2)

Nutzer 2026-10-02: zwei Geräte am selben Spiel — Stufe 1 lokales WLAN,
Stufe 2 Internet (erst nach Freigabe durch einen Verbindungstest).
- **Prinzip: Host rechnet, Gast zeigt.** Mario-Gerät = Host spielt ein
  normales Coop-Spiel (`players == COOP`, Luigi ohne lokales Gerät,
  `CoopInput.reset()`); Luigis Tasten kommen per Netz und werden auf die
  `p2_*`-Aktionen gedrückt (`NetHost._apply_mask`). Der Gast (`State.NET`)
  rechnet nichts, er zeigt nur.
- **`NetLink`** (`net_link.gd`): ENet (UDP) Port 47111, Kanal 0
  zuverlässig (Szene, Sounds, Eingaben, String-Tabelle), Kanal 1
  unzuverlässig (Snapshots); Nachrichten `var_to_bytes([typ, daten])`,
  nie Objekte. `Discovery`: Host lauscht auf 47110 und schickt jede
  Sekunde ein Beacon an 47112, der Gast lauscht auf 47112 und fragt per
  Broadcast „FIND“ (+ 127.0.0.1 für Tests), der Host antwortet direkt —
  klappt auch, wenn eine Seite eingehende Broadcasts verwirft (Android
  ohne Multicast-Lock). Fallback: Adresse eintippen (der Host zeigt seine
  WLAN-Adressen, `last_host` in den Settings). Nur nativ — der Browser
  kann kein UDP (Menüpunkt dort ausgeblendet, `Menus.wifi_possible()`).
- **`NetHost`** (30 Snapshots/s, deflate-komprimiert): Szene (`level`
  mit Kursindex / `map` / `wait` mit Text), Kamera (für die Bildschirm-
  größe des Gasts geklemmt), Theme, HUD (`Hud.net_state`), Karte
  (`WorldMap.net_state`) bzw. alle sichtbaren beweglichen Dinge des
  Kurses: Baum durchlaufen, Knoten mit Meta `net_static` überspringen
  (Tiles, Wasser, Becken, Strömungs-Streifen, Deko, Burg), pro Ding 9
  Ints + 12 Floats (Art, Ressource/Animation über String-Tabelle,
  Frame, Flags, z, Transform, Offset, Farbe — Modulate-Kette
  ausmultipliziert). Arten: AnimatedSprite2D, Sprite2D (Pfad oder
  `atlas|pfad|region`), ScorePopup, Effekte (Sparkle, JumpPuff,
  StunStars, MeteorMark — der Gast erzeugt dieselbe Klasse), Blase,
  Drachenzunge (statische Zeichenfunktionen `Player.draw_bubble_on`,
  `Dino.draw_tongue_on`). Nur was im Blickfeld des Gasts liegt (+96 px).
  Unbekanntes meldet `push_warning("NetHost: can't send …")`.
  Sounds: `SoundManager.net_tap` → alle play/music-Aufrufe gehen mit.
- **`NetClient`**: baut den festen Teil selbst (`Level.visual_only` —
  nur Tiles, Wasser, Deko, Burg), Puppets nach Netz-ID, gleitet
  Positionen und Kamera von Snapshot zu Snapshot (Sprünge > 48 px ohne
  Gleiten), eigene Lautstärke/Mute, sendet `in` (Bitmaske left, right,
  down, up, jump, run bei Änderung), `vp` (Bildschirmgröße), `pause`.
  Versionen müssen in Major.Minor gleich sein („hello“).
- **Abläufe**: Titel > Play > „2 Players - Wi-Fi“ > Host / Join; ein
  gespeichertes Coop-Spiel lässt sich per „Luigi via Wi-Fi“ fortsetzen.
  Pause von beiden Seiten (Gast: eigenes Menü Resume / Settings / Help /
  Leave). Gast weg → Banner „LUIGI LEFT - WAITING“, er kann wieder
  beitreten. Host zum Titel → Hosting endet, Gast bekommt „Mario ended
  the Wi-Fi game.“ Android: Berechtigungen internet, access_network_state,
  access_wifi_state, change_wifi_multicast_state.
- Tests: `nethost` + `netguest` bzw. `netshow` + `netwatch` in ZWEI
  Fenstern gleichzeitig (127.0.0.1); vorher sicherstellen, dass kein alter
  Testprozess den Port 47111 hält (sonst „error 20“ und der Gast landet
  beim alten Host). Hilfeseite „Wi-Fi“.

- **v1.9.3 (Nutzer)**: Menüpunkt heißt „2 Players - LAN / Wi-Fi“ (gemeint
  ist das lokale Netz, Kabel oder WLAN; nicht: Gäste-WLAN/getrennte
  Teilnetze). Hinweise im LAN-Menü, in der Host-Suche, bei „keine
  Antwort“ und auf der Hilfeseite: Host-PC mit Firewall → UDP 47110–47111
  freigeben; ohne Admin-Rechte (Schulnetz) geht „Online“ immer
  (ausgehende Verbindung zum Relay, keine Freigabe nötig). Android-Hosts
  und Gäste brauchen nie eine Freigabe, Windows fragt beim ersten Hosten.
  Playtest `lanmenu` (passen die Hinweise auf den Schirm).

## Online-Coop (v1.9, Stufe 2)

Freigabe nach dem Wi-Fi-Test (Nutzer 2026-10-02: „Klappt alles super“).
Server: Uberspace **vega.uberspace.de**, Domain **broesel.net**.
- Gleiches Prinzip wie Wi-Fi (Host rechnet, Gast zeigt), nur der Weg ist
  ein WebSocket zu einem **Vermittlungsdienst** (`server/relay.js`, Node +
  `ws`): Raum öffnen → 4-stelliger Code (ohne 0/O/1/I), Beitreten mit
  Code, danach reicht er Binär-Nachrichten 1:1 weiter; Steuer-Nachrichten
  als JSON-Text (host/join → room/joined/left/error), Grund beim Schließen
  im Close-Frame (`NetLink._poll_ws` → Ereignis „closed“ mit Text).
  Limits: 1 MB pro Nachricht, 200 Räume, Ping alle 20 s.
- **Raum-Codes ohne Doppelgänger (v1.9.1)**: im ersten Test Browser ↔
  RG552 (2026-10-02, über broesel.net) wurde „SV85“ als „5V85“ gelesen —
  S und 5 sehen in der Pixelschrift gleich aus. `CODE_CHARS` =
  `ABCDEFGHJKLMNPQRSTUVWXYZ3479` (keine 0 1 2 5 6 8, kein I O), und
  `Menus.clean_code()` macht aus getippten 5/2/8/6/0/1 die Buchstaben
  S/Z/B/G/O/I. **Nach Änderungen an relay.js das Deploy-Skript erneut
  ausführen** (Nutzer).
- **Beitreten ohne Spielstand-Warnung (v1.9.1)**: Titel „New Game“ führt
  direkt zur Spielerauswahl; die Rückfrage „NEW GAME? Your saved run will
  be replaced“ kommt erst vor etwas, das hier wirklich ein neues Spiel
  startet (`Menus._confirm_new()`: 1 Player, take turns, together, Host
  Wi-Fi/Online). Als Luigi beitreten fasst den Spielstand nie an.
- **v1.9.2** (zweiter Test Browser ↔ RG552): der allererste WebSocket-
  Aufbau nach App-Start scheiterte einmal („No connection to the online
  server“, broesel.net nur IPv4 95.143.172.245, kein IPv6-Problem) →
  `NetLink` versucht bis zu 3× still neu (`WS_TRIES`), solange der
  Server nie erreicht wurde. Beitreten-Bildschirm: Enter ist keine
  Beitreten-Taste mehr (drückt den gewählten Knopf), ein erneutes
  Leertaste/A des schon beigetretenen Mario drückt den gewählten Knopf,
  aber nie „Back“ (`_focus_is_cancel`); beim Fortsetzen steht der Fokus
  auf „Luigi via Wi-Fi“/„Luigi online“.
- Test mit dem RG552 ohne Zutun des Nutzers: Spiel per `monkey` starten
  (nur tagsüber!), Menüs per `adb shell input keyevent` (DPAD/ENTER),
  Code per `input text` + Tipp auf den Haken der Bildschirmtastatur,
  Gamepad gedrückt halten per `sendevent /dev/input/event3`
  (`retrogame_joypad`: ABS_HAT0X = 16 für links/rechts, BTN_SOUTH = 304 =
  A) — `input keyevent --longpress` hält nicht.
- Adresse: `application/config/relay_url` in project.godot
  (`wss://broesel.net/mario-relay`), Settings-Schlüssel `relay_url`
  überschreibt (Tests: `ws://127.0.0.1:8765`). Menüpunkt „2 Players -
  Online“ nur, wenn eine Adresse gesetzt ist; läuft auch im Browser.
- Online 20 statt 30 Snapshots/s (Takt mit Rest, sonst 15/s); der Gast
  misst den Abstand und gleitet entsprechend (`_snap_dt`). Eigene
  Ping-Messung (ping/pong alle 2 s, `NetClient.rtt_ms`). Schnelle Daten
  werden verworfen, wenn > 256 KB im Sendepuffer warten.
- **Einrichten/aktualisieren**: `server/deploy_uberspace.sh <benutzer>`
  (kopiert relay + Web-Build nach `~/html/mario-clone/`, `npm install`,
  supervisord-Dienst `~/etc/services.d/mario-relay.ini`,
  `uberspace web backend set /mario-relay --http --port 8765`). Details
  `server/README.md`. `server/` hat `.gdignore`, `node_modules` ist
  gitignored.
- Abschied: `NetLink.close()` gibt erst die Warteschlange ab (ENet:
  `peer_disconnect` verwirft noch Wartendes, darum flush davor) → Gast
  sieht „Mario ended the game.“
- Tests: `onlinehost` + `onlineguest` (zwei Fenster + lokaler Relay
  `cd server && PORT=8765 node relay.js`; Raum-Code über `room.txt` im
  Ausgabeordner). Hilfeseite „Online“.

## Biom-Gegner (v0.9)

- `a` Fledermaus (`bat.gd`, Höhle; `L.bat(c)` setzt sie direkt unter die
  Decke): schläft kopfüber, erwacht nur deutlich innerhalb des Bildes
  (Held < 96 px daneben, darunter), flattert 0,5 s auf der Stelle
  (Warnung + Ton), stürzt dann herab und fliegt wellenförmig weiter (durch
  Wände). Seit v0.14 (Nutzer: „schlecht zu erkennen, oft kein Ausweichen“)
  hell violett mit gelben Augen und Flughöhe `FLY_H` = 28 px über den
  Füßen des Helden (Hitbox-Unterkante ≥ 18 px darüber): klein läuft man
  drunter durch, groß duckt man sich. Stampfbar.
- `p` Kaktusturm (`cactus.gd`, Wüste): 3 (Welt 4: 4) schwankende Stachel-
  kugeln, kriecht zum Helden. Stachelig: Stampfen verletzt! Jeder Feuerball
  schlägt eine Kugel ab (`fire_hit()`, +200); Panzer/Stern/Zunge/Block von
  unten erledigen den ganzen Turm.
- `q` Pinguin (`penguin.gd`, `extends Shroom`, Schnee): schneller Läufer,
  rutscht alle paar Sekunden 1,1 s bäuchlings mit 2,6-fachem Tempo.
Feuerball ruft zuerst `fire_hit()` auf, falls vorhanden (Boss, Kaktus).

## Burgen + Boss (v0.8)

**Jede Burg eigen** (v0.14: 3-3 und 4-3 waren byte-gleich, die
Levelauswahl schien darum „den alten Kurs“ zu starten; v0.15: „noch zu
ähnlich, immer Säulen zuerst“): `make_levels.py` hat positionsunabhängige
Abschnitte `_sec_*(L, c, world)` mit Breite in `SECTION_WIDTH` —
Säulen, Stufen, Feuerstab-Gang, Ziegelbrücke, Lifte, niedriger Gang,
fallende Platten, Kippplanken, Lavasee, Blasen-Säulen, Hublifte, Gegner-
Halle (Welt-Gegner; Welt 4 mit Eisboden), Treppenturm, Feuerstab-Zähne.
`CASTLE_PLAN` legt je Welt Reihenfolge (jede Burg beginnt anders) und
Stimmung fest; 3 Bodenspalten Abstand, Mittel-Flagge vor dem mittleren
Abschnitt, danach der feste Schluss (?M?-Blöcke, Boss-Checkpoint, Arena).
Die Burglänge variiert (179–204 Spalten; Arena = `ARENA` im Level, Tests
lesen sie daraus). Stimmungen (`backdrop.gd`): `fortress` (1),
`fortress_magma` (rot), `fortress_sun` (Bernstein, Sand-Partikel),
`fortress_ice` (blau, Schnee), `fortress_storm` (violett, Wind),
`fortress_tide` (türkis, Blasen). Alle → Biom `castle`, `music_castle`.

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
- **Fairness + Animation (v0.15, Nutzer: „schießt noch, während er
  betäubt ist; Feuer trifft, wenn ich über ihm bin; nach dem ersten Treffer
  keine Munition mehr; wirkt steif“)**: jeder Angriff angekündigt (WINDUP
  0,4 s ausholen / CROUCH 0,2 s ducken); Treffer = STUN 1 s (Sterne
  `stun_stars.gd`, keine Angriffe, kein Laufen), alle fliegenden Geschosse
  verpuffen (`BossFlame.fizzle()`), danach weicht er vom Helden weg
  (`_retreat`, nie durch ihn hindurch) und wartet ≥ 1 s; kein Feuer, wenn
  der Held (fast) über ihm ist; hat der
  Held keine Feuerkraft, wirft der Boss bei jedem Treffer eine Feuerblume
  in die ferne Arenahälfte (`PowerUp.toss_to`).
- **Nie nach oben + Schwierigkeit (v1.2.1, Nutzer)**: Flammen fliegen nur
  waagrecht oder nach unten (max. 37°, `MAX_DOWN`), auch jede Fächer-
  Flamme (`_fan`); Eisbälle werden waagrecht ausgespuckt und springen erst
  am Boden hoch (Mindest-Rückprall in `boss_flame.gd`). Settings >
  Boss fight (seit v1.5.1 eigene Einstellung, „As game“ = wie
  Difficulty): `STUN` 1,0 / 0,8 / 0,5 s, Feuerblumen (`FLOWERS`) bei Leicht
  und Mittel, bei Schwer keine — Blumen kommen bei einem Treffer UND
  1,2 s nachdem der Held seine Feuerkraft verloren hat (`_no_fire_t`; der
  Nutzer hatte den Abwurf nie gesehen). Die Feuerblume vor der Arena und
  der Neustart mit Feuerkraft bleiben auf allen Stufen (faire Neustarts). Frames je Boss: idle1/2
  (atmen), walk1-3 (4-Phasen-Zyklus mit Auf und Ab), windup, roar, crouch,
  jump, hurt (`_boss_canvas`: `head`-Versatz, `arm`, `hurt`); Squash &
  Stretch beim Absprung, Landen, Treffer. Stampf-Test über
  `Player.can_stomp(top, h, depth)` mit fester Tiefe 10 px (+ Aufstieg).
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

## Weltkarte (v1.1, ersetzt „Select World“)

- **Kein Start-Hüpfer (v1.5.1)**: A betritt den Kurs UND ist Springen;
  die Welt hält erst am Frame-Ende an (`set_deferred`), der neue Held sah
  also noch „Sprung gedrückt“ und flog nach der Titelkarte weiter (47 px,
  Nutzer: „hüpft am Anfang jedes Levels“). `_begin_level()` setzt
  `player.input_enabled = false` bis die Karte weg ist und leert dann den
  Sprungpuffer. Playtest `starthop`.
- **Ablauf**: Titel „Play“ (`play_pressed(-1)`) → `game.gd::start_map_run()`
  = neuer Lauf (`_new_run()`: Punkte, Münzen, Leben, Kraft, Drache) → Karte
  (`State.MAP`, `_show_map()`), Held auf dem weitesten erreichten Kurs →
  A/Space/Enter oder zweites Antippen → `_enter_course()` → Kurs. Nach dem
  Ziel/Boss (`_level_done`) zurück zur Karte: der nächste Kurs wird sofort
  gespeichert (`[progress] level`), der Weg dorthin zeichnet sich (1,1 s)
  und der Held läuft von selbst hin. Tod = Neustart im Kurs wie bisher;
  Game Over → „Play Again“ = neuer Lauf auf der Karte an derselben Stelle.
  Nach dem letzten Kurs Siegerbildschirm. Levelauswahl-Cheat/„Boss“ starten direkt
  (`_start_game`) und landen danach ebenfalls auf der Karte;
  `_run_reach` = max(Fortschritt, gestarteter Kurs).
- **Karte** `world_map.gd` (`WorldMap`, Kind von World, eigene Banner-
  CanvasLayer 9 mit Kursname + Hinweis): Bild + Daten aus
  `tools/gen_map.py` — `assets/graphics/world_map.png` (1860×270, acht
  Regionen nebeneinander: Wiese mit Teich, Höhle mit Bergkamm/Lava, Wüste
  mit Pyramide/Oase, Schnee mit Gipfeln/See, Himmel mit Wolkeninseln +
  Regenbogen, Meer mit Strand/Inseln, Geisterhaus mit Villa/Gräbern/Nebel,
  Vulkan mit Lavastrom und Lavasee
  — jede neue Welt hängt rechts eine Region an: `W`, `REGIONS`, `NODES`,
  `CASTLES`, `BEND`, `PAL` in gen_map.py), `map_nodes.png` (offen gelb /
  geschafft grün mit Haken / gesperrt dunkel mit Schloss), `map_castles.png`
  (Mini-Burg, rote/grüne/graue Fahne), `world_map_data.gd` (`NODES` in
  LEVELS-Reihenfolge, `ROADS[i]` = Bezier-Polylinie von Kurs i nach i+1,
  `ROAD_KIND` dirt/cloud/plank). Wege und Markierungen zeichnet die Karte
  selbst (`_draw`), damit ein Weg aufgedeckt werden kann; offen = Index ≤
  `reach`, geschafft = Index < `reach`.
- **Steuerung**: Richtung → der Nachbar, dessen Weg in diese Richtung
  abgeht (`_neighbour_toward`, Vergleich mit einem Punkt ein Stück den Weg
  entlang); Richtungen VOR Sprung prüfen (↑ ist auch eine Sprungtaste; es
  gibt keine `move_up`-Aktion → `ui_up`). Antippen = emulierter Linksklick,
  Position über `make_input_local(event)` (kein Mauszeiger auf Touch).
  0,4 s Eingabesperre nach dem Erscheinen (gehaltenes A aus dem Kurs).
  Pause geht auch auf der Karte; Touch-Tasten sind dort sichtbar.
- Kamera folgt dem Kartenhelden waagrecht (`game.gd::_physics_process`),
  Backdrop-Thema `map` (keine Ebenen, keine Partikel), Musik `music_map`
  „Adventure Map“ (C-Dur-Marsch, 116 bpm). Hilfeseite „World Map“.
- Playtest `map` (Laufen, gesperrter Kurs, Pause, Betreten, Ziel → Weg
  aufdecken + speichern, Antippen) — setzt `[progress]` kurz auf 1-3 und
  stellt ihn danach wieder her.

## Spielstand + Highscore beim Aufhören (v1.2)

Nutzer (2026-09-27): „bei Exit konnte ich mich nicht in die Highscores
eintragen, und Leben/Punkte waren weg — so eine Karte soll doch
Zwischendurch-Aufhören erlauben. Auf keinen Fall darf Fortschritt verloren
gehen.“ Lösung:
- **Autosave** `save_game.gd` (`SaveGame`, `user://savegame.cfg` Abschnitt
  `[run]`: id, name, score, coins, lives, power, dino, at, best — Kurse als
  ID-String). `game.gd::save_run()` schreibt bei jedem Kartenschritt
  (`node_changed`), beim Erscheinen der Karte, bei jedem Kursstart (auch
  nach einem Tod), vor dem Quit-Dialog, in `_to_title()` und bei
  `NOTIFICATION_WM_CLOSE_REQUEST` / `WM_GO_BACK_REQUEST` /
  `APPLICATION_PAUSED` (Android kann eine App im Hintergrund still
  beenden). Mitten im Kurs: aktueller Stand (Kraft = `player.power`,
  Drache = `riding`), der Kurs beginnt beim Fortsetzen neu von der Karte.
  Während DYING wird nicht geschrieben (der Stand vom Kursstart gilt).
  Karte: `WorldMap.destination()` = Ziel eines laufenden Wegs/Aufdeckens.
- **Titel**: mit Spielstand „Continue  1-2“ (+ Punkte/Leben-Zeile) und
  „New Game“ → Rückfrage „NEW GAME?“ (Standardfokus „Back“). Ohne
  Spielstand wie bisher „Play“. Game Over / Sieg löscht den Spielstand
  (nur wenn es derselbe Lauf ist).
- **Pause „Main Menu“/„Exit“** → Dialog `Screen.QUIT` („BACK TO MENU?“ /
  „QUIT GAME?“): zeigt Punkte, Welt, Leben, Münzen, was gespeichert ist,
  und — wenn die Punkte in der Bestenliste stehen — „HIGH SCORE #n! Enter
  your name“ (LineEdit, vorbelegt mit dem Namen des Laufs). Knöpfe „Save &
  Menu“/„Save & Exit“ + „Back“. `Game.quit_game()` speichert vor `quit()`
  (`SceneTree.quit()` löst KEIN `WM_CLOSE_REQUEST` aus).
- **Ein Highscore-Eintrag pro Lauf**: `HallOfFame.record_run(run_id, name,
  score, world)` legt den Eintrag an (sobald er qualifiziert) bzw.
  aktualisiert ihn (Schlüssel `run`); läuft bei jedem Autosave mit (Name
  „YOU“, bis der Spieler einen eingibt: `Game.set_run_name()`). Dadurch
  kein doppelter Eintrag nach „Continue“ und kein verlorener Highscore bei
  App-Abbruch oder „New Game“. Game Over zeigt das Namensfeld, wenn der
  Lauf in der Liste steht, vorbelegt; „High Scores“ hebt den laufenden
  (Pause) bzw. gespeicherten (Titel) Lauf hervor.
- **Levelauswahl-Läufe** (`practice`, auch „Boss“ und nicht-gecheatete)
  schreiben den Spielstand NIE — sonst würde Ausprobieren den echten Lauf
  ersetzen — und bekommen seit v1.2.1 auch KEINEN Highscore (jeder
  ausprobierte Boss hinterließ einen „YOU“-Eintrag, Nutzer: „die Liste
  müllt zu“). „Play Again“ behält `practice`.
- **Name nur einmal (v1.2.1)**: hat der Lauf schon einen Namen, zeigt der
  Quit-Dialog nur „High score #n: NAME“ ohne Eingabefeld (Fokus direkt auf
  „Save & …“). High Scores vom Titel: „Clear list“ mit Rückfrage
  (`Screen.CLEARHOF`, Fokus auf „Back“). `HallOfFame.load_list()` wirft
  0-Punkte-Einträge alter Versionen weg.
- Hilfeseite „World Map“: „Saved all along: quit any time, Continue on
  title“. Playtest `save`.

## Touch-Tasten-Schalter (v0.5)

- `GameSettings.reached_world()` / `reached_level_id()` (Abschnitt
  `[progress]` in settings.cfg) merken den weitesten Kurs.
- Settings „Touch keys“ Auto/On/Off (`GameSettings.touch_buttons_visible`):
  Auto = nur auf Touch-Geräten OHNE verbundenes Gamepad (RG552 → aus).
  `Input.joy_connection_changed` schaltet live um. Die Hilfe zeigt die
  Touch-only-Seitenliste nur ohne Gamepad.
- Achtung Playtests, die Kurse ohne Cheat starten, setzen den Fortschritt
  auf dem Entwicklungsrechner — danach `[progress]` in
  `~/.local/share/godot/app_userdata/mario-clone/settings.cfg` prüfen.

## Offen / nächste Schritte

Siehe **`TODO.md`** (offene Punkte sammeln + abhaken, gilt über
Kontextwechsel hinaus).
