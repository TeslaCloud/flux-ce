--- The entity that represents an item instance lying in the world.
-- `Item.spawn` creates it and ties the instance to it with `set_item`, which gives the
-- entity the model, skin and color of the item. Pressing the use key on it briefly opens
-- the menu of the item for the player; holding the key for half a second takes the item.
-- On the client it draws the name and the description of the item as its target ID.

AddCSLuaFile()

ENT.Type = 'anim'
ENT.PrintName = 'Item'
ENT.Category = 'Flux'
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

if SERVER then
  --- Sets up the physics and the use type of the item entity.
  function ENT:Initialize()
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetUseType(ONOFF_USE)

    local phys_obj = self:GetPhysicsObject()

    if IsValid(phys_obj) then
      phys_obj:EnableMotion(true)
      phys_obj:Wake()
    end
  end

  --- Tracks how long the player holds the use key on the item.
  -- Releasing the key in under half a second runs the 'PlayerUseItemEntity' hook.
  -- @param activator [Entity the entity that pressed the use key, normally a Player]
  -- @param caller [Entity]
  -- @param use_type [Number USE_ enumerator]
  -- @param value [Number]
  function ENT:Use(activator, caller, use_type, value)
    local last_activator = self:get_nv('last_activator')

    -- prevent minge-grabbing glitch
    if IsValid(last_activator) and last_activator != activator then return end

    local hold_start = activator:get_nv('hold_start')

    if use_type == USE_ON then
      if !hold_start then
        activator:set_nv('hold_start', CurTime())
        activator:set_nv('hold_entity', self)
        self:set_nv('last_activator', activator)
      end
    elseif use_type == USE_OFF then
      if !hold_start then return end

      if CurTime() - hold_start < 0.5 then
        if IsValid(caller) and caller:IsPlayer() then
          if self.item then
            --- Called on the server when a player briefly presses the use key on an item
            -- entity, releasing it in under half a second. Holding the key longer takes
            -- the item instead and does not run this hook. The Items plugin handles it
            -- by telling the client of the player to open the menu of the item.
            -- @param activator [Player The player who used the entity]
            -- @param entity [Entity The `fl_item` entity]
            -- @param item_obj [Item The item instance tied to the entity]
            hook.Run('PlayerUseItemEntity', caller, self, self.item)
          else
            Flux.dev_print('A player attempted to use an item entity without an item object tied to it!')
          end
        end
      end

      activator:set_nv('hold_start', false)
      activator:set_nv('hold_entity', false)
      self:set_nv('last_activator', false)
    end
  end

  --- Makes the player take the item once they have held the use key on it for half a second.
  function ENT:Think()
    local last_activator = self:get_nv('last_activator')

    if !IsValid(last_activator) then return end

    local hold_start = last_activator:get_nv('hold_start')

    if hold_start and CurTime() - hold_start > 0.5 then
      if self.item then
        self.item:do_menu_action('on_take', last_activator)
      end

      last_activator:set_nv('hold_start', false)
      last_activator:set_nv('hold_entity', false)
      self:set_nv('last_activator', false)
    end
  end

  --- Ties an item instance to the entity, applying its model, skin and color,
  -- and tells all clients about it.
  -- @param item_obj [Item]
  -- @return [Boolean false if no item was given, nothing otherwise]
  function ENT:set_item(item_obj)
    if !item_obj then return false end

    --- Called on the server before an item instance is tied to an item entity, while the
    -- entity still has the model, skin and color it had before.
    -- @param entity [Entity The `fl_item` entity]
    -- @param item_obj [Item The item instance that is about to be set]
    hook.Run('PreEntityItemSet', self, item_obj)

    self:SetModel(item_obj:get_model())
    self:SetSkin(item_obj:get_skin())
    self:SetColor(item_obj:get_color())

    self.item = item_obj

    Item.network_entity_data(nil, self)

    --- Called on the server after an item instance has been tied to an item entity.
    -- The entity has the model, skin and color of the item by now, and the clients have
    -- been told which item it represents. When the item is being spawned by `Item.spawn`,
    -- the entity itself has not been positioned or spawned yet.
    -- @param entity [Entity The `fl_item` entity]
    -- @param item_obj [Item The item instance that has been set]
    hook.Run('OnEntityItemSet', self, item_obj)
  end
