# ForE · ScreenTime

[ZIP-Paket](ForE.zip) · [macOS-Builds und Tests](https://github.com/YSLkeinPlug-cell/ForE/actions)

Ein nativer macOS-Prototyp für Fokuszeiten, einen wachsenden Wald und lokalen Verlauf. Diese Variante verwendet **die Auszeit von macOS-Bildschirmzeit** statt des früheren Hosts-Datei-Sperrhelfers.

**Status:** Quellcode-Prototyp. [GitHub Actions](https://github.com/YSLkeinPlug-cell/ForE/actions/workflows/macos.yml) prüft den nativen macOS-Build und die Tests. Erfolgreiche Läufe stellen ein lokal ad hoc signiertes App-Bundle als Build-Artefakt bereit. Das Quellcode-Archiv enthält keine kompilierte oder notarisierte App. Die tatsächliche Bildschirmzeit-Automation muss zusätzlich interaktiv auf einem Mac geprüft werden.

## Der neue Mechanismus

ForE öffnet die Systemeinstellungen und bedient nach deiner Freigabe deren Auszeit-Steuerung über macOS-Bedienungshilfen (`AXUIElement`). Vor einer Sitzung wird der sichtbare Zustand gelesen; nach einer Änderung wird er erneut gelesen. Nur eine von dieser Sitzung eingeschaltete Auszeit wird am Ende wieder ausgeschaltet. Eine schon vorher aktive Auszeit bleibt bestehen.

**Das ist experimentelle Oberflächenautomation.** Apple stellt für native macOS-Apps keine öffentliche API zum Setzen globaler Bildschirmzeit-Sperrregeln bereit. Die iOS-Frameworks ManagedSettings und DeviceActivity sind kein gleichwertiger nativer macOS-Zugang. STWebpageController berücksichtigt vorhandene Website-Regeln innerhalb einer eigenen App, setzt aber keine globalen Regeln. Die unterstützten deutschen und englischen Bedienelemente können sich mit einer macOS-Version ändern. Wenn ForE den Zustand nicht eindeutig lesen oder bestätigen kann, meldet es das und führt zur manuellen Einrichtung; ein laufender Timer bestätigt keine App- oder Website-Sperre.

ForE konfiguriert **keine eigene App- oder Website-Sperrliste**. Was macOS während der Auszeit sperrt, bestimmst du in den Systemeinstellungen. Die App liest auch keine Bildschirmzeit-Nutzungsdaten aus.

## Bauen und starten

Du brauchst einen Mac mit **macOS 13 oder neuer**, Xcode 15+ einschließlich Command Line Tools oder eine passende Swift-5.9+-Toolchain. Öffne Terminal im entpackten Projektordner:

```sh
swift test
bash scripts/build-app.sh
open 'build/ForE ScreenTime.app'
```

Das Skript baut für die Architektur des verwendeten Macs (Apple Silicon oder Intel), erzeugt ein App-Bundle und signiert es lokal ad hoc. Es installiert nichts und ändert keine Bildschirmzeit-Einstellungen. Verschiebe die App vor der Bedienungshilfenfreigabe möglichst an einen festen Ort, etwa `/Applications`; nach einem Neubau kann die Freigabe erneut nötig sein. Für eine Weitergabe mit Developer-ID-Signatur und Notarisierung sind ein Apple-Entwicklerkonto und ein eigener Signierprozess nötig. Das Projekt lässt sich außerdem über `Package.swift` in Xcode öffnen.

Alternativ startet ein Doppelklick auf `Build.command` denselben Build. Die App liegt anschließend im Ordner `build`.

## Bildschirmzeit einmal einrichten

1. Öffne **Systemeinstellungen → Bildschirmzeit**. Aktiviere nötigenfalls **App- & Websiteaktivität**.
2. Wähle unter **Immer erlaubt** die benötigten Arbeits-Apps und **ForE ScreenTime**. Die Auszeit wirkt auf die übrigen Apps nach deinen macOS-Regeln. Prüfe Websites und Browser separat auf deinem Mac.
3. Richte **Auszeit** ein. Für eine tatsächlich erzwungene Sperre aktiviere **Bei Auszeit blockieren** und verwende einen von dir verwalteten Bildschirmzeitcode. ForE kennt diesen Code nicht und umgeht ihn nicht. Ein selbst bekannter Code lässt sich weiterhin selbst verwenden; die App ist keine manipulationssichere Sperre.
4. Prüfe bewusst, ob deine Bildschirmzeit über **Geräteübergreifend teilen** auch andere Apple-Geräte betrifft.
5. Erlaube ForE unter **Datenschutz & Sicherheit → Bedienungshilfen** den Zugriff. Die App fordert weder Administratorrechte noch Vollzugriff auf die Festplatte an.
6. Bestätige in ForE, dass du die Regeln eingerichtet hast. Diese Bestätigung ist deine Angabe und keine technische Prüfung. Prüfe den Auszeit-Schalter mit der entsprechenden Aktion und teste anschließend selbst eine zu sperrende App.

Die Bedienungshilfenfreigabe gilt für die App, nicht nur für Bildschirmzeit. Erteile sie nur einer von dir geprüften Version. Die Implementierung beschränkt ihre Suche auf bekannte Bildschirmzeit-Bedienelemente; sie ändert weder den Zeitplan noch deinen Code oder die „Immer erlaubt“-Liste.

## Eine Fokuszeit

Die Automation akzeptiert ausschließlich eindeutig beschriftete Auszeit-Elemente. Generische „Aktivieren“-/„Deaktivieren“-Knöpfe, zusätzliche Einstellungsfenster und offene Systemdialoge führen zur manuellen Prüfung. Dadurch kann auch eine sonst unterstützte macOS-Version den manuellen Weg erfordern.

Wähle eine Dauer und starte **Auszeit & Fokus**. Die Systemeinstellungen werden dabei sichtbar geöffnet. Falls Bildschirmzeit einen Code oder eine weitere Systembestätigung verlangt, erledige diese selbst. ForE behauptet erst nach dem Zurücklesen, dass der Auszeit-Schalter eingeschaltet ist. Das bestätigt den Schalter, nicht die Durchsetzung jeder Regel.

**Lass ForE während der Sitzung laufen.** Im Ruhezustand läuft die Frist nach der Systemuhr weiter; eine fällige Freigabe wird nach dem Aufwachen versucht. Der Timer verändert weder deinen Bildschirmzeit-Zeitplan noch plant er eine Freigabe in macOS selbst. Wird die App beendet, beendet macOS ihren Prozess oder schlägt die Automation fehl, kann die Auszeit aktiv bleiben. Es gibt keinen unabhängigen Hintergrundhelfer.

Bei unklarem Zustand zeigt ForE einen Wiederherstellungshinweis. Öffne dann Bildschirmzeit und prüfe bzw. ändere die Auszeit selbst, bevor du den Hinweis quittierst. Eine neue Sitzung ist bei ungeklärter Wiederherstellung gesperrt. Ändere die Auszeit möglichst nicht gleichzeitig manuell oder von einem anderen Gerät: Oberflächenautomation kann die Herkunft einer zwischenzeitlichen Änderung nicht zweifelsfrei ermitteln.

Wenn der Schalter nicht erkannt wird, öffne Bildschirmzeit selbst, aktiviere die Auszeit und wähle in ForE **Auszeit manuell aktivieren & Timer starten …**. Nach deiner ausdrücklichen Bestätigung läuft der Fokus-Timer ohne Bedienungshilfenaufrufe. Dieser Modus prüft die Auszeit nicht und schaltet sie am Ende nicht aus; das erledigst du selbst in macOS.

## Daten und bestehende ForE-Installation

Verlauf und Sitzungszustand bleiben im Benutzerordner `~/Library/Application Support/ForE-ScreenTime`. Keine Konten, Cloud-Anbindung oder Analyse-Tracker. Die System-Bildschirmzeit verwendet weiterhin Apples eigene Einstellungen und gegebenenfalls deine gewählte iCloud-Synchronisierung.

Diese Variante installiert keinen privilegierten Helfer und ändert `/etc/hosts` nicht. Sie übernimmt keine frühere Systeminstallation. Wenn der alte ForE-Sperrhelfer bereits auf deinem Mac installiert ist und eine alte Sitzung hält, gib diese zuerst mit der ursprünglichen App frei. Das Entfernen alter Helfer oder ihrer Systemeinstellungen geschieht hier nicht automatisch.

## Validierung

In der Linux-Arbeitsumgebung bestanden **20 Kernlogiktests** sowie die Swift-Syntax- und Shellprüfungen. Der macOS-Workflow führt zusätzlich sechs AppModel-Integrationstests und den nativen Release-Build aus. Den aktuellen Laufstatus findest du in GitHub Actions; die echte Bildschirmzeit-Steuerung wird weiterhin manuell geprüft. Details: [Prüfstand](Documentation/Verification.md).

- `swift test`: plattformunabhängige Sitzungs- und Statistiktests; auf macOS zusätzlich sechs Integrationstests mit simulierter Bildschirmzeit-Anbindung, ohne Systemänderungen.
- `bash scripts/build-app.sh`: vollständiger nativer Release-Build, App-Bundle und lokale Signaturprüfung.
- `.github/workflows/macos.yml`: dieselben Prüfungen auf einem macOS-Runner, anschließend App-Archiv als Build-Artefakt.
- [Mac-Prüfliste](Documentation/macOS-Validation.md): notwendige manuelle Tests der tatsächlichen Sperrwirkung, DE/EN-Oberfläche und Wiederherstellung.
- [Architektur](Documentation/Architecture.md): Zustands- und Berechtigungsgrenzen.

## Apple-Quellen

- [Bildschirmzeit: Auszeit auf dem Mac](https://support.apple.com/en-nz/guide/mac-help/mchl69510069/mac)
- [App-Limits auf dem Mac](https://support.apple.com/en-gb/guide/mac-help/mchl630bc02f/mac)
- [ManagedSettings-Plattformen](https://developer.apple.com/tutorials/data/documentation/managedsettings.json)
- [DeviceActivity-Plattformen](https://developer.apple.com/tutorials/data/documentation/deviceactivity.json)
- [STWebpageController](https://developer.apple.com/documentation/screentime/stwebpagecontroller)
- [Apples Grundlagen zur Bedienoberflächenautomation](https://developer.apple.com/library/archive/documentation/LanguagesUtilities/Conceptual/MacAutomationScriptingGuide/AutomatetheUserInterface.html)
