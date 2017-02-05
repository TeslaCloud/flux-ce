--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library.New("urlmat", rw)
local cache = rw.urlmat.cache or {}
rw.urlmat.cache = cache

local loading = {}

function rw.urlmat:CacheMaterial(url)
	if (isstring(url) and url != "") then
		local urlCRC = util.CRC(url)
		local exploded = string.Explode("/", url)

		if (istable(exploded) and #exploded > 0) then
			local extension = string.GetExtensionFromFilename(exploded[#exploded])

			if (extension) then
				local extension = "."..extension
				local path = "rework/materials/"..urlCRC..extension

				if (_file.Exists(path, "DATA")) then
					cache[urlCRC] = Material("../data/"..path, "noclamp smooth");
					return
				end

				local directories = string.Explode("/", path)
				local currentPath = ""

				for k, v in pairs(directories) do
					if (k < #directories) then
						currentPath = currentPath..v.."/"
						file.CreateDir(currentPath)
					end
				end

				http.Fetch(url, function(body, length, headers, code)
					path = path:gsub(".jpeg", ".jpg")
					file.Write(path, body)
					cache[urlCRC] = Material("../data/"..path, "noclamp smooth")

					hook.Run("OnURLMatLoaded", url, cache[urlCRC])
				end)
			end
		end
	end
end

local placeholder = Material("vgui/wave")

function URLMaterial(url)
	local urlCRC = util.CRC(url)

	if (cache[urlCRC]) then
		return cache[urlCRC]
	end

	if (!loading[urlCRC]) then
		rw.urlmat:CacheMaterial(url)
		loading[urlCRC] = true; -- we're in progress!
	end

	return placeholder; -- return some placeholder material while we download
end