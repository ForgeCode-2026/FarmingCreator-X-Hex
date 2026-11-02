# Changelog

Alle relevanten Änderungen an FarmingCreator-X-Hex. Bei jedem Update sind die Dateien aufgelistet, die beim Aktualisieren einer bestehenden Installation **ersetzt** werden müssen.

> **Update-Anleitung:** Server stoppen → die gelisteten Dateien durch die neuen Versionen ersetzen → Server starten. Eigene Anpassungen an `shared/config.lua` / `shared/consumables_config.lua` vorher sichern und danach wieder einpflegen. Die Datenbank bleibt bei Updates unverändert, sofern nicht ausdrücklich ein SQL-Import erwähnt wird.

---

## [1.5.2] – 2026-11-03

### Behoben

- **Dupe beim Abholen**: `collectJob` und `collectFinished` konnten parallel denselben Auftrag auszahlen. Aufträge werden während einer Datenbank-Operation gesperrt; der Status wird vor der Item-Ausgabe gespeichert und bei Fehlschlag zurückgesetzt.
- **Doppelte Rezept-Inputs**: Gleiche Items in einem Rezept werden zusammengerechnet. Schlägt das Entfernen eines Items fehl, werden bereits entfernte Items zurückgegeben.
- **Verarbeitung bei Datenbankfehlern**: Ein DB-Fehler beendet nicht mehr den Verarbeitungs-Thread und blockiert keine Aufträge mehr; eingesetzte Items werden zurückgegeben.
- **Projekt löschen**: Laufende Aufträge an den Punkten des Projekts werden wie beim Löschen eines Punkts entfernt und die Spieler benachrichtigt. Vor dem Löschen erscheint eine Ja/Nein-Abfrage.
- **Auszahlung**: Schlägt die Gutschrift fehl (z. B. QBCore ohne `black_money`-Konto), erhält der Spieler seine Items zurück.
- **Boost**: Kommazahl-Multiplikatoren (z. B. 1.5) beenden den Boost-Thread nicht mehr; Zeitfenster über Mitternacht (z. B. 22:00–02:00) funktionieren.
- **MySQL 8**: Das SQL-Skript nutzt kein MariaDB-only `ADD COLUMN IF NOT EXISTS` mehr. Fehlende Spalten werden beim Start automatisch ergänzt.
- **Datenschutz**: Der Identifier des erstellenden Admins wird nicht mehr an alle Clients synchronisiert.
- **Sync-Spam**: `forge_farming:requestSync` ist pro Spieler auf einen Aufruf alle 2 Sekunden begrenzt.
- **Servervalidierung**: Ganzzahlen, Textlängen, Farbwerte (0–255), Koordinaten und Blip-Werte werden geprüft.
- **NPC-Ausrichtung**: NPCs schauen beim Platzieren an Ost-/Westwänden nicht mehr in die Wand.
- **Marker-Vorschau**: Die Vorschau für Verarbeiter-/Verkäufer-Marker hat dieselbe Größe wie der echte Marker.
- **Ungültige Ped-Modelle**: werden erkannt statt endlos neu gespawnt; beim Platzieren erscheint eine Fehlermeldung.
- **Verkäufer-Menü**: hängt nicht mehr dauerhaft, wenn der Server nicht antwortet.
- **Performance**: Sammler- und Verarbeiter-Schleifen laufen ohne Punkte in der Nähe nur noch alle 500 ms.
- **Verkaufspreis löschen**: entfernt den gewählten Eintrag statt eines Eintrags an derselben Listenposition.
- **Fehlender Text**: `error_recipe_has_active_jobs` ist lokalisiert.

### Geändert

- `verkäufer.lua` heißt jetzt `verkaeufer.lua` (Client und Server), um Ladeprobleme mit Umlauten in Dateinamen zu vermeiden. **Die alten Dateien `client/modules/verkäufer.lua` und `server/modules/verkäufer.lua` bitte löschen.**
- Platzhalter in `Config.BoostStartAnnounce` / `Config.BoostEndAnnounce` ist jetzt `%s` statt `%d`.
- Abgeholte Aufträge werden beim Ressourcenstart aus `forge_farming_jobs` entfernt.

