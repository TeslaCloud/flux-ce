--- What vendors say: a vendor speaks to its customer with the phrases set for it in the
-- editor, or with the default phrases of the language of the customer, through one plain
-- line in the chat of that customer.

--- Makes a vendor say one of its phrases to a player: the text set for the vendor, or the
-- default phrase in the language of the player. The line goes to the chat of that player
-- only, or into a notification if the Chatbox plugin is not loaded.
-- @param vendor [Entity]
-- @param actor [Player who the vendor talks to]
-- @param id [String phrase ID, one of `Vendors.phrases`]
function Vendors:say(vendor, actor, id)
  if !IsValid(actor) or !self:is_vendor(vendor) then return end

  local data = vendor.vendor_data
  local lang = Flux.Lang:get_player_lang(actor)
  local text = data.phrases[id]

  if !isstring(text) or text == '' then
    text = (t('vendor.phrase.'..id, nil, lang))
  end

  --- Called on the server before a vendor says one of its phrases to a player.
  -- @param vendor [Entity The vendor]
  -- @param actor [Player The player the vendor talks to]
  -- @param id [String Phrase ID: 'greeting', 'refuse', 'no_money', 'no_stock', 'broke' or
  --   'thanks']
  -- @param text [String What the vendor is about to say]
  -- @return [Boolean Return false to keep the vendor silent, String Text to say instead]
  local result = hook.Run('VendorSay', vendor, actor, id, text)

  if result == false then return end

  if isstring(result) then
    text = result
  end

  if text == '' then return end

  local line = data.name..' '..(t('vendor.says', nil, lang))..': "'..text..'"'

  if Chatbox then
    Chatbox.add_text(actor, Color(255, 255, 160), line)
  else
    actor:notify(line)
  end
end
