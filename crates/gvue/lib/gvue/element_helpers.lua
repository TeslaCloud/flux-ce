local transferable_attributes = {
  ['color'] = true,
  ['font'] = true,
  ['font_size'] = true
}

local pt_to_px = 4 / 3
local cm_to_px = 1 / 48
local mm_to_px = 1 / 48 / 100

local null_function = function(e, n, what) return n end

local unit_callbacks = {
  ['px']    = null_function,
  ['pt']    = function(e, n, what) return n * pt_to_px end,
  ['cm']    = function(e, n, what) return n * cm_to_px end,
  ['mm']    = function(e, n, what) return n * mm_to_px end,
  ['in']    = function(e, n, what) return n * 96 end,
  ['pc']    = function(e, n, what) return n * pt_to_px * 12 end,
  ['vh']    = function(e, n, what) return (n * 0.01) * ScrH() end,
  ['vw']    = function(e, n, what) return (n * 0.01) * ScrW() end,
  ['em']    = function(e, n, what) return n * e._gvue.context.font_size end,
  ['rem']   = function(e, n, what) return n * Gvue:get_root_element_of(e)._gvue.context.font_size end,
  ['ex']    = function(e, n, what) return n * e._gvue.context.font_size end,
  ['vmin']  = function(e, n, what) return n * Gvue:get_screen_dimensions().min end,
  ['vmax']  = function(e, n, what) return n * Gvue:get_screen_dimensions().max end,
  ['ch']    = function(e, n, what)
    surface.SetFont(e._gvue.context.attributes.font_family)
    local size = surface.GetTextSize('0')
    return n * size
  end,
  ['%']     = function(e, n, what)
    return n * Gvue:get_context_attribute(Gvue:get_parent_of(e), what or 'font_size'))
  end,
}

function Gvue:get_unit_callback(unit)
  return unit_callbacks[unit] or null_function
end

function Gvue:attribute_is_transferable(attr)
  return transferable_attributes[attr]
end

function Gvue:get_screen_dimensions()
  local w, h = ScrW(), ScrH()

  if w > h then
    return { min = h, max = w }
  end

  return { min = w, max = h }
end

function Gvue:get_parent_of(e)
  return e._gvue.context.parent
end

function Gvue:get_root_element_of(e)
  local last_el

  repeat
    last_el = e

    if e then
      e = self:get_parent_of(e)
    end
  until !e

  return last_el
end

function Gvue:get_context_attribute(e, attr)
  local context_attributes = e._gvue.context.attributes
  local cur = context_attributes
  local split = attr:split('-')

  for k, v in ipairs(split) do
    if istable(cur[v]) then
      cur = v
    else
      return cur[v]
    end
  end

  return context_attributes[attr]
end
