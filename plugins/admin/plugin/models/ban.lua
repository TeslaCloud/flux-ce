--- Database record of a ban: the banned player's name and SteamID, the reason, the duration
-- in seconds (0 for a permanent ban) and the time at which the ban ends.
-- Bans are created with `Bolt:ban` and cached in the table returned by `Bolt:get_bans`.
-- @module [Ban]

class 'Ban' extends 'ActiveRecord::Base'
