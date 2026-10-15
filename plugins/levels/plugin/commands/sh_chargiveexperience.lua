--- The CharGiveExperience command gives experience to the targeted players' characters. A
-- negative amount takes experience away, which can lower their level. The level cap of the
-- server level does not bind it, so the experience can raise characters above the cap, but the
-- level floor does: a character that falls below the floor is raised back to it, keeping its
-- experience.

CMD.name = 'CharGiveExperience'
CMD.description = 'command.chargiveexperience.description'
CMD.syntax = 'command.chargiveexperience.syntax'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 2
CMD.player_arg = 1
CMD.aliases = { 'givexp', 'giveexperience', 'chargivexp' }

--- Gives the experience to every target that has an active character, past the level cap
-- if it is enough, raises those that fell below the level floor back to it, then notifies the
-- targets and staff.
-- @param actor [Player the player who ran the command, or an invalid entity for the console]
-- @param targets [List<Player> players matched by the first command argument]
-- @param amount [String experience to give, parsed with tonumber and rounded; negative to
--   take experience away]
function CMD:on_run(actor, targets, amount)
  amount = tonumber(amount)

  if amount and amount == amount then
    amount = math.Round(amount)
  end

  if !amount or amount != amount or amount == 0 then
    Flux.Player:notify(actor, 'error.invalid_value')

    return
  end

  local taken = amount < 0
  local shown_amount = math.abs(amount)
  local changed = {}

  for k, v in ipairs(targets) do
    if v:is_character_loaded() then
      v:give_experience(amount, 'command', true)
      v:notify(taken and 'notification.levels.experience_taken' or 'notification.levels.experience_given', {
        amount = shown_amount
      })

      Levels.raise_to_floor(v)

      table.insert(changed, v)
    end
  end

  if #changed == 0 then
    Flux.Player:notify(actor, 'error.levels.no_character', { target = util.player_list_to_string(targets) })

    return
  end

  self:notify_staff('command.chargiveexperience.'..(taken and 'message_taken' or 'message'), {
    player = get_player_name(actor),
    target = util.player_list_to_string(changed),
    amount = shown_amount
  })
end
