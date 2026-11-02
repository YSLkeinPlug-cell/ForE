# Safari-/Privat-Relay-Einrichtung: Timeout und Neustart beheben

Das korrigierte Quellprojekt liegt in **ForE-Safari.zip** in diesem Branch. Es enthält außerdem die bisherigen Korrekturen für Dienstregistrierung und AppKit aus dem Safari-Fix-Branch. `main` enthält weiterhin die ältere App ohne Safari-Dienst.

## Installation auf deinem Mac

1. Eine laufende Fokus-Sitzung beenden und die Website-Freigabe prüfen. ForE und Safari vollständig schließen.
2. **ForE-Safari.zip aus diesem Branch** herunterladen und in einen neuen Ordner entpacken. `ForE.xcodeproj` öffnen und dein bisheriges Development Team, Apple-Development-Signierung, Bundle-IDs und dieselbe gültige App Group für App und Erweiterung übernehmen.
3. In Xcode **Product → Clean Build Folder** und anschließend das Schema **ForE** bauen. Die vollständig gebaute `ForE.app` nach `/Applications` kopieren und die installierte App ersetzen.
4. Diese App aus Programme öffnen, Safari starten und die ForE-Erweiterung aktivieren. In ForE **Einstellungen → Safari-Schutz mit Privat-Relay → Hintergrundagent einrichten** wählen. Gegebenenfalls die macOS-Hintergrundfreigabe erlauben. Anschließend eine kurze Sitzung samt Freigabe bei geschlossener Haupt-App testen.

Das ZIP ist ein Xcode-Quellprojekt; es enthält keine fertig signierte App.

## Korrektur

- Die App wartet bis zu 41 Sekunden auf die Regelbestätigung. Bisher endete sie nach 15 Sekunden, bevor der Agent sein 30-Sekunden-Limit auswerten konnte.
- Die explizite Einrichtung startet einen bereits registrierten Agenten neu und entfernt seinen alten Status erst nach der abgeschlossenen Abmeldung. Dadurch läuft nach einem Update die neue Version und alte Fehler brechen den neuen Versuch nicht sofort ab.
- Ein fehlender Safari-Callback führt zu einer konkreten Fehlermeldung mit Wiederholungsanleitung. Der Agent bleibt erreichbar und versucht den Reload nach einer Pause erneut, statt sich ständig zu beenden. Sitzungsende und andere Statusänderungen lösen unabhängig von dieser Pause einen neuen Versuch aus.
- Verspätete Callbacks werden anhand ihrer Auftrags-ID verworfen. Bereitschaft erfordert weiterhin Safari-Erfolg und einen frischen Nachweis des exakt angeforderten Regelsatzes.

`Safari-Timeout-Fix.patch` zeigt die Änderungen am entpackten Quellprojekt gegenüber `fix/safari-agent-not-found` (Commit `23403c7d7f6575554f69d4d8afc2b0587efba8ff`). Bei einer bereits angepassten lokalen Kopie lassen sich diese Änderungen manuell übernehmen. Aus dem Projektordner ist der Patch mit `patch -p2` anwendbar.

## Prüfungen und Grenzen

Regressionstests verwenden feste Zeitwerte: Erfolg nach 20 Sekunden, fehlender Callback, verspätete Antworten, Wiederholungen, Freigabe nach Fehlern und passende Erweiterungsnachweise. Der neue GitHub-Workflow entpackt das tatsächliche ZIP, führt die Swift-Tests einschließlich der vorhandenen WebKit-Kompilierungstests aus und baut Debug und Release ohne Signierung.

Lokal ausgeführt: Swift 6.0.3 unter Linux, Paket-Build und **42 XCTest-Tests bestanden**, davon 20 Safari-Tests. Zusätzlich wurden `SafariAgent.swift` und `SafariProtection.swift` erfolgreich syntaktisch geparst. Die zwei WebKit-Tests werden unter Linux nicht ausgeführt; Apple-Frameworks lassen sich dort nicht vollständig bauen oder typprüfen. Der macOS-GitHub-Workflow ist vorbereitet, wurde aber noch nicht ausgeführt.

Die persönliche Signierung, Service-Management-Registrierung und echte Safari-Funktion einschließlich Privat-Relay müssen auf dem Mac geprüft werden. Die Korrektur behebt nachweisbare Fehler im Ablauf; aus dem Screenshot allein lässt sich die Ursache des ausbleibenden Safari-Callbacks nicht bestimmen.
