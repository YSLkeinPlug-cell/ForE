# Architektur: ForE ScreenTime

## Native Anwendung

Die SwiftUI-App ist ein Swift-Package-Executable (`ForEScreenTime`) mit einer gemeinsam genutzten Kernbibliothek (`ForECore`). `scripts/build-app.sh` erzeugt auf einem Mac das App-Bundle. Die Anwendung läuft ohne App-Sandbox, Administratorrechte oder privilegierten Helfer. Sie verwendet die vom Benutzer erteilte Bedienungshilfenfreigabe.

Die neue Version ist von der früheren Hosts-basierten ForE-Variante getrennt: eigene Bundle-ID, eigener Datenordner, keine Migration von Root-Helfern und kein Schreiben in `/etc/hosts`.

## Bildschirmzeit-Grenze

`ScreenTimeBridge` verwendet die öffentliche Accessibility-Schnittstelle, um die sichtbare Systemeinstellungen-App zu bedienen. Dies ist keine Bildschirmzeit-Programmierschnittstelle. Die Oberfläche von Bildschirmzeit besitzt keine zugesicherte, versionsübergreifend stabile Struktur.

Die Brücke sucht mit Zeit- und Traversierungsgrenzen nach bekannten deutschen bzw. englischen Auszeit-Bedienelementen. Unbekannte oder mehrdeutige Zustände erzeugen Fehler. Die Brücke ändert weder Zeitpläne, Bildschirmzeitcodes, geräteübergreifende Freigaben noch „Immer erlaubt“-Regeln. Systemabfragen und Codeeingaben bleiben Sache des Benutzers.

Ein zurückgelesener eingeschalteter Auszeit-Schalter bestätigt ausschließlich diesen Schalter. ForE kann damit weder „Bei Auszeit blockieren“ noch die Sperrwirkung für einzelne Apps, Browser und Websites garantieren. Die eigenständige Prüfung dieser Regeln ist Teil der Einrichtung.

## Sitzungsablauf und Wiederherstellung

Beim Start liest das Modell zunächst den sichtbaren Zustand. Eine bereits aktive Auszeit wird als fremde Einstellung behandelt und am Sitzungsende beibehalten. Eine ausgeschaltete Auszeit wird erst nach vorbereitetem lokalem Sitzungszustand aktiviert. Nur eine danach bestätigte, von der Sitzung vorgenommene Aktivierung darf später zurückgenommen werden.

Persistierter Zustand erlaubt es, nach einem Neustart einen nicht abgeschlossenen Vorgang zu erkennen. Unklare Änderungen dürfen nicht stillschweigend als eigene Auszeit interpretiert werden. Bei nicht eindeutig bestätigter Freigabe zeigt die App den Wiederherstellungsweg über die Systemeinstellungen und sperrt einen neuen Sitzungsstart, bis der Vorgang geklärt ist.

Die Herkunft externer Änderungen während der Sitzung ist nicht vollständig beobachtbar. Der Benutzer sollte die Auszeit daher nicht parallel in anderen Oberflächen oder auf synchronisierten Geräten ändern. Bildschirmzeit-Zeitpläne bleiben unter der Kontrolle von macOS.

Der manuelle Modus startet ausschließlich nach einer ausdrücklichen Bestätigung des Benutzers. Er verwendet keine Accessibility-Aufrufe, kennzeichnet den Schalterzustand als unbekannt und behandelt die Auszeit als fremde Einstellung. Die Rücknahme bleibt dabei beim Benutzer.

## Fristen und Lebenszyklus

Die Frist ist als Datum gespeichert. Schlafen des Macs pausiert die Fokuszeit nicht. Eine fällige Aktion kann erst ausgeführt werden, wenn der Prozess wieder läuft und die Systemeinstellungen erreichbar sind. Kein LaunchDaemon und kein unabhängiger Timer übernimmt die Freigabe nach dem Beenden der App. Eine verbleibende Auszeit wird über die Wiederherstellung oder manuell in macOS freigegeben.

Verlaufsdaten und Sitzungszustand liegen lokal unter `~/Library/Application Support/ForE-ScreenTime`. Die App ruft keine Konten oder externen Dienste auf. Apples optionale Bildschirmzeit-Synchronisierung ist davon unabhängig.

## Prüfbarkeit

Die Kernlogik besitzt XCTest-Tests. Accessibility und tatsächliche Sperren benötigen einen interaktiven Mac mit erteilter Freigabe; ein erfolgreicher Compilerlauf oder GitHub-Actions-Build prüft diese Wirkung nicht. Die konkrete macOS-Version und Oberflächensprache müssen im [Validierungsprotokoll](macOS-Validation.md) erfasst werden.
