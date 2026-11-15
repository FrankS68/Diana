# Diana planets.nu worker

Mistral Workflow, der der Agentin Diana POST-Zugriff auf die planets.nu-API gibt
(`game/loadturn`, `game/save`), da die Sandbox ausgehende POST-Anfragen sperrt.

## Struktur

- `apps/worker/src/worker/workflows/planets.py` – Workflow `diana-planets-api`
- `apps/worker/src/worker/entrypoints/worker.py` – Worker-Entrypoint
- `deploy/docker/Dockerfile.worker` – Dockerfile für das Managed Deployment
- `tests/` – lokale Tests (gemockte HTTP-Aufrufe, kein echter API-Key)

## Workflow `diana-planets-api`

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

## Deployment

Managed Deployment baut aus diesem Repository (`mistral_cloud`,
`dockerfile_path: deploy/docker/Dockerfile.worker`). Vor dem ersten Deploy:

1. Workspace-Secret `PLANETSNU_API_KEY` im Mistral Studio anlegen.
2. Deployment mit Secret-Binding `PLANETSNU_API_KEY -> secret:workspace:PLANETSNU_API_KEY` erzeugen.

## Lokale Tests

```bash
cd apps/worker
uv sync
uv run pytest ../../tests
```
