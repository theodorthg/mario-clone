# TODO — mario-clone

Offene Punkte sammeln und abhaken (gilt über Kontextwechsel hinaus; siehe
globale CLAUDE.md „TODO.md pro Projekt“). Neueste Einträge oben.
Hintergrund/Details zu erledigten Punkten stehen in `CLAUDE.md` bzw. im
Git-Log.

## Offen

- [ ] Boss-Balancing nach Spieltests (HP, Tempo, Angriffsrate der neuen
      Varianten) — wartet auf Nutzer-Feedback.
- [ ] Optional: weißer Hintergrund des Android-12-System-Splash (nur per
      Gradle-Build änderbar).
- [ ] Ideen: weitere Welten (z. B. Wolken/Himmel, Unterwasser), weitere
      Gegner, Plattform-Varianten (fallende/kippende Plattformen).

## Erledigt

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
