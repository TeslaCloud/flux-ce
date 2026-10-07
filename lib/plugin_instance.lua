class 'PluginInstance'

--- Class constructor. Fills in the basic plugin fields, then merges the whole data table
-- into the object.
-- @param id [String plugin ID; data.id is used if this is nil]
-- @param data [Map plugin info with name, author, folder, path, description and any
--   additional fields]
function PluginInstance:init(id, data)
  self.name         = data.name         or 'Unknown Plugin'
  self.author       = data.author       or 'Unknown Author'
  self.folder       = data.folder       or self.name:to_id()
  self.path         = data.path         or self.folder
  self.description  = data.description  or 'This plugin has no description.'
  self.id           = id or data.id     or self.name:to_id() or 'unknown'

  table.safe_merge(self, data)
end

--- Returns the name of the plugin.
-- @return [String]
function PluginInstance:get_name()
  return self.name
end

--- Returns the folder that contains the plugin's code.
-- @return [String]
function PluginInstance:get_folder()
  return self.folder
end

--- Returns the path the plugin was included from. Plugins are stored under this path.
-- @return [String]
function PluginInstance:get_path()
  return self.path
end

--- Returns the author of the plugin.
-- @return [String]
function PluginInstance:get_author()
  return self.author
end

--- Returns the description of the plugin.
-- @return [String]
function PluginInstance:get_description()
  return self.description
end

--- Sets the name of the plugin.
-- @param name [String new name; the current name is kept if this is nil]
function PluginInstance:set_name(name)
  self.name = name or self.name or 'Unknown Plugin'
end

--- Sets the author of the plugin.
-- @param author [String new author; the current author is kept if this is nil]
function PluginInstance:set_author(author)
  self.author = author or self.author or 'Unknown'
end

--- Sets the description of the plugin.
-- @param desc [String new description; the current description is kept if this is nil]
function PluginInstance:set_description(desc)
  self.description = desc or self.description or 'No description provided!'
end

--- Merges the fields of a table into the plugin object.
-- @param data [Map fields to merge]
function PluginInstance:set_data(data)
  table.safe_merge(self, data)
end

--- Makes the plugin available as a global variable, unless a global table with that name
-- already exists. Throws an error if the name starts with a lowercase letter.
-- @param alias [String name of the global, in ConstantStyle]
function PluginInstance:set_global(alias)
  if isstring(alias) then
    if alias[1]:is_lower() then
      error('bad plugin alias ('..alias..')\nplugin globals must follow the ConstantStyle!\n')
    end

    if !istable(_G[alias]) then
      _G[alias] = self
      self.alias = alias
    end
  end
end

--- Checks whether this plugin object is the schema.
-- @return [Boolean true for the schema, nil for regular plugins]
function PluginInstance:is_schema()
  return self._is_schema
end

--- Converts the plugin to a string of the form '#<Plugin:name>'.
-- @return [String]
function PluginInstance:__tostring()
  return '#<Plugin:'..self.name..'>'
end

--- Registers the plugin with the Plugin library.
-- @see [Plugin.register]
function PluginInstance:register()
  Plugin.register(self)
end
