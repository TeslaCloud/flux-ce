Flux = Flux or {}
Flux.start_time = os.clock()

-- Include the required third-party libraries.
if !string.utf8upper or !pon or !cable then
  include 'lib/vendor/utf8.min.lua'
  include 'lib/vendor/pon.min.lua'
  include 'lib/vendor/cable.min.lua'
  include 'lib/vendor/markdown.min.lua'
end

if Flux.initialized then
  MsgC(Color(0, 255, 100, 255), 'Lua auto-reload in progress...\n')
else
  MsgC(Color(0, 255, 100, 255), 'Initializing...\n')
end

-- Initiate shared boot.
include 'shared.lua'

Font.create_fonts()

if Flux.initialized then
  MsgC(Color(0, 255, 100, 255), 'Auto-reloaded in '..math.Round(os.clock() - Flux.start_time, 3)..' second(s)\n')
else
  MsgC(Color(0, 255, 100, 255), 'Flux v'..GM.version..' ('..GM.code_name..') has finished loading in '..math.Round(os.clock() - Flux.start_time, 3)..' second(s)\n')

  Flux.initialized = true
end
