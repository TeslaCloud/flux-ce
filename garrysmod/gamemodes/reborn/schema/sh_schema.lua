--[[
  This file in an entry point for your schema. It will be included first, right after all of the
  folders have been included (so, for example, "lib" folder would load before this file).

  You are supposed to use this file to include other files (such as hooks, etc).
--]]

util.include 'cl_schema.lua'
util.include 'sv_schema.lua'

-- It is recommended to include hooks after everything else has been included.
util.include 'cl_hooks.lua'
util.include 'sv_hooks.lua'

-- A function to kill a random player.
function Schema:kill_random_player()
  local random_player = player.random()

  if IsValid(random_player) then
    return random_player:Kill()
  end
end
