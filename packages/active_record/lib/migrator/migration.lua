--- A migration: one versioned step in the history of the database schema. A migration
-- file, named `<version>_<name>.lua`, creates a migration, describes its changes with the
-- schema statements in `change` (or in `up` and `down`) and returns it. Running the
-- migration up applies the changes; running it down reverts them, which happens
-- automatically for a `change` made of reversible statements.
--
-- The migrations of a schema live in its `db/migrate/` folder, where
-- `flux generate migration` creates new ones; those of packages and plugins live in their
-- `migrations` folder and are copied into the schema's folder when the server starts. The
-- class also keeps track of the migration that is running and prints its progress to the
-- console.

class 'ActiveRecord::Migration'

--- Whether migrations print what they do to the console.
-- @return [Boolean]
ActiveRecord.Migration.verbose = true

--- Set to true in a migration to run it outside of a transaction, e.g. because it
-- creates an index concurrently.
-- @return [Boolean]
ActiveRecord.Migration.disable_ddl_transaction = false

local current_migration = nil
local current_recorder = nil

--- Creates a migration. A migration file defines a migration, describes its changes in
-- #change (or in #up and #down) and returns it. The version and the name of the
-- migration come from its file name, '<version>_<name>.lua'.
-- ```
-- -- db/migrate/20190309120000_add_role_to_users.lua
-- local AddRoleToUsers = ActiveRecord.Migration.new()
--
-- function AddRoleToUsers:change()
--   add_column('users', 'role', 'string', { default = '\'user\'' })
-- end
--
-- return AddRoleToUsers
-- ```
-- @param version=nil [Number/String version of the migration; overridden by the file
--   name when the migration is loaded by the migrator]
-- @return [ActiveRecord::Migration(self)]
function ActiveRecord.Migration:init(version)
  self.version = version
  return self
end

--- Returns the migration that is running at the moment, if any.
-- @return [ActiveRecord::Migration]
function ActiveRecord.Migration.current_migration()
  return current_migration
end

--- Returns the command recorder that is collecting the statements of a #change that is
-- being reverted, if any.
-- @return [ActiveRecord::CommandRecorder]
function ActiveRecord.Migration.current_recorder()
  return current_recorder
end

--- Describes the schema changes of the migration. Meant to be overridden. The statements
-- used in here are reverted automatically when the migration is rolled back, as long as
-- they are reversible: create_table, add_column, rename_column, add_index,
-- add_foreign_key, add_reference, add_timestamps and their counterparts are. For the
-- rest, use #reversible or define #up and #down instead.
-- @return [ActiveRecord::Migration(self)]
function ActiveRecord.Migration:change()
  return self
end

--- Applies the migration. Runs #change by default; override it together with #down for
-- migrations that cannot be described by a reversible #change.
-- @return [ActiveRecord::Migration(self)]
function ActiveRecord.Migration:up()
  self:change()
  return self
end

--- Reverts the migration. Reverts #change by default.
-- @return [ActiveRecord::Migration(self)]
function ActiveRecord.Migration:down()
  self:revert(function() self:change() end)
  return self
end

--- Checks whether the migration overrides #change.
-- @return [Boolean]
function ActiveRecord.Migration:has_change()
  return self.change != ActiveRecord.Migration.change
end

--- Checks whether the migration is being reverted at the moment.
-- @return [Boolean]
function ActiveRecord.Migration:reverting()
  return self._reverting == true
end

--- Runs the migration in the given direction, printing what happens.
-- @param direction [String 'up' or 'down']
-- @return [ActiveRecord::Migration(self)]
function ActiveRecord.Migration:migrate(direction)
  local reverting = direction == 'down'

  self._reverting = reverting
  self:announce(reverting and 'reverting' or 'migrating')

  local start = os.clock()

  current_migration = self

  local success, exception = pcall(self.exec_migration, self, direction)

  current_migration = nil
  current_recorder = nil

  if !success then
    error(exception, 0)
  end

  self:announce((reverting and 'reverted' or 'migrated')..' ('..math.Round(os.clock() - start, 4)..'s)')

  return self
end

--- Runs the migration's #change, or #up / #down if #change is not overridden.
-- @warning [Internal]
-- @param direction [String 'up' or 'down']
function ActiveRecord.Migration:exec_migration(direction)
  if self:has_change() then
    if direction == 'down' then
      self:revert(function() self:change() end)
    else
      self:change()
    end
  else
    self[direction](self)
  end
