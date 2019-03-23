local start_time = os.clock()

function require_module(mod)
  local success, value = pcall(require, mod)

  if !success then
    ErrorNoHalt('Failed to open the "'..mod..'" module!\n')
    return false
  end

  return true
end

if !LITE_REFRESH then
  if !require_module 'fileio' then
    ErrorNoHalt('The fileio module has failed to load!\nPlease make sure that you have gmsv_fileio_'..((system.IsWindows() and 'win32') or 'linux')..'.dll in garrysmod/lua/bin folder!\nAborting startup...\n')
    return
  end

  include 'flux/lib/crate.lua'

  Crate:include 'flux'
end

if Flux.initialized then
  MsgC(Color(0, 255, 100, 255), 'Code reloaded in '..math.Round(os.clock() - start_time, 3)..' second(s)\n')
else
  MsgC(Color(0, 255, 100, 255), 'Boot complete in '..math.Round(os.clock() - start_time, 3)..' second(s)\n')
end
