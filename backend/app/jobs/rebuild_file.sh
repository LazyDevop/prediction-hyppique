#!/bin/sh
# Rebuild queue run by the `rebuild` Docker service (restart: unless-stopped).
#
# Each range of REBUILD_PLAGES ("debut fin;debut fin;...") is rebuilt with
# app.jobs.rebuild_historique, up to 3 passes until it exits 0. The job is
# resumable: complete days are skipped, so a restart (PC or Docker reboot)
# simply picks up where it stopped. When every range is done, a marker file
# is written and the container idles instead of exiting, so the restart
# policy never replays the queue.
set -u
cd /app
MARQUEUR=/app/data/rebuild_file_terminee
PLAGES="${REBUILD_PLAGES:-2022-11-06 2023-10-19;2021-10-20 2022-10-19;2025-10-20 2026-09-19;2024-10-20 2025-10-19;2023-10-20 2024-10-19;2022-10-20 2022-11-05}"

if [ -f "$MARQUEUR" ]; then
  echo "File de reconstruction déjà terminée ($(cat "$MARQUEUR")) : rien à faire."
  exec sleep infinity
fi

echo "File de reconstruction démarrée $(date -u)"
IFS=';'
for plage in $PLAGES; do
  IFS=' '
  set -- $plage
  journal="/app/data/rebuild_$1_$2.log"
  for passage in 1 2 3; do
    echo "Plage $1 -> $2, passage $passage (journal $journal)"
    python -m app.jobs.rebuild_historique --date-debut "$1" --date-fin "$2" >> "$journal" 2>&1
    rc=$?
    echo "EXIT=$rc" >> "$journal"
    [ "$rc" -eq 0 ] && break
  done
  IFS=';'
done

echo "FIN $(date -u)" > "$MARQUEUR"
echo "File de reconstruction terminée $(date -u)"
exec sleep infinity
