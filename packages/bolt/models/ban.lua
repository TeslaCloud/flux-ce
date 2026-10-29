--- Database record of a ban: the banned player's name and SteamID, the reason, the duration
-- in seconds (0 for a permanent ban), the time at which the ban ends, and the Steam name
-- and SteamID of the player who issued it (`admin_name` and `admin_steam_id`, empty for a
-- ban made from the server console or by code).
-- Bans are created with `Bolt:ban` and cached in the table returned by `Bolt:get_bans`.
-- @module [Ban]

class 'Ban' extends 'ActiveRecord::Base'
