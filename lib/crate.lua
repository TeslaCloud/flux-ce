---
-- Crate is a fancy name for Flux packages.
--
-- This library is the centralized controlling mechanism for them.

AddCSLuaFile()

if Crate then return end

local flow_path = 'flux/crates/flow/'
local schema_name = engine.ActiveGamemode()
local search_paths = {
  ['flux/crates/']              = true,
  [schema_name..'/schema/lib/'] = true,
  [schema_name..'/crates/']     = true,
  ['_flux/packages/']           = true,
  ['']                          = true
}

if SERVER then
  if !file.Exists(flow_path:gsub('/$', ''), 'LUA') then
    flow_path = nil

    for path, _ in pairs(search_paths) do
      if flow_path then break end

      local _, folders = file.Find(path..'flow*', 'LUA')

      if #folders > 0 then
        for _, f in ipairs(folders) do
          if f[1] == '.' then continue end

          if file.Exists(path..f..'/flow.cratespec', 'LUA') then
            flow_path = path..f..'/'
            break
          end
        end
      end
    end
  end
else
  flow_path = getenv 'FLOW_PATH'
end

if !flow_path then
  error 'flow: package not found!\n'
else
  add_client_env('FLOW_PATH', flow_path)
end

if !require_relative then
  include(flow_path..'lib/sh_helpers.lua')
end

if !Flux or (CLIENT and (!Flux or !Flux.shared or !Flux.shared.crates)) then
  require_relative 'flux/lib/flux_struct'
end

if !class then
  require_relative(flow_path..'lib/sh_class')
end

if !library then
  require_relative(flow_path..'lib/sh_library')
end

if !string.ensure_end then
  require_relative(flow_path..'lib/sh_aliases')
  require_relative(flow_path..'lib/sh_string')
end

if !table.safe_merge then
  require_relative(flow_path..'lib/sh_table')
end

require_relative 'package'

local crate_metadata = {}

if SERVER then
  Flux.shared.crates = {}
else
  crate_metadata = Flux.shared.crates
end

Crate             = {}
Crate.installed   = {}
Crate.current     = nil

--- Adds a search path relative to 'LUA' system.
-- @return [self]
function Crate:add_path(path)
  search_paths[path:ensure_end('/')] = true
  return self
end

--- Describes current package's specification.
-- For every singular function there is a plural alias and vice versa.
-- ```
-- Crate:describe(function(s)
--   s.name        = 'Example Package'
--   s.version     = '1.0'
--   s.date        = '2019-03-09'
--   s.summary     = 'Brief summary of what the package does.'
--   s.description = 'A more detailed description of what the package does.'
--   s.authors     = { 'Flux Developer' }
--   s.email       = 'example@example.com'
--   s.files       = { 'lib/example.lua', 'config/example.lua' }
--   s.global      = 'ExamplePackage'
--   s.website     = 'https://example.com'
--   s.license     = 'MIT'
--
--   s.depends     'random_dependency'
--
--   if IS_DEVELOPMENT then
--     s.depends   'random_development_package'
--   end
-- end)
-- ```
-- @return [Package]
function Crate:describe(callback)
  if callback then
    local mt = setmetatable({ depends = self.current.depends }, { __newindex = function(o, k, v)
      if k:ends('s') then
        if k:ends('ies') then
          k = k:gsub('ies$', 'y')
        else
          k = k:gsub('s$', '')
        end
      end

      self.current.metadata[k] = v
    end
    })

    callback(mt)
  end

  local meta = self.current.metadata

  if SERVER and meta.clientside then
    if istable(meta.file) then
      for k, file in ipairs(meta.file) do
        AddCSLuaFile(file)
      end
    elseif isstring(meta.file) then
      AddCSLuaFile(meta.file)
    end

    return self.current
  end

  if !istable(meta.global) then
    meta.global = { meta.global }
  end

  for k, v in ipairs(meta.global) do
    if isstring(v) then
      _G[v] = istable(_G[v]) and _G[v] or {}

      if !_G[v].__crate__ then
        _G[v].__crate__ = meta
      end
    end
  end

  -- Once globals are set-up, include dependencies!
  if istable(meta.deps) then
    for k, name in ipairs(meta.deps) do
      if name:ends('.lua') then
        include(self.current.__path__..name)
        continue
      end

      if !self:included(name) then
        self:include(name)
      end
    end
  end

  if meta.serverside then
    require_ignore('client', true)
  end

  local full_path = meta.full_path
  local client_files, server_files = meta.cl_file, meta.sv_file

  if isstring(client_files) then client_files = { client_files } end
  if isstring(server_files) then server_files = { server_files } end

  if SERVER then
    if istable(client_files) then
      for k, v in ipairs(client_files) do
        AddCSLuaFile(v)
      end
    end

    if istable(server_files) then
      for k, v in ipairs(server_files) do
        include(v)
      end
    end
  elseif istable(client_files) then
    for k, v in ipairs(client_files) do
      include(self.current.__path__..v)
    end
  end

  if istable(meta.file) then
    for k, file in ipairs(meta.file) do
      require_relative(full_path..file)
    end
  elseif isstring(meta.file) then
    require_relative(full_path..meta.file)
  end

  if meta.serverside then
    require_ignore('client', false)
  end

  return self.current
end

--- Determines if the package has already been installed.
-- @alias [Crate.present]
-- @alias [Crate.is_installed]
-- @return [Boolean]
function Crate:included(name)
  return istable(self.installed[name])
end

Crate.present       = Crate.included
Crate.is_installed  = Crate.included

