[Korrigiertes Projekt-ZIP](ForE-Safari.zip) · [Patch für vorhandene Projekte](ForE-II-Safari-Fokus-Fix.patch)

# Safari-Freigabe bei ausgeschaltetem Fokus · Build 3

Diese Fassung korrigiert die Safari-Variante von ForE: Nach dem Ausschalten oder Ablauf des Fokus soll die aktivierte Erweiterung keine Websites sperren. Während einer Sitzung bleiben ausschließlich die ausgewählten Domains und ihre bisherigen `www`-Varianten gesperrt.

## Ursache und Änderung

Die bisherige inaktive Regelliste enthielt eine Regel mit `url-filter: "^$"` und `action.type: "block"`. In Foundation passt dieser Ausdruck nur auf einen leeren String. WebKits Content-Blocker-Compiler erkennt jedoch Filter ohne ein erforderliches Zeichen als allgemeinen Treffer. Die vermeintlich wirkungslose Sperrregel konnte dadurch alle Seiten blockieren. Der erfolgreiche Compile-Callback erkannte diesen Fehler nicht; auch der bisherige Foundation-Regextest deckte ihn nicht ab.

Die inaktive Regelliste enthält jetzt genau diese Regel:

```json
[
  {
    "trigger": {
      "url-filter": ".*",
      "url-filter-is-case-sensitive": false
    },
    "action": {
      "type": "ignore-previous-rules"
    }
  }
]
```

Diese Aktion blockiert keine Anfrage. Sie betrifft nur ForEs eigene Regelliste. Andere Safari-Inhaltsblocker behalten ihre Wirkung. Ein leeres Array wird weiterhin vermieden, weil WebKit es zurückweist.

Die Änderung greift auch beim ersten Start ohne Sitzung, beim Ablauf sowie bei fehlender oder unlesbarer gemeinsamer Konfiguration. Die Regelerzeugung einer aktiven Sitzung und deren Domainprüfung bleiben erhalten. App und Erweiterung erhalten Build-Version 3. Der Hintergrundagent muss die neue Liste weiterhin erfolgreich an Safari übergeben; kompilierte Regeln besitzen keinen eigenen Ablauf-Timer.

Technischer Hintergrund in WebKit: [`URLFilterParser::finalize`](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/contentextensions/URLFilterParser.cpp) klassifiziert Filter ohne erforderliches Zeichen als `MatchesEverything`; [`ContentExtensionCompiler`](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/contentextensions/ContentExtensionCompiler.cpp) übernimmt diese als universelle Aktionen.

## Jetzt wieder surfen

Bis die neue App installiert ist: Unter **Safari → Einstellungen → Erweiterungen** den **ForE Safari-Schutz** ausschalten und die betroffene Website neu laden.

## Korrigierte App übernehmen

1. Eine laufende Sitzung beenden. ForE schließen, einen laufenden Xcode-Debug-Start stoppen und Safari vollständig mit **⌘Q** beenden.
2. Im entpackten Projekt **ForE.xcodeproj** öffnen. Die eigenen Team-, Bundle-ID- und App-Group-Einstellungen aus dem bisherigen Projekt übernehmen. App und Erweiterung müssen dieselbe berechtigte App Group verwenden. Details stehen im entpackten Projekt unter `Documentation/Safari-Setup.md`.
3. **Product → Clean Build Folder** ausführen und das vollständige Schema **ForE** bauen.
4. Unter **Products → ForE.app → Show in Finder** die neu gebaute vollständige App nach **Programme** kopieren und die bisherige App ersetzen. Anschließend genau diese installierte Kopie öffnen.
5. Safari öffnen, den **ForE Safari-Schutz** aktivieren und in ForE **Einstellungen → Hintergrundagent einrichten** wählen. Dadurch wird der alte Agent durch die aktuelle Version ersetzt und die inaktive Regelliste neu geladen. Eine erforderliche macOS-Hintergrundfreigabe bestätigen und auf den bereiten Status warten.

Für ein bereits persönlich konfiguriertes Projekt liegt zusätzlich ein Patch bei. Im Projektordner erst `git apply --check /Pfad/ForE-II-Safari-Fokus-Fix.patch` ausführen und anschließend denselben Patch mit `git apply` übernehmen. Das vollständige ZIP enthält alle Quelltexte; der Patch ist gegen den unten genannten Ausgangsstand erstellt.

## Auf dem Mac prüfen

1. Erweiterung aktiviert lassen, Fokus ausgeschaltet: `gesetze.jurafuchs.de` und eine Domain aus der Sperrliste müssen erreichbar sein.
2. Fokus starten: Eine ausgewählte Domain muss blockiert werden; `gesetze.jurafuchs.de` muss erreichbar bleiben, sofern es nicht in der Sperrliste steht.
3. Fokus vorzeitig beenden: Beide Domains müssen nach bestätigter Freigabe wieder erreichbar sein, während die Erweiterung aktiviert bleibt.
4. Eine kurze Sitzung automatisch auslaufen lassen und dabei ForE mit **⌘Q** schließen: Nach der Freigabe durch den Hintergrundagenten müssen beide Domains wieder erreichbar sein.

Jeden Aufruf frisch laden. Der Agent prüft den Sitzungszustand alle drei Sekunden; Safari muss den neuen Regelsatz zusätzlich übernehmen. Bleibt die Sperre bestehen, zur sofortigen Freigabe die ForE-Erweiterung ausschalten und den Agentstatus prüfen.

## Ausgangsstand und Prüfung

Grundlage ist `ForE-Safari.zip` aus `YSLkeinPlug-cell/ForE`, Zweig `fix/safari-rule-confirmation`, Commit `0e21a430e8c8c2a83dbb65caaa310b68c52b11a9` (Archiv-Blob `594565f76931dcbd49549c40118a8c54c004d86a`). Es handelt sich um das Safari-Projekt mit Xcode-Projekt, Hosts-Helper und Safari-Agent.

Unter Linux mit Swift 5.9.2 bestehen **45 Tests ohne Fehler**; alle **25 Swift-Dateien** bestehen die Syntaxprüfung. Der aktualisierte Regressionstest schlägt mit dem alten Regelerzeuger in allen sieben inaktiven Konfigurationen fehl und besteht mit der Korrektur. Ein zusätzlicher macOS-Test prüft echte WKWebView-Navigation in der Reihenfolge inaktiv → aktiv → inaktiv gegen einen lokalen HTTP-Server; er wurde hier nicht ausgeführt. Der genaue Prüfstand steht in `Pruefstand.txt`. Ein vollständiger macOS-Build, die persönliche Signierung sowie Safari mit aktivierter Erweiterung und der Hintergrundagent benötigen einen Mac. Eine hier erfolgreiche Prüfung der Kernlogik ersetzt diese Prüfung nicht.
