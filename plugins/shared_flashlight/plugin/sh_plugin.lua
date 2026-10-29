--- Shared Flashlight replaces the engine flashlight, which only the player who holds it can
-- see, with an `fl_flashlight` entity. The entity is created on the server, parented to the
-- player and sent to every client, and each client draws a projected light from the eyes of
-- the owner, so the server, the owner and everyone around them agree on whether a flashlight
-- is on and where it shines.
--
-- The flashlight key still toggles it: the plugin's `PlayerCanSwitchFlashlight` handler turns
-- the light on or off through `Player:set_flashlight` and keeps the engine flashlight from
-- toggling. The state is read with `Player:is_flashlight_on` on both realms, and the entity
-- of a lit flashlight with `Player:get_flashlight`. The light goes out when the player dies,
-- spawns and leaves the server. The `PlayerFlashlightChanged` hook runs on the server after
-- every change.
--
-- The `shared_flashlight_enabled` config switches the plugin off, which leaves the engine
-- flashlight alone; `shared_flashlight_fov`, `shared_flashlight_distance`,
-- `shared_flashlight_brightness` and `shared_flashlight_shadows` shape the light on every
-- client. The `shared_flashlight_item` config names an item that a player needs to have
-- equipped to turn either flashlight on, while the Items plugin is loaded; the light goes out
-- when that item is unequipped.
-- @module [SharedFlashlight]

PLUGIN:set_global('SharedFlashlight')

--- Flashlight entities by their owner, filled on the client as the entities arrive. On the
-- server the entity is kept on the player instead, see `Player:get_flashlight`.
SharedFlashlight.lights = SharedFlashlight.lights or {}

--- Tells whether the plugin stands in for the engine flashlight.
-- @return [Boolean value of the `shared_flashlight_enabled` config]
function SharedFlashlight:is_enabled()
  return Config.get('shared_flashlight_enabled', true)
end

--- Checks whether a player has the item that the `shared_flashlight_item` config names
-- equipped, which they need to turn their flashlight on. Every player has it while the config
-- is empty or the Items plugin is not loaded.
-- @param target [Player]
-- @return [Boolean]
function SharedFlashlight:has_flashlight_item(target)
  local item_id = Config.get('shared_flashlight_item', '')

  if !Items or !isstring(item_id) or item_id == '' then return true end

  return (target:has_item_equipped(item_id))
end

require_relative 'sv_hooks'
