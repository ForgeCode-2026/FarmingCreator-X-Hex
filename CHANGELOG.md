# Changelog

Alle relevanten Änderungen an FarmingCreator-X-Hex. Bei jedem Update sind die Dateien aufgelistet, die beim Aktualisieren einer bestehenden Installation **ersetzt** werden müssen.

> **Update-Anleitung:** Server stoppen → die gelisteten Dateien durch die neuen Versionen ersetzen → Server starten. Eigene Anpassungen an `shared/config.lua` / `shared/consumables_config.lua` vorher sichern und danach wieder einpflegen. Die Datenbank bleibt bei Updates unverändert, sofern nicht ausdrücklich ein SQL-Import erwähnt wird.

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
