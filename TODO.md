# TODO — mario-clone

Offene Punkte sammeln und abhaken (gilt über Kontextwechsel hinaus; siehe
globale CLAUDE.md „TODO.md pro Projekt“). Neueste Einträge oben.
Hintergrund/Details zu erledigten Punkten stehen in `CLAUDE.md` bzw. im
Git-Log.

## Offen

- [ ] **Absturz RG552 beim Einmauern der Boss-Arena** (einmalig vom Nutzer
      beobachtet, v0.9.x, 2026-09-26). Android-Logs des RG552 zeigten keine
      Absturzspur (kein SIGSEGV/Fatal signal, kein Godot-Fehler) — Ursache
      unbelegt. Vermutung: TileMapLayer-Zellen + Kollision wurden mitten im
      Physik-Schritt (aus `boss.gd::_physics_process`) geändert. v0.9.7:
      `start_boss` jetzt `call_deferred`, idempotent, mit Zustands-Guards,
      schiebt den Helden aus der Mauerspalte. **Falls es wieder passiert:**
      sofort (bevor das Log rotiert) `adb logcat -b crash -d` und
      `adb logcat -d | grep -iE "fatal|signal|godot|marioclone"` sichern und
      tiefer analysieren (ggf. Debug-APK mit Symbolen).
- [ ] OPPO noch auf v0.9.0 → beim nächsten Anschließen aktuelle APK
      installieren.
- [ ] Nutzer-Feedback zu den neuen Musikstücken (Wüste, Schnee, Burg,
      „World Clear“-Fanfare) — konnte sie nur technisch prüfen.
- [ ] Boss-Balancing nach Spieltests (HP, Tempo, Flammenrate).
- [ ] Nutzer fragen: Android-Splash-Fix (`disable_godot_boot_splash=false`)
      + Splash mit Fake-Ladebalken auch in tetris/pacman/galaga/centipede
      übernehmen?
- [ ] Optional: weißer Hintergrund des Android-12-System-Splash (nur per
      Gradle-Build änderbar).
- [ ] `tools/gen_audio.py` rendert Rauschen nicht deterministisch → Seed
      setzen, damit unveränderte Stücke keinen Binär-Churn erzeugen.
- [ ] Ideen: weitere Welten, bewegliche Plattformen, Boss-Varianten.

## Erledigt

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
