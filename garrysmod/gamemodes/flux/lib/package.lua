class 'Package'

function Package:init(file_path, lib_path, full_path)
  self.metadata = {
    name        = '',
    version     = '',
    date        = '',
    summary     = '',
    description = '',
    author      = '',
    email       = '',
    file        = { },
    cl_file     = { },
    sv_file     = { },
    website     = '',
    license     = '',
    global      = '',
    deps        = { },
    serverside  = false,
    clientside  = false
  }

  for k, v in pairs(self.metadata) do
    local f = function(obj, new_val)
      if istable(obj) and obj.class_name == self.class_name then
        obj.metadata[k] = new_val
      else
        self.metadata[k] = obj
      end
    end

    self[k] = f
    self[(!k:ends('y') and k..'s' or k:sub(1, k:len() - 1)..'ies')] = f
  end

  self.metadata.file_path = file_path
  self.metadata.lib_path  = lib_path
  self.metadata.full_path = full_path
  self.__path__           = full_path
end

function Package:depends(what)
  local name = isstring(self) and self or what

  if istable(self) then
    table.insert(self.metadata.deps, name)
  else
    table.insert(CRATE.metadata.deps, name)
  end
end
