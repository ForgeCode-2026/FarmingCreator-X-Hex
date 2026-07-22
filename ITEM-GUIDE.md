# Item erstellen in 60 Sekunden

Kurzanleitung für den Consumables Creator von FarmingCreator-X-Hex. Alles passiert ingame – kein Code, kein Neustart.

## 1. Creator öffnen

`/consumablescreator` eingeben (Admin-Berechtigung nötig, siehe [README – Berechtigungen](README.md#-berechtigungen)).

## 2. „Neues Consumable" → Vorlage wählen

Jede Vorlage ist ein fertiges, sofort speicherbares Item:

| Vorlage | Beschreibung |
| --- | --- |
| **Zigarette** | Raucher-Szenario mit kurzem Cooldown und minimalem Leben-Bonus. |
| **Joint** | Raucher-Animation mit Prop und leichtem Rausch über 90 Sekunden. |
| **Tablette/Medikament** | Schnelle Pillen-Animation, +25 Leben sofort, auch im Fahrzeug nutzbar. |
| **Kokain** | Zieh-Animation mit Tempo-Boost, Ausdauer und mittlerem Rausch. |
| **Meth** | Pfeifen-Animation mit Rüstung, starkem Tempo-Boost und starkem Rausch. |
| **Essen** | Burger-Animation mit +15 Leben sofort. |
| **Trinken** | Flaschen-Animation mit Ausdauer-Auffrischung, auch im Fahrzeug nutzbar. |
| **Leer (Standard)** | Neutrale Basis ohne Effekte – für komplett eigene Items. |

## 3. Item-Namen eingeben

Nur Kleinbuchstaben, Zahlen, `_` und `-` (z. B. `energy_drink`). **Wichtig:** Der Name muss exakt dem Itemnamen in eurem Inventar-System entsprechen!

## 4. Anzeigenamen eingeben

Leer lassen = wird automatisch aus dem Item-Namen erzeugt (`energy_drink` → „Energy drink").

## 5. Felder anpassen

Jede Einstellung ist ein eigener Menüeintrag und zeigt ihren aktuellen Wert – ein Klick bearbeitet genau diesen einen Wert. Ja/Nein-Einträge schalten direkt um.

| Feld | Bedeutung | Einheit / Grenzen |
| --- | --- | --- |
| **Label** | Anzeigename in Menü und Meldungen | max. 64 Zeichen |
| **Cooldown** | Wartezeit zwischen zwei Benutzungen | Sekunden, 0–3600 |
| **Konsumdauer** | Dauer der Konsum-Animation samt Fortschrittsbalken | Sekunden, 0–120 |
| **Konsumtext** | Text im Fortschrittsbalken während des Konsums | max. 160 Zeichen |
| **Im Fahrzeug nutzbar** | Konsum auch im Fahrzeug erlauben | Ja/Nein (Klick schaltet um) |
| **Animation** | Konsum-Animation: Preset (z. B. `rauchen`, `trinken`, `essen`), GTA-Szenario oder eigene Animation (Dict/Clip, optional mit Prop) | – |
| **Effektdauer** | Wie lange die zeitlichen Effekte wirken; `0` = nur Sofort-Effekte | Sekunden, 0–3600 |
| **Leben** | Sofort hinzugefügte Leben | 0–200, `0` oder leer = kein Effekt |
| **Rüstung** | Sofort hinzugefügte Rüstung | 0–100, `0` oder leer = kein Effekt |
| **Tempo-Boost** | Sprint-Multiplikator während der Effektdauer | 1.0–1.49 (GTA-Limit), leer oder `1.0` = aus |
| **Unendliche Ausdauer** | Keine Ausdauer-Erschöpfung während der Effektdauer | Ja/Nein (Klick schaltet um) |
| **Rausch** | Halluzinations-Preset: Aus, Leichter Rausch, Mittlerer Rausch, Starker Rausch oder Voller Trip | – |

## 6. Speichern

„Speichern" klicken – das Item liegt in MySQL und ist **sofort benutzbar**, ohne Server-Neustart.

> **Hinweis:** Das Item muss zusätzlich in eurem Inventar-System existieren (gleicher Name!). Fertige Beispiel-Dateien liegen in `install/consumables/`, Details in [README – Schritt 4](README.md#schritt-4--inventar-items-anlegen).

## Beispiel: Energy-Drink

1. `/consumablescreator` → „Neues Consumable" → Vorlage **Trinken**
2. Name: `energy_drink` → Anzeigename: `Energy-Drink`
3. Felder anpassen: **Effektdauer** `60` s, **Tempo-Boost** `1.15`, **Unendliche Ausdauer** auf `Ja`
4. **Speichern** → `energy_drink` im Inventar-System anlegen → fertig!

## Häufige Fehler

1. **Item wird nicht benutzt / passiert nichts beim Klicken:** Das Item existiert nicht im Inventar-System oder heißt dort anders – Name muss exakt übereinstimmen (siehe `install/consumables/` und [README – Schritt 4](README.md#schritt-4--inventar-items-anlegen)).
2. **„Keine Berechtigung":** Der Spieler ist nicht in der Admin-Gruppe (`Config.ESXAdminGroups` bzw. `Config.QBPermissionLevel`, siehe [README – Berechtigungen](README.md#-berechtigungen)).
3. **ox_inventory: Item verschwindet sofort oder doppelt:** `consume = 0` in der ox-Item-Definition vergessen – FarmingCreator entfernt das Item erst serverseitig nach abgeschlossener Animation.
