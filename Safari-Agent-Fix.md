# ForE: Safari-Hintergrundagent reparieren

**Aktuelle Ergänzung:** Der zusätzliche Fix für Zeitüberschreitungen und den kontrollierten Agent-Neustart ist in [Safari-Timeout-Fix.md](Safari-Timeout-Fix.md) beschrieben. Die folgenden Angaben dokumentieren den vorherigen Registrierungs-/AppKit-Fix.

Die Meldung „Die registrierte ForE-App wurde nicht gefunden“ wurde in der Safari-Version zu früh ausgelöst: Bei `SMAppService.Status.notFound` hat ForE keine Registrierung versucht. Das bloße Öffnen derselben App aus Programme konnte diesen Codepfad nicht beheben. Der Status beweist nicht, dass die App fehlt. Zusätzlich kann ein tatsächlich unvollständiges App-Paket oder eine veraltete macOS-Registrierung vorliegen.

## Korrigiertes Projekt installieren

1. **ForE-Safari.zip aus diesem Fix-Branch herunterladen** und in einen neuen Ordner entpacken. Das ist ein Xcode-Quellprojekt, keine fertig signierte App.
2. Eine laufende ForE-Sitzung beenden und die Website-Freigabe prüfen. ForE schließen und einen eventuellen Xcode-Lauf stoppen.
3. `ForE.xcodeproj` aus dem neuen Ordner öffnen. Dein bisheriges echtes Development Team, **Apple Development** als Signierung und dieselbe gültige macOS-App-Group für App und Safari-Erweiterung einstellen. Falls du eigene Bundle-IDs verwendet hast, diese ebenfalls übernehmen. Einzelheiten stehen im Projekt unter `Documentation/Safari-Setup.md`.
4. In Xcode **Product → Clean Build Folder** und anschließend **Product → Build** mit dem Schema **ForE** ausführen.
5. Unter **Products → ForE.app → Show in Finder** die neu gebaute App nach **Programme** (`/Applications`) kopieren und die bisherige App ersetzen. Danach diese Kopie im Finder öffnen.
6. In ForE unter **Einstellungen → Safari-Schutz mit Privat-Relay → Hintergrundagent einrichten** erneut einrichten. Wenn nötig, ForE unter **Systemeinstellungen → Allgemein → Anmeldeobjekte** (auf neueren Versionen **Anmeldeobjekte & Erweiterungen**) im Hintergrund erlauben. In Safari die ForE-Erweiterung aktivieren, dann in ForE **Status prüfen** wählen.

Erfolg bedeutet: **Erweiterung aktiviert** und **Hintergrundagent bereit**. Anschließend mit einer kurzen Testsitzung prüfen, dass die Website blockiert und nach Ablauf auch bei geschlossener App wieder freigegeben wird.

## Wenn weiter ein Fehler erscheint

**Safari-Reload bleibt ohne Antwort / `NSSharingService_Subsystem` fehlt:** Der macOS-Erweiterung fehlte die AppKit-Verknüpfung. Das aktuelle Projekt importiert im Request-Handler `Cocoa` und verknüpft `AppKit.framework` explizit im Target **ForESafariBlocker**. Für eine bestehende lokale Kopie unter **ForESafariBlocker → Build Phases → Link Binary With Libraries → +** `AppKit.framework` als **Required** hinzufügen (Systemframework: **Do Not Embed**). In `ContentBlockerRequestHandler.swift` `import Foundation` durch `import Cocoa` ersetzen. Die bereits korrigierten App-Group-Berechtigungen bleiben bestehen. Danach das Schema vollständig bereinigen und neu bauen, Safari beenden und wieder öffnen, den ForE-Agenten neu starten und die Einrichtung prüfen. Ein neuer Erweiterungsnachweis und eine erfolgreiche Regelbestätigung müssen vorliegen; den Ablauf einer kurzen Sitzung auch bei geschlossener App testen. Der konkrete Bootstrap-Fehler wurde in einem Benutzerprotokoll unter macOS 13.7.8 gefunden; der Funktionstest des korrigierten Builds muss auf dem Mac erfolgen.

