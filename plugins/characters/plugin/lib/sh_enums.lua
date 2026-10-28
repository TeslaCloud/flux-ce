--- Status codes of character creation. `Characters.create` returns one of them, handlers of
-- the PlayerCreateCharacter hook return the error codes, and the code is sent back to the
-- client that asked for the character.
-- * `CHAR_SUCCESS`: the character was created.
-- * `CHAR_ERR_NAME`: the name is invalid.
-- * `CHAR_ERR_DESC`: the description is invalid.
-- * `CHAR_ERR_GENDER`: the gender is invalid.
-- * `CHAR_ERR_EXISTS`: another character has the name already.
-- * `CHAR_ERR_LIMIT`: the player has as many characters as they may have.
-- * `CHAR_ERR_MODEL`: no model was selected.
-- * `CHAR_ERR_RECORD`: the player has no database record.
-- * `CHAR_ERR_UNKNOWN`: something else went wrong.

enumerate [[
  CHAR_SUCCESS
  CHAR_ERR_NAME
  CHAR_ERR_DESC
  CHAR_ERR_GENDER
  CHAR_ERR_EXISTS
  CHAR_ERR_LIMIT
  CHAR_ERR_MODEL
  CHAR_ERR_RECORD
  CHAR_ERR_UNKNOWN
]]
