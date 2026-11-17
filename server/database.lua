-- Automatic database setup. Runs once when the resource starts (Config.AutoDatabase).
-- Keep the schema identical to installation/database.sql.

local Tables = {
    [[CREATE TABLE IF NOT EXISTS `player_weapons` (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `player_weapons_custom` (
      `gunsiteid` varchar(20) NOT NULL,
      `propid` varchar(20) NOT NULL,
      `citizenid` varchar(50) NOT NULL,
      `item` varchar(50) NOT NULL,
      `propdata` longtext NOT NULL,
      PRIMARY KEY (`gunsiteid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `player_weapons_presets` (
      `id` int(11) NOT NULL AUTO_INCREMENT,
      `citizenid` varchar(50) NOT NULL,
      `weapon` varchar(64) NOT NULL,
      `name` varchar(32) NOT NULL,
      `components` varchar(4096) NOT NULL DEFAULT '{}',
      PRIMARY KEY (`id`),
      KEY `idx_citizen_weapon` (`citizenid`, `weapon`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

-- Columns added after the first release: { table, column, definition }
local Columns = {
    { 'player_weapons', 'customname', 'varchar(32) NULL DEFAULT NULL' },
    { 'player_weapons', 'engraving',  'varchar(64) NULL DEFAULT NULL' },
}

local function columnExists(tbl, col)
    local n = MySQL.scalar.await(
        'SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
        { tbl, col })
    return (tonumber(n) or 0) > 0
end

---@return boolean ok
function EnsureDatabase()
    local ok, err = pcall(function()
        for i = 1, #Tables do MySQL.query.await(Tables[i]) end
        for i = 1, #Columns do
            local c = Columns[i]
            if not columnExists(c[1], c[2]) then
                MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(c[1], c[2], c[3]))
            end
        end
    end)
    if not ok then
        print(('^1[rsg-weaponcomp] database setup failed: %s^7'):format(tostring(err)))
        return false
    end
    print('^2[rsg-weaponcomp] database tables ready^7')
    return true
end
