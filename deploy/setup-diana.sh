#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# setup-diana.sh – richtet die Agentin Diana auf diesem Raspberry Pi ein.
#
# Aufruf (als Benutzer frank):
#   cd <Pfad zum Repo-Klon>
#   ./deploy/setup-diana.sh
#
# Was das Script tut (idempotent, Privilegien über sudo):
#   1. Benutzer "diana" anlegen (falls fehlt)
#   2. Verzeichnisse anlegen:  /home/diana/agenten/diana (inkl. laeufe/)
#                              /home/diana/agenten/diana.colony-tools
#   3. PROMPT.md aus diesem Repo nach /home/diana/agenten/diana/ kopieren
#      (bei jedem Lauf überschrieben – das Repo ist die Quelle)
#   4. knownet.py suchen und kopieren (Kandidaten siehe KNOWNET_PY unten;
#      schon vorhandene Datei in dianas Verzeichnis wird nie überschrieben)
#   5. logbuch.md mit den sieben Abschnitten anlegen (NUR falls nicht
#      vorhanden; ein bestehendes Logbuch wird nie angetastet)
#   6. agent.env (0600, Owner diana) anlegen mit KNOWNET_URL, KNOWNET_API_KEY
#      und AGENT_CMD – bei vorhandener Datei wird nichts überschrieben
#      (Neuanlage:  sudo rm /home/diana/agenten/diana/agent.env  und erneut)
#   7. run.sh erzeugen (vom Cronjob aufgerufen)
#   8. Cron eintragen: täglich 07:00, Marker "# BEGIN diana" ... "# END diana"
#
# Security: Der KNOWNET_API_KEY wird interaktiv unsichtbar abgefragt und nur
# in agent.env (0600, Owner diana) auf dem PI gespeichert – niemals im Repo,
# in Logs oder in der Ausgabe dieses Scripts.
# ----------------------------------------------------------------------------
set -euo pipefail

AGENT_USER="diana"
AGENT_HOME="/home/${AGENT_USER}"
AGENT_DIR="${AGENT_HOME}/agenten/${AGENT_USER}"
COLONY_TOOLS_DIR="${AGENT_HOME}/agenten/${AGENT_USER}.colony-tools"
ENV_FILE="${AGENT_DIR}/agent.env"
RUN_SH="${AGENT_DIR}/run.sh"
LOGBUCH="${AGENT_DIR}/logbuch.md"
CRON_MARK_BEGIN="# BEGIN diana"
CRON_MARK_END="# END diana"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROMPT_SRC="${SCRIPT_DIR}/PROMPT.md"

SUDO=""
if [[ $EUID -ne 0 ]]; then
  SUDO="sudo"
fi

log()  { printf '\033[1;32m[setup-diana]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[setup-diana]\033[0m %s\n' "$*"; }

# Nett gemeinte Warnung, wenn die Systemzeitzone nicht Europe/Berlin ist
# (der 07:00-Cron sonst zur falschen Ortszeit startet).
if [[ -r /etc/timezone ]] && ! grep -q "Europe/Berlin" /etc/timezone; then
  warn "Systemzeitzone ist nicht Europe/Berlin."
  warn "  -> timedatectl set-timezone Europe/Berlin"
fi

# --- 1. Benutzer anlegen ----------------------------------------------------
if id "${AGENT_USER}" &>/dev/null; then
  log "Benutzer ${AGENT_USER} existiert bereits."
else
  log "Lege Benutzer ${AGENT_USER} an ..."
  $SUDO adduser --disabled-password --gecos "Diana (KI-Agentin)" "${AGENT_USER}"
fi

# --- 2. Verzeichnisse -------------------------------------------------------
log "Lege Verzeichnisse an ..."
$SUDO install -d -o "${AGENT_USER}" -g "${AGENT_USER}" \
  -m 0750 "${AGENT_DIR}" "${AGENT_DIR}/laeufe" "${COLONY_TOOLS_DIR}"

# --- 3. PROMPT.md -----------------------------------------------------------
if [[ -f "${PROMPT_SRC}" ]]; then
  log "Kopiere PROMPT.md -> ${AGENT_DIR}/PROMPT.md"
  $SUDO install -o "${AGENT_USER}" -g "${AGENT_USER}" -m 0640 \
    "${PROMPT_SRC}" "${AGENT_DIR}/PROMPT.md"
else
  warn "PROMPT.md nicht gefunden unter ${PROMPT_SRC}"
  warn "  -> bitte manuell nach ${AGENT_DIR} kopieren."
fi

