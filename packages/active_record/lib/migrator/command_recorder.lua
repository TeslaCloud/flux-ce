--- Reverting of migrations: the recorder that stands in for the schema statements while a
-- migration's `change` is being reverted, the inverters that turn each statement into the
-- one that undoes it, and the table object that `change_table` works on in the meantime.

--- Records schema statements instead of running them, which is how a migration's `change`
-- is reverted. While `ActiveRecord::Migration#revert` is at work, `ActiveRecord.ddl`
-- hands every statement to the recorder, which stores its inverse (`drop_table` for
-- `create_table`, `remove_column` for `add_column` and so on); the stored statements are
-- then run in reverse order. A statement that has no inverse, or that was not given
-- enough to work its inverse out, raises an error that explains how to make the migration
-- reversible.
class 'ActiveRecord::CommandRecorder'

--- Error message of statements that cannot be reverted automatically.
local function irreversible(command, reason)
  error(
    'ActiveRecord::IrreversibleMigration - this migration uses '..command..', which is not automatically '..
    'reversible.\n'..(reason and (reason..'\n') or '')..
    'To make the migration reversible you can either:\n'..
    '1. Define #up and #down methods in place of the #change method.\n'..
    '2. Use the #reversible method to define reversible behavior.',
    0
  )
end

local function pack(...)
  return { n = select('#', ...), ... }
end

local function command(name, ...)
  return { command = name, args = pack(...) }
end

--- The inverters of the reversible schema statements, which
-- `ActiveRecord::CommandRecorder#inverse_of` looks up by the name of the statement. A
-- statement that has no inverter cannot be reverted automatically.
--
-- Statement name -> function that takes the arguments of the statement (a list with
-- their count under 'n') and returns the inverse statement.
local inverters = {}

--- Inverts create_table into drop_table. The table definition is kept, so that the
-- drop_table can be inverted back.
function inverters.create_table(args)
  local name, options, callback = args[1], args[2], args[3]

  if isfunction(options) then
    callback, options = options, nil
  end

  return command('drop_table', name, options, callback)
end

--- Inverts define_model into a drop_table of the model's table.
function inverters.define_model(args)
  return command('drop_table', args[1], { model = true }, args[2])
end

--- Inverts drop_table into create_table, or into define_model for a model's table.
-- Raises an error if the table definition is not given.
function inverters.drop_table(args)
  local name, options, callback = args[1], args[2], args[3]

  if isfunction(options) then
    callback, options = options, nil
  end

  if !isfunction(callback) then
    irreversible(
      'drop_table',
      'To avoid mistakes, drop_table is only reversible if given the table definition (which can be empty).'
    )
  end

  if istable(options) and options.model then
    return command('define_model', name, callback)
  end

  return command('create_table', name, options, callback)
end

--- Inverts rename_table by swapping the names.
function inverters.rename_table(args)
  return command('rename_table', args[2], args[1])
end

--- Inverts add_column into remove_column.
function inverters.add_column(args)
  return command('remove_column', args[1], args[2], args[3], args[4])
end

--- Inverts remove_column into add_column. Raises an error if the type of the column is
-- not given.
function inverters.remove_column(args)
  local name, type = args[2], args[3]

  if istable(name) then
    type = name.type
  end

  if !isstring(type) then
    irreversible('remove_column', 'remove_column is only reversible if given a type.')
  end

  return command('add_column', args[1], args[2], args[3], args[4])
end

--- Inverts rename_column by swapping the column names.
function inverters.rename_column(args)
  return command('rename_column', args[1], args[3], args[2])
end

--- Inverts add_timestamps into remove_timestamps.
function inverters.add_timestamps(args)
  return command('remove_timestamps', args[1], args[2])
end

--- Inverts remove_timestamps into add_timestamps.
function inverters.remove_timestamps(args)
  return command('add_timestamps', args[1], args[2])
end

--- Inverts add_reference into remove_reference.
function inverters.add_reference(args)
  return command('remove_reference', args[1], args[2], args[3])
end

--- Inverts remove_reference into add_reference.
function inverters.remove_reference(args)
  return command('add_reference', args[1], args[2], args[3])
end

--- Inverts add_index into remove_index of the same columns. Understands both the
-- positional and the table form of the arguments.
function inverters.add_index(args)
  local table_name, columns, options = args[1], args[2], args[3]

  if istable(table_name) and columns == nil then
    local args = table.Copy(table_name)
    table_name, columns = args[1], args[2]
    args[1], args[2] = nil, nil
    options = args
  end

  local inverse = table.Copy(options or {})
  inverse.column = columns

  return command('remove_index', table_name, inverse)
end

--- Inverts remove_index into add_index. Raises an error if the column(s) of the index
-- are not given.
function inverters.remove_index(args)
  local table_name, options = args[1], args[2]

  if isstring(options) then
    options = { column = options }
  elseif istable(options) and options[1] then
    options = { column = table.Copy(options) }
  end

  if !istable(options) or !options.column then
    irreversible('remove_index', 'remove_index is only reversible if given the column(s) of the index.')
  end

  local inverse = table.Copy(options)
  local columns = inverse.column

  inverse.column = nil
  inverse.if_exists = nil

  return command('add_index', table_name, columns, inverse)
end

--- Inverts add_foreign_key into remove_foreign_key.
function inverters.add_foreign_key(args)
  return command('remove_foreign_key', args[1], args[2], args[3])
end

