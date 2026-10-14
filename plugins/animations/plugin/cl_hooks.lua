--- Client side of the Animations plugin: the panel in the context menu that lists the
-- animations of the local player's model, and the crosshair being hidden during one.
-- The panel only sends requests: the animation itself, the movement lock and the third
-- person view all come from the server.

local scale_x = math.scale_x
local panel_color = Color(0, 0, 0, 100)

--- Adds the animations panel to the context menu, listing every animation the local player's model supports.
-- @param context_menu [Panel context menu the panel is parented to]
function Animations:ContextMenuCreated(context_menu)
  if !Theme.initialized() then return end

  local panel = vgui.Create('fl_base_panel', context_menu)
  panel:SetSize(math.scale_size(200, 224))
  panel:SetPos(scale_x(100), ScrH() * 0.7)
  panel:DockPadding(scale_x(4), math.scale(4), scale_x(4), math.scale(4))
  panel.Paint = function(pnl, w, h)
    draw.RoundedBox(0, 0, 0, w, h, panel_color)
  end

  local title = vgui.Create('DLabel', panel)
  title:SetText(t'ui.animations.title')
  title:SetFont(Theme.get_font('text_normal'))
  title:SetColor(color_white)
  title:SetContentAlignment(5)
  title:SizeToContents()
  title:Dock(TOP)

  local scroll = vgui.Create('DScrollPanel', panel)
  scroll:Dock(FILL)

  panel.previews = {}

  --- Refills the list with a button and model preview tooltip for each animation the
  -- player's model can play, in the order the animations were registered in. Clicking a
  -- button asks the server to start the animation, or to leave the one being played.
  function panel:rebuild()
    scroll:Clear()

    local previews = self.previews

    for i = 1, #previews do
      local preview = previews[i]

      if IsValid(preview) then
        preview:Remove()
      end
    end

    previews = {}
    self.previews = previews

    for k, v in ipairs(Animations:get_list()) do
      local sequences = Animations:get_sequences(PLAYER, v)

      if !sequences then continue end

      local line = vgui.Create('fl_button', scroll)
      line:Dock(TOP)
      line:set_text(t(v.name))
      line:set_text_offset(scale_x(4))
      line.animation = v.id
      line.DoClick = function(pnl)
        PLAYER:play_animation(pnl.animation)
      end

      local preview_back = vgui.Create('fl_base_panel')
      preview_back:SetSize(math.scale_size(150, 150))

      local preview_model = vgui.Create('DModelPanel', preview_back)
      preview_model:Dock(FILL)
      preview_model:SetModel(PLAYER:GetModel())
      preview_model.LayoutEntity = function(pnl, entity)
        pnl:RunAnimation()
      end

      if IsValid(preview_model.Entity) then
        preview_model.Entity:SetSequence(sequences.variants[1])
      end

      line:SetTooltipPanel(preview_back)

      previews[#previews + 1] = preview_back

      scroll:AddItem(line)
    end
  end

  Flux.animations_panel = panel
end

--- Rebuilds the animations panel so it matches the player's current model.
function Animations:OnContextMenuOpen()
  local panel = Flux.animations_panel

  if IsValid(panel) then
    panel:rebuild()
  end
end

--- Hides the crosshair while the local player is playing an animation.
-- @return [Boolean false while animating, nil otherwise]
function Animations:ShouldHUDPaintCrosshair()
  if PLAYER:get_nv('fl_animation') then
    return false
  end
end
