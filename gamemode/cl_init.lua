local start_time = os.clock()

include 'env.lua'
include 'flux/lib/crate.lua'

if Flux.initialized then
  Crate:reload 'flux'
  MsgC(Color(0, 255, 100, 255), 'Code reloaded in '..math.Round(os.clock() - start_time, 3)..' second(s)\n')
else
  Crate:include 'flux'
  MsgC(Color(0, 255, 100, 255), 'Boot complete in '..math.Round(os.clock() - start_time, 3)..' second(s)\n')
end

Font.create_fonts()
