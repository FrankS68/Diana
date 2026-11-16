# Diana auf dem Raspberry Pi (Self-Hosted Worker)

Der Pi läuft als Worker der Mistral-Workflows-Plattform: Er registriert den
Workflow `diana-planets-api` und führt Executions aus, die von der Agentin Diana
gestartet werden. Der Pi macht die POST-Aufrufe an `api.planets.nu` direkt.

Voraussetzungen: Raspberry Pi 4/5 mit **64-bit** Raspberry Pi OS (Bookworm oder
neuer), Internetzugang.

## 1. Installation

```bash
sudo apt update && sudo apt install -y git curl
git clone https://github.com/FrankS68/Diana.git
cd Diana
bash deploy/pi/install.sh
```

Das Skript installiert `uv`, Python 3.12 und alle Abhängigkeiten.

## 2. Konfiguration

```bash
cp deploy/pi/env.example deploy/pi/env
nano deploy/pi/env
```

Eintragen:
- `MISTRAL_API_KEY`: API-Key aus console.mistral.ai
- `PLANETSNU_API_KEY`: planets.nu-API-Key des Accounts lomize

`deploy/pi/env` ist gitignored und bleibt auf dem Pi.

## 3. Testlauf (Vordergrund)

```bash
bash deploy/pi/run.sh
```

Erwartet: Der Worker verbindet sich und registriert `diana-planets-api`.
Mit Strg+C beenden.

## 4. Autostart per systemd

```bash
sudo cp deploy/pi/diana-worker@.service /etc/systemd/system/
sudo systemctl daemon-reload
# Annahme: Das Repo liegt unter /home/pi/Diana und der Benutzer heißt pi
sudo systemctl enable --now diana-worker@pi
journalctl -u diana-worker@pi -f
```

Wenn Repo-Pfad oder Benutzer abweichen, den `WorkingDirectory`/`User` in der
Unit entsprechend anpassen.

## 5. Verification

Die Agentin startet eine Test-Execution (`loadinfo`) gegen den Workflow. Auf dem
Pi erscheint die Ausführung im Log (`journalctl -u diana-worker@pi`).

## Hinweise

- Ist der Pi offline, wartet eine gestartete Execution und läuft, sobald der
  Worker wieder erreichbar ist.
- Der Worker braucht nur ausgehende Verbindungen (Mistral-API,
  api.planets.nu). Keine Ports öffnen.
- Update: `git pull && bash deploy/pi/install.sh && sudo systemctl restart diana-worker@pi`
