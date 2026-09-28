# TODO — mario-clone

Offene Punkte sammeln und abhaken (gilt über Kontextwechsel hinaus; siehe
globale CLAUDE.md „TODO.md pro Projekt“). Neueste Einträge oben.
Hintergrund/Details zu erledigten Punkten stehen in `CLAUDE.md` bzw. im
Git-Log.

## Offen

Letzte Erweiterungsrunde (Nutzer 2026-09-28: „alle machen, dann ist mit
Erweiterungen Schluss, bis mir etwas einfällt“), jede Stufe als eigene
Version inkl. itch.io-Upload:
- [x] v1.3.0 Wasser: Schwimmbecken mitten im Level, Strömungen, Burg 6-3
      mit gefluteten Abschnitten (Graben + Tank), Strömungen in 6-1/6-2,
      Hilfeseite „Pools & Currents“.
- [x] v1.4.0 Welt 7 „Geisterhaus“ (2026-09-28): 7-1 Haunted Hall,
      7-2 Moonlit Graveyard, Burg 7-3 Phantom Keep; Türen/Grüfte als
      Durchgänge, Geister (kommen nur, wenn man wegschaut), Knochen-
      Schildkröte, Phantom-König (blendet sich weg), Musik „Haunted
      Waltz“, Karten-Region, Hilfeseite „Ghost House“.
- [ ] v1.5.0 Welt 8 „Vulkan“ (letzte Welt, Endboss).
- [x] itch.io-Upload per `butler` (2026-09-28, Nutzer hat Channels
      linux/android/windows/web angelegt): v1.4.0 gepusht. Ablauf in der
      Wurzel-CLAUDE.md; Chrome + `projects/itch_upload_server.py` nur noch
      als Fallback (so kam v1.3.0 zuerst hoch).

## Erledigt

- [x] v1.2.1 Feinschliff (Nutzer 2026-09-28, nach RG552-Test):
      1. Highscore-Liste müllt nicht mehr zu: Levelauswahl-Läufe ohne
         Eintrag, Name wird pro Lauf nur einmal gefragt, „Clear list“.
      2. Eingeklemmter Panzer: nach 10.000 ausgezahlten Punkten zerbricht er
         (kein endloses Punkte-/1UP-Farmen).
      3. Zehn verschiedene Bonusräume statt der immer gleichen Münzhöhle
         (eigener Aufbau, Hintergrund, Musik; Unterwasser-Grotte in 3-2).
      4. Boss je Schwierigkeit: Leicht wie bisher, Mittel kürzer betäubt,
         Schwer kurz betäubt ohne Feuerblumen; Blume auch nach Feuerverlust;
         nie mehr nach oben schießen (Flammen waagrecht/abwärts, Eisbälle
         waagrecht).
- [x] v1.2.0 Kein Fortschritt geht beim Aufhören verloren (Nutzer
      2026-09-27: „bei Exit kein Highscore-Eintrag, Leben nicht
      gespeichert“): Autosave des Laufs (Punkte, Leben, Münzen, Kraft,
      Drache, Kartenplatz), „Continue“/„New Game“ auf dem Titel, Rückfrage
      vor Main Menu/Exit mit Namenseingabe für die Bestenliste, ein
      mitwachsender Highscore-Eintrag pro Lauf.
- [x] v1.1.0 Weltkarte (Nutzerwunsch 2026-09-27): alle 6 Welten auf einer
      Karte, Held läuft über die Wege, geschaffte/offene/gesperrte Kurse,
      nach jedem Kurs zurück zur Karte mit aufgedecktem Weg, Musik
      „Adventure Map“, Hilfeseite; ersetzt „Select World“.
- [x] v1.1.0 `_selftest.gd` erkennt Kompilierfehler wirklich
      (`can_instantiate()`, alle Skripte automatisch) — vorher Exit 0 trotz
      Fehler. Andere Projekte: als eigene Aufgabe vorgeschlagen.
