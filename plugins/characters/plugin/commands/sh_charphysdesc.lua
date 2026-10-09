--- Command that lets players change the physical description of their own character. Run
-- without text, it asks for the new description in a prompt.

CMD.name = 'CharPhysDesc'
CMD.description = 'command.charphysdesc.description'
CMD.syntax = 'command.charphysdesc.syntax'
CMD.category = 'permission.categories.character_management'
CMD.aliases = { 'physdesc', 'chardesc' }
CMD.no_console = true

--- Changes the description of the caller's character to the given text, or opens a prompt on
-- their client when no text is given. A caller without a character is told that they cannot
-- do this now.
-- @param actor [Player the player who ran the command]
-- @param ... [Vararg words of the new description, joined with spaces]
-- @see [Characters.change_desc]
function CMD:on_run(actor, ...)
  local new_desc = table.concat({ ... }, ' ')

  if new_desc == '' and actor:is_character_loaded() then
    Cable.send(actor, 'fl_character_desc_prompt')

    return
  end

  Characters.change_desc(actor, new_desc)
end
