--- The whitelist of a `User` for one faction, stored in the `whitelists` table as the faction
-- ID. A whitelist restricts nobody: it lets its player create characters that start as
-- members of the faction, which character creation offers as an option of its own (see
-- `Factions:AdjustCharacterCreationOptions`). Anyone who wears or carries what grants the
-- faction is a member, whitelisted or not.

class 'Whitelist' extends 'ActiveRecord::Base'

Whitelist:belongs_to 'User'