### Zu ersetzende Dateien

| Datei | Grund |
| --- | --- |
| `fxmanifest.lua` | umbenannte Verkäufer-Dateien, Versions-Bump auf 1.5.2 |
| `framework/init.lua` | ESX-Auszahlung prüft das Konto |
| `client/main.lua` | NPC-Ausrichtung, Vorschau, Löschabfrage, Ped-Prüfung |
| `client/modules/farming.lua` | Schleifen-Performance |
| `client/modules/verarbeiter.lua` | Ped-Prüfung, Schleifen-Performance |
| `client/modules/verkaeufer.lua` | ersetzt `verkäufer.lua`; Timeout, Ped-Prüfung |
| `server/main.lua` | Validierung, Sync-Limit, Migrationen, Projekt-Löschung |
| `server/modules/farming.lua` | Boost-Fixes |
| `server/modules/verarbeiter.lua` | Dupe-Schutz, Inputs, DB-Fehlerbehandlung |
| `server/modules/verkaeufer.lua` | ersetzt `verkäufer.lua`; Auszahlungs-Rollback |
| `shared/sv_config.lua` | `%s`-Platzhalter für Boost-Texte |
| `locals/languages/de.lua` | neue Fehlermeldungen |
| `sql/forge-Farming.sql` | MySQL-8-kompatibel |
| `CHANGELOG.md` | Release-Hinweise für 1.5.2 |

## [1.5.1] – 2026-08-03

### Behoben

- **HUD-Notify-Adapter**: `fc_hud` erhält Notify-Werte wieder in der erwarteten Reihenfolge `type, title, message, timeout`; alle unterstützten HEX-HUDs erhalten `title, message, type, timeout` über ihre Exports. HelpNotify- und Native-Fallbacks bleiben erhalten.
- **Creator-Admin-Gate**: `/farmingcreator` und `/consumablescreator` öffnen ihre Menüs nur nach einer gemeinsamen serverseitigen Prüfung über die konfigurierten ESX-/QBCore-Adminrechte. Abgewiesene Spieler erhalten „Keine Berechtigung“; alle Mutation-Checks bleiben erhalten.

### Zu ersetzende Dateien

| Datei | Grund |
| --- | --- |
| `framework/init.lua` | korrigierte HUD-Adapter, Argumentreihenfolge und Fallbacks |
| `client/main.lua` | autorisiertes Farming-Creator-Open-Event |
| `server/creator_access.lua` | gemeinsame serverseitige Creator-Admin-Prüfung |
| `server/modules/consumables.lua` | geschützter Consumables-Creator-Command |
| `server/main.lua` | geschützter Farming-Creator-Command |
| `tests/test_framework_hud.lua` | Regressionstests für HUD-Auswahl und Fallbacks |
| `tests/test_creator_access.lua` | Regressionstest für die Creator-Zugriffsprüfung |
| `fxmanifest.lua` | Script-Eintrag und Versions-Bump auf 1.5.1 |
| `CHANGELOG.md` | Release-Hinweise für 1.5.1 |

## [1.5.0] – 2026-08-01

### Behoben

- **Absoluter Consumable-Speed**: Ein Item-Speed überschreibt während der Wirkung den bereits erhöhten Server-Standard. Der Item-Wert wird im Effekt-Thread erneut gesetzt und nach Ablauf, Tod, Effektwechsel oder Ressourcenstopp durch `Config.Playerspeed` ersetzt.
- **Gültiger Standard-Speed**: `Config.Playerspeed` ist jetzt eine Zahl statt einer Tabelle und wird vor der Übergabe an FiveM-Natives defensiv begrenzt.
- **Consumable-Progress**: Die zuvor fehlenden clientseitigen Methoden `Framework.StartProgress` und `Framework.StopProgress` sind implementiert.

### Hinzugefügt

