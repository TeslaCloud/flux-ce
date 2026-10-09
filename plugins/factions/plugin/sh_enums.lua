--- Adds the status codes of the Factions plugin to the character creation codes of the
-- Characters plugin: CHAR_ERR_FACTION (the faction is invalid or the player has no access to
-- it), CHAR_ERR_FACTION_LIMIT (the player has as many characters of the faction as it
-- allows) and CHAR_ERR_FACTION_REFUSED (the on_character_create callback of the faction has
-- refused the character).

enumerate('CHAR_ERR_FACTION CHAR_ERR_FACTION_LIMIT CHAR_ERR_FACTION_REFUSED', 'CHAR')