--- Inverts remove_foreign_key into add_foreign_key. Raises an error if the referenced
-- table is not given.
function inverters.remove_foreign_key(args)
  if !isstring(args[2]) then
    irreversible('remove_foreign_key', 'remove_foreign_key is only reversible if given the referenced table.')
  end

  return command('add_foreign_key', args[1], args[2], args[3])
end

--- Inverts create_reference into remove_foreign_key of the reference's key.
function inverters.create_reference(args)
  local reference = args[1]

  return command('remove_foreign_key', reference.table_name, reference.foreign_table, {
    column = reference.key,
    name = reference.name
  })
end

--- Inverts execute_block into itself: the block is run either way, and decides what to
-- do from the direction of the migration.
function inverters.execute_block(args)
  return command('execute_block', args[1])
end

--- Creates a recorder. The recorder stands in for the schema statements while a
-- migration's #change is being reverted: every statement made is recorded, and in the
-- end the inverse of every statement is run in reverse order.
-- @return [ActiveRecord::CommandRecorder(self)]
function ActiveRecord.CommandRecorder:init()
  self.commands = {}
  self._reverting = false
  return self
end

--- Checks whether recorded statements are stored as their inverse.
-- @return [Boolean]
function ActiveRecord.CommandRecorder:reverting()
  return self._reverting
end

--- Records a statement. While reverting, the inverse of the statement is recorded
-- instead. The statements of change_table are recorded one by one.
-- @param name [String name of the statement, e.g. 'add_column']
-- @param ... [Vararg arguments of the statement]
function ActiveRecord.CommandRecorder:record(name, ...)
  if name == 'change_table' then
    return self:record_change_table(...)
  end

  local args = pack(...)

  if self._reverting then
    table.insert(self.commands, self:inverse_of(name, args))
  else
    table.insert(self.commands, { command = name, args = args })
  end
end

--- Records the statements made through the table object of change_table.
-- @param table_name [String]
-- @param callback [Function receives an ActiveRecord::TableRecorder]
function ActiveRecord.CommandRecorder:record_change_table(table_name, callback)
  callback(ActiveRecord.TableRecorder.new(self, table_name))
end

--- Returns the inverse of a statement, e.g. remove_column for add_column. Raises an
-- error for statements that cannot be reverted.
-- @param name [String name of the statement]
-- @param args [List arguments of the statement, with their count under 'n']
-- @return [Map the inverse, with the keys 'command' and 'args']
function ActiveRecord.CommandRecorder:inverse_of(name, args)
  local inverter = inverters[name]

  if !inverter then
    irreversible(name)
  end

  return inverter(args)
end

--- Records the statements made inside of the function in reverse, so that running the
-- recorded statements undoes them.
-- @param callback [Function]
function ActiveRecord.CommandRecorder:revert(callback)
  self._reverting = !self._reverting

  local previous = self.commands
  self.commands = {}

  local success, exception = pcall(callback)
  local recorded = self.commands

  self.commands = previous

  for i = #recorded, 1, -1 do
    table.insert(self.commands, recorded[i])
  end

  self._reverting = !self._reverting

  if !success then
    error(exception, 0)
  end
end

--- Runs the recorded statements in order.
function ActiveRecord.CommandRecorder:replay()
  for k, v in ipairs(self.commands) do
    ActiveRecord.ddl(v.command, unpack(v.args, 1, v.args.n))
  end
end

--- The table object that `change_table` hands to its callback while statements are being
-- recorded. It has the methods of a real table definition (the column types, `remove`,
-- `rename`, `timestamps` and `references`), each of which records the matching statement
-- (`add_column`, `remove_column` and so on) on its `ActiveRecord::CommandRecorder`.
class 'ActiveRecord::TableRecorder'

--- Creates the object that change_table hands to its callback while statements are
-- being recorded. It has the column type methods of a real table definition, as well
-- as remove, rename, timestamps and references, and records each call as a statement.
-- @param recorder [ActiveRecord::CommandRecorder]
-- @param table_name [String]
-- @return [ActiveRecord::TableRecorder(self)]
function ActiveRecord.TableRecorder:init(recorder, table_name)
  self.recorder = recorder
  self.table_name = table_name

  local types = ActiveRecord.Adapters[ActiveRecord.adapter_name:capitalize()].types or {}

  for type, def in pairs(types) do
    self[type] = function(s, name, ...)
      local options
      name, options = ActiveRecord.column_args(name, ...)

      s.recorder:record('add_column', s.table_name, name, type, options)
    end
  end

  return self
end

--- Records the removal of a column.
-- @param name [String column name]
function ActiveRecord.TableRecorder:remove(name)
  self.recorder:record('remove_column', self.table_name, name)
end

--- Records the renaming of a column.
-- @param name [String current column name]
-- @param new_name [String]
function ActiveRecord.TableRecorder:rename(name, new_name)
  self.recorder:record('rename_column', self.table_name, name, new_name)
end

--- Records the addition of the timestamp columns.
-- @param options=nil [Map column options]
function ActiveRecord.TableRecorder:timestamps(options)
  self.recorder:record('add_timestamps', self.table_name, options)
end

--- Records the addition of a reference column.
-- @param name [String/Map name of the referenced model, or the table form of the arguments]
-- @param ... [Vararg options]
function ActiveRecord.TableRecorder:references(name, ...)
  local options
  name, options = ActiveRecord.column_args(name, ...)

  self.recorder:record('add_reference', self.table_name, name, options)
end

ActiveRecord.TableRecorder.belongs_to = ActiveRecord.TableRecorder.references
