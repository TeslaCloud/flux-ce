local start_time = os.clock()

include 'flux/lib/crate.lua'

Crate:include 'flux'

Font.create_fonts()

if Flux.initialized then
  MsgC(Color(0, 255, 100, 255), 'Code reloaded in '..math.Round(os.clock() - start_time, 3)..' second(s)\n')
else
  MsgC(Color(0, 255, 100, 255), 'Boot complete in '..math.Round(os.clock() - start_time, 3)..' second(s)\n')
end
