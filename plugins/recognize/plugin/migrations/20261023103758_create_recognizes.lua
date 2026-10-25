--- Migration that creates the `recognizes` table, which holds the characters that a
-- character recognizes and the names it knows them by.

local CreateRecognizes = ActiveRecord.Migration.new()

--- Creates the recognizes table.
function CreateRecognizes:change()
  create_table('recognizes', function(t)
    t:integer 'character_id'
    t:integer 'target_id'
    t:string  'name'
    t:timestamps()
  end)
end

return CreateRecognizes
