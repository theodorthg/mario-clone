#!/usr/bin/env bash
# Online-Vermittlungsdienst (relay.js) + Web-Version auf Uberspace einrichten
# bzw. aktualisieren. Aufruf vom Projektordner mario-clone aus:
#
#   server/deploy_uberspace.sh <uberspace-benutzer> [host]
#
# host: Standard vega.uberspace.de. Braucht SSH-Zugang (Schlüssel oder
# Passwortabfrage). Mehrfach ausführbar — beim zweiten Mal wird nur
# aktualisiert und der Dienst neu gestartet.
#
# Ergebnis:
#   https://broesel.net/mario-clone/    Web-Version (statische Dateien)
#   wss://broesel.net/mario-relay       Vermittlungsdienst (Raum-Codes)
#   https://broesel.net/mario-relay     zeigt "mario-clone relay ok, N room(s)"
set -euo pipefail

U="${1:?Uberspace-Benutzername angeben}"
H="${2:-vega.uberspace.de}"
PORT=8765
HERE="$(cd "$(dirname "$0")" && pwd)"
WEB="$HERE/../../web-release-mario-clone"

echo "== Dateien kopieren nach $U@$H"
ssh "$U@$H" "mkdir -p ~/mario-relay ~/etc/services.d ~/html/mario-clone"
scp "$HERE/relay.js" "$HERE/package.json" "$U@$H:mario-relay/"
if [ -f "$WEB/index.html" ]; then
  rsync -a --delete "$WEB/" "$U@$H:html/mario-clone/"
else
  echo "   (kein Web-Build unter $WEB — Web-Version übersprungen)"
fi

echo "== Dienst einrichten"
ssh "$U@$H" bash -s <<REMOTE
set -e
uberspace tools version use node 22 >/dev/null 2>&1 || true
cd ~/mario-relay && npm install --omit=dev --no-audit --no-fund
cat > ~/etc/services.d/mario-relay.ini <<INI
[program:mario-relay]
directory=%(ENV_HOME)s/mario-relay
command=node relay.js
environment=PORT="$PORT"
autostart=yes
autorestart=yes
startsecs=5
INI
supervisorctl reread
supervisorctl update
supervisorctl restart mario-relay || true
uberspace web backend set /mario-relay --http --port $PORT
sleep 2
supervisorctl status mario-relay
uberspace web backend list
REMOTE

echo "== Test"
curl -s "https://broesel.net/mario-relay" || echo "(noch nicht erreichbar — Domain/Backend prüfen)"
