--- The CharAttributeBoostClear command removes the boosts and leveling multipliers from the
-- characters of the targeted players: those of one attribute, or all of them if no
-- attribute is given. Allowed for moderators by default.

CMD.name = 'CharAttributeBoostClear'
CMD.description = 'command.charattributeboostclear.description'
CMD.syntax = 'command.charattributeboostclear.syntax'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 1
CMD.player_arg = 1
CMD.aliases = { 'attboostclear', 'clearattboosts', 'charattboostclear' }

--- Returns the translated command description with every registered attribute ID listed.
-- @return [String]
function CMD:get_description()
  return t(self.description, { attributes = table.concat(table.GetKeys(Attributes.get_stored()), ', ') })
end

--- Removes the boosts and multipliers of one attribute, or of every attribute, from every
-- target, then notifies staff and the targets that lost any.
-- @param actor [Player the player who ran the command, or an invalid entity for the console]
-- @param targets [List<Player> players matched by the first command argument]
-- @param attribute_id=nil [String attribute to clear, normalized with to_id; every attribute
--   if omitted]
function CMD:on_run(actor, targets, attribute_id)
  local attribute

  if attribute_id then
    attribute_id = attribute_id:to_id()
    attribute = Attributes.find(attribute_id)

    if !attribute then
      Flux.Player:notify(actor, 'error.attribute_not_valid', { attribute = attribute_id })

      return
    end
  end

  for k, v in ipairs(targets) do
    local removed = v:remove_attribute_boosts(attribute_id) + v:remove_attribute_multipliers(attribute_id)

    if removed > 0 then
      v:notify(attribute and 'notification.attribute.boosts_cleared' or 'notification.attribute.boosts_cleared_all', {
        attribute = attribute and attribute.name
      })
    end
  end

  self:notify_staff('command.charattributeboostclear.'..(attribute and 'message' or 'message_all'), {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets),
    attribute = attribute and attribute.name
  })
end
