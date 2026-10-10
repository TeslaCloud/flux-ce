--- Help: the pages of the Help tab of the tab menu. A page is registered under an ID with
-- `Flux.Help:add_page` and shows up as a tab of its own, in the order of the priorities.
-- Its contents are a Lumen element tree that comes from one of two places: a Lumen template
-- from a `views/lumen` folder (the usual way, see `Lumen`), or a function that returns the
-- elements. Flux registers three pages itself: 'commands' (every command the local player
-- may run, see `Flux.Help:get_commands`), 'plugins' and 'credits'.
--
-- The pages are rendered every time the Help tab is opened, in the language of the player,
-- so a page can show what is true at that moment.
-- ```
-- -- plugin/cl_plugin.lua, with the page in plugin/views/lumen/rules.lumen
-- Flux.Help:add_page('rules', {
--   title = 'ui.help.rules.title',
--   component = 'rules',
--   priority = 5
-- })
-- ```
-- @module [Flux.Help]

mod 'Flux::Help'

local isstring   = isstring
local istable    = istable
local isfunction = isfunction
local tostring   = tostring
local sort       = table.sort

local stored = Flux.Help.stored or {}
Flux.Help.stored = stored

--- Translates a text that may be a language phrase, leaving out the second value `t` returns.
-- @param text [Any text or phrase; anything but a string that is not empty gives an empty
--   string]
-- @return [String]
local function translate(text)
  if !isstring(text) or text == '' then return '' end

  return (t(text))
end

--- Adds a page to the Help tab, or replaces the page that has the same ID.
-- ```
-- Flux.Help:add_page('server_info', {
--   title = 'ui.help.server_info.title',
--   priority = 5,
--   visible = function(page)
--     return PLAYER:has_initialized()
--   end,
--   render = function(page)
--     return Lumen.element('text', { style = { font = 'menu_large' } }, { GetHostName() })
--   end
-- })
-- ```
-- @param id [String unique page ID made of Latin letters, digits and underscores]
-- @param data [Map page options. Give one of: component (String ID of a Lumen template, or
--   Function a Lumen component; it receives the page as the `page` prop along with `props`)
--   or render (Function(page) that returns a Lumen element). Optional: title (String text or
--   phrase shown on the tab of the page, the ID by default), priority (Number pages are
--   ordered by ascending priority, 50 by default), props (Map more props for the component)
--   and visible (Function(page) return a falsy value to leave the page out)]
-- @return [Map the stored page, or nil if the ID or the options are not valid]
function Flux.Help:add_page(id, data)
  if !isstring(id) or !id:match('^[%w_]+$') or !istable(data) then
    ErrorNoHalt("Not adding the '"..tostring(id).."' help page! Its ID or its options are not valid!\n")

    return
  end

  data.id = id
  data.title = isstring(data.title) and data.title != '' and data.title or id
  data.priority = tonumber(data.priority) or 50

  stored[id] = data

  return data
end

--- Removes a page from the Help tab.
-- @param id [String page ID]
function Flux.Help:remove_page(id)
  stored[id] = nil
end

--- Returns a page of the Help tab.
-- @param id [String page ID]
-- @return [Map the page, or nil if there is no such page]
function Flux.Help:find_page(id)
  return stored[id]
end

--- Returns every page that has been added to the Help tab.
-- @return [Map pages keyed by page ID]
function Flux.Help:all()
  return stored
end

--- Returns the pages that the Help tab shows right now: the ones whose `visible` function,
-- if they have one, returns a truthy value.
-- @return [List<Map> pages ordered by priority, pages of the same priority by ID]
function Flux.Help:get_pages()
  local pages = {}

  for id, page in pairs(stored) do
    if !isfunction(page.visible) or page.visible(page) then
      pages[#pages + 1] = page
    end
  end

  sort(pages, function(a, b)
    if a.priority == b.priority then
      return a.id < b.id
    end

    return a.priority < b.priority
  end)

  return pages
end

--- Renders the contents of a page: the element of its component with the page as a prop, or
-- what its render function returns. A page that fails to render is reported in the console
-- and comes out empty, so that it does not take the other pages down with it.
-- @param page [Map page, as returned by Flux.Help#get_pages or Flux.Help#find_page]
-- @return [Map Lumen element of the page, or nil if the page has none]
function Flux.Help:render_page(page)
  if !istable(page) then return nil end

  if isfunction(page.render) then
    local success, result = pcall(page.render, page)

    if !success then
      ErrorNoHalt("The '"..tostring(page.id).."' help page has failed to render!\n")
      error_with_traceback(tostring(result))

      return nil
    end

    if result == nil or result == false then return nil end

    return result
  end

  local component = page.component

  if isstring(component) then
    component = Lumen.component(component)
  end

  if component == nil then return nil end

  local props = { page = page }

  if istable(page.props) then
    for k, v in pairs(page.props) do
      props[k] = v
    end
  end

  return Lumen.element(component, props)
end

--- Returns the prefix to show in front of the names of commands: '/' if that is one of the
-- command prefixes of the server, else the first of them.
-- @return [String]
function Flux.Help:get_command_prefix()
  local prefixes = Config.get('command_prefixes')

  if !istable(prefixes) or table.HasValue(prefixes, '/') then
    return '/'
  end

  return isstring(prefixes[1]) and prefixes[1] or '/'
end

--- Lists the commands the local player is allowed to run, grouped by category, for the
-- Commands page of the Help tab. The texts are translated to the current language. Commands
-- without a category end up in a category of their own, and categories that translate to the
-- same name are merged.
-- @return [List<Map> categories ordered by name: name (String translated name) and
--   commands (List<Map> ordered by name: id (String), name (String), syntax (String,
--   empty if the command takes no arguments), description (String) and aliases
--   (List<String> the other names the command can be called by))]
function Flux.Help:get_commands()
  local client = LocalPlayer()
  local categories = {}
  local by_name = {}

  if !IsValid(client) then return categories end

  for id, command in pairs(Flux.Command.stored) do
    if client:can(command.id) then
      local name = translate(command.category or 'ui.help.commands.uncategorized')
      local category = by_name[name]

      if !category then
        category = { name = name, commands = {} }
        by_name[name] = category

        categories[#categories + 1] = category
      end

      local description = command.description
      local syntax = command.syntax
      local aliases = {}

      if isfunction(command.get_description) then
        description = command:get_description()
      end

      if syntax == '[-]' then
        syntax = ''
      end

      for k, v in ipairs(command.aliases or {}) do
        if v != command.id then
          aliases[#aliases + 1] = v
        end
      end

      local commands = category.commands

      commands[#commands + 1] = {
        id = command.id,
        name = tostring(command.name or command.id),
        syntax = translate(syntax),
        description = translate(description),
        aliases = aliases
      }
    end
  end

  for k, v in ipairs(categories) do
    sort(v.commands, function(a, b)
      local first, second = a.name:utf8lower(), b.name:utf8lower()

      if first == second then
        return a.id < b.id
      end

      return first < second
    end)
  end

  sort(categories, function(a, b)
    return a.name < b.name
  end)

  return categories
end

Flux.Help:add_page('commands', {
  title = 'ui.help.commands.title',
  component = 'help_commands',
  priority = 10
})

Flux.Help:add_page('plugins', {
  title = 'ui.help.plugins.title',
  component = 'help_plugins',
  priority = 20
})

Flux.Help:add_page('credits', {
  title = 'ui.help.credits.title',
  component = 'help_credits',
  priority = 90
})
