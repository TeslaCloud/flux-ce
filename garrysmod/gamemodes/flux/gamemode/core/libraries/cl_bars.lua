--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]if (!font) then
  util.Include("cl_font.lua")
end

library.New("bars", fl)

local stored = fl.bars.stored or {}
local sorted = fl.bars.sorted or {}
fl.bars.stored = stored
fl.bars.sorted = sorted

-- Some fail-safety variables.
fl.bars.defaultX = 8
fl.bars.defaultY = 8
fl.bars.defaultW = font.Scale(312)
fl.bars.defaultH = 18
fl.bars.defaultSpacing = 6

function fl.bars:Register(id, data, force)
  if (!data) then return end

  force = force or fl.Devmode

  if (stored[id] and !force) then
    return stored[id]
  end

  stored[id] = {
    id = id,
    text = data.text or "",
    color = data.color or Color(200, 90, 90),
    maxValue = data.maxValue or 100,
    hinderColor = data.hinderColor or Color(255, 0, 0),
    hinderText = data.hinderText or "",
    display = data.display or 100,
    minDisplay = data.minDisplay or 0,
    hinderDisplay = data.hinderDisplay or false,
    value = data.value or 0,
    hinderValue = data.hinderValue or 0,
    x = data.x or self.defaultX,
    y = data.y or self.defaultY,
    width = data.width or self.defaultW,
    height = data.height or self.defaultH,
    cornerRadius = data.cornerRadius or 0,
    priority = data.priority or table.Count(stored),
    type = data.type or BAR_TOP,
    font = data.font or "Text_Bar",
    spacing = data.spacing or self.defaultSpacing,
    textOffset = data.textOffset or 1,
    callback = data.callback
  }

  hook.Run("OnBarRegistered", stored[id], id, force)

  return stored[id]
end

function fl.bars:Get(id)
  if (stored[id]) then
    return stored[id]
  end

  return false
end

function fl.bars:SetValue(id, newValue)
  local bar = self:Get(id)

  if (bar) then
    theme.Call("PreBarValueSet", bar, bar.value, newValue)

    if (bar.value != newValue) then
      if (bar.hinderDisplay and bar.hinderValue) then
        bar.value = math.Clamp(newValue, 0, bar.maxValue - bar.hinderValue + 2)
      end

      bar.interpolated = util.CubicEaseInOutTable(150, bar.value, newValue)
      bar.value = math.Clamp(newValue, 0, bar.maxValue)
    end
  end
end

function fl.bars:HinderValue(id, newValue)
  local bar = self:Get(id)

  if (bar) then
    theme.Call("PreBarHinderValueSet", bar, bar.hinderValue, newValue)

    if (bar.value != newValue) then
      bar.hinderValue = math.Clamp(newValue, 0, bar.maxValue)
    end
  end
end

function fl.bars:Prioritize()
  sorted = {}

  for k, v in pairs(stored) do
    if (!hook.Run("ShouldDrawBar", v)) then
      continue
    end

    hook.Run("PreBarPrioritized", v)

    sorted[v.priority] = sorted[v.priority] or {}

    if (v.type == BAR_TOP) then
      table.insert(sorted[v.priority], v.id)
    end
  end

  return sorted
end

function fl.bars:Position()
  self:Prioritize()

  local lastY = self.defaultY
  local lastX = self.defaultX

  for priority, ids in pairs(sorted) do
    for k, v in pairs(ids) do
      local bar = self:Get(v)

      if (bar and bar.type == BAR_TOP) then
        local offX, offY = hook.Run("AdjustBarPos", bar)
        offX = offX or 0
        offY = offY or 0

        bar.y = lastY + offY
        bar.x = bar.x + offX
        lastY = lastY + bar.height + bar.spacing
      end
    end
  end

end

function fl.bars:Draw(id)
  local barInfo = self:Get(id)

  if (barInfo) then
    hook.Run("PreDrawBar", barInfo)
    theme.Call("PreDrawBar", barInfo)

    if (!hook.Run("ShouldDrawBar", barInfo)) then
      return
    end

    theme.Call("DrawBarBackground", barInfo)

    if (hook.Run("ShouldFillBar", barInfo) or barInfo.value != 0) then
      theme.Call("DrawBarFill", barInfo)
    end

    if (barInfo.hinderDisplay and barInfo.hinderDisplay <= barInfo.hinderValue) then
      theme.Call("DrawBarHindrance", barInfo)
    end

    if (fl.settings:GetBool("DrawBarText")) then
      theme.Call("DrawBarTexts", barInfo)
    end

    hook.Run("PostDrawBar", barInfo)
    theme.Call("PostDrawBar", barInfo)
  end
end

function fl.bars:DrawTopBars()
  for priority, ids in pairs(sorted) do
    for k, v in ipairs(ids) do
      self:Draw(v)
    end
  end
end

function fl.bars:Adjust(id, data)
  local bar = self:Get(id)

  if (bar) then
    table.Merge(bar, data)
  end
end

do
  local flBars = {}

  function flBars:LazyTick()
    if (IsValid(fl.client)) then
      fl.bars:Position()

      for k, v in pairs(stored) do
        if (v.callback) then
          fl.bars:SetValue(v.id, v.callback(stored[k]))
        end

        hook.Run("AdjustBarInfo", k, stored[k])
      end
    end
  end

  function flBars:PreDrawBar(bar)
    bar.curI = bar.curI or 1

    bar.realFillWidth = bar.width * (bar.value / bar.maxValue)

    if (bar.interpolated == nil) then
      bar.fillWidth = bar.realFillWidth
    else
      if (bar.curI > 150) then
        bar.interpolated = nil
        bar.curI = 1
      else
        bar.fillWidth = bar.width * (bar.interpolated[math.Round(bar.curI)] / bar.maxValue)
        bar.curI = bar.curI + math.Clamp(math.Round(1 * (FrameTime() / 0.006)), 1, 10)
      end
    end

    bar.text = string.utf8upper(fl.lang:TranslateText(bar.text))
    bar.hinderText = string.utf8upper(fl.lang:TranslateText(bar.hinderText))
  end

  function flBars:ShouldDrawBar(bar)
    if (bar.display < bar.value or bar.minDisplay >= bar.value) then
      return false
    end

    return true
  end

  plugin.add_hooks("FLBarHooks", flBars)

  fl.bars:Register("health", {
    text = "#BarText_Health",
    color = Color(200, 40, 40),
    maxValue = 100,
    callback = function(bar)
      return fl.client:Health()
    end
  })

  fl.bars:Register("armor", {
    text = "#BarText_Armor",
    color = Color(80, 80, 220),
    maxValue = 100,
    callback = function(bar)
      return fl.client:Armor()
    end
  })

  fl.bars:Register("respawn", {
    text = "#BarText_Respawn",
    color = Color(50, 200, 50),
    maxValue = 100,
    x = ScrW() * 0.5 - fl.bars.defaultW * 0.5,
    y = ScrH() * 0.5 - 8,
    textOffset = 1,
    height = 16,
    type = BAR_MANUAL
  })
end
