--- ItemRadio is the base class for radios: items that let the character who keeps one in
-- their hotbar speak and listen on a frequency.
-- A radio can be turned on and off and retuned through its item menu. A derived item may
-- set `frequency`, the frequency its instances are tuned to until a player changes it
-- (100.1 by default).
-- @module [ItemRadio]

class 'ItemRadio' extends 'ItemEquipable'

ItemRadio.name = 'item.radio.name'
ItemRadio.description = 'item.radio.description'
ItemRadio.weight = 0.2
ItemRadio.category = 'item.category.communication'
ItemRadio.model = 'models/gibs/shield_scanner_gib1.mdl'
ItemRadio.equip_slot = 'item.slot.communication'

ItemRadio:set_action_sound('on_toggle', 'buttons/button17.wav')
ItemRadio:set_action_sound('set_frequency', 'buttons/button18.wav')

ItemRadio:add_button('toggle', {
  get_name = function(item_obj) return item_obj:is_enabled() and 'item.option.disable' or 'item.option.enable' end,
  get_icon =
    function(item_obj) return item_obj:is_enabled() and 'icon16/lightning_delete.png' or 'icon16/lightning_add.png' end,
  callback = 'on_toggle'
})

ItemRadio:add_button('frequency', {
  name = 'item.option.frequency',
  icon = 'icon16/control_equalizer_blue.png',
  callback = 'change_frequency',
  on_show = function(item_obj)
    return item_obj:is_enabled()
  end
})

--- Checks whether the radio is turned on.
-- @return [Boolean whether the radio is enabled, true by default]
function ItemRadio:is_enabled()
  return self:get_data('enabled', true)
end

--- Turns the radio on or off.
-- @param actor [Player player toggling the radio]
function ItemRadio:on_toggle(actor)
  self:set_data('enabled', !self:is_enabled())
end

--- Returns the frequency the radio is tuned to.
-- @return [Number frequency, the item's default or 100.1 if it was never set]
function ItemRadio:get_frequency()
  return self:get_data('frequency', self.frequency or 100.1)
end

--- Tunes the radio to a frequency and plays the tuning sound.
-- @param frequency [Number new frequency]
function ItemRadio:set_frequency(frequency)
  self:set_data('frequency', frequency)
  self:play_sound('set_frequency')
end

--- Asks the player to enter a new frequency for the radio. Called on the server when the
-- frequency button of the item menu is pressed; the answer is checked by
-- `Communications.tune_radio` before the radio is retuned.
-- @param actor [Player player changing the frequency]
function ItemRadio:change_frequency(actor)
  if !SERVER then return end

  Communications.request_frequency(actor, self)
end
