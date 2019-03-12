if !font then util.include 'cl_font.lua' end
if !Flux.Lang then util.include 'sh_lang.lua' end

library 'Flux::Bars'

local stored = Flux.Bars.stored or {}
local sorted = Flux.Bars.sorted or {}
Flux.Bars.stored = stored
Flux.Bars.sorted = sorted

-- Some fail-safety variables.
Flux.Bars.default_x = 8
Flux.Bars.default_y = 8
Flux.Bars.default_w = Font.scale(312)
Flux.Bars.default_h = 18
Flux.Bars.default_spacing = 6

function Flux.Bars:register(id, data, force)
  if !data then return end

  force = force or Flux.development

  if stored[id] and !force then
    return stored[id]
  end

  stored[id] = {
    id = id,
    text = data.text or '',
    color = data.color or Color(200, 90, 90),
    max_value = data.max_value or 100,
    hinder_color = data.hinder_color or Color(255, 0, 0),
    hinder_text = data.hinder_text or '',
    display = data.display or 100,
    min_display = data.min_display or 0,
    hinder_display = data.hinder_display or false,
    value = data.value or 0,
    hinder_value = data.hinder_value or 0,
    x = data.x or self.default_x,
    y = data.y or self.default_y,
    width = data.width or self.default_w,
    height = data.height or self.default_h,
    corner_radius = data.corner_radius or 0,
    priority = data.priority or table.Count(stored),
    type = data.type or BAR_TOP,
    font = data.font or 'text_bar',
    spacing = data.spacing or self.default_spacing,
    text_offset = data.text_offset or 1,
    callback = data.callback
  }

  hook.run('OnBarRegistered', stored[id], id, force)

  return stored[id]
end

function Flux.Bars:get(id)
  if stored[id] then
    return stored[id]
  end

  return false
end

function Flux.Bars:set_value(id, new_value)
  local bar = self:get(id)

  if bar then
    Theme.call('PreBarValueSet', bar, bar.value, new_value)

    if bar.value != new_value then
      if bar.hinder_display and bar.hinder_value then
        bar.value = math.Clamp(new_value, 0, bar.max_value - bar.hinder_value + 2)
      end

      bar.interpolated = util.cubic_ease_in_out_t(150, bar.value, new_value)
      bar.value = math.Clamp(new_value, 0, bar.max_value)
    end
  end
end

function Flux.Bars:hinder_value(id, new_value)
  local bar = self:get(id)

  if bar then
    Theme.call('PreBarHinderValueSet', bar, bar.hinder_value, new_value)

    if bar.value != new_value then
      bar.hinder_value = math.Clamp(new_value, 0, bar.max_value)
    end
  end
end

function Flux.Bars:prioritize()
  sorted = {}

  for k, v in pairs(stored) do
    if !hook.run('ShouldDrawBar', v) then
      continue
    end

    hook.run('PreBarPrioritized', v)

    sorted[v.priority] = sorted[v.priority] or {}

    if v.type == BAR_TOP then
      table.insert(sorted[v.priority], v.id)
    end
  end

  return sorted
end

function Flux.Bars:position()
  self:prioritize()

  local last_y = self.default_y

  for priority, ids in pairs(sorted) do
    for k, v in pairs(ids) do
      local bar = self:get(v)

      if bar and bar.type == BAR_TOP then
        local offX, offY = hook.run('AdjustBarPos', bar)
        offX = offX or 0
        offY = offY or 0

        bar.y = last_y + offY
        bar.x = bar.x + offX
        last_y = last_y + bar.height + bar.spacing
      end
    end
  end

end

function Flux.Bars:draw(id)
  local bar_info = self:get(id)

  if bar_info then
    hook.run('PreDrawBar', bar_info)
    Theme.call('PreDrawBar', bar_info)

    if !hook.run('ShouldDrawBar', bar_info) then
      return
    end

    Theme.call('DrawBarBackground', bar_info)

    if hook.run('ShouldFillBar', bar_info) or bar_info.value != 0 then
      Theme.call('DrawBarFill', bar_info)
    end

    if bar_info.hinder_display and bar_info.hinder_display <= bar_info.hinder_value then
      Theme.call('DrawBarHindrance', bar_info)
    end

    Theme.call('DrawBarTexts', bar_info)

    hook.run('PostDrawBar', bar_info)
    Theme.call('PostDrawBar', bar_info)
  end
end

function Flux.Bars:DrawTopBars()
  for priority, ids in pairs(sorted) do
    for k, v in ipairs(ids) do
      self:draw(v)
    end
  end
end

function Flux.Bars:adjust(id, data)
  local bar = self:get(id)

  if bar then
    table.merge(bar, data)
  end
end

do
  local Bars = {}

  function Bars:LazyTick()
    if IsValid(PLAYER) then
      Flux.Bars:position()

      for k, v in pairs(stored) do
        if v.callback then
          Flux.Bars:set_value(v.id, v.callback(stored[k]))
        end

        hook.run('AdjustBarInfo', k, stored[k])
      end
    end
  end

  function Bars:PreDrawBar(bar)
    bar.cur_i = bar.cur_i or 1

    bar.real_fill_width = bar.width * (bar.value / bar.max_value)

    if bar.interpolated == nil then
      bar.fill_width = bar.real_fill_width
    else
      if bar.cur_i > 150 then
        bar.interpolated = nil
        bar.cur_i = 1
      else
        bar.fill_width = bar.width * (bar.interpolated[math.Round(bar.cur_i)] / bar.max_value)
        bar.cur_i = bar.cur_i + math.Clamp(math.Round(1 * (FrameTime() / 0.006)), 1, 10)
      end
    end

    bar.text = string.utf8upper(bar.text)
    bar.hinder_text = string.utf8upper(bar.hinder_text)
  end

  function Bars:ShouldDrawBar(bar)
    if bar.display < bar.value or bar.min_display >= bar.value then
      return false
    end

    return true
  end

  Plugin.add_hooks('FLBarHooks', Bars)

  Flux.Bars:register('respawn', {
    text = t'bar_text.respawn',
    color = Color(50, 200, 50),
    max_value = 100,
    x = ScrW() * 0.5 - Flux.Bars.default_w * 0.5,
    y = ScrH() * 0.5 - 8,
    text_offset = 1,
    height = 16,
    type = BAR_MANUAL
  })
end
