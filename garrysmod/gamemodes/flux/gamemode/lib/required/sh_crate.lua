--
-- Crate is the fancy name for the Flux libraries
--
-- This library is the centralized controlling mechanism for them.
--

if Crate then return end

if !string.ensure_end then
  include 'flux/gamemode/lib/flow/sh_aliases.lua'
  include 'flux/gamemode/lib/flow/sh_string.lua'
end

Crate = {}

local search_paths = {
  ['flux/gamemode/lib/'] = true,
  [fl.schema..'/schema/lib/'] = true
}

function Crate:add_path(path)
  search_paths[path:ensure_end('/')] = true

  return self
end

function Crate:try_include(path, original_path)
  local main_file = path:ensure_end('/')..'cratefile.lua'

  print(main_file)

  if file.Exists(main_file, 'LUA') then
    return util.include(main_file)
  else
    if file.Exists(path..'.lua', 'LUA') then
      return util.include(path..'.lua')
    else
      for k, v in ipairs(w'sh_ sv_ cl_') do
        local new_path = path:gsub('('..original_path..')', v..'%1.lua')

        if file.Exists(new_path, 'LUA') then
          return util.include(new_path)
        end
      end
    end
  end
end

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
    return util.include(path)
  end
end