# --- 4. knownet.py ----------------------------------------------------------
KNOWNET_DST="${AGENT_DIR}/knownet.py"
if [[ -f "${KNOWNET_DST}" ]]; then
  log "knownet.py liegt bereits in ${AGENT_DIR} – unverändert übernommen."
else
  # Kandidaten, erster Treffer gewinnt:
  #   KNOWNET_PY  = Umgebungsvariable mit explizitem Pfad
  #   daneben übliche Orte (u. a. Kalliopes Verzeichnis)
  CANDIDATES=(
    "${KNOWNET_PY:-}"
    "${SCRIPT_DIR}/knownet.py"
    "${SCRIPT_DIR}/deploy/knownet.py"
    "${HOME}/agenten/kalliope/knownet.py"
    "${HOME}/agenten/knownet/knownet.py"
    "/home/claudine/agenten/kalliope/knownet.py"
  )
  KNOWNET_FOUND=""
  for c in "${CANDIDATES[@]}"; do
    if [[ -n "${c}" && -f "${c}" ]]; then KNOWNET_FOUND="${c}"; break; fi
  done
  if [[ -n "${KNOWNET_FOUND}" ]]; then
    log "Kopiere knownet.py von ${KNOWNET_FOUND} -> ${KNOWNET_DST}"
    $SUDO install -o "${AGENT_USER}" -g "${AGENT_USER}" -m 0640 \
      "${KNOWNET_FOUND}" "${KNOWNET_DST}"
  else
    warn "knownet.py nicht gefunden. Nachholen mit:"
    warn "  KNOWNET_PY=/pfad/knownet.py ./deploy/setup-diana.sh"
    warn "oder manuell:"
    warn "  sudo cp /pfad/knownet.py ${KNOWNET_DST}"
    warn "  sudo chown ${AGENT_USER}:${AGENT_USER} ${KNOWNET_DST}"
  fi
fi

# --- 5. Logbuch -------------------------------------------------------------
if [[ -f "${LOGBUCH}" ]]; then
  log "Logbuch existiert bereits (${LOGBUCH}) – wird NICHT verändert."
else
  log "Lege Logbuch-Skelett an: ${LOGBUCH}"
  $SUDO tee "${LOGBUCH}" >/dev/null <<'EOF'
# Diana-Logbuch

## Anweisungen

(Trage hier Aufgaben für Diana ein; sie hakt Erledigtes mit [x] ab.)

- [ ] Beispiel-Anweisung: Thema X priorisieren ...

## Themen & Suchfokus

- Colony: (noch keine)
- Aktuell in knownet: (wird von Diana aktualisiert)

## Bewertungsmaßstab

- Seriosität (S), Relevanz (R), Neuigkeit/Aktualität (N) je 1–5.
- Aufnehmen nur, wenn keine Achse unter 3 und S+R+N ≥ 12.
- Max. 5 Quellen pro Lauf; max. 2 Falschaussagen pro Lauf.

## Aufgenommene Quellen

| Datum | Knownet-ID | Titel mit URL | S/R/N | KI-% | Begründung | Aussagen-IDs / Verknüpfungen |
|---|---|---|---|---|---|---|

## Widerlegte Falschaussagen

| Datum | Behauptung | Aussage-ID | Widerlegt durch | Kern der Widerlegung |
|---|---|---|---|---|

## Verworfene Kandidaten

| Datum | URL | Grund |
|---|---|---|

## Logbuch-Einträge

| Zeitpunkt (UTC) | Eintrag |
|---|---|
EOF
  $SUDO chown "${AGENT_USER}:${AGENT_USER}" "${LOGBUCH}"
  $SUDO chmod 0640 "${LOGBUCH}"
fi

# --- 6. agent.env -----------------------------------------------------------
if [[ -f "${ENV_FILE}" ]]; then
  log "agent.env existiert bereits (${ENV_FILE}) – wird NICHT verändert."
  log "  (Neuanlage:  sudo rm ${ENV_FILE}  und Script erneut ausführen.)"
