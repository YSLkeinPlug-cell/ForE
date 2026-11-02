# Safari-/Privat-Relay-Einrichtung: Dienststart und Regelbestätigung beheben

Das korrigierte Quellprojekt liegt in **ForE-Safari.zip** in diesem Branch. Es enthält außerdem die bisherigen Korrekturen für Dienstregistrierung und AppKit aus dem Safari-Fix-Branch. `main` enthält weiterhin die ältere App ohne Safari-Dienst.

## Installation auf deinem Mac

1. Eine laufende Fokus-Sitzung beenden und die Website-Freigabe prüfen. ForE und Safari vollständig schließen.
2. **ForE-Safari.zip aus diesem Branch** herunterladen und in einen neuen Ordner entpacken. `ForE.xcodeproj` öffnen und dein bisheriges Development Team, Apple-Development-Signierung, Bundle-IDs und dieselbe gültige App Group für App und Erweiterung übernehmen.
3. In Xcode **Product → Clean Build Folder** und anschließend das Schema **ForE** bauen. Die vollständig gebaute `ForE.app` nach `/Applications` kopieren und die installierte App ersetzen.
4. Diese App aus Programme öffnen, Safari starten und die ForE-Erweiterung aktivieren. In ForE **Einstellungen → Safari-Schutz mit Privat-Relay → Hintergrundagent einrichten** wählen. Gegebenenfalls die macOS-Hintergrundfreigabe erlauben. Anschließend eine kurze Sitzung samt Freigabe bei geschlossener Haupt-App testen.

Das ZIP ist ein Xcode-Quellprojekt; es enthält keine fertig signierte App.

## Ergänzung für fehlenden Agentstatus und Hauptthread-Warnungen

Die vorherige Fassung konnte noch vor dem ersten Heartbeat im Safari-Aufruf festhängen. Timer und Status starteten erst danach. Jetzt werden der erste Status und der Timer vor dem Safari-Aufruf eingerichtet; SafariServices hat eine eigene Request-Queue. Die Oberfläche führt Service-Management und Containerzugriffe außerhalb des Hauptthreads aus und liest einen veröffentlichten Registrierungsstatus. Ein fehlender Prozessstatus erhält eine eigene Diagnose, statt erneut nur zur Einrichtung aufzufordern.

Das App-Target deaktiviert Debug-Dylib-Unterstützung ausdrücklich für den eigenständigen launchd-Start. App und Erweiterung haben Build-Version **2**. Nach dem Neubau Xcode stoppen, die vollständige neue App nach Programme kopieren und dort den Agenten erneut einrichten.

Für den separaten Hintergrundprozess liefert die macOS-App **Konsole** mit dem Filter **SafariAgent** Start- und Initialisierungsfehler. Die Xcode-Konsole der Haupt-App ist kein vollständiges Agentprotokoll. Die gezeigten generischen Hauptthread-/CGS-Warnungen allein bestimmen den konkreten Mac-Fehler nicht.

## Korrektur

- Die App wartet bis zu 41 Sekunden auf die Regelbestätigung. Bisher endete sie nach 15 Sekunden, bevor der Agent sein 30-Sekunden-Limit auswerten konnte.
- Die explizite Einrichtung startet einen bereits registrierten Agenten neu und entfernt seinen alten Status erst nach der abgeschlossenen Abmeldung. Dadurch läuft nach einem Update die neue Version und alte Fehler brechen den neuen Versuch nicht sofort ab.
- Ein fehlender Safari-Callback führt zu einer konkreten Fehlermeldung mit Wiederholungsanleitung. Der Agent bleibt erreichbar und versucht den Reload nach einer Pause erneut, statt sich ständig zu beenden. Sitzungsende und andere Statusänderungen lösen unabhängig von dieser Pause einen neuen Versuch aus.
- Verspätete Callbacks werden anhand ihrer Auftrags-ID verworfen. Bereitschaft erfordert weiterhin Safari-Erfolg und einen frischen Nachweis des exakt angeforderten Regelsatzes.

`Safari-Timeout-Fix.patch` zeigt die Änderungen am entpackten Quellprojekt gegenüber `fix/safari-agent-not-found` (Commit `23403c7d7f6575554f69d4d8afc2b0587efba8ff`). Bei einer bereits angepassten lokalen Kopie lassen sich diese Änderungen manuell übernehmen. Aus dem Projektordner ist der Patch mit `patch -p2` anwendbar.

## Prüfungen und Grenzen

Regressionstests verwenden feste Zeitwerte: Erfolg nach 20 Sekunden, fehlender Callback, verspätete Antworten, Wiederholungen, Freigabe nach Fehlern und passende Erweiterungsnachweise. Der neue GitHub-Workflow entpackt das tatsächliche ZIP, führt die Swift-Tests einschließlich der vorhandenen WebKit-Kompilierungstests aus und baut Debug und Release ohne Signierung.

Lokal ausgeführt: Swift 6.0.3 unter Linux, Paket-Build und **45 XCTest-Tests bestanden**. Drei neue Scheduler-Tests prüfen unter anderem, dass ein absichtlich blockierter Request die Heartbeats und Statusantworten nicht anhält. Zusätzlich wurden `SafariAgent.swift` und `SafariProtection.swift` erfolgreich syntaktisch geparst. Ein zusätzlicher Typcheck mit kleinen Ersatzdefinitionen für nicht verfügbare Apple-APIs prüft die Swift-Actor-/UI-Struktur, ersetzt jedoch keinen echten macOS-SDK-Build. Die zwei WebKit-Tests werden unter Linux nicht ausgeführt. Der vorige GitHub-macOS-Job wurde vor der Ausführung abgebrochen; er liefert keinen Build-Nachweis.

Die persönliche Signierung, Service-Management-Registrierung und echte Safari-Funktion einschließlich Privat-Relay müssen auf dem Mac geprüft werden. Die Korrektur behebt nachweisbare Fehler im Ablauf; aus dem Screenshot allein lässt sich die Ursache des ausbleibenden Safari-Callbacks nicht bestimmen.
