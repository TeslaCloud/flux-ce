class 'Package'

function Package:init()
  self.metadata = {
    name        = '',
    version     = '',
    date        = '',
    summary     = '',
    description = '',
    author      = '',
    email       = '',
    file        = { },
    website     = '',
    license     = '',
    global      = ''
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
end

function Package:depends(what)
  local name = isstring(self) and self or what

  if !Crate:included(name) then
    Crate:include(name)
  end
end
