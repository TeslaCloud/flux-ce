--- The whitelist of a `User` for one faction, stored in the `whitelists` table as the faction
-- ID. The character creation menu only offers a whitelisted faction to players who have a
-- whitelist for it, and the server refuses to create a character of such a faction for
-- anyone else.

class 'Whitelist' extends 'ActiveRecord::Base'

Whitelist:belongs_to 'User'
