--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]PLUGIN:SetName("TeslaCloud Blacklist")
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
  ["STEAM_0:0:81566201"] = "Go lick kuro's butt some more :)", -- ross
  -- TNF community players and admins
  ["STEAM_0:0:53046893"] = "You have been blacklisted due to bad affiliations!", -- [TNF]AnalCaptain
  ["STEAM_0:0:43712567"] = "You have been blacklisted due to bad affiliations!", -- 🔰[TNF][CUPS]Cup of Tea🔰
  ["STEAM_0:0:59648570"] = "You have been blacklisted due to bad affiliations!", -- Blender 2.78
  ["STEAM_0:0:86748785"] = "You have been blacklisted due to bad affiliations!", -- 🔰[THF][CUPS]Cup of Anime🔰
  ["STEAM_0:1:10947122"] = "You have been blacklisted due to bad affiliations!" -- [TNF] Vesthamer
}

local badKeywords = {
  "[tnf]", "[ tnf ]", "[ tnf]", "[tnf ]", " tnf ",
  "[tnf", "(tnf", "(tnf)", "tnf)", "the new future", "( tnf", "tnf )",
  "kurozael", "conna wiles", "connawiles", "kuropixel", "cloudsixteen",
  "cloud sixteen"
}

function PLUGIN:OnPluginsLoaded()
  local contents = file.Read("flux_blacklist.txt", "DATA")

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

        file.Write("flux_blacklist.txt", pon.encode(blacklist))

        print("Dropping "..name.." for having bad keyword '"..v.."' in their name!")

        return false, defaultReason
      end
    end
  end
end
