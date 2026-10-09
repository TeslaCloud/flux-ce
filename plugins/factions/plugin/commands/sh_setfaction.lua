--- Staff command that moves players into another faction.

CMD.name = 'SetFaction'
CMD.description = 'command.setfaction.description'
CMD.syntax = 'command.setfaction.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 2
CMD.player_arg = 1
CMD.aliases = { 'plytransfer', 'charsetfaction', 'chartransfer' }

--- Returns the translated command description with every registered faction ID listed.
-- @return [String]
function CMD:get_description()
  local factions = {}

  for k, v in pairs(Factions.all()) do
    table.insert(factions, k)
  end

  return t(self.description, { factions = table.concat(factions, ', ') })
end

--- Moves every target into the faction found by name and notifies the targets and staff.
-- Targets without a character are skipped, and so are those whose transfer is refused by
-- `Factions.can_transfer`; the actor is told the reason of every refusal.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
-- @param name [String faction ID or name, or a part of either]
-- @param strict=nil [String any extra argument makes the faction lookup exact]
function CMD:on_run(actor, targets, name, strict)
  local faction_table = Factions.find(name, (strict and true) or false)

  if !faction_table then
    Flux.Player:notify(actor, 'error.faction.invalid', { faction = name })

    return
  end

  local transferred = {}

  for k, v in ipairs(targets) do
    if v:IsBot() or v:is_character_loaded() then
      local allowed, reason, arguments = Factions.can_transfer(v, faction_table)

      if allowed then
        table.insert(transferred, v)
      else
        Flux.Player:notify(actor, reason, arguments)
      end
    else
      Flux.Player:notify(actor, 'error.faction.no_character', { target = v:name() })
    end
  end

  if #transferred == 0 then return end

  self:notify_staff('command.setfaction.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(transferred),
    faction = faction_table.name
  })

  for k, v in ipairs(transferred) do
    v:set_faction(faction_table.faction_id)
    v:notify('notification.faction_changed', { faction = faction_table.name }, faction_table.color)
  end
end
