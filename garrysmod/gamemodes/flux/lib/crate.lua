---
-- Crate is a fancy name for Flux packages.
--
-- This library is the centralized controlling mechanism for them.

AddCSLuaFile()

if Crate then return end

if !require_relative then
  include 'flux/crates/flow/lib/sh_helpers.lua'
end

if !Flux or (CLIENT and (!Flux or !Flux.shared or !Flux.shared.crates)) then
  require_relative 'flux/lib/flux_struct'
end

if !class then
  require_relative 'flux/crates/flow/lib/sh_class'
end

if !library then
  require_relative 'flux/crates/flow/lib/sh_library'
end

if !string.ensure_end then
  require_relative 'flux/crates/flow/lib/sh_aliases'
  require_relative 'flux/crates/flow/lib/sh_string'
end

if !table.safe_merge then
  require_relative 'flux/crates/flow/lib/sh_table'
end

require_relative 'package'

local crate_metadata = {}

if SERVER then
  Flux.shared.crates = {}
else
  crate_metadata = Flux.shared.crates
end

Crate                           = {}
Crate.installed                 = {}
Crate.current                   = nil

local search_paths = {
  ['flux/crates/']              = true,
  [Flux.schema..'/schema/lib/'] = true,
  [Flux.schema..'/crates/']     = true,
  ['_flux/packages/']           = true,
  ['']                          = true
}

--- Adds a search path relative to 'LUA' system.
-- @return [Table(self)]
function Crate:add_path(path)
  search_paths[path:ensure_end('/')] = true

  return self
end

--- Describes current package's specification.
-- For every singular function there is a plural alias and vice versa.
-- ```
-- Crate:describe(function(s)
--   s.name        'Example Package'
--   s.version     '1.0'
--   s.date        '2019-03-09'
--   s.summary     'Brief summary of what the package does.'
--   s.description 'A more detailed description of what the package does.'
--   s.authors     { 'Flux Developer' }
--   s.email       'example@example.com'
--   s.files       { 'lib/example.lua', 'config/example.lua' }
--   s.global      'ExamplePackage'
--   s.website     'https://example.com'
--   s.license     'MIT'
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
    callback(self.current)
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

  if istable(meta.global) then
    for k, v in ipairs(meta.global) do
      _G[v] = istable(_G[v]) and _G[v] or {}

      if !_G[v].__crate__ then
        _G[v].__crate__ = meta
      end
    end
  elseif isstring(meta.global) then
    _G[meta.global] = istable(_G[meta.global]) and _G[meta.global] or {}

    if !_G[meta.global].__crate__ then
      _G[meta.global].__crate__ = meta
    end
  end

  -- Once globals are set-up, include dependencies!
  if istable(meta.deps) then
    for k, name in ipairs(meta.deps) do
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
      include(v)
    end
  end

  if istable(meta.file) then
    for k, file in ipairs(meta.file) do
      local filename = file:file_from_filename()

      if filename:starts('sv') or filename:starts('cl') or filename:starts('sh') then
        require_relative(full_path..file)
      else
        include(full_path..file)
      end
    end
  elseif isstring(meta.file) then
    local file = meta.file
    local filename = file:file_from_filename()

    if filename:starts('sv') or filename:starts('cl') or filename:starts('sh') then
      require_relative(full_path..file)
    else
      include(full_path..file)
    end
  end

  if meta.serverside then
    require_ignore('client', false)
  end

  return self.current
end

--- Determines if the package has already been installed.
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
  self.installed[name] = nil
  return self:include(name)
end

do
  local function do_include(file_path, lib_path, full_path)
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
  function Crate:include(name)
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

      return do_include(meta.file_path, name, name)
    end
  end
end
