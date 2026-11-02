# Prüfstand · 2. November 2026

## Ausgeführt und bestanden

- **20 XCTest-Tests** mit Swift 6.0.3 im Swift-5-Sprachmodus unter Linux: 10 Statistiktests und 10 Tests des Bildschirmzeit-Sitzungsjournals; keine Fehler.
- Swift-Parserprüfung aller **16 Swift-Quell- und Testdateien**. Das ist eine Syntaxprüfung, kein nativer macOS-Build.
- Swift-Package-Manifest beim Linux-Testlauf kompiliert und geladen.
- `bash -n` für `Build.command` und `scripts/build-app.sh`.
- Info.plist als Property List geladen; Bundle-ID und Executable-Namen geprüft.
- Ursprünglicher Hosts-Sperrdienst, Root-Helfer und alte Helfer-Tests aus dieser Variante entfernt.

## Noch auf macOS auszuführen

- Vollständiger SwiftUI-/AppKit-Build, App-Bundle, Codesign-Prüfung und App-Start.
- Die sechs AppModel-Integrationstests mit simulierter Bildschirmzeit-Anbindung. Sie sind im macOS-Testtarget enthalten; sie greifen nicht auf reale Systemeinstellungen zu.
- Echte Accessibility-Berechtigung, Auffinden und Rücklesen der Auszeit-Steuerung auf jeder vorgesehenen macOS-Version und Sprache.
- Tatsächliche Sperrwirkung für die vom Benutzer eingerichteten Apps und Websites.
- Die vollständige [Mac-Prüfliste](macOS-Validation.md).

Die mitgelieferte GitHub-Actions-Konfiguration ist vorbereitet, wurde in dieser Arbeitsumgebung aber nicht ausgeführt. Es liegt eine Quellcode-Version vor; keine kompilierte oder notarisierte macOS-App.
