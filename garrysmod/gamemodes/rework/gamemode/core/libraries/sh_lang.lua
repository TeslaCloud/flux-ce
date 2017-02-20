--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library.New("lang", rw)
local stored = rw.lang.stored or {}
rw.lang.stored = stored;

local cache = {}
local textCache = {}

function rw.lang:GetTable(name)
	stored[name] = stored[name] or {}

	return stored[name]
end

function rw.lang:GetAll()
	return stored
end

function rw.lang:GetString(language, identifier, arguments)
	language = (istable(stored[language]) and language) or "en"

	local langString = nil
	arguments = arguments or {}

	langString = stored[language][identifier] or identifier

	if (!isstring(langString)) then return identifier end

	for k, v in pairs(arguments) do
		langString = string.gsub(langString, "#"..k, tostring(v), 1)
	end

	langString = langString:Replace(";", "")

	return hook.Run("TranslatePhrase", language, identifier, arguments) or langString
end

function rw.lang:GetPlural(language, phrase, count)
	local langTable = stored[language]
	local translated = self:TranslateText(phrase)

	if (!langTable) then return translated end

	if (langTable.Pluralize) then
		return langTable:Pluralize(phrase, count, translated)
	elseif (language == "en") then
		if (util.IsVowel(translated:sub(translated:len(), translated:len()))) then
			return translated.."es"
		else
			return translated.."s"
		end
	end

	return translated
end

function rw.lang:GetCase(language, phrase, case)
	if (language == "en") then return self:TranslateText(phrase) end

	local langTable = stored[language]
	local translated = self:TranslateText(phrase)

	if (!langTable) then return translated end

	if (langTable.GetCase) then
		return langTable:GetCase(phrase, count, translated)
	end

	return translated
end

-- Explicit mode. This will attempt to translate the given text regardless of anything else.
function rw.lang:TranslateText(sText)
	if (!isstring(sText)) then return "nil" end

	if (textCache[sText]) then
		return textCache[sText]
	end

	if (!string.find(sText, "#")) then
		textCache[sText] = sText
		return sText
	end

	local hooked = hook.Run("TranslateText", sText)

	if (hooked) then
		textCache[sText] = hooked

		return hooked
	end

	local oldText = sText
	local phrases = string.FindAll(sText, "#[%w_.]+")
	local translations = {}

	for k, v in ipairs(phrases) do
		local phraseEnd = nil
		local colonDetected = false

		if (sText:sub(v[3] + 1, v[3] + 1) == ":") then
			phraseEnd = sText:find(";", v[2])
			colonDetected = true
		end

		if (!phraseEnd and !colonDetected) then
			phraseEnd = sText:find(" ", v[2])

			if (!phraseEnd) then
				phraseEnd = v[3]
			else
				phraseEnd = phraseEnd - 1
			end
		elseif (!phraseEnd and colonDetected) then
			phraseEnd = v[3]
		end

		translations[#translations + 1] = L(sText:sub(v[2], phraseEnd))
		phrases[k] = sText:sub(v[2], phraseEnd)
	end

	for k, v in ipairs(translations) do
		sText = sText:Replace(phrases[k], v)
	end

	textCache[oldText] = sText

	return sText
end

if (CLIENT) then
	function L(identifier)
		local lang = GetConVar("gmod_language"):GetString()

		if (!cache[lang]) then
			cache[lang] = {}
		end

		if (cache[lang][identifier]) then
			return cache[lang][identifier]
		end

		local args = {}

		-- Get all the arguments.
		if (string.find(identifier, ";")) then
			args = string.Explode(",", identifier)

			local colon = args[1]:find(":")

			-- The first result will always be the base identifier.
			identifier = args[1]:sub(1, colon - 1)
			args[1] = args[1]:sub(colon + 1, args[1]:len())
		end

		local text =  rw.lang:GetString(lang, identifier, args)

		cache[lang][identifier] = text

		return text
	end

	function rw.lang:Pluralize(phrase, count)
		local lang = GetConVar("gmod_language"):GetString()

		if (lang) then
			return self:GetPlural(lang, phrase, count)
		end
	end

	function rw.lang:Case(phrase, case)
		local lang = GetConVar("gmod_language"):GetString()

		if (lang) then
			return self:GetCase(lang, phrase, case)
		end
	end

	surface.bTranslating = surface.bTranslating or true

	--[[
		This is to stop our overrides from parsing translations, we
		don't want certain things like the chatbox to be translated.
	--]]
	function surface.NoTranslate(bValue)
		surface.bTranslating = !bValue
	end

	surface.OldGetTextSize = surface.OldGetTextSize or surface.GetTextSize

	function surface.GetTextSize(sText)
		if (surface.bTranslating) then
			sText = rw.lang:TranslateText(sText)
		end

		return surface.OldGetTextSize(sText)
	end

	surface.OldDrawText = surface.OldDrawText or surface.DrawText
	--[[
		Overwrite the way the surface library draws text,
		this way we can put translations into anything that uses this,
		like draw.SimpleText, etc.

		This will give us control over basically every text drawn
		with Lua outside of Derma.
	--]]
	function surface.DrawText(sText)
		if (surface.bTranslating) then
			sText = rw.lang:TranslateText(sText)
		end

		return surface.OldDrawText(sText)
	end

	local PANEL_META = FindMetaTable("Panel")

	PANEL_META.OldSetText = PANEL_META.OldSetText or PANEL_META.SetText

	-- Overwrite the way panels set their text, this way we can stick our translations in.
	function PANEL_META:SetText(sText)
		if (string.sub(sText, 1, 1) == "#" and surface.bTranslating) then
			local phraseName = sText
			local translated = L(sText)

			if (translated != sText and !self.AllowInput) then
				sText = translated
			elseif (translated != text and self.AllowInput) then
				sText = string.gsub(sText, "#", "")
			end

			self.__PhraseName = sText
		end

		return self:OldSetText(sText)
	end

	do
		local oldLang = "en"

		hook.Add("LazyTick", "LanguageChecker", function()
			local newLang = GetConVar("gmod_language"):GetString()

			if (oldLang != newLang) then
				textCache = {}
				cache = {}
				oldLang = newLang
			end
		end)
	end
else
	--[[
		Simply get the identifier with any arguments to send to clients.

		Since translation is done by player, we let clientside handle this,
		so we network the raw identifier with any arguments and let the client parse it.
	--]]
	function L(player, identifier, ...)
		local arguments = {...}

		-- In case the format L(identifier, ...) is used.
		if (isstring(player)) then
			if (identifier) then
				table.insert(arguments, 1, identifier)
			end

			identifier = player
		end

		if (identifier) then
			local text = "#"..identifier

			--[[
				We do this to provide backcompat for the
				few translations that were actually done serverside.

				This is also a way nicer way to do things, but
				you need to remember this is ONLY available serverside.

				Clientside needs to manually concat arguments.
			--]]
			if (arguments) then
				text = text..":"

				for k, v in ipairs(arguments) do
					text = text..v

					if (k < #arguments) then
						text = text..","
					end
				end

				text = text..";"
			end

			return text
		end
	end
end