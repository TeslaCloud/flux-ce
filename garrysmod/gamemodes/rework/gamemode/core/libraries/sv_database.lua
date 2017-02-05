--[[
	mysql - 1.0.2
	A simple MySQL wrapper for Garry's Mod.

	Alexander Grist-Hucker
	http://www.alexgrist.com
--]]

library.New("db", rw)
local QueueTable = {}
rw.db.Module = rw.db.Module or config.Get("mysql_module") or "sqlite"
local Connected = false

if (rw.db.Module != "sqlite") then
	rw.core:DevPrint("Using "..rw.db.Module.." as MySQL module...")
	SafeRequire(rw.db.Module)
end

local type = type
local tostring = tostring
local table = table

--[[
	Phrases
--]]

local MODULE_NOT_EXIST = "[Rework:Database] The %s module does not exist!\n"

--[[
	Begin Query Class.
--]]

local QUERY_CLASS = {}
QUERY_CLASS.__index = QUERY_CLASS

function QUERY_CLASS:New(tableName, queryType)
	local newObject = setmetatable({}, QUERY_CLASS)
		newObject.queryType = queryType
		newObject.tableName = tableName
		newObject.selectList = {}
		newObject.insertList = {}
		newObject.updateList = {}
		newObject.createList = {}
		newObject.whereList = {}
		newObject.orderByList = {}
	return newObject
end

function QUERY_CLASS:Escape(text)
	return rw.db:Escape(tostring(text))
end

function QUERY_CLASS:ForTable(tableName)
	self.tableName = tableName
end

function QUERY_CLASS:Where(key, value)
	self:WhereEqual(key, value)
end

