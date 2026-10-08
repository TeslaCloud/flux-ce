--- A character of a player, stored in the `characters` table.
-- It belongs to a `User` and holds the name, gender, physical description, model, skin and
-- health of the character; other plugins add their own columns and relations, as Factions does
-- with the faction and rank. A record is only valid with a name and a physical description;
-- how long they may be is set by the `character_min_name_len`, `character_max_name_len`,
-- `character_min_desc_len` and `character_max_desc_len` configs and checked when a character
-- is created or its description is changed by its player. Characters are created and changed
-- through the `Characters` functions and the `Player` extensions rather than directly.

class 'Character' extends 'ActiveRecord::Base'

Character:belongs_to 'User'
Character:has_one 'ammunition'

Character:validates('user_id', { presence = true })
Character:validates('steam_id', { presence = true })
Character:validates('name', { presence = true })
Character:validates('gender', { presence = true })
Character:validates('phys_desc', { presence = true })
Character:validates('model', { presence = true })
