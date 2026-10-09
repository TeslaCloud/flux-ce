--- The Container Tool changes the container the owner is looking at. Left click applies the
-- mode picked in the tool's settings panel: it gives the container the entered name, message
-- or password, or fills it with random items of the chosen category up to the chosen share
-- of its slots. Right click removes the name, the message or the password instead. The tool
-- requires the `manage_containers` permission, which every action checks as well, and
-- filling requires the `fill_containers` permission on top of it.

TOOL.Category = 'Flux'
TOOL.Name = 'Container Tool'
TOOL.Command = nil
TOOL.ConfigName = ''
TOOL.permission = 'manage_containers'

TOOL.ClientConVar['mode'] = '1'
TOOL.ClientConVar['name'] = ''
TOOL.ClientConVar['message'] = ''
TOOL.ClientConVar['password'] = ''
TOOL.ClientConVar['share'] = '50'
TOOL.ClientConVar['category'] = 'all'

local modes = { 'name', 'message', 'password', 'fill' }
local handlers = {}

--- Gives the container the name entered in the tool's settings, or removes its name.
-- @param tool [Tool the container tool]
-- @param owner [Player the tool owner]
-- @param entity [Entity the container prop]
-- @param reset [Boolean true to remove the name]
function handlers.name(tool, owner, entity, reset)
  local name = !reset and tool:GetClientInfo('name') or nil

  name = Container:set_container_name(entity, name)

  if name then
    owner:notify('notification.container.name_set', { name = name })
  else
    owner:notify('notification.container.name_removed')
  end
end

--- Gives the container the message entered in the tool's settings, or removes its message.
-- @param tool [Tool the container tool]
-- @param owner [Player the tool owner]
-- @param entity [Entity the container prop]
-- @param reset [Boolean true to remove the message]
function handlers.message(tool, owner, entity, reset)
  local message = !reset and tool:GetClientInfo('message') or nil

  if Container:set_container_message(entity, message) then
    owner:notify('notification.container.message_set')
  else
    owner:notify('notification.container.message_removed')
  end
end

--- Gives the container the password entered in the tool's settings, or removes its
-- password.
-- @param tool [Tool the container tool]
-- @param owner [Player the tool owner]
-- @param entity [Entity the container prop]
-- @param reset [Boolean true to remove the password]
function handlers.password(tool, owner, entity, reset)
  local password = !reset and tool:GetClientInfo('password') or nil

  password = Container:set_container_password(entity, password)

  if password then
    owner:notify('notification.container.password_set', { password = password })
  else
    owner:notify('notification.container.password_removed')
  end
end

--- Fills the container with random items of the category and up to the share of slots set
-- in the tool's settings. Needs the 'fill_containers' permission.
-- @param tool [Tool the container tool]
-- @param owner [Player the tool owner]
-- @param entity [Entity the container prop]
-- @param reset [Boolean true if the owner has pressed right click, which does nothing here]
-- @return [Boolean false if nothing was added, nothing otherwise]
function handlers.fill(tool, owner, entity, reset)
  if reset then return false end

  if !owner:can('fill_containers') then
    owner:notify('error.no_permission')

    return false
  end

  local category = tool:GetClientInfo('category')

  if category == '' or category == 'all' then
    category = nil
  end

  local share = math.Clamp(tool:GetClientNumber('share', 50), 1, 100) / 100
  local added, error_text = Container:fill(entity, share, category)

  if !added then
    owner:notify(error_text)

    return false
  end

  owner:notify('notification.container.filled', { count = added })
end

--- Runs the handler of the selected mode on the container that was hit. Serverside only.
-- @param trace [Map trace result of the tool owner's aim]
-- @param reset [Boolean true to remove what the mode sets instead of setting it]
-- @return [Boolean true if the container was changed, false if it was not, nil if the
--   owner lacks the 'manage_containers' permission]
function TOOL:ApplyMode(trace, reset)
  local owner = self:GetOwner()

  if !IsValid(owner) or !owner:can('manage_containers') then return end

  local handler = handlers[modes[self:GetClientNumber('mode')] or '']

  if !handler then return false end

  local entity = trace.Entity

  if !Container:is_container(entity) then
    owner:notify('error.container.not_valid')

    return false
  end

  return handler(self, owner, entity, reset) != false
end

--- Applies the selected mode to the container the owner is looking at.
-- @param trace [Map trace result of the tool owner's aim]
-- @return [Boolean true if the container was changed (always true clientside), false if it
--   was not, nil if the owner lacks the 'manage_containers' permission]
function TOOL:LeftClick(trace)
  if CLIENT then return true end

  return self:ApplyMode(trace, false)
end

--- Removes what the selected mode sets from the container the owner is looking at: its
-- name, its message or its password.
-- @param trace [Map trace result of the tool owner's aim]
-- @return [Boolean true if the container was changed (always true clientside), false if it
--   was not, nil if the owner lacks the 'manage_containers' permission]
function TOOL:RightClick(trace)
  if CLIENT then return true end

  return self:ApplyMode(trace, true)
end

if CLIENT then
  --- Adds a labelled drop-down to the control panel that sets a console variable to the
  -- value of the picked option and shows the option the variable is set to.
  -- @param panel [Panel the tool's control panel]
  -- @param label [String text shown next to the drop-down]
  -- @param convar [String full name of the console variable]
  -- @param choices [List<Map> the options, each with a title and a value]
  local function add_dropdown(panel, label, convar, choices)
    local combo_box = panel:ComboBox(label, convar)

    combo_box:SetSortItems(false)

    for k, v in ipairs(choices) do
      combo_box:AddChoice(v.title, v.value)
    end
  end

  --- Builds the tool's settings panel: the mode, the name, the message, the password, the
  -- share of slots to fill and the category of the items to fill with.
  -- @param panel [Panel the tool's control panel]
  function TOOL.BuildCPanel(panel)
    local mode_choices = {}
    local category_choices = { { title = t'tool.container.any_category', value = 'all' } }

    for k, v in ipairs(modes) do
      table.insert(mode_choices, { title = t('tool.container.mode_'..v), value = tostring(k) })
    end

    for k, v in ipairs(Container:get_loot_categories()) do
      table.insert(category_choices, { title = t(v), value = v })
    end

    panel:AddControl('Header', { Description = t'tool.container.desc' })

    add_dropdown(panel, t'tool.container.mode', 'container_mode', mode_choices)

    panel:AddControl('TextBox', {
      Label = t'tool.container.custom_name',
      Command = 'container_name',
      MaxLenth = '64'
    })
    panel:AddControl('TextBox', {
      Label = t'tool.container.message',
      Command = 'container_message',
      MaxLenth = '256'
    })
    panel:AddControl('TextBox', {
      Label = t'tool.container.password',
      Command = 'container_password',
      MaxLenth = '64'
    })
    panel:AddControl('Slider', {
      Label = t'tool.container.share',
      Command = 'container_share',
      Type = 'Integer',
      Min = 1,
      Max = 100
    })

    add_dropdown(panel, t'tool.container.category', 'container_category', category_choices)
  end
end
