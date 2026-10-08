--- Generates migration files for the `flux generate migration <Name> [column:type ...]`
-- console command. The name of the migration decides what its `change` starts out with:
-- a `create_table` for 'Create<Table>', `add_column` calls for 'Add<Columns>To<Table>'
-- and `remove_column` calls for 'Remove<Columns>From<Table>'. The file is written into
-- the `db/migrate/` folder of the active schema under a new version.

class 'ActiveRecord::MigrationGenerator'

--- Creates a generator for a migration file.
-- The name decides the contents of the generated #change:
-- 'Create<Table>' creates the table with the given columns, 'Add<Columns>To<Table>'
-- adds the columns and 'Remove<Columns>From<Table>' removes them; any other name
-- gives an empty #change.
-- ```
-- ActiveRecord.MigrationGenerator.new('AddRoleToUsers', { 'role:string' }):generate()
-- ```
-- @param name [String name in CamelCase or snake_case]
-- @param fields=nil [List<String> columns as 'name:type' ('string' if no type is given,
--   'references' for a reference column)]
-- @return [ActiveRecord::MigrationGenerator(self)]
function ActiveRecord.MigrationGenerator:init(name, fields)
  name = tostring(name or '')

  if name:find('_') or name[1]:is_lower() then
    name = name:camel_case()
  end

  self.name = name
  self.file_name = name:underscore()
  self.fields = {}

  for k, v in ipairs(fields or {}) do
    local column, type = v:match('^([%w_]+):?([%w_]*)$')

    if column then
      table.insert(self.fields, { name = column, type = type != '' and type or 'string' })
    end
  end

  return self
end

local function table_name_from(part)
  return Flow.Inflector:pluralize(part:underscore())
end

local function quote(str)
  return "'"..str.."'"
end

--- Returns the body of the generated #change, indented by two spaces.
-- @return [String]
function ActiveRecord.MigrationGenerator:body()
  local lines = {}
  local table_name = self.name:match('^Create(.+)$')

  if table_name then
    table_name = table_name_from(table_name)

    table.insert(lines, 'create_table('..quote(table_name)..', function(t)')

    for k, v in ipairs(self.fields) do
      if v.type == 'references' or v.type == 'belongs_to' then
        table.insert(lines, '  t:references '..quote(v.name))
      else
        table.insert(lines, '  t:'..v.type..' '..quote(v.name))
      end
    end

    table.insert(lines, '  t:timestamps()')
    table.insert(lines, 'end)')

    return lines
  end

  local columns, add_table = self.name:match('^Add(.+)To(.+)$')

  if add_table then
    add_table = table_name_from(add_table)

    for k, v in ipairs(self.fields) do
      if v.type == 'references' or v.type == 'belongs_to' then
        table.insert(lines, 'add_reference('..quote(add_table)..', '..quote(v.name)..')')
      else
        table.insert(lines, 'add_column('..quote(add_table)..', '..quote(v.name)..', '..quote(v.type)..')')
      end
    end

    return lines
  end

  local columns, remove_table = self.name:match('^Remove(.+)From(.+)$')

  if remove_table then
    remove_table = table_name_from(remove_table)

    for k, v in ipairs(self.fields) do
      if v.type == 'references' or v.type == 'belongs_to' then
        table.insert(lines, 'remove_reference('..quote(remove_table)..', '..quote(v.name)..')')
      else
        table.insert(lines, 'remove_column('..quote(remove_table)..', '..quote(v.name)..', '..quote(v.type)..')')
      end
    end

    return lines
  end

  return lines
end

--- Returns the source of the migration file.
-- @return [String]
function ActiveRecord.MigrationGenerator:render()
  local body = self:body()
  local change = ''

  if #body > 0 then
    change = string.set_indent(table.concat(body, '\n'), '  ')..'\n'
  end

  return
    'local '..self.name..' = ActiveRecord.Migration.new()\n\n'..
    'function '..self.name..':change()\n'..
    change..
    'end\n\n'..
    'return '..self.name..'\n'
end

--- Writes the migration file into the schema's migrations folder, with a new version.
-- @param context=nil [ActiveRecord::MigrationContext context whose first path the file
--   is written to; the default context if none is given]
-- @return [String path of the file, relative to the game folder]
function ActiveRecord.MigrationGenerator:generate(context)
  if self.name == '' then
    error('ActiveRecord - the migration needs a name!', 0)
  end

  context = context or ActiveRecord.migration_context or ActiveRecord.MigrationContext.new()

  for k, v in ipairs(context:migrations()) do
    if v.name == self.file_name then
      error(
        'ActiveRecord - another migration is already named '..self.file_name..': '..v.filename..
          '. Use a different name.',
        0
      )
    end
  end

  local file_name =
    'gamemodes/'..context.migrations_paths[1]..context:next_migration_number()..'_'..self.file_name..'.lua'

  File.write(file_name, self:render())

  return file_name
end
