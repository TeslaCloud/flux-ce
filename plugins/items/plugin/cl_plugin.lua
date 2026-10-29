--- Client side of the Items plugin that is not a hook handler: the hotbar of the local
-- player, which the context menu shows and the slot binds pop up for a moment.

local IsValid = IsValid
local math_scale = math.scale

--- Creates a panel for the local player's hotbar at the bottom of the screen.
-- @return [Panel the fl_inventory panel]
function Items:create_hotbar()
  local hotbar = PLAYER:get_inventory('hotbar'):create_panel()
  hotbar:set_slot_size(math_scale(80))
  hotbar:set_slot_padding(math_scale(8))
  hotbar:draw_inventory_slots(true)
  hotbar:set_title()
  hotbar:SizeToContents()
  hotbar:SetPos(ScrW() * 0.5 - hotbar:GetWide() * 0.5, ScrH() - hotbar:GetTall() - math_scale(16))

  return hotbar
end

--- Shows the hotbar for a short time, fading it out gradually.
-- Makes the hotbar fully opaque again if it is on the screen already.
function Items:popup_hotbar()
  if !IsValid(PLAYER.hotbar) then
    PLAYER.hotbar = self:create_hotbar()
    PLAYER.hotbar:rebuild()

    timer.Create('fl_hotbar_popup', 0.05, 0, function()
      local hotbar = PLAYER.hotbar

      if IsValid(hotbar) then
        local alpha = hotbar:GetAlpha()
        hotbar:SetAlpha(alpha - 5)

        if alpha <= 50 then
          hotbar:safe_remove()
        end
      else
        timer.Destroy('fl_hotbar_popup')
      end
    end)
  else
    PLAYER.hotbar:SetAlpha(255)
  end
end
