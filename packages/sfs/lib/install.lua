--- Installer of the SFS package: loads Srlion's Fast Serializer into the `sfs` global and
-- makes its encoder report functions as an unsupported type.

--- Called by the Package manager once the package has been included.
-- Sends the library to clients and loads SFS into the global of the same name.
function PACKAGE:__installed__()
  AddCSLuaFile(self.__path__..'lib/sfs.lua')

  if !sfs then
    sfs = include(self.__path__..'lib/sfs.lua')
  end

  local encoder = sfs.Encoder

  encoder.encoders['function'] = function(buf)
    encoder.write_str(buf, 'unsupported type: ')
    encoder.write_str(buf, 'function')

    return true
  end
end
