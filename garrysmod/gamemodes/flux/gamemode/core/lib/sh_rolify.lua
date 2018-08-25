--[[
  Inspired by Rolify RubyGem.
]]

local rolify_table = Settings.rolify and Settings.rolify.table_name or 'player_roles'
local rolify_module = {}

local function remove_role(subject, role, object)
  local query = fl.db:delete(rolify_table)
    query:where('steam_id', subject:SteamID())
    if role then query:where('role', role) end
    if object then query:where('object', tostring(object)) end
  query:execute()
end

local function insert_role(subject, role, object)
  local timestamp = to_datetime(os.time())
  local query = fl.db:insert(rolify_table)
    query:insert('steam_id', subject:SteamID())
    if role then query:insert('role', role) end
    if object then query:insert('object', tostring(object)) end
    query:insert('created_at', timestamp)
    query:insert('updated_at', timestamp)
  query:execute()
end

local function update_role(subject, role, object)
  local timestamp = to_datetime(os.time())
  local query = fl.db:update(rolify_table)
    query:where('steam_id', subject:SteamID())
    if role then query:update('role', role) end
    if object then query:update('object', tostring(object)) end
    query:update('updated_at', timestamp)
  query:execute()
end

local function check_roles_table(object, table)
  for k, v in pairs(table) do
    if v == false then remove_role(self, k)
    elseif istable(v) then
      if !v.synced then
        v.synced = true
        insert_role(object, k)
      elseif v.update then
        v.update = false
        update_role(object, k)
      end
      for obj, status in pairs(v) do
        if status == false then
          remove_role(self, k, obj)
        elseif istable(status) then
          if !status.synced then
            status.synced = true
            insert_role(object, k, obj)
          elseif status.update then
            status.update = false
            update_role(object, k, obj)
          end
        end
      end
    end
  end
end

function rolify_module.save_roles(self)
  check_roles_table(self, self.roles)
end

function rolify_module.load_roles(self)
  local query = fl.db:select(rolify_table)
    query:where('steam_id', self:SteamID())
    query:callback(function(result)
      if fl.db:is_result(result) then
        for k, v in ipairs(result) do
          self:add_role(v.role, tostring(v.object), true)
        end
      end
    end)
  query:execute()
end

function rolify_module.add_role(self, role, object, synced)
  local role_table = self.roles[role] or { synced = synced }

  if object then
    role_table[tostring(object)] = {}
  end

  self.roles[role] = role_table
end

function rolify_module.remove_role(self, role, object)
  local role_table = self.roles[role]

  if role_table then
    if object then
      self.roles[role][tostring(object)] = false
    else
      self.roles[role] = false -- set to remove
    end
  end
end

function rolify_module.has_role(self, role, object)
  if object then
    return self.roles[role] and self.roles[role][tostring(object)]
  end

  return self.roles[role]
end

function rolify(object)
  object.roles = {}
  for k, v in pairs(rolify_module) do
    object[k] = v
  end
end