end

--- Runs the inverse of the statements made inside of the function. Normally used inside
-- of #change to undo what an earlier migration did.
-- ```
-- function Migration:change()
--   revert(function()
--     create_table('logs', function(t) t:text 'body' end)
--   end)
-- end
-- ```
-- @param callback [Function/ActiveRecord::Migration function that makes the statements,
--   or a migration whose #change is reverted]
function ActiveRecord.Migration:revert(callback)
  if istable(callback) then
    local migration = callback
    callback = function() migration:change() end
  end

  if current_recorder then
    -- Already recording (nested revert): flip the direction of the recorder for the
    -- duration of the callback.
    current_recorder:revert(callback)
    return
  end

  local recorder = ActiveRecord.CommandRecorder.new()
  current_recorder = recorder

  local success, exception = pcall(recorder.revert, recorder, callback)

  current_recorder = nil

  if !success then
    error(exception, 0)
  end

  recorder:replay()
end

--- Lets #change run code that differs between migrating and reverting. The helper that
-- the callback receives runs its 'up' function only when migrating and its 'down'
-- function only when reverting.
-- ```
-- function Migration:change()
--   reversible(function(dir)
--     dir:up(function() execute("UPDATE users SET role = 'user'") end)
--     dir:down(function() execute("UPDATE users SET role = NULL") end)
--   end)
-- end
-- ```
-- @param callback [Function receives the direction helper]
function ActiveRecord.Migration:reversible(callback)
  local reverting = self:reverting()
  local helper = {}

  --- Runs the function only when migrating.
  function helper:up(fn) if !reverting then fn() end end
  --- Runs the function only when reverting.
  function helper:down(fn) if reverting then fn() end end

  self:execute_block(function() callback(helper) end)
end

--- Runs a function. When the migration is being reverted through its #change, the
-- function is recorded like a statement and run in its turn.
-- @param callback [Function]
function ActiveRecord.Migration:execute_block(callback)
  ActiveRecord.ddl('execute_block', callback)
end

--- Returns the name used in the console output: the camel-cased name of the migration
-- file, or the class name.
-- @return [String]
function ActiveRecord.Migration:display_name()
  return self.name or self.class_name
end

--- Prints a line that stands out, prefixed with the version and the name of the migration.
-- @param message [String]
function ActiveRecord.Migration:announce(message)
  if !self:is_verbose() then return end

  local text = '== '..tostring(self.version or '')..' '..tostring(self:display_name())..': '..message..' '

  print(text..string.rep('=', math.max(0, 75 - text:len())))
end

--- Prints a message.
-- @param message [String]
-- @param subitem=false [Boolean indent the message as a sub-item of the previous one]
function ActiveRecord.Migration:say(message, subitem)
  if !self:is_verbose() then return end

  print((subitem and '   -> ' or '-- ')..message)
end

--- Prints a message, runs a function and prints the time it took.
-- @param message [String]
-- @param callback [Function]
-- @return [Any whatever the function returns]
function ActiveRecord.Migration:say_with_time(message, callback)
  self:say(message)

  local start = os.clock()
  local result = callback()

  self:say(math.Round(os.clock() - start, 4)..'s', true)

  return result
end

--- Runs a function without printing anything.
-- @param callback [Function]
-- @return [Any whatever the function returns]
function ActiveRecord.Migration:suppress_messages(callback)
  local verbose = self.verbose
  self.verbose = false

  local success, result = pcall(callback)

  self.verbose = verbose

  if !success then
    error(result, 0)
  end

  return result
end

--- Checks whether the migration prints its progress.
-- @return [Boolean]
function ActiveRecord.Migration:is_verbose()
  return self.verbose != false and ActiveRecord.Migration.verbose != false
end

--- Generates the version for a new migration from the current time (YYYYMMDDHHMMSS in
-- UTC), increased past the given version if that one is newer.
-- @param number=nil [Number/String version that the new one has to be greater than]
-- @return [String 14-digit version]
function ActiveRecord.Migration.next_migration_number(number)
  local timestamp = os.date('!%Y%m%d%H%M%S')
  local next_number = (tonumber(number) or 0) + 1

  if next_number > tonumber(timestamp) then
    return string.format('%.0f', next_number)
  end

  return timestamp
end