- **Automatische HEX-HUD-Erkennung**: `fc_hud`, Final HUD, Final HUD V2, Future HUD, Genesis HUD, Premium HUD, Free HUD und HUD V4 werden anhand ihres gestarteten Resource-Namens erkannt.
- **Zentrale HUD-Schnittstelle**: Notify, HelpNotify, Announce und Progressbar laufen über `framework/init.lua`. Ohne unterstütztes HUD greifen sichere GTA-Fallbacks.
- **Consumable-Erfolgsnachricht**: Nach dem serverseitig bestätigten Konsum erscheint genau eine Success-Notify mit dem lokalisierten Item-Namen.
- **Konfigurierbarer Versions-Check**: Repository, Branch, Aktivierung, Startverzögerung und maximales Changelog-Ausgabelimit befinden sich in `shared/sv_config.lua`.
- **Regressionstests**: Eigenständige Lua-Tests decken Speed-Lebenszyklus, alle unterstützten HUD-Resource-Namen sowie SemVer- und Changelog-Verarbeitung ab.

### Zu ersetzende Dateien

| Datei | Grund |
| --- | --- |
| `framework/init.lua` | zentraler automatischer HUD-Adapter |
| `client/modules/farming.lua` | zentraler HelpNotify-Aufruf |
| `client/modules/verarbeiter.lua` | zentraler HelpNotify-Aufruf |
| `client/modules/verkäufer.lua` | zentraler HelpNotify-Aufruf |
| `client/modules/consumables.lua` | absoluter Speed und Consumable-Notify |
| `client/main.lua` | zentraler Platzierungs-Hinweis |
| `shared/consumables_config.lua` | numerischer Standard-Speed und automatische Progress-Auswahl |
| `shared/sv_config.lua` | GitHub-Versionseinstellungen |
| `server/version_utils.lua` | sichere SemVer- und Changelog-Verarbeitung |
| `server/version_check.lua` | gehärteter GitHub-Checker und txAdmin-Ausgabe |
| `locals/languages/de.lua` | neue Consumable-Erfolgsnachricht |
| `fxmanifest.lua` | Script-Eintrag und Versions-Bump |
| `CHANGELOG.md` | Changelog-Eintrag |

Kein SQL-Import nötig. Es wurden keine neuen Commands hinzugefügt.

---

## [1.4.0] – 2026-07-22

### Geändert

- **Einzelfeld-Bearbeitung im Consumables-Creator**: Der Item-Entwurf zeigt jede Einstellung als eigenen Menüeintrag mit aktuellem Wert (Label, Cooldown, Konsumdauer, Konsumtext, Fahrzeug, Animation, Effektdauer, Leben, Rüstung, Tempo-Boost, Ausdauer, Rausch). Ein Klick bearbeitet genau einen Wert – die bisherigen Abschnitts-Assistenten mit mehreren Eingaben hintereinander entfallen.
- **Separate Felder für Leben und Rüstung**: Beide Effekte werden einzeln eingegeben (Leben 0–200, Rüstung 0–100; `0` oder leer entfernt den Effekt).
- **Direkte Ja/Nein-Toggles**: „Im Fahrzeug nutzbar" und „Unendliche Ausdauer" schalten per Klick direkt um, ohne Eingabefenster.

### Hinzugefügt

- **ITEM-GUIDE.md**: Kompakte deutsche Schritt-für-Schritt-Anleitung „Item erstellen in 60 Sekunden" mit Vorlagen-Übersicht, Tabelle aller Felder samt Grenzen, Energy-Drink-Beispiel und den häufigsten Fehlern.

### Zu ersetzende Dateien

| Datei | Grund |
| --- | --- |
| `client/consumables_creator.lua` | flaches Einzelfeld-Menü statt Abschnitts-Buttons |
| `client/modules/consumables_creator_fields.lua` | Einzelfeld-Editoren statt Abschnitts-Assistenten |
| `locals/languages/de.lua` | neue und angepasste Locale-Keys |
| `ITEM-GUIDE.md` | neue Datei |
| `fxmanifest.lua` | Versions-Bump |
| `README.md` | Doku-Update (optional) |
| `CHANGELOG.md` | Changelog-Eintrag (optional) |

