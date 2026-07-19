-- Optionales Beispiel fuer die gaengige ESX-Items-Tabelle.
-- Die Itemnamen entsprechen den Seed-Items aus Config.Items (shared/consumables_config.lua).
-- Passe die Spalten an, falls dein ESX/Inventory ein anderes Schema nutzt.

INSERT IGNORE INTO `items` (`name`, `label`, `weight`) VALUES
('cigarette', 'Zigarette', 10),
('joint', 'Joint', 10),
('painkiller', 'Schmerztablette', 5),
('adrenaline', 'Adrenalin', 20),
('cocaine', 'Kokain', 10),
('meth', 'Meth', 10),
('lsd', 'LSD', 5);