- [x] 2026-09-27 **v1.0.0 — finales Release** (Nutzer: „mach das finale
      Release“): 6 Welten, 19 Kurse, 6 Bosse; Boss-Balancing nach v0.15
      vom Nutzer abgenommen.
- [x] v0.15.0 Boss fairer (Nutzer 2026-09-27): jeder Angriff angekündigt
      (ausholen/ducken), Treffer = 1 s betäubt ohne Angriffe, fliegende
      Geschosse verpuffen, danach Rückzug; kein Feuer auf einen Helden über
      ihm, Flammen max. ~22° nach oben; ohne Feuerkraft wirft er bei jedem
      Treffer eine Feuerblume.
- [x] v0.15.0 Settings „1-UP points“: Extraleben alle 2500/5000/10000/20000
      Punkte (Standard aus); Settings-Liste scrollt.
- [x] v0.15.0 Burgen unverwechselbar: 14 Abschnittsarten, jede Burg mit
      eigener Reihenfolge und eigenem Anfang (?-Blöcke bleiben vorn).
- [x] v0.15.0 Bosse flüssiger: Atmen, 4-Phasen-Laufzyklus, Ausholen,
      Brüllen, Ducken, Treffer-Gesicht mit Sternen, Squash & Stretch.
- [x] v0.15.0 Hilfe: Fledermäuse — „duck or walk under them“.
- [x] v0.14.0 Levelauswahl „startet den alten Kurs“: die Auswahl selbst
      funktionierte (Pad/Tipp getestet, 6-3 beim Nutzer ok) — die Burgen
      sahen gleich aus (3-3 = 4-3 byte-gleich). Jetzt eigener Aufbau +
      eigene Farbstimmung je Burg (`CASTLE_PLAN`).
- [x] v0.14.0 Schildkröten über unsichtbaren Pilzen: überlappende Läufer
      laufen auseinander; nach einem Stampfer wird ein zweiter berührter
      Gegner mitgestampft statt zu verletzen.
- [x] v0.14.0 Stampfen zu penibel: `Player.can_stomp()` — oberes ~60 %
      der Hitbox, letzte 3 Frames, „fiel gerade noch“ (Area2D-Frame-Verzug).
- [x] v0.14.0 Fledermäuse: hell violett mit gelben Augen, 0,5 s Warnung vor
      dem Sturzflug, Flughöhe über dem kleinen Helden (groß: ducken).
- [x] v0.13.0 Welt 6 „Sea“ (letzte Welt): 6-1 Coral Reef, 6-2 Deep Trench,
      Burg 6-3 Tide Fortress mit Endboss (alle Angriffe, 5 HP); Schwimmen,
      Riff-/Strand-Biome, Fische, Quallen, Krabben, Seeigel, Musik „Coral
      Waltz“, Hilfeseite „Sea World“; Drache wartet während Unterwasser-Kursen.
- [x] v0.12.0 Welt 5 „Sky“: 5-1 Cloud Kingdom, 5-2 Sunset Skyway, Burg 5-3
      Storm Citadel; Wolkenboden/-brücken, fallende Platten (`D`),
      Kippplanken (`T`), Wolkenkobold + Stachi, Möwen, Blitz-Boss, Musik
      „Cloud Nine“, Hilfeseite „Sky World“.
- [x] v0.11.0 Sprung-Gefühl (Nutzer 2026-09-27: schmale Plattformen in 1-4
      zu schwer): weniger Nachrutschen (Bodenbremse ×2, Landebremse),
      Mindest-Sprunghöhe ~3 Tiles auch bei kurzem Tippen, Doppelsprung
      (abschaltbar), Säulen in 1-4 3 breit statt 2.
- [x] v0.11.0 Mute-Knopf im Sound-Menü wechselte die Anzeige nicht
      (Lambda hatte die noch leere Button-Variable eingefangen); Anzeige
      folgt jetzt `Snd.mute_changed` — auch HUD-Lautsprecher, M, Select.