else
  DEFAULT_URL="http://spiekeroog.fritz.box:8082"
  if [[ -t 0 ]]; then
    read -r -p "KNOWNET_URL [${DEFAULT_URL}]: " IN_URL
    read -rs -p "KNOWNET_API_KEY (Eingabe unsichtbar): " IN_KEY; echo
    read -r -p "AGENT_CMD (Befehlsvorlage, z. B. claude -p \"\$(cat PROMPT.md)\"): " IN_CMD
  else
    IN_URL="${KNOWNET_URL:-}"
    IN_KEY="${KNOWNET_API_KEY:-}"
    IN_CMD="${AGENT_CMD:-}"
    if [[ -z "${IN_URL}" || -z "${IN_KEY}" || -z "${IN_CMD}" ]]; then
      warn "Kein interaktives Terminal: bitte KNOWNET_URL, KNOWNET_API_KEY"
      warn "und AGENT_CMD als Umgebungsvariablen setzen und erneut ausführen."
      exit 1
    fi
  fi
  TMP_ENV="$(mktemp)"
  trap 'rm -f "${TMP_ENV}"' EXIT
  {
    printf '# Diana agent.env – von setup-diana.sh angelegt (0600). Key nicht weitergeben.\n'
    printf 'KNOWNET_URL=%q\n'      "${IN_URL:-${DEFAULT_URL}}"
    printf 'KNOWNET_API_KEY=%q\n' "${IN_KEY:-}"
    printf 'AGENT_CMD=%q\n'       "${IN_CMD:-}"
  } > "${TMP_ENV}"
  $SUDO install -o "${AGENT_USER}" -g "${AGENT_USER}" -m 0600 \
    "${TMP_ENV}" "${ENV_FILE}"
  rm -f "${TMP_ENV}"
  trap - EXIT
  if [[ -z "${IN_KEY}" ]]; then
    warn "KNOWNET_API_KEY ist leer – bitte nachtragen:  sudoedit ${ENV_FILE}"
  fi
  log "agent.env angelegt (0600, Owner ${AGENT_USER})."
fi

# --- 7. run.sh --------------------------------------------------------------
log "Erzeuge ${RUN_SH} ..."
$SUDO tee "${RUN_SH}" >/dev/null <<'EOF'
#!/usr/bin/env bash
# Wird vom Cronjob aufgerufen. Lädt agent.env und startet die KI-CLI.
set -euo pipefail
cd "$(dirname "$0")"
if [[ -f agent.env ]]; then
  set -a
  . ./agent.env
  set +a
fi
if [[ -z "${AGENT_CMD:-}" ]]; then
  echo "[run.sh] AGENT_CMD ist nicht gesetzt – bitte agent.env ausfüllen." >&2
  exit 1
fi
exec bash -c "${AGENT_CMD}"
EOF
$SUDO chown "${AGENT_USER}:${AGENT_USER}" "${RUN_SH}"
$SUDO chmod 0750 "${RUN_SH}"

# --- 8. Cron ----------------------------------------------------------------
log "Aktualisiere crontab für ${AGENT_USER} ..."
CRON_LINE="0 7 * * * ${RUN_SH} >> ${AGENT_DIR}/lauf.log 2>&1"
CURRENT_CRON="$($SUDO crontab -u "${AGENT_USER}" -l 2>/dev/null || true)"
# Alten Marker-Block entfernen, Rest behalten, neuen Block anhängen.
KEPT_CRON="$(printf '%s\n' "${CURRENT_CRON}" | awk -v b="${CRON_MARK_BEGIN}" -v e="${CRON_MARK_END}" '
  $0 == b { skip = 1; next }
  $0 == e { skip = 0; next }
  !skip   { print }'
)"
TMP_CRON="$(mktemp)"
trap 'rm -f "${TMP_CRON}"' EXIT
{
  # führende Leerzeilen des Rests vermeiden
  printf '%s\n' "${KEPT_CRON}" | sed '/./,$!d'
  if [[ -n "$(printf '%s' "${KEPT_CRON}" | tr -d '[:space:]')" ]]; then echo; fi
  printf '%s\n%s\n%s\n' "${CRON_MARK_BEGIN}" "${CRON_LINE}" "${CRON_MARK_END}"
} > "${TMP_CRON}"
$SUDO crontab -u "${AGENT_USER}" "${TMP_CRON}"
rm -f "${TMP_CRON}"
trap - EXIT
log "Cron eingetragen: ${CRON_LINE}"

# --- Abschluss --------------------------------------------------------------
echo
log "Fertig. Zusammenfassung:"
log "  Benutzer:            ${AGENT_USER}"
log "  Arbeitsverzeichnis:  ${AGENT_DIR}  (PROMPT.md, knownet.py, laeufe/)"
log "  Colony-Tools:        ${COLONY_TOOLS_DIR}"
log "  Logbuch:             ${LOGBUCH}"
log "  Umgebung:            ${ENV_FILE}  (0600)"
log "  Cron:                täglich 07:00 via ${RUN_SH}"
echo
log "Nächste Schritte prüfen:"
log "  1. sudoedit ${ENV_FILE}   -> KNOWNET_API_KEY und AGENT_CMD korrekt?"
log "  2. knownet.py vorhanden?  -> sonst Meldung oben beachten"
log "  3. Testlauf als diana:    sudo -u ${AGENT_USER} ${RUN_SH}"

# eof