function QUERY_CLASS:WhereEqual(key, value)
	self.whereList[#self.whereList + 1] = "`"..key.."` = \""..self:Escape(value).."\""
end

function QUERY_CLASS:WhereNotEqual(key, value)
	self.whereList[#self.whereList + 1] = "`"..key.."` != \""..self:Escape(value).."\""
end

function QUERY_CLASS:WhereLike(key, value)
	self.whereList[#self.whereList + 1] = "`"..key.."` LIKE \""..self:Escape(value).."\""
end

function QUERY_CLASS:WhereNotLike(key, value)
	self.whereList[#self.whereList + 1] = "`"..key.."` NOT LIKE \""..self:Escape(value).."\""
end

function QUERY_CLASS:WhereGT(key, value)
	self.whereList[#self.whereList + 1] = "`"..key.."` > \""..self:Escape(value).."\""
end

function QUERY_CLASS:WhereLT(key, value)
	self.whereList[#self.whereList + 1] = "`"..key.."` < \""..self:Escape(value).."\""
end

function QUERY_CLASS:WhereGTE(key, value)
	self.whereList[#self.whereList + 1] = "`"..key.."` >= \""..self:Escape(value).."\""
end

function QUERY_CLASS:WhereLTE(key, value)
	self.whereList[#self.whereList + 1] = "`"..key.."` <= \""..self:Escape(value).."\""
end

function QUERY_CLASS:OrderByDesc(key)
	self.orderByList[#self.orderByList + 1] = "`"..key.."` DESC"
end

function QUERY_CLASS:OrderByAsc(key)
	self.orderByList[#self.orderByList + 1] = "`"..key.."` ASC"
end

function QUERY_CLASS:Callback(queryCallback)
	self.callback = queryCallback
end

function QUERY_CLASS:Select(fieldName)
	self.selectList[#self.selectList + 1] = "`"..fieldName.."`"
end

function QUERY_CLASS:Insert(key, value)
	self.insertList[#self.insertList + 1] = {"`"..key.."`", "\""..self:Escape(value).."\""}
end

function QUERY_CLASS:Update(key, value)
	self.updateList[#self.updateList + 1] = {"`"..key.."`", "\""..self:Escape(value).."\""}
end

function QUERY_CLASS:Create(key, value)
	self.createList[#self.createList + 1] = {"`"..key.."`", value}
end

function QUERY_CLASS:PrimaryKey(key)
	self.primaryKey = "`"..key.."`"
end

function QUERY_CLASS:Limit(value)
	self.limit = value
end

function QUERY_CLASS:Offset(value)
	self.offset = value
end

local function BuildSelectQuery(queryObj)
	local queryString = {"SELECT"}

	if (!istable(queryObj.selectList) or #queryObj.selectList == 0) then
		queryString[#queryString + 1] = " *"
	else
		queryString[#queryString + 1] = " "..table.concat(queryObj.selectList, ", ")
	end

	if (isstring(queryObj.tableName)) then
		queryString[#queryString + 1] = " FROM `"..queryObj.tableName.."` "
	else
		ErrorNoHalt("[Rework:Database] No table name specified!\n")
		return
	end

	if (istable(queryObj.whereList) and #queryObj.whereList > 0) then
		queryString[#queryString + 1] = " WHERE "
		queryString[#queryString + 1] = table.concat(queryObj.whereList, " AND ")
	end

	if (istable(queryObj.orderByList) and #queryObj.orderByList > 0) then
		queryString[#queryString + 1] = " ORDER BY "
		queryString[#queryString + 1] = table.concat(queryObj.orderByList, ", ")
	end

	if (isnumber(queryObj.limit)) then
		queryString[#queryString + 1] = " LIMIT "
		queryString[#queryString + 1] = queryObj.limit
	end

	return table.concat(queryString)
end

local function BuildInsertQuery(queryObj)
	local queryString = {"INSERT INTO"}
	local keyList = {}
	local valueList = {}

	if (isstring(queryObj.tableName)) then
		queryString[#queryString + 1] = " `"..queryObj.tableName.."`"
	else
		ErrorNoHalt("[Rework:Database] No table name specified!\n")
		return
	end

	for i = 1, #queryObj.insertList do
		keyList[#keyList + 1] = queryObj.insertList[i][1]
		valueList[#valueList + 1] = queryObj.insertList[i][2]
	end

	if (#keyList == 0) then
		return
	end

	queryString[#queryString + 1] = " ("..table.concat(keyList, ", ")..")"
	queryString[#queryString + 1] = " VALUES ("..table.concat(valueList, ", ")..")"

	return table.concat(queryString)
end

local function BuildUpdateQuery(queryObj)
	local queryString = {"UPDATE"}

	if (isstring(queryObj.tableName)) then
		queryString[#queryString + 1] = " `"..queryObj.tableName.."`"
	else
		ErrorNoHalt("[Rework:Database] No table name specified!\n")
		return
	end

	if (istable(queryObj.updateList) and #queryObj.updateList > 0) then
		local updateList = {}

		queryString[#queryString + 1] = " SET"

		for i = 1, #queryObj.updateList do
			updateList[#updateList + 1] = queryObj.updateList[i][1].." = "..queryObj.updateList[i][2]
		end

		queryString[#queryString + 1] = " "..table.concat(updateList, ", ")
	end

	if (istable(queryObj.whereList) and #queryObj.whereList > 0) then
		queryString[#queryString + 1] = " WHERE "
		queryString[#queryString + 1] = table.concat(queryObj.whereList, " AND ")
	end

	if (isnumber(queryObj.offset)) then
		queryString[#queryString + 1] = " OFFSET "
		queryString[#queryString + 1] = queryObj.offset
	end

	return table.concat(queryString)
end

local function BuildDeleteQuery(queryObj)
	local queryString = {"DELETE FROM"}

	if (isstring(queryObj.tableName)) then
		queryString[#queryString + 1] = " `"..queryObj.tableName.."`"
	else
		ErrorNoHalt("[Rework:Database] No table name specified!\n")
		return
	end

	if (istable(queryObj.whereList) and #queryObj.whereList > 0) then
		queryString[#queryString + 1] = " WHERE "
		queryString[#queryString + 1] = table.concat(queryObj.whereList, " AND ")
	end

	if (isnumber(queryObj.limit)) then
		queryString[#queryString + 1] = " LIMIT "
		queryString[#queryString + 1] = queryObj.limit
	end

	return table.concat(queryString)
end

local function BuildDropQuery(queryObj)
	local queryString = {"DROP TABLE"}

	if (isstring(queryObj.tableName)) then
		queryString[#queryString + 1] = " `"..queryObj.tableName.."`"
	else
		ErrorNoHalt("[Rework:Database] No table name specified!\n")
		return
	end

	return table.concat(queryString)
end

local function BuildTruncateQuery(queryObj)
	local queryString = {"TRUNCATE TABLE"}

	if (isstring(queryObj.tableName)) then
		queryString[#queryString + 1] = " `"..queryObj.tableName.."`"
	else
		ErrorNoHalt("[Rework:Database] No table name specified!\n")
		return
	end

	return table.concat(queryString)
end

local function BuildCreateQuery(queryObj)
	local queryString = {"CREATE TABLE IF NOT EXISTS"}

	if (isstring(queryObj.tableName)) then
		queryString[#queryString + 1] = " `"..queryObj.tableName.."`"
	else
		ErrorNoHalt("[Rework:Database] No table name specified!\n")
		return
	end

	queryString[#queryString + 1] = " ("

	if (istable(queryObj.createList) and #queryObj.createList > 0) then
		local createList = {}

		for i = 1, #queryObj.createList do
			if (rw.db.Module == "sqlite") then
				createList[#createList + 1] = queryObj.createList[i][1].." "..string.gsub(string.gsub(string.gsub(queryObj.createList[i][2], "AUTO_INCREMENT", ""), "AUTOINCREMENT", ""), "INT ", "INTEGER ")
			else
				createList[#createList + 1] = queryObj.createList[i][1].." "..queryObj.createList[i][2]
			end
		end

		queryString[#queryString + 1] = " "..table.concat(createList, ", ")
	end

	if (isstring(queryObj.primaryKey)) then
		queryString[#queryString + 1] = ", PRIMARY KEY"
		queryString[#queryString + 1] = " ("..queryObj.primaryKey..")"
	end

	queryString[#queryString + 1] = " )"

	return table.concat(queryString);
end

function QUERY_CLASS:Execute(bQueueQuery)
	local queryString = nil
	local queryType = string.lower(self.queryType)

	if (queryType == "select") then
		queryString = BuildSelectQuery(self)
	elseif (queryType == "insert") then
		queryString = BuildInsertQuery(self)
	elseif (queryType == "update") then
		queryString = BuildUpdateQuery(self)
	elseif (queryType == "delete") then
		queryString = BuildDeleteQuery(self)
	elseif (queryType == "drop") then
		queryString = BuildDropQuery(self)
	elseif (queryType == "truncate") then
		queryString = BuildTruncateQuery(self)
	elseif (queryType == "create") then
		queryString = BuildCreateQuery(self)
	end

	if (isstring(queryString)) then
		if (!bQueueQuery) then
			return rw.db:RawQuery(queryString, self.callback)
		else
			return rw.db:Queue(queryString, self.callback)
		end
	end
end

--[[
	End Query Class.
--]]

function rw.db:Select(tableName)
	return QUERY_CLASS:New(tableName, "SELECT")
end

function rw.db:Insert(tableName)
	return QUERY_CLASS:New(tableName, "INSERT")
end

function rw.db:Update(tableName)
	return QUERY_CLASS:New(tableName, "UPDATE")
end

function rw.db:Delete(tableName)
	return QUERY_CLASS:New(tableName, "DELETE")
end

function rw.db:Drop(tableName)
	return QUERY_CLASS:New(tableName, "DROP")
end

function rw.db:Truncate(tableName)
	return QUERY_CLASS:New(tableName, "TRUNCATE")
end

function rw.db:Create(tableName)
	return QUERY_CLASS:New(tableName, "CREATE")
end

-- A function to connect to the MySQL database.
function rw.db:Connect(host, username, password, database, port, socket, flags)
	if (!port) then
		port = 3306
	end

	if (rw.db.Module == "tmysql4") then
		if (!istable(tmysql)) then
			require("tmysql4")
		end

		if (tmysql) then
			local errorText = nil

			self.connection, errorText = tmysql.initialize(host, username, password, database, port, socket, flags)

			if (!self.connection) then
				self:OnConnectionFailed(errorText)
			else
				self:OnConnected()
			end
		else
			ErrorNoHalt(string.format(MODULE_NOT_EXIST, rw.db.Module))
		end
	elseif (rw.db.Module == "mysqloo") then
		if (!istable(mysqloo)) then
			require("mysqloo")
		end

		if (mysqloo) then
			local clientFlag = flags or 0

			if (!isstring(socket)) then
				self.connection = mysqloo.connect(host, username, password, database, port)
			else
				self.connection = mysqloo.connect(host, username, password, database, port, socket, clientFlag)
			end

			self.connection.onConnected = function(database)
				rw.db:OnConnected()
			end

			self.connection.onConnectionFailed = function(database, errorText)
				rw.db:OnConnectionFailed(errorText)
			end		

			self.connection:connect()
		else
			ErrorNoHalt(string.format(MODULE_NOT_EXIST, rw.db.Module))
		end
	elseif (rw.db.Module == "sqlite") then
		rw.db:OnConnected()
	end
end

-- A function to query the MySQL database.
function rw.db:RawQuery(query, callback, flags, ...)
	if (!self.connection and self.Module != "sqlite") then
		self:Queue(query)
	end

	if (self.Module == "tmysql4") then
		local queryFlag = flags or QUERY_FLAG_ASSOC

		self.connection:Query(query, function(result)
			local queryStatus = result[1]["status"]

			if (queryStatus) then
				if (isfunction(callback)) then
					local bStatus, value = pcall(callback, result[1]["data"], queryStatus, result[1]["lastid"])

					if (!bStatus) then
						ErrorNoHalt(string.format("[Rework:Database] MySQL Callback Error!\n%s\n", value))
					end
				end
			else
				ErrorNoHalt(string.format("[Rework:Database] MySQL Query Error!\nQuery: %s\n%s\n", query, result[1]["error"]))
			end
		end, queryFlag, ...)
	elseif (self.Module == "mysqloo") then
		local queryObj = self.connection:query(query)

		queryObj:setOption(mysqloo.OPTION_NAMED_FIELDS)

		queryObj.onSuccess = function(queryObj, result)
			if (callback) then
				-- FFFFFFFUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU
				local bStatus, value = pcall(callback, result)//, queryObj:status(), queryObj:lastInsert())

				if (!bStatus) then
					ErrorNoHalt(string.format("[Rework:Database] MySQL Callback Error!\n%s\n", value))
				end
			end
		end

		queryObj.onError = function(queryObj, errorText)
			ErrorNoHalt(string.format("[Rework:Database] MySQL Query Error!\nQuery: %s\n%s\n", query, errorText))
		end

		queryObj:start()
	elseif (rw.db.Module == "sqlite") then
		local result = sql.Query(query)

		if (result == false) then
			ErrorNoHalt(string.format("[Rework:Database] SQL Query Error!\nQuery: %s\n%s\n", query, sql.LastError()))
		else
			if (callback) then
				local bStatus, value = pcall(callback, result)

				if (!bStatus) then
					ErrorNoHalt(string.format("[Rework:Database] SQL Callback Error!\n%s\n", value))
				end
			end
		end
	else
		ErrorNoHalt(string.format("[Rework:Database] Unsupported module \"%s\"!\n", rw.db.Module))
	end
end

-- A function to add a query to the queue.
function rw.db:Queue(queryString, callback)
	if (isstring(queryString)) then
		QueueTable[#QueueTable + 1] = {queryString, callback}
	end
end

-- A function to escape a string for MySQL.
function rw.db:Escape(text)
	if (self.connection) then
		if (rw.db.Module == "tmysql4") then
			return self.connection:Escape(text)
		elseif (rw.db.Module == "mysqloo") then
			return self.connection:escape(text)
		end
	else
		return sql.SQLStr(string.gsub(text, "\"", "'"), true)
	end
end

-- A function to disconnect from the MySQL database.
function rw.db:Disconnect()
	if (self.connection) then
		if (rw.db.Module == "tmysql4") then
			return self.connection:Disconnect();	
		end
	end

	Connected = false
end

function rw.db:Think()
	if (#QueueTable > 0) then
		if (istable(QueueTable[1])) then
			local queueObj = QueueTable[1]
			local queryString = queueObj[1]
			local callback = queueObj[2]

			if (isstring(queryString)) then
				self:RawQuery(queryString, callback)
			end

			table.remove(QueueTable, 1)
		end
	end
end

-- A function to set the module that should be used.
function rw.db:SetModule(moduleName)
	rw.db.Module = moduleName
end

-- Called when the database connects sucessfully.
function rw.db:OnConnected()
	MsgC(Color(25, 235, 25), "[Rework:Database] Connected to the database using "..rw.db.Module.."!\n")

	local queryObj = self:Create("rw_bans")
		queryObj:Create("key", "INT NOT NULL AUTO_INCREMENT")
		queryObj:Create("steamID", "VARCHAR(25) NOT NULL")
		queryObj:Create("name", "VARCHAR(255) NOT NULL")
		queryObj:Create("unbanTime", "INT NOT NULL")
		queryObj:Create("banTime", "INT DEFAULT NULL")
		queryObj:Create("reason", "TEXT DEFAULT NULL")
		queryObj:Create("permaban", "BOOL NOT NULL")
		queryObj:PrimaryKey("key")
	queryObj:Execute()

	local queryObj = self:Create("rw_players")
		queryObj:Create("key", "INT NOT NULL AUTO_INCREMENT")
		queryObj:Create("steamID", "VARCHAR(25) NOT NULL")
		queryObj:Create("name", "VARCHAR(255) NOT NULL")
		queryObj:Create("joinTime", "INT DEFAULT NULL")
		queryObj:Create("lastPlayTime", "INT DEFAULT NULL")
		queryObj:Create("userGroup", "TEXT NOT NULL")
		queryObj:Create("secondaryGroups", "TEXT DEFAULT NULL")
		queryObj:Create("customPermissions", "TEXT DEFAULT NULL")
		queryObj:Create("data", "TEXT DEFAULT NULL")
		queryObj:Create("whitelists", "TEXT DEFAULT NULL")
		queryObj:PrimaryKey("key")
	queryObj:Execute()

	if (!rw.SchemaDisabled("characters")) then
		local queryObj = self:Create("rw_characters")
			queryObj:Create("key", "INT NOT NULL AUTO_INCREMENT")
			queryObj:Create("steamID", "VARCHAR(25) NOT NULL")
			queryObj:Create("name", "VARCHAR(255) NOT NULL")
			queryObj:Create("faction", "TEXT NOT NULL")
			queryObj:Create("model", "TEXT NOT NULL")
			queryObj:Create("class", "TEXT DEFAULT NULL")
			queryObj:Create("physDesc", "TEXT DEFAULT NULL")
			queryObj:Create("inventory", "TEXT DEFAULT NULL")
			queryObj:Create("ammo", "TEXT DEFAULT NULL")
			queryObj:Create("money", "INT DEFAULT NULL")
			queryObj:Create("uniqueID", "INT DEFAULT NULL")
			queryObj:Create("charPermissions", "TEXT DEFAULT NULL")
			queryObj:Create("data", "TEXT DEFAULT NULL")
			queryObj:PrimaryKey("key")
		queryObj:Execute()
	end

	local queryObj = self:Create("rw_logs")
		queryObj:Create("key", "INT NOT NULL AUTO_INCREMENT")
		queryObj:Create("entry", "TEXT NOT NULL")
		queryObj:PrimaryKey("key")
	queryObj:Execute()

	Connected = true
	hook.Run("DatabaseConnected")
end

-- Called when the database connection fails.
function rw.db:OnConnectionFailed(errorText)
	ErrorNoHalt("[Rework:Database] Unable to connect to the database!\n"..errorText.."\n")

	hook.Run("DatabaseConnectionFailed", errorText)
end

-- A function to check whether or not the module is connected to a database.
function rw.db:IsConnected()
	return Connected
end

function rw.db:EasyWrite(tableName, where, data)
	if (!data or !istable(data)) then
		ErrorNoHalt("[Rework] Easy MySQL error! Data has unexpected value type (table expected, got "..type(data)..")\n")
		return
	end

	if (!where) then
		ErrorNoHalt("[Rework] Easy MySQL error! 'where' table is malformed! ([1] = "..type(where[1])..", [2] = "..type(where[2])..")\n")
		return
	end

	local query = self:Select(tableName)
		if (istable(where[1])) then
			for k, v in pairs(where) do
				query:Where(v[1], v[2])
			end
		else
			query:Where(where[1], where[2])
		end

		query:Callback(function(result, status, lastID)
			if (istable(result) and #result > 0) then
				local updateObj = self:Update(tableName)

					for k, v in pairs(data) do
						updateObj:Update(k, v)
					end

					updateObj:Where(where[1], where[2])
					updateObj:Callback(function()
						rw.core:DevPrint("Easy MySQL updated data. ('"..tableName.."' WHERE "..where[1].." = "..where[2]..")")
					end)

				updateObj:Execute()
			else
				local insertObj = self:Insert(tableName)

					for k, v in pairs(data) do
						insertObj:Insert(k, v)
					end

					insertObj:Callback(function(result)
						if (!istable(where[1])) then
							rw.core:DevPrint("Easy MySQL inserted data into '"..tableName.."' WHERE "..where[1].." = "..where[2]..".")
						else
							local msg = "Easy MySQL inserted data into '"..tableName.."' WHERE "
							local i = 0

							for k, v in pairs(where) do
								i = i + 1
								msg = msg..v[1].." = "..v[2]

								if (table.Count(where) != i) then
									msg = msg.." AND "
								end
							end

							rw.core:DevPrint(msg)
						end
					end)

				insertObj:Execute()
			end
		end)

	query:Execute()
end

function rw.db:EasyRead(tableName, where, callback)
	if (!where) then
		ErrorNoHalt("[Rework] Easy MySQL Read error! 'where' table is malformed! ([1] = "..type(where[1])..", [2] = "..type(where[2])..")\n")
		return false
	end

	local query = self:Select(tableName)
		if (istable(where[1])) then
			for k, v in pairs(where) do
				query:Where(v[1], v[2])
			end
		else
			query:Where(where[1], where[2])
		end

		query:Callback(function(result)
			rw.core:DevPrint("Easy MySQL has successfully read the data!")

			local success, value = pcall(callback, result, (istable(result) and #result > 0))

			if (!success) then
				ErrorNoHalt("[RW:EasyRead Error] "..value.."\n")
			end
		end)

	query:Execute()
end

timer.Create("Rework.Database.Think", 1, 0, function()
	rw.db:Think()
end)