--- Searches for a package with the specified name and returns
-- a full path to it's cratespec, the name of the package and
-- full path to the folder.
-- Returns false if the package cannot be found.
-- @return [String(cratespec_path) String(name) String(folder_path)]
-- @return [Boolean]
function Crate:find(name)
  local folder_path = name:ensure_end('/')
  local files, _ = file.Find(folder_path..'*.cratespec', 'LUA')

  if !istable(files) or #files == 0 then
    for path, v in pairs(search_paths) do
      local full_path = path..folder_path:ensure_end('/')
      local files, _ = file.Find(full_path..'*.cratespec', 'LUA')

      if istable(files) and #files > 0 then
        return full_path..files[1], name, full_path
      end
    end
  elseif istable(files) then
    return folder_path..files[1], name, folder_path
  end

  return false
end

--- Searches for the package with the specified name and
-- returns true if the package exists, false otherwise.
-- @return [Boolean]
function Crate:exists(name)
  return tobool(self:find(name))
end

--- Reloads the package with the specified name.
-- @return [Table(self)]
function Crate:reload(name)
  if istable(self.installed[name]) and self.installed[name].metadata.reload then
    self.installed[name] = nil
    return self:include(name)
  end
end

--- Parse version string.
-- @return [Hash]
function Crate:parse_version(version)
  local buf = nil
  local init = 1
  local last = 'x'
  local version_data = {
    x = nil,
    y = nil,
    z = nil,
    sum = nil,
    suffix = nil,
    op = '=='
  }

  version = version:gsub('%s', '')

  if version[1] == '~' or version[1] == '>' then
    version_data.op = ({ ['>']=1, ['=']=1 })[version[2]] and version:sub(1, 2) or version:sub(1, 1)
    init = version_data.op:len() + 1
  end

  for i = init, version:len() do
    local v = version[i]

    if v != '.' and v != '-' then
      buf = (buf or '')..v
    else
      if buf then
        if !version_data.x then
          version_data.x = tonumber(buf)
          last = 'y'
        elseif !version_data.y then
          version_data.y = tonumber(buf)
          last = 'z'
        elseif !version_data.z then
          version_data.z = tonumber(buf)
          last = 'suffix'
        end

        if v == '-' then last = 'suffix' end

        buf = nil
      else
        error('invalid package version: '..tostring(version)..'\n')
      end
    end
  end

  if buf then
    version_data[last] = buf
  end

  version_data.x = tonumber(version_data.x) or 0
  version_data.y = tonumber(version_data.y) or 0
  version_data.z = tonumber(version_data.z) or 0
  version_data.sum = tonumber(
    tostring(version_data.x)..
    tostring(version_data.y)..
    tostring(version_data.z)
  )

  return version_data
end

--- Returns -1 if version1 is older than version2.
-- Returns 0 if versions are equal.
-- Returns 1 if version1 is newer than version2.
-- @return [Number]
function Crate:compare_version(version1, version2)
  if !istable(version1) or !istable(version2) then return false end

  local s1, s2 = version1.sum or 0, version2.sum or 0

  if s1 < s2 then
    return -1
  elseif s1 == s2 then
    return 0
  elseif s1 > s2 then
    return 1
  end
end

--- Returns true if version2 matches the version1 template.
-- @return [Number]
function Crate:is_version(version1, version2)
  local res = self:compare_version(version1, version2)

  if version1.op == '==' and res == 0 then
    if version1.suffix and version1.suffix != version2.suffix then return false end

    return true
  elseif version1.op == '>=' and (res == -1 or res == 0) then
    return true
  elseif version1.op == '~>' and res != 1 then
    if res == 0 then return true end

    local x, y, z, x1, y1, z1 = version1.x, version1.y, version1.z, version2.x, version2.y, version2.z

    if x == x1 then
      if y == y1 then
        return z1 >= z
      elseif z == 0 and y == 0 then
        return true
      elseif z == 0 then
        return y1 >= y
      end
    end
  end

  return false
end

do
  --- @ignore
  local function do_include(file_path, lib_path, full_path)
    if istable(Crate.installed[lib_path]) and !Crate.installed[lib_path].metadata.reload then
      return
    end

    local parent_crate

    if Crate.current then
      parent_crate = Crate.current
    end

    Crate.current = Package.new(file_path, lib_path, full_path)
    CRATE = Crate.current

    if CLIENT then
      Crate.current.metadata = crate_metadata[lib_path]
      Crate:describe()
    else
      include(file_path)

      if !Crate.current.metadata.serverside then
        Flux.shared.crates[lib_path] = table.Copy(Crate.current.metadata)
      else
        Flux.shared.crates[lib_path] = false
      end
    end

    Crate.installed[lib_path] = Crate.current

    if isfunction(Crate.current.__installed__) then
      Crate.current:__installed__()
    end

    Crate.current = parent_crate
    CRATE         = parent_crate
  end

  --- Attempts to include the package with the specified name.
  -- This function will look for the package in the search paths that have previously been added.
  -- If no package with the matching name can be found, throws an error.
  -- @return [...]
  function Crate:include(name, version)
    -- Skip Lua files.
    if name:EndsWith('.lua') then return true end

    if SERVER then
      local folder_path = name:ensure_end('/')
      local files, _ = file.Find(folder_path..'*.cratespec', 'LUA')

      if !istable(files) or #files == 0 then
        for path, v in pairs(search_paths) do
          local full_path = path..folder_path:ensure_end('/')
          local files, _ = file.Find(full_path..'*.cratespec', 'LUA')

          if istable(files) and #files > 0 then
            return do_include(full_path..files[1], name, full_path)
          end
        end

        error('could not load "'..name..'" (no crate spec file found)')
      elseif istable(files) and #files > 0 then
        return do_include(folder_path..files[1], name, folder_path)
      else
        error('could not load "'..name..'" (library not found)')
      end
    else
      local meta = crate_metadata[name]

      if meta == false then return end

      return do_include(meta.file_path, name, meta.full_path)
    end
  end
end
