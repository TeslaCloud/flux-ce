--- Gamemastery gives gamemasters a way to run the world without a character of their own.
-- A player with the `gamemastery` permission who has no active character is in gamemaster
-- mode: alive, in noclip that cannot be left, invulnerable and vanished, with the
-- `gamemastering` networked variable set. They are not killed and hidden like other players
-- without a character, and the main menu does not open for them after the intro.
--
-- Gamemasters share a pool of characters that belong to a dedicated user record. Any of them
-- can possess a pool character, which turns them into it on the spot, release it to go back
-- to gamemaster mode where they stand, place it in the world as an `fl_gm_character` entity
-- by dragging its card from the tab menu onto the world, and delete it. A pool character is
-- played by one gamemaster at a time. Players of the `gamemaster` role never own characters:
-- whatever they create goes into the pool. Admins keep their own characters and add to the
-- pool with a button of the main menu.
-- @module [Gamemastery]

PLUGIN:set_global('Gamemastery')

require_relative 'cl_plugin'
require_relative 'cl_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'

Gamemastery.pool_steam_id = 'GAMEMASTER_POOL'
Gamemastery.pool_name = 'Gamemasters'
Gamemastery.role_id = 'gamemaster'

--- Checks whether a player may use the gamemaster tools: a real player with the
-- 'gamemastery' permission.
-- @param target [Player]
-- @return [Boolean]
function Gamemastery.is_gamemaster(target)
  return IsValid(target) and target:IsPlayer() and !target:IsBot() and tobool(target:can('gamemastery'))
end

--- Checks whether a player has the `gamemaster` role, which never owns characters.
-- @param target [Player]
-- @return [Boolean]
function Gamemastery.has_gamemaster_role(target)
  return IsValid(target) and target:GetUserGroup() == Gamemastery.role_id
end

--- Checks whether a player is in gamemaster mode.
-- @param target [Player]
-- @return [Boolean]
function Gamemastery.is_in_mode(target)
  return IsValid(target) and target:get_nv('gamemastering') == true
end

--- Completes arguments of the 'gm_character' type with the names of the pool characters:
-- those the server has sent to the client, or those the server keeps.
-- @return [List<String> character names, sorted]
local function complete_gm_character()
  local names = {}

  for _, v in ipairs(Gamemastery.get_pool()) do
    if isstring(v.name) then
      names[#names + 1] = v.name
    end
  end

  table.sort(names, function(a, b)
    return a:utf8lower() < b:utf8lower()
  end)

  return names
end

Flux.Command:add_completer('gm_character', complete_gm_character)

--- Registers the 'gamemastery' permission.
function Gamemastery:RegisterPermissions()
  Bolt:register_permission(
    'gamemastery',
    'Gamemastery',
    'Lets the player be in the world without a character and play the shared gamemaster characters.',
    'permission.categories.administration'
  )
end

--- Lets gamemasters without an active character stay in the world.
-- @param target [Player]
-- @return [Boolean false for a gamemaster who has no active character, otherwise nil]
function Gamemastery:PlayerNeedsCharacter(target)
  if !target:is_character_loaded() and Gamemastery.is_gamemaster(target) then
    return false
  end
end

--- Lifts the character limit for players of the `gamemaster` role, whose characters all go
-- into the pool, and on the server for a player whose request creates a pool character.
-- @param target [Player]
-- @param _limit [Number the value of the character_limit config]
-- @return [Number math.huge when the limit does not apply, otherwise nil]
function Gamemastery:GetCharacterLimit(target, _limit)
  if Gamemastery.has_gamemaster_role(target) or (SERVER and target.gm_pool_creation) then
    return math.huge
  end
end

--- Lets a character that goes into the pool be created in any faction: the whitelist and the
-- amount of characters its creator may have in the faction do not apply. That is every
-- character of a player of the `gamemaster` role, and a character a gamemaster creates for
-- the pool from the main menu.
-- @param target [Player]
-- @param data [Map creation data; on the client the extra data of the creation screen]
-- @return [Boolean true when the limits do not apply, otherwise nil]
function Gamemastery:PlayerCanBypassFactionCreationLimits(target, data)
  if Gamemastery.has_gamemaster_role(target) then
    return true
  end

  if istable(data) and data.gamemaster == true and Gamemastery.is_gamemaster(target) then
    return true
  end
end

--- Keeps a player in gamemaster mode from leaving noclip.
-- @param actor [Player]
-- @return [Boolean false while the player is in gamemaster mode, otherwise nil]
function Gamemastery:PlayerExitNoclip(actor)
  if Gamemastery.is_in_mode(actor) then
    return false
  end
end
