--- Client entry point of the gamemode.
-- Loads the environment, the standard library and the package manager and includes the `flux`
-- package, or reloads it on a code refresh, then creates the fonts.

local start_time = os.clock()

include 'env.lua'
include 'flux/lib/stdlib/sh_stdlib.lua'
include 'flux/lib/package.lua'

if Flux.initialized then
  Package:reload 'flux'
  MsgC(Color(0, 255, 100, 255), 'Code reloaded in '..math.Round(os.clock() - start_time, 3)..' second(s)\n')
else
  Package:include 'flux'
  MsgC(Color(0, 255, 100, 255), 'Boot complete in '..math.Round(os.clock() - start_time, 3)..' second(s)\n')
end

Font.create_fonts()

print_debug_metrics()
