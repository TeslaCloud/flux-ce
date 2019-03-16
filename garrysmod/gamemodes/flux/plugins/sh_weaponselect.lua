PLUGIN:set_name('Weapon Selector')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Adds custom weapon selector for use with Flux.')

if SERVER then
  concommand.Add('selectweapon', function(player, command, arguments)
    local weapon = player:GetWeapons()[tonumber(arguments[1]) or 1]

    if IsValid(weapon) then
      player:SelectWeapon(weapon:GetClass())
    end
  end)

  return
end

PLUGIN.weapon_index = PLUGIN.weapon_index or 1
PLUGIN.is_open = PLUGIN.is_open or false
PLUGIN.open_time = PLUGIN.open_time or 0
PLUGIN.cur_alpha = PLUGIN.cur_alpha or 255
PLUGIN.display = PLUGIN.display or {}
PLUGIN.index_offset = PLUGIN.index_offset or nil

local function relative_clamp(n, min, max)
  if n > max then
    return relative_clamp(n - max, min, max)
  elseif n < min then
    return relative_clamp(max - n, min, max)
  end

  return n
end

local function safe_index(tab, idx)
  return tab[relative_clamp(idx, 1, #tab)]
end

function PLUGIN:HUDShouldDraw(element)
  if element == 'CHudWeaponSelection' then
    return false
  end
end

function PLUGIN:HUDPaint()
  if !IsValid(PLAYER) then return end

  if self.is_open then
    if self.index_offset and self.index_offset != 0 then
      local dir = (self.index_offset == math.abs(self.index_offset)) -- true = down, false = up
      local frame_time = FrameTime() * 16
      local targets = {}

      if !self.display[1].target then
        local idx = self.weapon_index - ((dir and self.index_offset - 1) or self.index_offset + 1)
        targets = self:make_display(idx, true)
      end

      for k, v in ipairs(self.display) do
        if !v.target then
          local next = safe_index(targets, (dir and k - 1) or k + 1)

          -- Make first and last weapons look nicer when scrolling.
          if dir and k == 1 then
            v.y = targets[5].y + 50
            v.scale = v.scale * 0.5
          elseif !dir and k == 5 then
            v.y = targets[1].y - 50
            v.scale = v.scale * 0.5
          end

          v.target = next.y
          v.scale_target = next.scale
          v.weapon = next.weapon

          if k == 3 + ((dir and 1) or -1) then
            v.highlight = true
          end
        end

        if math.abs(v.y - v.target) < 1 then
          self.index_offset = (dir and self.index_offset - 1) or self.index_offset + 1
          self:make_display(self.weapon_index - self.index_offset)

          break
        end

        local abs_offset = math.Clamp(math.abs(self.index_offset), 1, 100)

        self.display[k].y = Lerp(frame_time * abs_offset, v.y, v.target)
        self.display[k].scale = Lerp(frame_time * abs_offset, v.scale, v.scale_target)

        if self.display[k + ((dir and 1) or -1)] and self.display[k + ((dir and 1) or -1)].highlight then
          self.display[k].highlight = false
        end
      end
    end

    local x, y = ScrW() - 306, ScrH() * 0.5 - 84, 200
    local w, h = 200, 186

    render.SetScissorRect(x, y, x + w, y + h, true)

    draw.RoundedBox(0, x, y, w, h, Color(40, 40, 40, 100 * (self.cur_alpha / 255)))

    for k, v in ipairs(self.display) do
      local color = Color(255, 255, 255, self.cur_alpha * v.scale / 1.3)

      if v.highlight then
        color = Theme.get_color('accent')
      end

      surface.draw_text_scaled((IsValid(v.weapon) and v.weapon:GetPrintName():utf8upper()) or 'UNKNOWN WEAPON', Theme.get_font('text_normal_large'), v.x, v.y, v.scale, color)
    end

    render.SetScissorRect(0, 0, 0, 0, false)
  end
end

function PLUGIN:Think()
  if self.is_open then
    if CurTime() - self.open_time > 5 then
      self.cur_alpha = math.Clamp(self.cur_alpha - 2, 0, 255)

      if self.cur_alpha == 0 then
        self.is_open = false
      end
    else
      self.cur_alpha = Lerp(FrameTime() * 16, self.cur_alpha, 255)
    end
  end
end

do
  local prev_index = 0

  function PLUGIN:PlayerBindPress(player, bind, pressed)
    local weapon = player:GetActiveWeapon()

    if !player:InVehicle() then
      if hook.run('ShouldOpenWepselect', player) != false then
        local weapon_count = table.Count(player:GetWeapons())
        local old_index = self.weapon_index
        bind = bind:lower()

        if bind:find('invprev') and pressed then
          self.weapon_index = relative_clamp(self.weapon_index - 1, 1, weapon_count)

          Plugin.call('OnWeaponIndexChange', old_index, self.weapon_index)

          return true
        elseif bind:find('invnext') and pressed then
          self.weapon_index = relative_clamp(self.weapon_index + 1, 1, weapon_count)

          Plugin.call('OnWeaponIndexChange', old_index, self.weapon_index)

          return true
        elseif bind:find('slot') and pressed then
          local index = tonumber(bind:sub(5, bind:len())) or 1
          local classic_scroll = false

          if index == prev_index or (index == 2 and prev_index == 1) or (index == 1 and prev_index == 2) then
            if index == 1 then
              self.weapon_index = self.weapon_index - 1
            else
              self.weapon_index = self.weapon_index + 1
            end

            self.weapon_index = relative_clamp(self.weapon_index, 1, weapon_count)

            classic_scroll = true
          end

          prev_index = index

          if !classic_scroll then
            index = relative_clamp(index, 1, weapon_count)

            self.weapon_index = index
          else
            index = self.weapon_index
          end

          Plugin.call('OnWeaponIndexChange', old_index, index)

          return true
        elseif bind:find('attack') and self.is_open and pressed then
          RunConsoleCommand('selectweapon', self.weapon_index)

          Plugin.call('OnWeaponSelected', self.weapon_index)

          return true
        end
      end
    end
  end
end

function PLUGIN:OnWeaponIndexChange(old_index, index)
  self.is_open = true
  self.open_time = CurTime()

  if #self.display == 0 then
    self:make_display(index)
  else
    self.index_offset = index - old_index

    local weapon_count = #PLAYER:GetWeapons()

    if math.abs(self.index_offset) == (weapon_count - 1) then
      self.index_offset = -(self.index_offset / (weapon_count - 1))
    end
  end
end

function PLUGIN:OnWeaponSelected(index)
  self.is_open = false
  self.cur_alpha = 0
  self.display = {}
end

function PLUGIN:make_display(index, tab)
  local client_weapons = PLAYER:GetWeapons()
  local count = table.Count(client_weapons)
  local offsety = 32
  local result = {}

  for i = -2, 2 do
    local scale = 1 - math.abs(i * 0.25)

    table.insert(result, {
      weapon = safe_index(client_weapons, index + i),
      scale = scale,
      x = ScrW() - 300,
      y = ScrH() * 0.5 - 90 + offsety - 36 * scale * 0.5,
      highlight = (i == 0)
    })

    offsety = offsety + 32
  end

  if tab then
    return result
  else
    self.display = result
  end
end
