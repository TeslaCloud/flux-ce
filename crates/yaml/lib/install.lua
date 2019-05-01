function CRATE:__installed__()
  if !YAML then
    YAML = include(self.__path__..'lib/yaml.lua')
  end
end
