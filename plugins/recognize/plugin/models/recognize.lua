--- A recognition stored for a character, a row of the `recognizes` table: the character it
-- belongs to (`character_id`), the character that is recognized (`target_id`) and the name
-- that one is known by (`name`), which is their real name or a false one. The records of a
-- character are loaded with it into its `recognizes` list and saved together with it.
-- @module [Recognize]

class 'Recognize' extends 'ActiveRecord::Base'

Recognize:belongs_to 'Character'

--- Deletes the row again if the recognition was forgotten while it was still being
-- inserted, when the record had no ID to delete it by.
function Recognize:after_create()
  if self.discarded then
    self:destroy()
  end
end
