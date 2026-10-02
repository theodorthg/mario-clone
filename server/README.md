# Online-Coop: Vermittlungsdienst (relay)

Ab v1.9 können Mario und Luigi über das Internet zusammen spielen. Marios
Gerät rechnet das Spiel, Luigis Gerät zeigt es (wie beim Wi-Fi-Coop). Damit
sich die beiden finden, braucht es einen kleinen, dauerhaft laufenden Dienst:
`relay.js` (Node.js + Paket `ws`). Er vergibt 4-stellige Raum-Codes und
reicht die Datenpakete zwischen genau zwei Spielern weiter — er speichert
nichts und rechnet nichts.

Im Spiel steht die Adresse in `project.godot`:
`application/config/relay_url = "wss://broesel.net/mario-relay"`
(für Tests überschreibbar per Settings-Schlüssel `relay_url`).

## Einrichten auf Uberspace (vega.uberspace.de, Domain broesel.net)

Einmalig (und bei jedem Update), vom Ordner `projects/mario-clone` aus:

```
server/deploy_uberspace.sh <uberspace-benutzer>
```

Das Skript
1. kopiert `relay.js` + `package.json` nach `~/mario-relay/` und den
   Web-Build nach `~/html/mario-clone/` (→ https://broesel.net/mario-clone/),
2. installiert `ws` (`npm install`), legt den Dienst
   `~/etc/services.d/mario-relay.ini` an (supervisord: startet automatisch,
   auch nach einem Neustart des Servers, und nach Abstürzen neu),
3. leitet den Pfad `/mario-relay` per `uberspace web backend set` auf den
   Dienst (Port 8765) weiter — HTTPS/WSS macht Uberspace selbst.

Prüfen: https://broesel.net/mario-relay im Browser zeigt
`mario-clone relay ok, 0 room(s)`.

Nützlich auf dem Server:
```
supervisorctl status mario-relay      # läuft er?
supervisorctl restart mario-relay
supervisorctl tail -f mario-relay     # Protokoll (Räume auf/zu)
uberspace web backend list
```

## Lokal testen

```
cd server && npm install && PORT=8765 node relay.js
```
und im Spiel (Settings-Datei) `relay_url = "ws://127.0.0.1:8765"`; die
Playtests `onlinehost` + `onlineguest` machen das selbst.
