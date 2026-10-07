--- Loads the YAML library into the YAML global, unless it is loaded already.
function CRATE:__installed__()
  if !YAML then
    YAML = include(self.__path__..'lib/yaml.lua')
  end
end
