--- Migration that creates the `skills` table, which holds the rank of every skill of a
-- character.

local CreateSkills = ActiveRecord.Migration.new()

--- Creates the skills table.
function CreateSkills:change()
  create_table('skills', function(t)
    t:string  'skill_id'
    t:references('character', { foreign_key = { on_delete = 'cascade' } })
    t:integer 'rank'
    t:timestamps()
  end)
end

return CreateSkills
