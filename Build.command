#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$project_dir"
if bash scripts/build-app.sh; then
    echo "Die App liegt unter: $project_dir/build/ForE ScreenTime.app"
else
    echo "Der Build ist fehlgeschlagen. Bitte die Meldung oben prüfen."
    read -r -p "Zum Schließen die Eingabetaste drücken … "
    exit 1
fi
read -r -p "Zum Schließen die Eingabetaste drücken … "
