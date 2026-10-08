--- A character of a player, stored in the `characters` table.
-- It belongs to a `User` and holds the name, gender, physical description, model, skin and
-- health of the character; other plugins add their own columns and relations, as Factions does
-- with the faction and rank. A record is only valid with a name of 4 to 24 characters and a
-- physical description of 16 to 200 characters. Characters are created and changed through the
-- `Characters` functions and the `Player` extensions rather than directly.

class 'Character' extends 'ActiveRecord::Base'

Character:belongs_to 'User'
Character:has_one 'ammunition'

Character:validates('user_id', { presence = true })
Character:validates('steam_id', { presence = true })
Character:validates('name', { presence = true, min_length = 4, max_length = 24 })
Character:validates('gender', { presence = true })
Character:validates('phys_desc', { presence = true, min_length = 16, max_length = 200 })
Character:validates('model', { presence = true })

--- Runs the RestoreCharacter hook after the character has been loaded from the database,
-- provided its user has been loaded as well.
function Character:restored()
  if self.user then
    --- Called on the server from `Character:restored`, when a character record has been loaded
    -- from the database, but only if its user record is already attached to it at that moment.
    -- @param owner [Player the player of the user record the character belongs to]
    -- @param char_id [Number ID of the character]
    -- @param character [Character]
    hook.Run('RestoreCharacter', self.user.player, self.id, self)
  end
end