- [x] 2026-09-27 Weißer Android-12-System-Splash: Nutzer entscheidet
      „Weg 1“ (reines Weiß, kein Gradle-Build) — so bleibt es.
- [x] 2026-09-27 Android-System-Startbildschirm (vor dem Splash) einheitlich
      reines Weiß: `splash_screen/icon` = transparentes
      `assets/icon/android_splash_blank.png`, `branding_image` leer (Nutzer-
      wunsch, ohne Gradle-Build; Hintergrundfarbe ließe sich nur per Gradle
      ändern).
- [x] v0.10.0 Bewegliche Plattformen (`~` seitwärts, `^` auf/ab) in 1-3,
      2-2, 3-1, 4-1 und den Burgen 3-3/4-3.
- [x] v0.10.0 Boss-Varianten je Welt: 1 gezielte Flamme, 2 Dreifach-Fächer,
      3 Sand-Schockwellen bei jeder Landung, 4 springende Eisbälle.
- [x] v0.10.0 `gen_audio.py` deterministisch (Rausch-Seed pro Stück,
      ffmpeg `+bitexact`): zwei Läufe → byte-identische Dateien.
- [x] 2026-09-27 Absturz RG552 beim Einmauern der Boss-Arena: laut Nutzer
      direkt nach dem Einmauer-Sound beim Betreten der Arena → passt genau
      zur behobenen Ursache (Tile-Änderung im Physik-Schritt, v0.9.7);
      zusätzlich Belastungstest `bossstress` (16 Arena-Starts, teils mit Tod
      im selben Frame) ohne Fehler. Abgehakt.
- [x] 2026-09-26 Splash in den anderen Projekten geprüft: tetris + galaga
      haben ihren Ladebalken-Splash schon; centipede bekam `splash.gd`;
      pacman hat noch gar keinen Splash (→ dort offen, Nutzer fragen).
- [x] 2026-09-26 v0.9.7 auf dem Handy (CPH2581) installiert.
- [x] 2026-09-26 Nutzer-Feedback Musik: „top“.
- [x] v0.9.7 Boss-Arena-Start robuster (deferred, idempotent); TODO.md
      eingeführt; Playtest überspringt den Splash erst nach `_ready`.
- [x] v0.9.6 Splash mit Fake-Ladebalken (3 s, überspringbar).
- [x] v0.9.5 Splash auch auf Android (`disable_godot_boot_splash=false`).
- [x] v0.9.4 Faire Bosskämpfe: Checkpoint + Feuerblume vor der Arena,
      Neustart dort immer mit Feuer-Kraft, 1UP bei Sieg.
- [x] v0.9.3 Splash-Screen des Nutzers eingebaut.
- [x] v0.9.2 Levelauswahl: „Boss“-Knopf je Welt (v0.9.1 hatte Parse-Fehler,
      Release gelöscht).
- [x] v0.9.0 Biom-Gegner: Fledermaus, Kaktusturm, Pinguin.
- [x] v0.8.0 Boss-Burgen 1-4/2-3/3-3/4-3, Levelauswahl-Cheat (B,Y,X,A /
      LEVELS / 5× Titel tippen), gecheatete Läufe ohne Highscore.
- [x] v0.7.0 Tasten/Gamepad-Buttons in den Settings umbelegen.
- [x] v0.6.0 Zweites Level je Welt (2-2, 3-2 Abend, 4-2 Nacht).
- [x] v0.5.0 App-Icon mit dem Helden, Weltauswahl, Touch-Tasten-Schalter.
- [x] v0.4.0 Schildkröten, Welten Höhle/Wüste/Schnee.
- [x] v0.3.0 Level 1-2/1-3, geflügelte Gegner, Schnapp-Pflanzen, Wasser,
      bebilderte Hilfe.
- [x] v0.2.0 Neuaufbau mit eigener Pixel-Art (statt PixelLab), Level 1-1,
      Drache, Sound, Menüs.
