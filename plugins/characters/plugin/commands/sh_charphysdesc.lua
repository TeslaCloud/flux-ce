--- Command that lets players change the physical description of their own character. Run
-- without text, it asks for the new description in a prompt.

CMD.name = 'CharPhysDesc'
CMD.description = 'command.charphysdesc.description'
CMD.syntax = 'command.charphysdesc.syntax'
CMD.category = 'permission.categories.character_management'
CMD.arg_types = { 'text' }
CMD.aliases = { 'physdesc', 'chardesc' }
CMD.no_console = true

--- Changes the description of the caller's character to the given text, or opens a prompt on
-- their client when no text is given. A caller without a character is told that they cannot
-- do this now.
-- @param actor [Player the player who ran the command]
-- @param new_desc=nil [String the new description, as it was typed]
-- @see [Characters.change_desc]
function CMD:on_run(actor, new_desc)
  new_desc = new_desc or ''

  if new_desc == '' and actor:is_character_loaded() then
    Cable.send(actor, 'fl_character_desc_prompt')

    return
  end

  Characters.change_desc(actor, new_desc)
end