Kein SQL-Import nötig.

---

## [1.3.0] – 2026-07-21

### Hinzugefügt

- **Automatischer Versions-Check beim Serverstart**: Das Script vergleicht die installierte Version mit der neuesten Version auf GitHub. Ist die Installation veraltet, werden in der Server-Konsole die neue Versionsnummer, der Download-Link und alle Changelog-Einträge seit der installierten Version ausgegeben. Ist alles aktuell, erscheint eine kurze grüne Bestätigung.

### Zu ersetzende Dateien

| Datei | Grund |
| --- | --- |
| `server/version_check.lua` | neue Datei |
| `fxmanifest.lua` | neuer Script-Eintrag + Versions-Bump |
| `CHANGELOG.md` | Changelog-Eintrag (optional) |

Kein SQL-Import nötig.

---

## [1.2.0] – 2026-07-20

### Hinzugefügt

- **jaksam_inventory als vollwertiger Inventar-Modus** (`Config.Consumables.Inventory = 'jaksam_inventory'`): Benutzung über jaksams `registerUsableItem`, Besitzprüfung und Entfernung über die jaksam-Exports (`getTotalItemAmount`, `removeItem`).

### Zu ersetzende Dateien

| Datei | Grund |
| --- | --- |
| `server/consumables/consumables_inventory.lua` | neuer jaksam_inventory-Modus |
| `fxmanifest.lua` | Versions-Bump |
| `README.md` | Doku-Update (optional) |
| `CHANGELOG.md` | Changelog-Eintrag (optional) |

Kein SQL-Import nötig.

---

## [1.1.0] – 2026-07-20

### Hinzugefügt

- **Item-Vorlagen im Consumables-Creator**: Neue Items starten aus einer fertigen Vorlage (Zigarette, Joint, Tablette/Medikament, Kokain, Meth, Essen, Trinken oder Leer) und sind sofort speicherbar. Vorlage wählen → Name eingeben → Anzeigename eingeben (leer = automatisch aus dem Namen) → fertig.
- Neue Config-Sektion `Config.ItemTemplates` in `shared/consumables_config.lua` – eigene Vorlagen können ergänzt werden.
- Neue Locale-Keys `consumables_template_select` und `consumables_field_label_optional` in `locals/languages/de.lua`.

### Zu ersetzende Dateien

| Datei | Grund |
| --- | --- |
| `client/consumables_creator.lua` | neuer Vorlagen-Ablauf beim Item-Erstellen |
| `client/modules/consumables_creator_fields.lua` | neuer Select-Helper |
| `shared/consumables_config.lua` | neue `Config.ItemTemplates` (eigene Anpassungen an `Config.Consumables`/`Config.Items` vorher sichern!) |
| `locals/languages/de.lua` | neue Locale-Keys |
| `fxmanifest.lua` | Versions-Bump |
| `README.md` | Doku-Update (optional) |

Kein SQL-Import nötig, keine Server-Dateien betroffen.

---

## [1.0.5] – 2026-07-19 – Initial Release

Erstveröffentlichung mit vollem Funktionsumfang – keine Dateien zu ersetzen, Erstinstallation gemäß [README](README.md):

- Farming-System: Creator-Menü (`/farmingcreator`), Sammeln → Verarbeiten → Verkaufen, Live-Platzierung, Blips, Boost-Zeitfenster, Discord-Logging.
- Consumables-System: Creator-Menü (`/consumablescreator`), MySQL-Persistenz mit Erst-Seed, Animations- und Halluzinations-Presets, Sekunden-Eingaben, Effekte (Leben, Rüstung, Tempo, Ausdauer, Rausch), Abbruch & Cooldowns.
- Inventar-Anbindung: ESX/QBCore-Framework, ox_inventory, HEX v4; Install-Beispiele unter `install/consumables/` inkl. ESX-Refresh-Hook.
- Exports & Events: siehe [EXPORTS.md](EXPORTS.md).
