--- Installer of the YAML package: loads the parser into the `YAML` global and adds
-- `YAML.read`, which reads and parses a file. The package is only included on the server.

--- Loads the YAML library into the YAML global, unless it is loaded already,
-- and adds the YAML.read file helper to it when it is missing.
function PACKAGE:__installed__()
  if !YAML then
    YAML = include(self.__path__..'lib/yaml.lua')
  end

  if !YAML.read then
    --- Reads and parses a YAML file.
    -- @param file_name [String path to the file, relative to the game folder]
    -- @return [Any parsed document (usually a Map), or nil if the file does not exist]
    function YAML.read(file_name)
      if file.Exists(file_name, 'GAME') then
        return YAML.eval(file.Read(file_name, 'GAME'))
      end
    end
  end
end
