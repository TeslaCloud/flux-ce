--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

-- A function to get lowercase type of an object.
function typeof(obj)
	return type(obj):lower();
end;

function Try(id, func, ...)
	id = id or "Try";
	local result = {pcall(func, ...)};
	local success = result[1];
	table.remove(result, 1);

	if (!success) then
		ErrorNoHalt("[Rework:"..id.."] Failed to run the function!\n");
		ErrorNoHalt(unpack(result), "\n");
	elseif (result[1] != nil) then
		return unpack[result];
	end;
end;

do
	local materialCache = {};

	function util.GetMaterial(mat)
		materialCache[mat] = materialCache[mat] or Material(mat);
		return materialCache[mat];
	end;
end;

base64 = base64 or {};

local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
-- encoding
function base64.encode(data)
	return ((data:gsub('.', function(x) 
		local r, b = '', x:byte();

		for i = 8, 1, -1 do 
			r = r..(b%2^i - b%2^(i - 1) > 0 and '1' or '0') 
		end

		return r;
	end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
		if (#x < 6) then return '' end

		local c=0

		for i = 1, 6 do 
			c = c + (x:sub(i, i) == '1' and 2^(6 - i) or 0) 
		end

		return b:sub(c + 1, c + 1)
	end)..({ '', '==', '=' })[#data%3 + 1])
end

-- decoding
function base64.decode(data)
	data = string.gsub(data, '[^'..b..'=]', '')
	return (data:gsub('.', function(x)
		if (x == '=') then return '' end

		local r, f='',(b:find(x)-1)

		for i = 6, 1, -1 do
			r = r..(f%2^i - f%2^(i - 1) > 0 and '1' or '0')
		end

		return r;
	end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
		if (#x != 8) then return '' end

		local c = 0

		for i=1,8 do
			c = c + (x:sub(i, i) == '1' and 2^(8 - i) or 0)
		end

		return string.char(c)
	end))
end

-- A function to convert a single hexadecimal digit to decimal.
function util.HexToDec(hex)
	if (type(hex) == "number") then return hex; end;

	hex = hex:lower();

	local hexDigits = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"};
	local negative = false;

	if (hex:StartWith("-")) then
		hex = hex:sub(2, 2);
		negative = true;
	end;

	for k, v in ipairs(hexDigits) do
		if (v == hex) then
			if (!negative) then
				return k - 1;
			else
				return -(k - 1);
			end;
		end;
	end;

	ErrorNoHalt("[Catwork] '"..hex.."' is not a hexadecimal number!");
	return 0;
end;

function util.HexToDecimal(hex)
	if (type(hex) == "number") then return hex; end;

	local sum = 0;
	local chars = table.Reverse(string.Explode("", hex))
	local idx = 1;

	for i = 0, hex:len() - 1 do
		sum = sum + util.HexToDec(chars[idx]) * math.pow(16, i);
		idx = idx + 1;
	end;

	return sum;
end;

-- A function to convert hexadecimal color to a color structure.
function util.HexToColor(hex)
	if (hex:StartWith("#")) then
		hex = hex:sub(2, hex:len());
	end;

	if (hex:len() != 6 and hex:len() != 8) then
		return Color(255, 255, 255);
	end;

	local hexColors = {};
	local initLen = hex:len() / 2;

	for i = 1, hex:len() / 2 do
		table.insert(hexColors, hex:sub(1, 2))
		
		if (i != initLen) then
			hex = hex:sub(3, hex:len());
		end;
	end;

	local color = {};

	for k, v in ipairs(hexColors) do
		local chars = table.Reverse(string.Explode("", v));
		local sum = 0;
		
		for i = 1, 2 do
			sum = sum + util.HexToDec(chars[i]) * math.pow(16, i - 1);
		end;
		
		table.insert(color, sum);
	end;

	return Color(color[1], color[2], color[3], (color[4] or 255));
end;

local colors = {
	aliceblue 		= Color(240, 248, 255),
	antiquewhite 	= Color(250, 235, 215),
	aqua 			= Color(0, 255, 255),
	aquamarine 		= Color(127, 255, 212),
	azure		 	= Color(240, 255, 255),
	beige 			= Color(245, 245, 220),
	bisque 			= Color(255, 228, 196),
	black 			= Color(0, 0, 0),
	blanchedalmond 	= Color(255, 235, 205),
	blue 			= Color(0, 0, 255),
	blueviolet 		= Color(138, 43, 226),
	brown 			= Color(165, 42, 42),
	burlywood	 	= Color(222, 184, 135),
	cadetblue 		= Color(95, 158, 160),
	chartreuse 		= Color(127, 255, 0),
	chocolate 		= Color(210, 105, 30),
	coral			= Color(255, 127, 80),
	cornflowerblue 	= Color(100, 149, 237),
	cornsilk 		= Color(255, 248, 220),
	crimson 		= Color(220, 20, 60),
	cyan 			= Color(0, 255, 255),
	darkblue 		= Color(0, 0, 139),
	darkcyan 		= Color(0, 139, 139),
	darkgoldenrod 	= Color(184, 134, 11),
	darkgray 		= Color(169, 169, 169),
	darkgreen 		= Color(0, 100, 0),
	darkgrey 		= Color(169, 169, 169),
	darkkhaki 		= Color(189, 183, 107),
	darkmagenta 	= Color(139, 0, 139),
	darkolivegreen 	= Color(85, 107, 47),
	darkorange 		= Color(255, 140, 0),
	darkorchid 		= Color(153, 50, 204),
	darkred 		= Color(139, 0, 0),
	darksalmon 		= Color(233, 150, 122),
	darkseagreen 	= Color(143, 188, 143),
	darkslateblue 	= Color(72, 61, 139),
	darkslategray 	= Color(47, 79, 79),
	darkslategrey 	= Color(47, 79, 79),
	darkturquoise 	= Color(0, 206, 209),
	darkviolet 		= Color(148, 0, 211),
	deeppink 		= Color(255, 20, 147),
	deepskyblue 	= Color(0, 191, 255),
	dimgray 		= Color(105, 105, 105),
	dimgrey 		= Color(105, 105, 105),
	dodgerblue 		= Color(30, 144, 255),
	firebrick 		= Color(178, 34, 34),
	floralwhite 	= Color(255, 250, 240),
	forestgreen 	= Color(34, 139, 34),
	fuchsia 		= Color(255, 0, 255),
	gainsboro 		= Color(220, 220, 220),
	ghostwhite 		= Color(248, 248, 255),
	gold 			= Color(255, 215, 0),
	goldenrod 		= Color(218, 165, 32),
	gray 			= Color(128, 128, 128),
	grey 			= Color(128, 128, 128),
	green 			= Color(0, 128, 0),
	greenyellow 	= Color(173, 255, 47),
	honeydew 		= Color(240, 255, 240),
	hotpink 		= Color(255, 105, 180),
	indianred 		= Color(205, 92, 92),
	indigo 			= Color(75, 0, 130),
	ivory 			= Color(255, 255, 240),
	khaki 			= Color(240, 230, 140),
	lavender 		= Color(230, 230, 250),
	lavenderblush 	= Color(255, 240, 245),
	lawngreen 		= Color(124, 252, 0),
	lemonchiffon 	= Color(255, 250, 205),
	lightblue 		= Color(173, 216, 230),
	lightcoral 		= Color(240, 128, 128),
	lightcyan 		= Color(224, 255, 255),
	lightgoldenrodyellow = Color(250, 250, 210),
	lightgray 		= Color(211, 211, 211),
	lightgreen 		= Color(144, 238, 144),
	lightgrey 		= Color(211, 211, 211),
	lightpink 		= Color(255, 182, 193),
	lightsalmon 	= Color(255, 160, 122),
	lightseagreen 	= Color(32, 178, 170),
	lightskyblue 	= Color(135, 206, 250),
	lightslategray 	= Color(119, 136, 153),
	lightslategrey 	= Color(119, 136, 153),
	lightsteelblue 	= Color(176, 196, 222),
	lightyellow 	= Color(255, 255, 224),
	lime 			= Color(0, 255, 0),
	limegreen 		= Color(50, 205, 50),
	linen 			= Color(250, 240, 230),
	magenta 		= Color(255, 0, 255),
	maroon 			= Color(128, 0, 0),
	mediumaquamarine = Color(102, 205, 170),
	mediumblue 		= Color(0, 0, 205),
	mediumorchid 	= Color(186, 85, 211),
	mediumpurple 	= Color(147, 112, 219),
	mediumseagreen 	= Color(60, 179, 113),
	mediumslateblue = Color(123, 104, 238),
	mediumspringgreen = Color(0, 250, 154),
	mediumturquoise = Color(72, 209, 204),
	mediumvioletred = Color(199, 21, 133),
	midnightblue 	= Color(25, 25, 112),
	mintcream 		= Color(245, 255, 250),
	mistyrose 		= Color(255, 228, 225),
	moccasin 		= Color(255, 228, 181),
	navajowhite 	= Color(255, 222, 173),
	navy		 	= Color(0, 0, 128),
	oldlace 		= Color(253, 245, 230),
	olive 			= Color(128, 128, 0),
	olivedrab 		= Color(107, 142, 35),
	orange 			= Color(255, 165, 0),
	orangered 		= Color(255, 69, 0),
	orchid 			= Color(218, 112, 214),
	palegoldenrod 	= Color(238, 232, 170),
	palegreen 		= Color(152, 251, 152),
	paleturquoise 	= Color(175, 238, 238),
	palevioletred 	= Color(219, 112, 147),
	papayawhip 		= Color(255, 239, 213),
	peachpuff 		= Color(255, 218, 185),
	peru 			= Color(205, 133, 63),
	pink 			= Color(255, 192, 203),
	plum 			= Color(221, 160, 221),
	powderblue 		= Color(176, 224, 230),
	purple 			= Color(128, 0, 128),
	red 			= Color(255, 0, 0),
	rosybrown 		= Color(188, 143, 143),
	royalblue 		= Color(65, 105, 225),
	saddlebrown 	= Color(139, 69, 19),
	salmon 			= Color(250, 128, 114),
	sandybrown 		= Color(244, 164, 96),
	seagreen 		= Color(46, 139, 87),
	seashell 		= Color(255, 245, 238),
	sienna 			= Color(160, 82, 45),
	silver 			= Color(192, 192, 192),
	skyblue 		= Color(135, 206, 235),
	slateblue 		= Color(106, 90, 205),
	slategray 		= Color(112, 128, 144),
	slategrey 		= Color(112, 128, 144),
	snow 			= Color(255, 250, 250),
	springgreen 	= Color(0, 255, 127),
	steelblue 		= Color(70, 130, 180),
	tan 			= Color(210, 180, 140),
	teal 			= Color(0, 128, 128),
	thistle			= Color(216, 191, 216),
	tomato 			= Color(255, 99, 71),
	turquoise 		= Color(64, 224, 208),
	violet 			= Color(238, 130, 238),
	wheat 			= Color(245, 222, 179),
	white 			= Color(255, 255, 255),
	whitesmoke 		= Color(245, 245, 245),
	yellow 			= Color(255, 255, 0),
	yellowgreen 	= Color(154, 205, 50)
};

rw.oldColor = rw.oldColor or Color;

function Color(r, g, b, a)
	if (typeof(r) == "string") then
		if (r:StartWith("#")) then
			return util.HexToColor(r);
		elseif (colors[r:lower()]) then
			return colors[r:lower()];
		else
			return Color(255, 255, 255);
		end;
	else
		return rw.oldColor(r, g, b, a);
	end;
end;

-- A function to do C-style formatted prints.
function printf(str, ...)
	print(Format(str, ...));
end;

-- Let's face it. When you develop for C++ you kinda want to do this in Lua.
function cout(...)
	print(...);
end;

-- A function to select a random player.
function player.Random()
	local allPly = player.GetAll();

	if (#allPly > 0) then
		return allPly[math.random(1, #allPly)];
	end;
end;

function player.Find(name, bCaseInsensitive)
	if (name == nil) then return; end;
	if (typeof(name) != "string" and IsValid(name)) then return name; end;
	if (typeof(name) != "string") then return; end;

	for k, v in ipairs(_player.GetAll()) do
		if (v:Name():find(name)) then
			return v;
		elseif (bCaseInsensitive and v:Name():utf8lower():find(name:utf8lower())) then
			return v;
		elseif (v:SteamID() == name) then
			return v;
		end;
	end;
end;

function string.FindAll(str, pattern)
	if (!str or !pattern) then return; end;

	local hits = {};
	local lastPos = 1;

	while (true) do
		local startPos, endPos = string.find(str, pattern, lastPos);
		
		if (!startPos) then
			break;
		end;
		
		table.insert(hits, {str:sub(startPos, endPos), startPos, endPos})
		
		lastPos = endPos + 1;
	end;

	return hits;
end;

function string.IsCommand(str)
	for k, v in ipairs(config.Get("command_prefixes")) do
		if (str:StartWith(v)) then
			return true;
		end;
	end;

	return false;
end;

function string.MakeID(str)
	str = str:lower();
	str = str:gsub(" ", "_");

	return str;
end;

function util.GetTextSize(font, text)
	surface.SetFont(font);

	return surface.GetTextSize(text);
end;

function util.GetFontSize(font)
	return util.GetTextSize(font, "abg");
end;

function util.GetTextHeight(font, text)
	local textW, textH = util.GetTextSize(font, text);

	return textH;
end;

function util.GetFontHeight(font)
	local textW, textH = util.GetFontSize(font, "abg");

	return textH;
end;

function util.GetPanelClass(panel)
	if (panel and panel.GetTable) then
		local pTable = panel:GetTable();

		if (pTable and pTable.ClassName) then
			return pTable.ClassName;
		end;
	end;
end;

-- Adjusts x, y to fit inside x2, y2 while keeping original aspect ratio.
function util.FitToAspect(x, y, x2, y2)
	local aspect = x / y;

	if (x > x2) then
		x = x2;
		y = x * aspect;
	end;

	if (y > y2) then
		y = y2;
		x = y * aspect;
	end;

	return x, y;
end;

function util.ToBool(value)
	return (tonumber(value) == 1 or value == true or value == "true");
end;

function util.CubicEaseIn(curStep, steps, from, to)
	return (to - from) * math.pow(curStep / steps, 3) + from;
end;

function util.CubicEaseOut(curStep, steps, from, to)
	return (to - from) * (math.pow(curStep / steps - 1, 3) + 1) + from;
end;

function util.CubicEaseInTable(steps, from, to)
	local result = {};

	for i = 1, steps do
		table.insert(result, util.CubicEaseIn(i, steps, from, to));
	end

	return result;
end;

function util.CubicEaseOutTable(steps, from, to)
	local result = {};

	for i = 1, steps do
		table.insert(result, util.CubicEaseOut(i, steps, from, to));
	end

	return result;
end;

function util.CubicEaseInOut(curStep, steps, from, to)
	if (curStep > (steps / 2)) then
		return util.CubicEaseOut(curStep - steps / 2, steps / 2, from, to);
	else
		return util.CubicEaseIn(curStep, steps, from, to);
	end
end;

function util.CubicEaseInOutTable(steps, from, to)
	local result = {};

	for i = 1, steps do
		table.insert(result, util.CubicEaseInOut(i, steps, from, to));
	end

	return result;
end;