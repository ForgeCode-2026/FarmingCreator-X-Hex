# FarmingCreator-X-Hex

Umfangreiches, admin-gesteuertes Farming-System für FiveM mit vollständigem Ingame-Creator:
Sammeln → Verarbeiten → Verkaufen → Konsumieren – komplett ohne Code, direkt im Spiel erstellt, angepasst und live platziert.

**NEU: Integriertes Consumables-System – erstellt eure eigenen Drogen, Medikamente & Konsum-Items komplett ingame!**

---

## 📑 Inhaltsverzeichnis

- [Features](#-features)
- [Voraussetzungen](#-voraussetzungen)
- [Installation](#-installation)
- [Befehle](#%EF%B8%8F-befehle)
- [Berechtigungen](#-berechtigungen)
- [Consumables](#-consumables)
  - [MySQL-Erstbefüllung (Seed)](#mysql-erstbefüllung-seed)
  - [Inventar-Anbindung](#inventar-anbindung)
  - [Exports](#exports)
  - [Animationsarten](#animationsarten)
  - [Effekte & Rausch-Presets](#effekte--rausch-presets)
- [Exports & Events](#-exports--events)
- [Test-Checkliste](#-test-checkliste)
- [Wichtige Hinweise](#%EF%B8%8F-wichtige-hinweise)

---

## ✨ Features

### Farming

- **Creator-Menü** – Beliebig viele Farm-Projekte, Rezepte und Verkaufspreise komplett ingame erstellen; Punkte jederzeit anpassen oder löschen.
- **Live-Platzierung mit Vorschau** – Marker oder NPCs frei in der Welt setzen, mit Echtzeit-Vorschau, Scroll-Größe und individueller Farbe & Höhe.
- **Verarbeitungs-System mit Live-Anzeige** – Echtzeit-Fortschritt inklusive Live-Restzeit; fertige Waren vorzeitig abholbar, Abhol-Menge wählbar (z. B. Waffen nur einzeln).
- **Verkaufs-System** – Dynamische Min-/Max-Preise pro Item, wählbares Auszahlungskonto (Bar, Bank oder Schwarzgeld), optionaler Polizei-Alarm bei Schwarzgeld-Verkäufen.
- **Anpassbare Map-Blips** – Eigenes Symbol und eigene Farbe pro Punkt.
- **Boost-Zeitfenster** – Zeiträume mit erhöhter Sammel-Ausbeute belohnen aktive Spielzeiten.
- **Discord-Logging** – Webhooks für Sammeln, Verarbeiten und Verkaufen.

### Consumables

- **Consumables-Creator** – Drogen, Medikamente, Essen & Trinken komplett ingame erstellen: Neue Items starten aus fertigen Vorlagen (Zigarette, Joint, Tablette, Kokain, Meth, Essen, Trinken oder Leer) und sind sofort speicherbar; Label, Cooldown, Konsumdauer (bequem in Sekunden), Animation & Prop lassen sich danach feinjustieren – gespeichert in MySQL, sofort benutzbar, ganz ohne Neustart.
- **Effekte & Rausch-Presets** – Leben, Rüstung, Tempo-Boost, Ausdauer sowie vier vorgefertigte Halluzinations-Stufen (vom leichten Rausch bis zum vollen LSD-Trip) mit Screen-Effekten, Kamerawackeln, Torkel-Gang und Umfall-Chance.
- **Animations-Presets & Props** – 8 fertige Konsum-Animationen (Rauchen, Trinken, Pillen, Spritze u. v. m.) inklusive Props in der Hand; eigene Scenarios/Animationen ebenfalls möglich.
- **Inventar-Support** – ESX-/QBCore-Standard-Inventar, ox_inventory (Client-Export) und HEX v4; 7 fertige Beispiel-Items mit Install-Dateien liegen bei.

### Sicherheit

- **Exploit-safe & komplett server-sided** – Alle sicherheitsrelevanten Aktionen (Sammeln, Verarbeiten, Verkaufen, Konsumieren, Auszahlungen) werden ausschließlich serverseitig geprüft und berechnet: kein Item-Dupe, kein Reward-Spoofing, keine Aktionen ohne Berechtigung.
- **Manipulationssicherer Konsum** – Tokens, serverseitige Besitzprüfung und Cooldowns.
- **Distanz-Schutzsystem** – Sammeln endet automatisch, sobald der Spieler den Bereich verlässt – auch bei manipuliertem Client.
- **ESX & QBCore Support** – Läuft out-of-the-box auf beiden Frameworks. Ungefähr **6.500 Zeilen Code**.

---

## 📦 Voraussetzungen

| Abhängigkeit | Pflicht | Zweck |
| --- | --- | --- |
| [oxmysql](https://github.com/CommunityOx/oxmysql) | ✅ | Datenbank |
| `hex_menu_api` | ✅ | Menü-System (Creator & Eingaben) |
| ESX **oder** QBCore | ✅ | Framework |
| `ox_inventory` / `hex_4_inventory` | optional | nur bei entsprechendem Inventar-Modus |

---

## 🔧 Installation

### Schritt 1 – Resource einfügen

Den Ordner `FarmingCreator` in euren `resources`-Ordner kopieren.

### Schritt 2 – SQL importieren

Die Datei `sql/forge-Farming.sql` in die Datenbank importieren. Sie enthält die Tabellen für Farm-Projekte **und** Consumables.

### Schritt 3 – Framework einstellen

In `shared/config.lua`:

```lua
Config.Framework = 'esx' -- alternativ 'qbcore'
```

### Schritt 4 – Inventar-Items anlegen

Die Seed-Items aus `Config.Items` (`shared/consumables_config.lua`) müssen im Inventar existieren. Fertige Beispiele liegen in `install/consumables/`:

| Datei | Zielsystem |
| --- | --- |
| `install/consumables/esx_items.sql` | klassische ESX-`items`-Tabelle |
| `install/consumables/qb_items.lua` | `qb-core/shared/items.lua` |
| `install/consumables/ox_items.lua` | `ox_inventory/data/items.lua` |
| `install/consumables/esx_refresh_hook.lua` | `es_extended/server/` (+ Eintrag in der es_extended-`fxmanifest.lua`) – lässt ESX neu erstellte Items ohne Neustart erkennen, siehe [EXPORTS.md](EXPORTS.md) |

### Schritt 5 – Startreihenfolge in der server.cfg

FarmingCreator muss **nach** `oxmysql` und `hex_menu_api` starten:

```cfg
ensure oxmysql
ensure hex_menu_api
ensure FarmingCreator
```

Optionale Inventar-Resourcen (`ox_inventory`, `hex_4_inventory`) ebenfalls **vor** FarmingCreator starten, wenn sie in der Config ausgewählt sind. Sie sind bewusst **keine** harten Manifest-Dependencies, damit beide Framework-Modi ohne sie lauffähig bleiben.

### Schritt 6 – Server starten ✅

Beim allerersten Start werden die Beispiel-Items automatisch in MySQL importiert (siehe [Seed](#mysql-erstbefüllung-seed)).

---

## ⌨️ Befehle

| Befehl | Funktion |
| --- | --- |
| `/farmingcreator` | Öffnet den Farming Creator (Projekte, Punkte, Rezepte, Verkaufspreise) |
| `/consumablescreator` | Öffnet den Consumables Creator (Befehlsname über `Config.Consumables.CreatorCommand` änderbar) |

---

## 🔐 Berechtigungen

Beide Creator-Befehle prüfen serverseitig `Framework.HasPermission`:

- **ESX**: Die Spieler-Gruppe muss in `Config.ESXAdminGroups` enthalten sein (`shared/sv_config.lua`, Standard: `admin`, `superadmin`).
- **QBCore**: Der Spieler benötigt das Permission-Level aus `Config.QBPermissionLevel` (Standard: `admin`).

Normale Spieler ohne Berechtigung werden mit einer Fehlermeldung abgewiesen; auch alle Creator-Net-Events sind serverseitig abgesichert.

---

## 💊 Consumables

Neue Items starten im Creator aus einer fertigen Vorlage (Zigarette, Joint, Tablette, Kokain, Meth, Essen, Trinken oder Leer, definiert in `Config.ItemTemplates`) und sind direkt nach Name und Anzeigename mit „Speichern" fertig – alle Abschnitte bleiben zum Feintuning verfügbar.

### MySQL-Erstbefüllung (Seed)

`Config.Items` in `shared/consumables_config.lua` dient **nur dem Erstimport**: Beim allerersten Start mit leerer Consumables-Tabelle werden die Seed-Items in MySQL geschrieben. Danach ist **MySQL autoritativ** – Änderungen an `Config.Items` haben keine Wirkung mehr; Items werden ausschließlich über den Consumables Creator (oder direkt in der Datenbank) gepflegt.

### Inventar-Anbindung

`Config.Consumables.Inventory` in `shared/consumables_config.lua` steuert die Anbindung:

| Wert | Verhalten |
| --- | --- |
| `'framework'` | ESX `RegisterUsableItem` bzw. QBCore `CreateUseableItem`; Item-Entfernung über das Framework |
| `'ox_inventory'` | Benutzung startet über den Client-Export in den ox-Item-Definitionen; Zählen/Entfernen über ox-Exports |
| `'hex_4_inventory'` | Benutzung über die Framework-Bridge; Zählen/Entfernen über die nativen HEX-Exports (`GetInventory`, `RemoveItemFromInventory`) |

Für `ox_inventory` muss jedes Item so definiert sein (siehe `install/consumables/ox_items.lua`):

```lua
['cocaine'] = {
    label = 'Kokain',
    weight = 10,
    stack = true,
    close = true,
    consume = 0,
    client = { export = 'FarmingCreator.UseConsumable' }
},
```

> `consume = 0` ist Pflicht: FarmingCreator entfernt das Item erst serverseitig **nach** abgeschlossener Animation. Wurde der Resource-Ordner umbenannt, muss `FarmingCreator` im Export durch den tatsächlichen Ordnernamen ersetzt werden.

### Exports

- **Client** (für ox_inventory-Item-Hooks):

  ```lua
  client = { export = 'FarmingCreator.UseConsumable' }
  ```

- **Server** (für eigene Inventare mit Usable-Item-Callback):

  ```lua
  exports['FarmingCreator']:UseConsumable(source, 'cocaine')
  ```

  Rückgabe ist `true`, wenn der Konsum gestartet wurde.

### Animationsarten

Jedes Item wählt seine Animation auf eine von drei Arten:

1. **Preset**: Name eines Eintrags aus `Config.AnimationPresets` (mitgeliefert: `rauchen`, `joint`, `pille`, `kokain`, `meth`, `trinken`, `essen`, `ruestung`). Presets bringen ggf. ihr eigenes Prop mit.
2. **Szenario**: ein GTA-Szenario wie `WORLD_HUMAN_SMOKING`.
3. **Eigene Animation (Dict/Clip)**: `dict` + `clip`, optional `flag`, `blendIn`, `blendOut`, `playbackRate` sowie ein eigenes **Prop** (`model`, `bone`, `position`, `rotation` – Standard-Bone ist die rechte Hand).

Alle drei Modi sind im Consumables Creator über den Abschnitt „Animation" konfigurierbar.

### Effekte & Rausch-Presets

| Einstellung | Bedeutung |
| --- | --- |
| `duration` | Effektdauer (`0` = nur Sofort-Effekte); im Creator bequem in **Sekunden** eingegeben |
| `health` | sofort hinzugefügte Leben |
| `armor` | sofort hinzugefügte Rüstung, maximal 100 |
| `speed` | Sprint-Multiplikator von 1.0 bis 1.49 (GTA-Limit) |
| `stamina` | `true` für unendliche Ausdauer während der Wirkung |
| `hallucination.timecycle` | Farb-/Bildfilter von GTA V |
| `hallucination.strength` | Stärke des Bildfilters von 0.0 bis 1.0 |
| `hallucination.pulsing` | lässt die Filterstärke leicht pulsieren |
| `hallucination.screenEffect` | GTA-PostFX-Effekt (z.B. `DrugsMichaelAliensFight`) |
| `hallucination.cameraShake` | Kamerawackeln, sinnvoll zwischen 0.05 und 1.0 |
| `hallucination.motionBlur` | aktiviert Bewegungsunschärfe |
| `hallucination.movementClipset` | verändert den Laufstil (z.B. `move_m@drunk@slightlydrunk`) |
| `hallucination.ragdollChance` | prozentuale Sturzchance pro Sekunde |

Im Creator stehen vier vorgefertigte Halluzinations-Presets bereit (`Config.HallucinationPresets`):

| Preset | Wirkung |
| --- | --- |
| **Leichter Rausch** | milder Bildfilter, leichtes Kamerawackeln |
| **Mittlerer Rausch** | pulsierender Filter, mehr Kamerawackeln |
| **Starker Rausch** | Screen-Effekt, Motion Blur, Torkel-Gang, gelegentliches Umfallen |
| **Voller Trip** | maximale Stufe – volles Programm |

Eigene Presets können in `shared/consumables_config.lua` ergänzt werden.

Nach Ablauf werden alle zeitlich begrenzten Effekte vollständig zurückgesetzt. Abbruch während des Konsums ist mit der Taste aus `Config.Consumables.CancelKey` (Standard: `X`) möglich; Cooldowns gelten pro Item und Spieler.

---

## 🔌 Exports & Events

Eine vollständige Übersicht aller Exports, Hooks und Events (Notify-Anbindung, `forge_itemcreator:refreshItems`, interne Net-Events) steht in **[EXPORTS.md](EXPORTS.md)**.

---

## ✅ Test-Checkliste

Nach der Installation kurz durchtesten:

1. `/farmingcreator` und die bestehenden Farming-Abläufe (Sammeln, Verarbeiten, Verkaufen) funktionieren.
2. `/consumablescreator` wird für normale Spieler abgewiesen und öffnet sich für Admins.
3. Ein Item vollständig im Creator erstellen, sofort benutzen und prüfen, dass es nach einem Server-Neustart erneut aus MySQL geladen wird.
4. Abbruch (Taste `X`), Itementfernung nach Abschluss, Cooldown, Props und alle Effekte (Leben, Rüstung, Tempo, Ausdauer, Halluzination) prüfen.
5. Update und Delete eines Items während laufender Nutzung bleiben konsistent (kein Absturz, keine verwaisten Effekte).
6. Manipulierte Net-Events (z.B. gefälschte Creator- oder Complete-Events) verändern weder SQL noch die Registry.

---

## ⚠️ Wichtige Hinweise

### ESX-Refresh-Hook installieren

Damit ESX neu erstellte Items **ohne Neustart** erkennt, liegt die fertige Hook-Datei `install/consumables/hook.lua` bei. Sie gehört **serverseitig in es_extended**:

1. Datei nach `es_extended/server/` kopieren.
2. In der `fxmanifest.lua` von es_extended unter `server_scripts` eintragen: `'server/hook.lua'`.

Inhalt (kann alternativ ans Ende einer bestehenden Server-Datei von es_extended eingefügt werden):

```lua
AddEventHandler('forge_farming:refreshItems', function()
    if ESX and type(ESX.RefreshItems) == 'function' then
        ESX.RefreshItems()
    end
end)
```

> Bugs oder Wünsche gerne privat melden.
