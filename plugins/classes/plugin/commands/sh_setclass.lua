--- Staff command that sets the class of players within their faction.

CMD.name = 'SetClass'
CMD.description = 'command.setclass.description'
CMD.syntax = 'command.setclass.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 2
CMD.player_arg = 1
CMD.aliases = { 'plysetclass', 'charsetclass' }

--- Returns the translated command description with every registered class ID listed.
-- @return [String]
function CMD:get_description()
  local classes = {}

  for k, v in pairs(Classes.all()) do
    table.insert(classes, k)
  end

  table.sort(classes)

  return t(self.description, { classes = table.concat(classes, ', ') })
end

--- Puts every target whose faction has the class found by name into that class, regardless
-- of its limit and of the class change cooldown, and notifies the targets and staff. The
-- caller is told when none of the targets is in the faction of the class.
-- @param actor [Player the player who ran the command, an invalid entity for the console]
-- @param targets [List<Player> players matched by the first command argument]
-- @param name [String class ID or name, or a part of either]
-- @param strict=nil [String any extra argument makes the class lookup exact]
function CMD:on_run(actor, targets, name, strict)
  local class_table = Classes.find(name, (strict and true) or false)

  if !class_table then
    Flux.Player:notify(actor, 'error.class.invalid', { class = name })

    return
  end

  local changed = {}

  for k, v in ipairs(targets) do
    if v:set_class(class_table.class_id) then
      v:notify('notification.class_changed', { class = class_table.name }, class_table:get_color())

      table.insert(changed, v)
    end
  end

  if #changed == 0 then
    Flux.Player:notify(actor, 'error.class.wrong_faction', { class = class_table.name })

    return
  end

  self:notify_staff('command.setclass.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(changed),
    class = class_table.name
  })
end