else
  --- Draws the model of the item.
  function ENT:Draw()
    self:DrawModel()
  end

  --- Draws the name and the description of the item when the local player looks at it up close.
  -- Requests the item from the server and draws a loading cog if it is not known yet.
  -- @param x [Number screen position]
  -- @param y [Number screen position]
  -- @param distance [Number distance between the local player and the entity]
  function ENT:DrawTargetID(x, y, distance)
    if distance > 150 then return end

    local text = 'ERROR'
    local desc = 'Meow probably broke it again'
    local alpha = self.alpha or 255

    if distance > 100 then
      local d = distance - 100
      alpha = math.Clamp(255 * (50 - d) / 50, 0, 255)
    end

    local col = Color(255, 255, 255, alpha)
    local col2 = Color(0, 0, 0, alpha)

    if self.item then
      --- Called on the client every frame before the target ID of an item entity is drawn,
      -- while the local player looks at the entity from at most 150 units away.
      -- @param entity [Entity The `fl_item` entity]
      -- @param item_obj [Item The item instance tied to the entity]
      -- @param x [Number Screen x of the center of the target ID]
      -- @param y [Number Screen y of the top of the target ID]
      -- @param alpha [Number Opacity of the target ID from 0 to 255; it fades out past
      --   100 units]
      -- @param distance [Number Distance between the local player and the entity]
      -- @return [Boolean Return false to prevent the name and the description from being
      --   drawn; `PostDrawItemTargetID` is not run then]
      if hook.Run('PreDrawItemTargetID', self, self.item, x, y, alpha, distance) == false then
        return
      end

      text = t(self.item:get_name())
      desc = t(self.item:get_description())
    else
      if !self.data_requested then
        Cable.send('fl_items_data_request', self:EntIndex())
        self.data_requested = true
      end

      Flux.draw_rotating_cog(x, y - 48, 48, 48, Color(255, 255, 255))

      return
    end

    local name_font = Theme.get_font('tooltip_large')
    local desc_font = Theme.get_font('tooltip_small')
    local width, height = util.text_size(text, name_font)
    local max_width = width
    local desc_height = 0
    local wrapped = util.wrap_text(desc, desc_font, ScrW() * 0.33, 0)

    for k, v in pairs(wrapped) do
      local w, h = util.text_size(v, desc_font)

      desc_height = desc_height + h

      if w > max_width then
        max_width = w
      end
    end

    local box_x, box_y = x - max_width * 0.5 - 8, y - 8
    local box_width, box_height = max_width + 16, height + desc_height + 16
    local accent_color = Theme.get_color('accent'):alpha(200)
    local ent_pos = self:GetPos():ToScreen()
    local anim_id = 'itemid_gradient_'..self.item.instance_id

    Flux.register_animation(anim_id, box_x - max_width, nil, FrameTime() * 8)

    render.SetScissorRect(box_x, box_y, box_x + box_width, box_y + box_height, true)
      Flux.draw_animation(anim_id, alpha > 150 and box_x or box_x - max_width, box_y, function(x, y)
        draw.textured_rect(
          Theme.get_material('gradient'),
          alpha > 240 and box_x or x,
          y,
          box_width,
          box_height,
          accent_color
        )
      end)
    render.SetScissorRect(0, 0, 0, 0, false)

    if alpha > 100 then
      draw.line(box_x, y + height + desc_height + 8, ent_pos.x, ent_pos.y, accent_color)
    end

    draw.SimpleTextOutlined(text, name_font, x - width * 0.5, y, col, nil, nil, 1, col2)

    y = y + 26

    for k, v in pairs(wrapped) do
      local w, h = util.text_size(v, desc_font)

      draw.SimpleTextOutlined(v, desc_font, x - w * 0.5, y, col, nil, nil, 1, col2)

      y = y + h
    end

    --- Called on the client every frame after the name and the description of an item
    -- entity have been drawn as its target ID. Handlers can draw more lines below them.
    -- @param entity [Entity The `fl_item` entity]
    -- @param item_obj [Item The item instance tied to the entity]
    -- @param x [Number Screen x of the center of the target ID]
    -- @param y [Number Screen y right below the last line of the description]
    -- @param alpha [Number Opacity of the target ID from 0 to 255]
    -- @param distance [Number Distance between the local player and the entity]
    hook.Run('PostDrawItemTargetID', self, self.item, x, y, alpha, distance)
  end
end