**Xcode-Fehler `Cannot find 'SMAppServiceErrorDomain' in scope`:** Das aktuelle ZIP korrigiert beide Stellen in `SafariProtection.swift`. Zum Aktualisieren eines bereits geöffneten Projekts an beiden Stellen `failure.domain == SMAppServiceErrorDomain` durch `failure.domain == "SMAppServiceErrorDomain"` ersetzen und erneut bauen. Die Anführungszeichen sind erforderlich. So wird die von `NSError` gelieferte Fehlerdomain verglichen, ohne das in älteren SDKs fehlende Konstantensymbol zu verwenden. Ein Xcode-Update oder ein höheres macOS-Mindestziel ist für diese Korrektur nicht nötig.

Die neue Meldung enthält bei Registrierungsfehlern die Fehlerdomain, Fehlernummer und den Pfad der tatsächlich laufenden App. Diese vollständige Meldung für die weitere Diagnose verwenden.

Die Dienstdatei im installierten App-Paket lässt sich ohne Änderungen prüfen:

```sh
plutil -lint "/Applications/ForE.app/Contents/Library/LaunchAgents/de.fore.safari-agent.plist"
test -x "/Applications/ForE.app/Contents/MacOS/ForE" && echo "ForE-Programm vorhanden"
```

Wenn die Dienstdatei fehlt, das vollständige Schema neu bauen. Nicht nachträglich Dateien in die signierte App einsetzen. Ein globales Zurücksetzen aller macOS-Hintergrundeinträge ist für diesen Fix nicht vorgesehen.

## Änderung und Prüfstand

Basis ist der Safari-Branch `export/fore-safari-private-relay-2026-10-30`, Commit `591406db646327c0c92282b18799cb256ebd76df`. Im Quellarchiv wurden ausschließlich `ForE/Services/SafariProtection.swift`, `SafariBlocker/ContentBlockerRequestHandler.swift`, `ForE.xcodeproj/project.pbxproj` und `Documentation/Safari-Setup.md` geändert. Der lesbare Patch liegt neben dem ZIP unter `Safari-Agent-Fix.patch` (aus dem entpackten Projekt mit `patch -p2` anwendbar, falls stattdessen die bestehende Safari-Codebasis aktualisiert werden soll).

Die Einrichtung prüft das App-Paket, versucht auch bei `.notFound` eine Registrierung und kann nach einem fehlgeschlagenen Versuch den einzelnen alten ForE-Dienst abmelden und einmal neu registrieren. Das Abmelden wird abgewartet. Fehlende Benutzerfreigaben werden weiterhin respektiert; bereits aktivierte Dienste werden nicht neu registriert. Die Bereitschaft erfordert weiterhin einen aktuellen Agentstatus und eine Safari-Regelbestätigung.

Geprüft: Archivintegrität, unveränderte übrige Dateien, XML-Plists und Xcode-Schemata sowie LaunchAgent-Konfiguration und Einbettungsverweise. **Nicht ausgeführt:** Swift-/Xcode-Build und echte Safari-/macOS-Dienstregistrierung, da diese Arbeitsumgebung Linux ohne Swift-Compiler ist. Das korrigierte Projekt muss auf dem Mac gebaut und geprüft werden.

Quellen: [Apple: Service-Status](https://developer.apple.com/documentation/servicemanagement/smappservice/status-swift.enum), [Apple: register()](https://developer.apple.com/documentation/servicemanagement/smappservice/register%28%29), [Karabiner: Erfahrungen mit veralteten Dienstregistrierungen](https://github.com/pqrs-org/Karabiner-Elements/blob/main/DEVELOPMENT.md#macos-service-management). Die Karabiner-Beobachtungen betreffen Daemons und belegen nicht die konkrete Ursache auf jedem Mac.
