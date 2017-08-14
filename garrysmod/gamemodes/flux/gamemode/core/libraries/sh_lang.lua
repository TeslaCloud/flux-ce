--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library.New("lang", fl)

local stored = fl.lang.stored or {}
fl.lang.stored = stored

local cache = {}
local textCache = {}

local defaultLangTable = {
	NiceTime = function(self, time)
		if (time == 1) then
			return "#second:"..time..";", 0
		elseif (time < 60) then
			return "#second:"..time..";s", 0
		elseif (time < (60 * 60)) then
			local t = math.floor(time / 60)

			return "#minute:"..t..";"..((t != 1 and "s") or ""), time - t * 60
		elseif (time < (60 * 60 * 24)) then
			local t = math.floor(time / 60 / 60)

			return "#hour:"..t..";"..((t != 1 and "s") or ""), time - t * 60 * 60
		elseif (time < (60 * 60 * 24 * 7)) then
			local t = math.floor(time / 60 / 60 / 24)

			return "#day:"..t..";"..((t != 1 and "s") or ""), time - t * 60 * 60 * 24
		elseif (time < (60 * 60 * 24 * 30)) then
			local t = math.floor(time / 60 / 60 / 24 / 7)

			return "#week:"..t..";"..((t != 1 and "s") or ""), time - t * 60 * 60 * 24 * 7
		elseif (time < (60 * 60 * 24 * 30 * 12)) then
			local t = math.floor(time / 60 / 60 / 24 / 30)

			return "#month:"..t..";"..((t != 1 and "s") or ""), time - t * 60 * 60 * 24 * 30
		elseif (time >= (60 * 60 * 24 * 365)) then
			local t = math.floor(time / 60 / 60 / 24 / 365)

			return "#year:"..t..";"..((t != 1 and "s") or ""), time - t * 60 * 60 * 24 * 365
		else
			return "#second:"..time..";s", 0
		end
	end,
	NiceTimeFull = function(self, time)
		local out = ""
		local i = 0

		while (time > 0) do
			if (i >= 100) then break end -- fail safety

			local str, remainder = self:NiceTime(time)

			time = remainder

			if (time <= 0) then
				if (i != 0) then
					out = out.."#and "..str
				else
					out = str
				end
			else
				out = out..str.." "
			end

			i = i + 1
		end

		return out
	end
}

function fl.lang:GetTable(name)
	stored[name] = stored[name] or table.Copy(defaultLangTable) or {}

	return stored[name]
end

function fl.lang:GetAll()
	return stored
end

function fl.lang:GetString(language, identifier, arguments)
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

function fl.lang:GetPlural(language, phrase, count)
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

function fl.lang:NiceTime(language, time)
	time = tonumber(time) or 0

	local langTable = stored[language]

	if (langTable and langTable.NiceTime) then
		return langTable:NiceTime(time)
	end

	return string.NiceTime(time)
end

function fl.lang:NiceTimeFull(language, time)
	time = tonumber(time) or 0

	local langTable = stored[language]

	if (langTable and langTable.NiceTimeFull) then
		return langTable:NiceTimeFull(time)
	end

	return string.NiceTime(time)
end

function fl.lang:GetCase(language, phrase, case)
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
function fl.lang:TranslateText(sText)
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

function fl.lang:GetPlayerLang(player)
	if (!IsValid(player)) then return "en" end

	return player:GetNetVar("language", "en")
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

		local text =  fl.lang:GetString(lang, identifier, args)

		cache[lang][identifier] = text

		return text
	end

	function fl.lang:Pluralize(phrase, count)
		local lang = GetConVar("gmod_language"):GetString()

		if (lang) then
			return self:GetPlural(lang, phrase, count)
		end
	end

	function fl.lang:Case(phrase, case)
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
			sText = fl.lang:TranslateText(sText)
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
			sText = fl.lang:TranslateText(sText)
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

				netstream.Start("Flux::Player::Language", newLang)
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