# Prüfstand · 2. November 2026

## Ausgeführt und bestanden

- **20 XCTest-Tests** mit Swift 6.0.3 im Swift-5-Sprachmodus unter Linux: 10 Statistiktests und 10 Tests des Bildschirmzeit-Sitzungsjournals; keine Fehler.
- Swift-Parserprüfung aller **16 Swift-Quell- und Testdateien**. Das ist eine Syntaxprüfung, kein nativer macOS-Build.
- Swift-Package-Manifest beim Linux-Testlauf kompiliert und geladen.
- `bash -n` für `Build.command` und `scripts/build-app.sh`.
- Info.plist als Property List geladen; Bundle-ID und Executable-Namen geprüft.
- Ursprünglicher Hosts-Sperrdienst, Root-Helfer und alte Helfer-Tests aus dieser Variante entfernt.

## Nativer macOS-Build und Integrationstests

Die GitHub-Actions-Pipeline führt `swift test`, den Release-Build, die App-Bündelung und die lokale Codesign-Prüfung aus. Aktueller Status und Build-Artefakt: [macOS-Workflow](https://github.com/YSLkeinPlug-cell/ForE/actions/workflows/macos.yml). Dieser Status ist getrennt von den oben dokumentierten lokalen Linux-Prüfungen.

Am 2. November wurden zwei vom macOS-Compiler gemeldete Probleme korrigiert: die Nebenläufigkeit des Benachrichtigungs-Callbacks und das nicht verfügbare Symbol `kAXLinkRole`. Die Aktivierungsbenachrichtigung verwendet jetzt ein gespeichertes Combine-Abonnement; Links werden über den Accessibility-Rollennamen `AXLink` erkannt.

## Interaktiv auf macOS zu prüfen

- App-Start und Bedienung des erzeugten Bundles auf dem Ziel-Mac.
- Echte Accessibility-Berechtigung, Auffinden und Rücklesen der Auszeit-Steuerung auf jeder vorgesehenen macOS-Version und Sprache.
- Tatsächliche Sperrwirkung für die vom Benutzer eingerichteten Apps und Websites.
- Die vollständige [Mac-Prüfliste](macOS-Validation.md).

Ein erfolgreicher CI-Build bestätigt keine reale App- oder Website-Sperre. Die sechs AppModel-Integrationstests verwenden eine simulierte Bildschirmzeit-Anbindung und ändern keine Systemeinstellungen. Das Quellcode-Archiv enthält weiterhin keine kompilierte oder notarisierte macOS-App.
