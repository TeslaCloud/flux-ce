---
-- Crate is a fancy name for Flux libraries
--
-- This library is the centralized controlling mechanism for them.

if Crate then return end

if !string.ensure_end then
  include 'flux/gamemode/lib/flow/sh_aliases.lua'
  include 'flux/gamemode/lib/flow/sh_string.lua'
end

if !table.safe_merge then
  include 'flux/gamemode/lib/flow/sh_table.lua'
end

include 'classes/sh_package.lua'

Crate           = {}
Crate.installed = {}
Crate.current   = nil

local search_paths = {
  ['flux/gamemode/lib/']      = true,
  [fl.schema..'/schema/lib/'] = true,
  ['lua/_flux/packages/']     = true
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
  callback(self.current)

  local meta = self.current.metadata

  if istable(meta.global) then
    for k, v in ipairs(meta.global) do
      _G[v] = _G[v] or {}
    end
  elseif isstring(meta.global) then
    _G[meta.global] = _G[meta.global] or {}
  end

  if istable(meta.file) then
    for k, file in ipairs(meta.file) do
      if file:starts('sv') or file:starts('cl') or file:starts('sh') then
        util.include(file)
      else
        include(file)
      end
    end
  elseif isstring(meta.file) then
    local file = meta.file

    if file:starts('sv') or file:starts('cl') or file:starts('sh') then
      util.include(file)
    else
      include(file)
    end
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

do
  local function do_include(path, original_path)
    Crate.current = Package.new()
    CRATE = Crate.current

    local values = { util.include(path) }

    Crate.installed[original_path] = Crate.current

    Crate.current = nil

    return unpack(values)
  end

  --- @warning [Internal]
  -- Attempts to include the package with the provided path.
  -- @return [...]
  function Crate:try_include(path, original_path)
    local main_file = path:ensure_end('/')..'cratefile.lua'

    if file.Exists(main_file, 'LUA') then
      return do_include(main_file, original_path)
    else
      if file.Exists(path..'.lua', 'LUA') then
        return do_include(path..'.lua', original_path)
      else
        for k, v in ipairs(w'sh_ sv_ cl_') do
          local new_path = path:gsub('('..original_path..')', v..'%1.lua')

          if file.Exists(new_path, 'LUA') then
            return do_include(new_path, original_path)
          end
        end
      end
    end
  end

  --- Attempts to include the package with the specified name.
  -- This function will look for the package in the search paths that have previously been added.
  -- If no package with the matching name can be found, throws an error.
  -- @return [...]
  function Crate:include(path)
    local original_path = path

    if !file.Exists(path, 'LUA') then
      local succeeded = false

      for k, v in pairs(search_paths) do
        local success, err = pcall(self.try_include, self, k..path, original_path)

        if success then
          succeeded = true
          break
        end
      end

      if !succeeded then
        error('could not load "'..original_path..'" (library not found)')
      end
    else
      return do_include(path, original_path)
    end
  end
end
