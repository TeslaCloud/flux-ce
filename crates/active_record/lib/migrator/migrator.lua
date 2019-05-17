include 'migration.lua'
include 'schema.lua'

class 'ActiveRecord::Migrator'

local migration_files = {}

function ActiveRecord.Migrator:init(version)
  self.db_path = 'gamemodes/'..Flux.get_schema_folder()..'/db'
  self.schema_path = self.db_path..'/schema.lua'

  if !file.Exists(self.schema_path, 'GAME') then
    ErrorNoHalt "Warning - Unable to find the 'db/schema.lua' file. Attempting to generate schema...\n"
    return self:generate_schema(version)
  end

  self.schema = include(self.schema_path:gsub('gamemodes/', ''))
  self.schema.version = version or self.schema.version
  ActiveRecord.metadata = self.schema.metadata or ActiveRecord.metadata or {}

  return self
end

function ActiveRecord.Migrator:generate_schema(version)
  File.delete(self.db_path..'/.keep')
  File.write(self.schema_path, ActiveRecord.dump_schema(version or (self.schema and self.schema.version) or 0))
  self.schema = include(self.schema_path:gsub('gamemodes/', ''))
  ActiveRecord.metadata = self.schema.metadata or ActiveRecord.metadata or {}

  return self
end

function ActiveRecord.Migrator:run_migrations(folder, force)
  if !self.schema then error "Can't run migrations without a schema!" end

  if #migration_files > 0 then
    for k, v in ipairs(migration_files) do
      self:migration_from_file(v)
    end
  end

  folder = (folder or self.db_path..'/migrate/'):gsub('gamemodes/', '')

  local migration_start = os.clock()
  local migration_count = 0
  local initial_version = tonumber(self.schema.version) or 0

  folder = folder:ensure_end('/')

  local files, folders = file.Find(folder..'*', 'LUA')

  for k, v in ipairs(files) do
    local version, migration_name = v:match('^(%d+)_([^%.]+)%.lua')

    if (tonumber(version) or 0) > tonumber(self.schema.version) or force then
      if migration_count == 0 then
        print('Running migrations...')
      end

      local start_time = os.clock()
      local migration = include(folder..v)

      if migration and isfunction(migration.up) then
        migration:up()

        print('-> '..folder..v)
        print('Updated '..self.schema.version..' -> '..migration.version)
        print('('..math.Round(os.clock() - start_time, 4)..'s)\n')

        self.schema.version = migration.version or self.schema.version

        migration_count = migration_count + 1
      end
    end
  end

  if tonumber(initial_version) != tonumber(self.schema.version) then
    if initial_version == 0 then
      self.schema:setup_references()
    end

    if migration_count > 0 then
      print('Ran '..migration_count..' migration'..(migration_count > 1 and 's' or '')..' in '..math.Round(os.clock() - migration_start, 4)..'s.')
      self:generate_schema()
    end
  end

  return self
end

function ActiveRecord.Migrator:setup_database()
  self.schema:create_tables()
  self.schema:setup_references()
  return self
end

function ActiveRecord.Migrator:generate_version()
  local version = to_timestamp(os.time())
  local files, folders = file.Find(self.db_path..'/migrate/*.lua', 'GAME')

  for k, v in ipairs(files) do
    local ver = v:match('^(%d+)_')

    if tonumber(version) == tonumber(ver) then
      version = tonumber(version) + 1
    end
  end

  return version
end

function ActiveRecord.Migrator:migration_exists(version, name)
  version = version or 0
  name = (name or ''):underscore()

  local files, folders = file.Find(self.db_path..'/migrate/*.lua', 'GAME')

  for k, v in ipairs(files) do
    local ver, migration_name = v:match('^(%d+)_([^%.]+)%.lua')

    if tonumber(ver) == tonumber(version) or migration_name == name then
      return true
    end
  end

  return false
end

function ActiveRecord.Migrator:generate_migration(name, body, verbose, file_path)
  File.delete(self.db_path..'/migrate/.keep')

  local version = self:generate_version()
  file_path = (file_path and file_path:ensure_end('/') or (self.db_path..'/migrate/'))..version..'_'..name:underscore()..'.lua'

  File.write(file_path, [[local Migration = ActiveRecord.Migration.new(]]..version..[[)
  function Migration:change()
]]..string.set_indent(body or '', '    '):trim_end('    ')..[[
  end
return Migration
]])

  if verbose then
    print('Generated migration:\n-> '..file_path)
  end

  return self
end

function ActiveRecord.Migrator:migration_from_file(file)
  file = file:ensure_start('gamemodes/')
  local file_name = File.name(file)
  local version, name = file_name:match('^(%d+)_([^%.]+)%.lua')

  if !version then
    name = file_name:gsub('%.lua', '')
  end

  if self:migration_exists(version, name) then return end

  local contents = File.read(file)

  if contents then
    self:generate_migration(name, contents, Flux.development)
  end

  return self
end

function ActiveRecord.Migrator:add_file(path)
  table.insert(migration_files, 'gamemodes/'..path)
  return self
end
