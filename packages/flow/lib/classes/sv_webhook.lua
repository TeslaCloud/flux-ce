--- A Discord webhook that the server can post messages to. The class is also the registry of
-- the webhooks: `Webhook:add` stores a webhook under an ID, and `Webhook:get`, `Webhook:all`
-- and `Webhook:get_type` look the stored ones up. Every webhook lists the types of messages it
-- accepts, so that a message of some type can be posted to all of the webhooks that want it.
-- Flux creates the webhooks listed in the settings of the server and queues log messages for
-- them with `Log:to_discord`. Every five seconds each webhook posts what it has queued, joined
-- into messages of at most 2000 bytes and at most two messages at a time, which keeps the
-- posts within the rate limit of Discord. Messages are posted as JSON with every mention
-- disabled, so that text from players cannot ping anyone.

local registered_hooks = Webhook and Webhook.hooks or {}

const max_message_length = 2000
const max_pending = 200
const max_posts_per_flush = 2
const flush_interval = 5

class 'Webhook'

Webhook.base_url  = 'https://discord.com/api/webhooks/{id}/{key}'
Webhook.url       = nil
Webhook.id        = nil
Webhook.key       = nil
Webhook.hooks     = registered_hooks

--- Creates a new Discord webhook.
-- @param id='' [String ID of the Discord webhook]
-- @param key='' [String token of the Discord webhook]
-- @param types={} [List<String> types of messages the webhook accepts, 'all' for any type]
function Webhook:init(id, key, types)
  self.id     = id or ''
  self.key    = key or ''
  self.url    = self.base_url:gsub('{key}', self.key):gsub('{id}', self.id)
  self.types  = istable(types) and types or {}
  self.pending = {}
end

--- Posts a message to the Discord webhook right away, as JSON with every mention disabled.
-- @param message [String]
-- @param data={} [Map optional username, avatar_url and tts fields of the message]
function Webhook:push(message, data)
  if !self.url or !isstring(message) then return end

  data = data or {}

  HTTP({
    url = self.url,
    method = 'POST',
    type = 'application/json',
    body = util.TableToJSON({
      content = message,
      username = data.username,
      avatar_url = data.avatar_url,
      tts = data.tts,
      allowed_mentions = { parse = {} }
    })
  })
end

--- Queues a message for the next `Webhook:flush`. Once 200 messages are waiting, the oldest
-- one is dropped for every message that is added.
-- @param message [String]
function Webhook:queue(message)
  if !isstring(message) or message == '' then return end

  local pending = self.pending

  if #pending >= max_pending then
    table.remove(pending, 1)
  end

  pending[#pending + 1] = message
end

local function utf8_boundary(text, limit)
  local cut = limit

  while cut > 0 and (text:byte(cut + 1) & 0xC0) == 0x80 do
    cut -= 1
  end

  return cut > 0 ? cut : limit
end

--- Removes from the front of a queue the messages that fit into one Discord message and
-- returns them joined with line breaks. A message longer than the limit is split at a
-- character boundary and its rest stays at the front of the queue.
-- @param pending [List<String> queued messages, not empty]
-- @return [String text of at most 2000 bytes]
local function take_message(pending)
  local first = pending[1]

  if #first > max_message_length then
    local cut = utf8_boundary(first, max_message_length)

    pending[1] = first:sub(cut + 1)

    return first:sub(1, cut)
  end

  local total = #pending
  local length = #first
  local count = 1

  for i = 2, total do
    length += #pending[i] + 1

    if length > max_message_length then break end

    count = i
  end

  local text = table.concat(pending, '\n', 1, count)

  for i = 1, total do
    pending[i] = pending[i + count]
  end

  return text
end

--- Posts the queued messages, joined into Discord messages of at most 2000 bytes, at most two
-- of them per call; what does not fit stays queued for the next call.
function Webhook:flush()
  local pending = self.pending

  for _ = 1, max_posts_per_flush do
    if #pending == 0 then return end

    self:push(take_message(pending))
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
-- @param message_type [String message type]
-- @return [List<Webhook>]
function Webhook:get_type(message_type)
  local ret = {}

  for _, webhook in pairs(self.hooks) do
    if webhook:is_type(message_type) then
      ret[#ret + 1] = webhook
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
-- @param message_type [String message type]
-- @return [Boolean]
function Webhook:is_type(message_type)
  local types = self.types

  for i = 1, #types do
    local v = types[i]

    if v == message_type or v == 'all' then
      return true
    end
  end

  return false
end

Webhook.exists      = Webhook.present
Webhook.exist       = Webhook.present
Webhook.find        = Webhook.get
Webhook.find_by_id  = Webhook.get

timer.Create('fl_webhooks', flush_interval, 0, function()
  for _, webhook in pairs(Webhook.hooks) do
    webhook:flush()
  end
end)
