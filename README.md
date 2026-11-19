# Diana – Agentin für das Wissensnetz knownet

Diana läuft per Cronjob (headless) auf dem Raspberry Pi Spiekeroog als Benutzer
`diana`, täglich um 07:00 (Europe/Berlin), Arbeitsverzeichnis `~/agenten/diana`.
Sie sucht neue Quellen zu den Themen im Wissensnetz knownet, bewertet sie
(Seriosität, Relevanz, Neuigkeit plus KI-Wahrscheinlichkeit) und nimmt gut
bewertete Quellen samt Kernaussagen in knownet auf – ausdrücklich auch
widersprechende Befunde und widerlegte Falschaussagen.

**Das verbindliche Agenten-Prompt steht in [`PROMPT.md`](PROMPT.md).**

## Einrichtung (einmalig, als `frank` auf dem PI)

```bash
cd <Pfad zum Repo-Klon>
./deploy/setup-diana.sh            # interaktiv (fragt URL, API-Key, AGENT_CMD ab)
# oder nicht-interaktiv:
KNOWNET_URL=http://spiekeroog.fritz.box:8082 \
KNOWNET_API_KEY=... AGENT_CMD='claude -p "$(cat PROMPT.md)"' \
./deploy/setup-diana.sh
```

Das Script [`deploy/setup-diana.sh`](deploy/setup-diana.sh) ist idempotent:
- legt Benutzer `diana` und alle Verzeichnisse an, falls fehlend,
- kopiert `PROMPT.md` aus dem Repo nach `/home/diana/agenten/diana/`,
- sucht `knownet.py` (Python-Umgebungsvariable `KNOWNET_PY`, Repo-Ordner, oder
  Kalliopes Verzeichnis `/home/claudine/agenten/kalliope/knownet.py`),
- legt `logbuch.md` nur an, wenn es noch nicht existiert (bestehendes Logbuch
  wird nie angetastet),
- schreibt `agent.env` (0600) mit KNOWNET_URL / KNOWNET_API_KEY / AGENT_CMD
  (der API-Key landet nur dort – nie im Repo oder in Logs),
- erzeugt `run.sh` und trägt den Cronjob (täglich 07:00) zwischen den Markern
  `# BEGIN diana` / `# END diana` in dianas crontab ein (bestehende Einträge
  bleiben unangetastet, erneutes Ausführen ersetzt nur diesen Block).

## Logbuch & Laufartefakte

- Logbuch: lokale Datei `~/agenten/diana/logbuch.md` (dort auch Franks
  Anweisungen und Suchfokus).
- Laufartefakte: `~/agenten/diana/laeufe/<JJJJ-MM-TT>.json` (Import),
  `-ki.json` (KI-Bewertungen Bestandsquellen), `-ergebnis.json` (angelegte IDs).
- Colony-Tools-Freigabe: `~/agenten/diana.colony-tools`.

## Setup (Raspberry Pi, Benutzer `diana`)

1. `sudo adduser diana`, danach `/home/diana/agenten/diana` anlegen (Owner diana).
2. `knownet.py` dort ablegen; `KNOWNET_URL` und `KNOWNET_API_KEY` als
   Umgebungsvariablen für den Cronjob setzen (Key nie in Dateien/Repos).
3. `logbuch.md` mit den sieben Abschnitten aus PROMPT.md anlegen.
4. Cron: `0 7 * * * cd /home/diana/agenten/diana && <headless-KI-Befehl> >> lauf.log 2>&1`
   (Konkrete KI-CLI noch eintragen; WebSearch-/WebFetch-Zugang und optional
   `mcp__thecolony__colony_*` freigeben.)

---

## Alter Bestandteil: planets.nu-API-Worker

Dieses Repo enthielt ursprünglich nur den Mistral-Workflow, der der Agentin
Diana POST-Zugriff auf die planets.nu-API gibt (`game/loadturn`, `game/save`),
da die Sandbox ausgehende POST-Anfragen sperrt. Dieser Worker bleibt bis auf
Weiteres im Repo (siehe unten), ist aber nicht Teil des neuen knownet-Einsatzes.

### Struktur (Worker)

- `apps/worker/src/worker/workflows/planets.py` – Workflow `diana-planets-api`
- `apps/worker/src/worker/entrypoints/worker.py` – Worker-Entrypoint
- `deploy/docker/Dockerfile.worker` – Dockerfile für das Managed Deployment
- `tests/` – lokale Tests (gemockte HTTP-Aufrufe, kein echter API-Key)

### Workflow `diana-planets-api`

Input (Pydantic `PlanetsApiInput`):

| Feld | Bedeutung |
|---|---|
| `action` | `loadinfo`, `loadturn`, `save`, `get`, `post` |
| `gameid`, `playerid`, `turn`, `version`, `savekey`, `saveindex` | Parameter für loadturn/save |
| `path`, `params`, `fields` | für generische `get`/`post`-Aufrufe (nur Pfade unter `/game/`) |

Output: `ApiResult` mit `status_code`, `body` (JSON) und `text` (Fallback).

Der API-Key wird nie im Code oder in Antworten geführt: Der Worker liest ihn beim
Start aus der Umgebungsvariable `PLANETSNU_API_KEY`, die im Managed Deployment an
ein Workspace-Secret gebunden wird.

### Deployment (Worker)

Managed Deployment baut aus diesem Repository (`mistral_cloud`,
`dockerfile_path: deploy/docker/Dockerfile.worker`). Vor dem ersten Deploy:

1. Workspace-Secret `PLANETSNU_API_KEY` im Mistral Studio anlegen.
2. Deployment mit Secret-Binding `PLANETSNU_API_KEY -> secret:workspace:PLANETSNU_API_KEY` erzeugen.

### Lokale Tests (Worker)

```bash
cd apps/worker
uv sync
uv run pytest ../../tests
```
