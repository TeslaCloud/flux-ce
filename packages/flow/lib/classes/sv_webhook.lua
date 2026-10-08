--- A Discord webhook that the server can post messages to. The class is also the registry of
-- the webhooks: `Webhook:add` stores a webhook under an ID, and `Webhook:get`, `Webhook:all`
-- and `Webhook:get_type` look the stored ones up. Every webhook lists the types of messages it
-- accepts, so that a message of some type can be posted to all of the webhooks that want it.
-- Flux creates the webhooks listed in the settings of the server and posts log messages to
-- them with `Log:to_discord`.

class 'Webhook'

Webhook.base_url  = 'https://discordapp.com/api/webhooks/{id}/{key}'
Webhook.url       = nil
Webhook.id        = nil
Webhook.key       = nil
Webhook.hooks     = {}

--- Creates a new Discord webhook.
-- @param id='' [String ID of the Discord webhook]
-- @param key='' [String token of the Discord webhook]
-- @param types={} [List<String> types of messages the webhook accepts, 'all' for any type]
function Webhook:init(id, key, types)
  self.id     = id or ''
  self.key    = key or ''
  self.url    = self.base_url:gsub('{key}', self.key):gsub('{id}', self.id)
  self.types  = istable(types) and types or {}
end

--- Posts a message to the Discord webhook.
-- @param message [String]
-- @param data={} [Map optional username, avatar_url and tts fields of the message]
function Webhook:push(message, data)
  if self.url and isstring(message) then
    data = data or {}

    http.Post(self.url, {
      content = message,
      username = data.username,
      avatar_url = data.avatar_url,
      tts = data.tts
    })
  end
end

--- Adds a webhook to the list of registered webhooks.
-- ```
-- Webhook:add(id, Webhook.new(data.id, data.key, data.types))
-- ```
-- @param id [String ID to store the webhook under]
-- @param webhook=nil [Webhook/Function webhook or a function that returns one, a blank webhook
--   is created if omitted]
-- @return [Webhook the stored webhook]
function Webhook:add(id, webhook)
  if istable(webhook) then
    self.hooks[id] = webhook
  elseif isfunction(webhook) then
    self.hooks[id] = webhook()
  else
    self.hooks[id] = Webhook.new('', '')
  end

  return self.hooks[id]
end

--- Returns the registered webhook with the specified ID.
-- Also available as Webhook#find and Webhook#find_by_id.
-- @param id [String]
-- @return [Webhook the webhook, or nil if there is no such webhook]
function Webhook:get(id)
  return self.hooks[id]
end

--- Returns all of the registered webhooks.
-- @return [Map webhooks by ID]
function Webhook:all()
  return self.hooks
end

--- Returns the registered webhooks that accept messages of the specified type.
-- @param type [String message type]
-- @return [List<Webhook>]
function Webhook:get_type(type)
  local ret = {}

  for k, v in pairs(self.hooks) do
    if v:is_type(type) then
      table.insert(ret, v)
    end
  end

  return ret
end

--- Checks whether a webhook with the specified ID is registered.
-- Also available as Webhook#exists and Webhook#exist.
-- @param id [String]
-- @return [Boolean]
function Webhook:present(id)
  return tobool(self.hooks[id])
end

--- Checks whether this webhook accepts messages of the specified type.
-- @param type [String message type]
-- @return [Boolean]
function Webhook:is_type(type)
  for k, v in ipairs(self.types) do
    if v == type or v == 'all' then
      return true
    end
  end

  return false
end

Webhook.exists      = Webhook.present
Webhook.exist       = Webhook.present
Webhook.find        = Webhook.get
Webhook.find_by_id  = Webhook.get
