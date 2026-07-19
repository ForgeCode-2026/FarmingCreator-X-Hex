CREATE TABLE IF NOT EXISTS `forge_farming_projects` (
    `id`              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `label`           VARCHAR(100)    NOT NULL,
    `raw_item`        VARCHAR(50)     NOT NULL,
    `raw_min_amount`  INT             NOT NULL,
    `raw_max_amount`  INT             NOT NULL,
    `gather_duration` INT             NOT NULL COMMENT 'Dauer eines Sammel-Ticks in Millisekunden',
    `sell_prices`     JSON            NOT NULL COMMENT 'Projektweite Verkaufspreise: [{item, price}, ...]',
    `created_at`      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `forge_farming_recipes` (
    `id`            INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `project_id`    INT UNSIGNED    NOT NULL,
    `label`         VARCHAR(100)    NOT NULL,
    `inputs`        JSON            NOT NULL COMMENT 'Input-Items pro Durchlauf: [{item, amount}, ...]',
    `output_item`   VARCHAR(50)     NOT NULL,
    `output_amount` INT             NOT NULL,
    `duration`      INT             NOT NULL COMMENT 'Dauer pro Durchlauf in Millisekunden',

    PRIMARY KEY (`id`),
    KEY `idx_recipes_project` (`project_id`),
    CONSTRAINT `fk_recipes_project`
        FOREIGN KEY (`project_id`) REFERENCES `forge_farming_projects` (`id`)
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `forge_farming_points` (
    `id`                   INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `project_id`           INT UNSIGNED     NOT NULL,
    `type`                 ENUM('sammler', 'verarbeiter', 'verkaeufer') NOT NULL,
    `x`                    FLOAT            NOT NULL,
    `y`                    FLOAT            NOT NULL,
    `z`                    FLOAT            NOT NULL,
    `heading`              FLOAT            NOT NULL,
    `placement_mode`       ENUM('marker', 'npc') NOT NULL,
    `marker_type`          INT              NULL,
    `marker_color_r`       TINYINT UNSIGNED NULL,
    `marker_color_g`       TINYINT UNSIGNED NULL,
    `marker_color_b`       TINYINT UNSIGNED NULL,
    `marker_color_a`       TINYINT UNSIGNED NULL,
    `marker_radius`        FLOAT            NULL,
    `marker_height_offset` FLOAT            NULL DEFAULT 0 COMMENT 'Manueller Z-Offset für Verarbeiter-/Verkäufer-Marker (keine automatische Boden-Ausrichtung)',
    `ped_model`            VARCHAR(64)      NULL,
    `payout_account`       ENUM('cash', 'bank', 'black_money') NULL,
    `show_blip`            TINYINT(1)       NOT NULL DEFAULT 1 COMMENT 'Ob dieser Punkt einen Map-Blip bekommt, im Creator pro Punkt einstellbar',
    `police_alert`         TINYINT(1)       NOT NULL DEFAULT 0 COMMENT 'Ob an diesem Verkäufer-Punkt (Auszahlung Schwarzgeld) ein Polizei-Alarm ausgelöst wird',
    `blip_sprite`          INT              NULL COMMENT 'Blip-Symbol (Sprite-ID) pro Punkt; NULL = Typ-Standard',
    `blip_color`           INT              NULL COMMENT 'Blip-Farbe (0-85) pro Punkt; NULL = Typ-Standard',
    `created_by`           VARCHAR(64)      NOT NULL COMMENT 'Spieler-Identifier des erstellenden Admins',
    `created_at`           TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    KEY `idx_points_project` (`project_id`),
    CONSTRAINT `fk_points_project`
        FOREIGN KEY (`project_id`) REFERENCES `forge_farming_projects` (`id`)
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

ALTER TABLE `forge_farming_points`
    ADD COLUMN IF NOT EXISTS `show_blip` TINYINT(1) NOT NULL DEFAULT 1
    COMMENT 'Ob dieser Punkt einen Map-Blip bekommt, im Creator pro Punkt einstellbar';

ALTER TABLE `forge_farming_points`
    ADD COLUMN IF NOT EXISTS `police_alert` TINYINT(1) NOT NULL DEFAULT 0
    COMMENT 'Ob an diesem Verkäufer-Punkt (Auszahlung Schwarzgeld) ein Polizei-Alarm ausgelöst wird';

ALTER TABLE `forge_farming_points`
    ADD COLUMN IF NOT EXISTS `blip_sprite` INT NULL
    COMMENT 'Blip-Symbol (Sprite-ID) pro Punkt; NULL = Typ-Standard';

ALTER TABLE `forge_farming_points`
    ADD COLUMN IF NOT EXISTS `blip_color` INT NULL
    COMMENT 'Blip-Farbe (0-85) pro Punkt; NULL = Typ-Standard';

CREATE TABLE IF NOT EXISTS `forge_farming_jobs` (
    `id`                INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `player_identifier` VARCHAR(64)     NOT NULL,
    `point_id`          INT UNSIGNED    NOT NULL,
    `recipe_id`         INT UNSIGNED    NOT NULL,
    `amount`            INT             NOT NULL COMMENT 'Anzahl Durchläufe (Batch-Menge)',
    `total_duration`    INT             NOT NULL COMMENT 'Gesamtdauer in Millisekunden, beim Start eingefroren',
    `accumulated_ms`    INT             NOT NULL DEFAULT 0 COMMENT 'Bereits verstrichene Verarbeitungszeit in Millisekunden',
    `status`            ENUM('running', 'ready', 'collected') NOT NULL DEFAULT 'running',
    `started_at`        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_tick_at`      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    KEY `idx_jobs_point_status` (`point_id`, `status`),
    KEY `idx_jobs_player` (`player_identifier`),
    KEY `idx_jobs_recipe` (`recipe_id`),
    CONSTRAINT `fk_jobs_point`
        FOREIGN KEY (`point_id`) REFERENCES `forge_farming_points` (`id`)
        ON DELETE CASCADE,
    CONSTRAINT `fk_jobs_recipe`
        FOREIGN KEY (`recipe_id`) REFERENCES `forge_farming_recipes` (`id`)
        ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `forge_farming_consumables` (
    `item_name`  VARCHAR(50)     NOT NULL,
    `definition` JSON            NOT NULL,
    `created_at` TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`item_name`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `forge_farming_meta` (
    `meta_key`   VARCHAR(64)     NOT NULL,
    `meta_value` VARCHAR(255)    NOT NULL,

    PRIMARY KEY (`meta_key`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
