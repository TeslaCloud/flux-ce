--- Loads the YAML library into the YAML global, unless it is loaded already,
-- and adds the YAML.read file helper to it when it is missing.
function PACKAGE:__installed__()
  if !YAML then
    YAML = include(self.__path__..'lib/yaml.lua')
  end

  if !YAML.read then
    --- Reads and parses a YAML file. If a '.local.yml' (or '.local.yaml') variant of the
    -- file exists next to it, that file is read instead.
    -- @param file_name [String path to the file, relative to the game folder]
    -- @return [Any parsed document (usually a Map), or nil if the file does not exist]
    function YAML.read(file_name)
      if file.Exists(file_name, 'GAME') then
        local local_name = file_name:gsub('%.y([a]?)ml', '.local.y%1ml')

        if file.Exists(local_name, 'GAME') then
          file_name = local_name
        end

        return YAML.eval(file.Read(file_name, 'GAME'))
      end
    end
  end
end
