-- rsg-weaponcomp tables.
-- Created automatically on start when Config.AutoDatabase = true (default).
-- Import this file manually only if you set Config.AutoDatabase = false.

CREATE TABLE IF NOT EXISTS `player_weapons` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `serial` varchar(16) NOT NULL,
  `citizenid` varchar(9) NOT NULL,
  `components` varchar(4096) NOT NULL DEFAULT '{}',
  `components_before` varchar(4096) NOT NULL DEFAULT '{}',
  `price` decimal(5,2) NOT NULL DEFAULT 0.00,
  `town` int(11) NOT NULL DEFAULT 0,
  `customname` varchar(32) NULL DEFAULT NULL,
  `engraving` varchar(64) NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `player_weapons_custom` (
  `gunsiteid` varchar(20) NOT NULL,
  `propid` varchar(20) NOT NULL,
  `citizenid` varchar(50) NOT NULL,
  `item` varchar(50) NOT NULL,
  `propdata` longtext NOT NULL,
  PRIMARY KEY (`gunsiteid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `player_weapons_presets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `weapon` varchar(64) NOT NULL,
  `name` varchar(32) NOT NULL,
  `components` varchar(4096) NOT NULL DEFAULT '{}',
  PRIMARY KEY (`id`),
  KEY `idx_citizen_weapon` (`citizenid`, `weapon`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Upgrading an install from before v3.4.0 by hand (skipped when Config.AutoDatabase = true):
-- ALTER TABLE `player_weapons` ADD COLUMN `customname` varchar(32) NULL DEFAULT NULL;
-- ALTER TABLE `player_weapons` ADD COLUMN `engraving` varchar(64) NULL DEFAULT NULL;
