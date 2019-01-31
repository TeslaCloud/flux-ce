fl = fl or {}
fl.start_time = os.clock()

-- Include pON, Cable and UTF-8 library
if !string.utf8len or !pon or !cable then
  include 'vendor/utf8.lua'
  include 'vendor/pon.lua'
  include 'vendor/cable.lua'
end

if fl.initialized then
  MsgC(Color(0, 255, 100, 255), 'Lua auto-reload in progress...\n')
else
  MsgC(Color(0, 255, 100, 255), 'Initializing...\n')
end

-- Gotta have screen scaling before everything else!
if !set_screen_scale then
  include 'flux/gamemode/lib/cl_scaling.lua'
end

-- Initiate shared boot.
include 'shared.lua'

font.create_fonts()

if fl.initialized then
  MsgC(Color(0, 255, 100, 255), 'Auto-reloaded in '..math.Round(os.clock() - fl.start_time, 3).. ' second(s)\n')
else
  MsgC(Color(0, 255, 100, 255), 'Flux v'..GM.version..' ('..GM.code_name..') has finished loading in '..math.Round(os.clock() - fl.start_time, 3).. ' second(s)\n')

  fl.initialized = true
end
