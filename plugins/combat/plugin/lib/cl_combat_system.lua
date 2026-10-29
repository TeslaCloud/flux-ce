--- Client side of the turn based combat: the notification of whose turn it is and the combat
-- messages in the chat.

if !CombatSystem then
  PLUGIN:set_global('CombatSystem')
end

--- Shows a short centered notification, replacing the previous one.
-- @param text [String text to display]
function CombatSystem:create_notify(text)
  if IsValid(Flux.combat_notify) then
    Flux.combat_notify:safe_remove()
  end

  local notify = vgui.Create('DNotify')
  notify:SetLife(2)

  local label = vgui.Create('DLabel', notify)
  label:Dock(FILL)
  label:SetText(text)
  label:SetTextColor(color_white)
  label:SetFont(Theme.get_font('main_menu_title'))
  label:SizeToContents()

  notify:AddItem(label)
  notify:SetSize(label:GetSize())
  notify:SetPos(ScrW() * 0.5 - notify:GetWide() * 0.5, ScrH() * 0.2)

  Flux.combat_notify = notify
end

--- Prints a combat message to chat, colored by whether it is good, bad or neutral for the local player.
-- @param text [String language phrase of the message]
-- @param arguments=nil [Table phrase arguments, entities are replaced with their names]
function CombatSystem:create_message(text, arguments)
  local color = Color('lightgray')

  if arguments then
    if text:find('success') and arguments.attacker == PLAYER
    or text:find('fail') and arguments.target == PLAYER then
      color = Color('aqua')
    elseif text:find('success') and arguments.target == PLAYER
    or text:find('fail') and arguments.attacker == PLAYER then
      color = Color('orangered')
    elseif arguments.entity == PLAYER then
      color = Color('gold')
    end

    for k, v in pairs(arguments) do
      if isstring(v) then
        arguments[k] = t(v)
      elseif isentity(v) and IsValid(v) then
        arguments[k] = v:IsPlayer() and v:name() or v:get_name()
      end
    end
  end

  chat.AddText(16, color, t(text, arguments))
end
