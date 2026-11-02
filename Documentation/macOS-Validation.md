# macOS-Validierung

**Auslieferungsstatus:** Diese Liste ist noch nicht auf einem echten Mac ausgeführt. Nicht angekreuzte Punkte sind keine bestandenen Prüfungen. Ein Linux-Quellcodecheck ersetzt weder den nativen Build noch diese interaktiven Tests.

Testumgebung: macOS-Version / Build ______ · Sprache ______ · CPU ______ · Swift-Version ______ · Datum ______

## Build und Start

- [ ] `swift test` erfolgreich; Ergebnis und Testanzahl dokumentiert.
- [ ] `bash scripts/build-app.sh` erfolgreich; `codesign --verify --strict` bestanden.
- [ ] Bundle startet aus einem festen Pfad, Hauptfenster und Menüleiste sind bedienbar.
- [ ] Fokus-, Bildschirmzeit-, Wald- und Einstellungsansicht ohne abgeschnittene Texte.
- [ ] Start unter macOS 13+ geprüft; jede beworbene zusätzliche Version separat getestet.

## Berechtigungen und kontrollierte Fehler

- [ ] Ohne Bedienungshilfenfreigabe erfolgt keine Bildschirmzeit-Änderung und keine Erfolgsmeldung.
- [ ] Freigabe erteilen, App nötigenfalls neu starten; Status wird neu gelesen.
- [ ] Freigabe während einer Sitzung entziehen: Freigabefehler und Wiederherstellungshinweis statt behaupteter Aufhebung.
- [ ] Unbekannte Sprache, unsichtbares/mehrdeutiges Bedienelement oder nicht erreichbare Systemeinstellungen: begrenzter Abbruch ohne Klick auf einen anderen Schalter.
- [ ] Kein Administratorpasswort, keine AppleScript-Automation-Freigabe und kein Vollzugriff auf die Festplatte angefordert.

## Tatsächliche Bildschirmzeitwirkung

- [ ] App- & Websiteaktivität aktiviert; „Immer erlaubt“ enthält Arbeits-Apps und ForE.
- [ ] „Bei Auszeit blockieren“ und Bildschirmzeitcode eingerichtet; Code bleibt ausschließlich beim Benutzer.
- [ ] Bei Auszeit tatsächlich eine zu sperrende App öffnen und Sperrbildschirm prüfen.
- [ ] Zugelassene Arbeits-App und ForE bleiben nutzbar.
- [ ] Gewünschte Websites in jedem verwendeten Browser einzeln prüfen; kein pauschaler Schluss aus dem Auszeit-Schalter.
- [ ] Eigenen Zeitplan und „Geräteübergreifend teilen“ dokumentieren und mögliche Wechselwirkungen prüfen.

## Automation auf Deutsch und Englisch

- [ ] Ausgangszustand „Auszeit aus“ wird richtig gelesen.
- [ ] Start aktiviert ausschließlich die manuelle Auszeit und liest denselben Zustand danach zurück.
- [ ] Zeitplan-Schalter, Bildschirmzeit-Hauptschalter, Code und „Immer erlaubt“ bleiben unverändert.
- [ ] Geplantes Ende nimmt eine durch ForE bestätigte eigene Aktivierung zurück; Zustand anschließend erneut gelesen.
- [ ] Vorzeitiges Ende führt denselben Freigabeweg aus.
- [ ] Ausgangszustand „Auszeit bereits ein“: Start und Ende lassen diese fremde Auszeit bestehen.
- [ ] Systemdialog/Codeabfrage kann manuell erledigt werden; ohne Erledigung keine falsche Bestätigung.
- [ ] Alle Fälle für jede unterstützte Sprache und macOS-Version wiederholen.

## Fehlerfälle und Persistenz

- [ ] Manueller Modus startet ohne Bedienungshilfenfreigabe nach Bestätigung, prüft keine Sperre und ändert die Auszeit beim Ende nicht.
- [ ] Zusätzliche Einstellungsfenster oder Systemdialoge verhindern automatische Klicks; nach manuellem Aufräumen erneut prüfen.

- [ ] Mac vor Ende schlafen legen; nach Aufwachen wird eine fällige Freigabe versucht.
- [ ] App normal beenden: verbleibende Auszeit und erforderliche Wiederherstellung sind klar erkennbar.
- [ ] Prozess während des Starts und während der Freigabe hart beenden; beim nächsten Start keine stille fremde Freigabe.
- [ ] Gespeicherten Zustand kontrolliert unlesbar machen: keine neue Sitzung und keine Überschreibung der beschädigten Datei.
- [ ] Automation nach Änderung scheitern lassen: kein neuer Start bei unklarem Ausgangszustand.
- [ ] Manuelle Wiederherstellung öffnen, Auszeit selbst prüfen und erst danach Hinweis quittieren.
- [ ] Systemuhränderung während Sitzung prüfen; tatsächliche Wirkung einer verkürzten/verlängerten Frist dokumentieren.
- [ ] Bei parallel manuell/geräteübergreifend geändertem Zustand Grenzen der Eigentumserkennung dokumentieren.
- [ ] Verlauf, Tagesziel und Wald nach Neustart korrekt; abgebrochene Sitzungen erhalten keinen Abschlussbaum.

## Alte ForE-Installation

- [ ] Bei separat installiertem früherem Hosts-Helfer wird dieser weder verändert noch als ScreenTime-Zustand interpretiert.
- [ ] Alte Sitzung zuerst über die ursprüngliche App beenden; Testblockierungen nicht gleichzeitig laufen lassen.

Ergebnis / offene Fehler / relevante AX-Beschriftungen: ______
