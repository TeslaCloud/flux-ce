--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

PLUGIN:SetName("TeslaCloud Blacklist")
PLUGIN:SetAuthor("Mr. Meow")
PLUGIN:SetDescription("Automatically prevents access to any TeslaCloud-ran servers to certain players.")

--[[
	This code is here for indev and private versions only.
	This will be removed in release.
--]]

local defaultReason = "You have been blacklisted from this server!"

local blacklist = {
	["STEAM_0:1:26720819"] = "Banned for being a dick.", -- banned me for being me
	["STEAM_0:1:36296412"] = "Banned for severe ToS violations.", -- ddosed me
	["STEAM_0:1:8387555"] = "No Flux for you mate :p", -- kuro
	["STEAM_0:1:66844990"] = "Banned for severe ToS violations.", -- ddos
	["STEAM_0:1:49235892"] = "Banned for severe ToS violations.", -- ddos
	-- TNF community players and admins
	["STEAM_0:0:53046893"] = "You have been blacklisted due to bad affiliations!", -- [TNF]AnalCaptain
	["STEAM_0:1:98463373"] = "You have been blacklisted due to bad affiliations!", -- Дови
	["STEAM_0:1:39162722"] = "You have been blacklisted due to bad affiliations!", -- Aksinya Astakhova
	["STEAM_0:0:78302726"] = "You have been blacklisted due to bad affiliations!", -- step000nchik #1WW
	["STEAM_0:1:49235892"] = "You have been blacklisted due to bad affiliations!", -- Takumi
	["STEAM_0:0:77222389"] = "You have been blacklisted due to bad affiliations!", -- The Mask
	["STEAM_0:1:39496371"] = "You have been blacklisted due to bad affiliations!", -- [Hakers]cherep_
	["STEAM_0:0:74317098"] = "You have been blacklisted due to bad affiliations!", -- [RT]-=XOMAK=-
	["STEAM_0:0:43712567"] = "You have been blacklisted due to bad affiliations!", -- 🔰[TNF][CUPS]Cup of Tea🔰
	["STEAM_0:1:158640316"] = "You have been blacklisted due to bad affiliations!", -- AnonimusRedBlue
	["STEAM_0:0:59648570"] = "You have been blacklisted due to bad affiliations!", -- Blender 2.78
	["STEAM_0:1:89076554"] = "You have been blacklisted due to bad affiliations!", -- Frix
	["STEAM_0:1:75772998"] = "You have been blacklisted due to bad affiliations!", -- J'zargo
	["STEAM_0:0:72273145"] = "You have been blacklisted due to bad affiliations!", -- [SOW] Player
	["STEAM_0:0:72161468"] = "You have been blacklisted due to bad affiliations!", -- Raup "7-6-0" Raus
	["STEAM_0:0:198023944"] = "You have been blacklisted due to bad affiliations!", -- mirrad233
	["STEAM_0:0:49512624"] = "You have been blacklisted due to bad affiliations!", -- BlyeBerry
	["STEAM_0:0:86748785"] = "You have been blacklisted due to bad affiliations!", -- 🔰[THF][CUPS]Cup of Anime🔰
	["STEAM_0:0:74707290"] = "You have been blacklisted due to bad affiliations!", -- Моге-Ко♥♪
	["STEAM_0:1:86275919"] = "You have been blacklisted due to bad affiliations!", -- Кошак-пышак
	["STEAM_0:0:101423388"] = "You have been blacklisted due to bad affiliations!", -- Immortal
	["STEAM_0:1:88616406"] = "You have been blacklisted due to bad affiliations!", -- [TNF]you're fired
	["STEAM_0:1:10947122"] = "You have been blacklisted due to bad affiliations!", -- [TNF] Vesthamer
	["STEAM_0:0:88416778"] = "You have been blacklisted due to bad affiliations!", -- P U L S A R
	["STEAM_0:1:18294986"] = "You have been blacklisted due to bad affiliations!", -- Macleod962
	["STEAM_0:1:117523547"] = "You have been blacklisted due to bad affiliations!" -- Lurker_666
}

local badKeywords = {
	"[tnf]", "[ tnf ]", "[ tnf]", "[tnf ]",
	"[tnf", "(tnf", "(tnf)", "tnf)", "the new future", "( tnf", "tnf )",
	"kurozael", "conna wiles", "connawiles", "kuropixel", "cloudsixteen",
	"cloud sixteen"
}

function PLUGIN:OnPluginsLoaded()
	local contents = fileio.Read("data/flux_blacklist.txt")

	if (isstring(contents)) then
		blacklist = pon.decode(contents) or {}
	end
end

function PLUGIN:CheckPassword(steamID64, ip, password, clPassword, name)
	local steamid = util.SteamIDFrom64(steamID64)
	local entry = blacklist[steamid]

	if (entry) then
		print("Dropping "..name.." for being in the blacklist. Entry: "..steamid)

		return false, entry
	end

	if (isstring(name)) then
		local lowerName = string.utf8lower(name)

		for k, v in ipairs(badKeywords) do
			if (string.find(name, v, 1, true)) then
				blacklist[steamid] = defaultReason

				fileio.Write("data/flux_blacklist.txt", pon.encode(blacklist))

				print("Dropping "..name.." for having bad keyword '"..v.."' in their name!")

				return false, defaultReason
			end
		end
	end
end