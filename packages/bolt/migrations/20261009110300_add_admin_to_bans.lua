--- Migration that adds the `admin_name` and `admin_steam_id` columns to the `bans` table.
-- The columns hold the Steam name and the SteamID of the player who issued a ban. They are
-- empty for the bans made from the server console or by code, and for the bans that were
-- made before this migration.

local AddAdminToBans = ActiveRecord.Migration.new()

--- Adds the admin_name and admin_steam_id columns to bans.
function AddAdminToBans:change()
  add_column('bans', 'admin_name', 'string', { null = true })
  add_column('bans', 'admin_steam_id', 'string', { null = true })
end

return AddAdminToBans
