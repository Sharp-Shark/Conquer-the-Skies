CTS.saving = {}

-- The path to the save file
CTS.saving.folderPath = 'LocalMods/'
CTS.saving.savePath = CTS.saving.folderPath .. 'Conquer the Skies.json'

-- Which keys should have their values saved
CTS.saving.keys = {
	'NoWaterClass.Type.OutsideHasAir',
}

-- Get any value from the table CTS
CTS.saving.get = function (path)
	local value = CTS
	for key in CTS.stringSplit(path, '.') do
		if value == nil then return end
		value = value[key]
	end
	return value
end

-- Set any value from the table CTS
CTS.saving.set = function (path, new)
	local value = CTS
	local counter = CTS.tableSize(CTS.stringSplit(path, '.'))
	for key in CTS.stringSplit(path, '.') do
		if value == nil then return end
		if counter == 1 then
			value[key] = new
		end
		value = value[key]
		counter = counter - 1
	end
	return value
end

-- Loads from file
CTS.saving.load = function (keys, filePath)
	local filePath = filePath or CTS.saving.savePath
	
	local tbl = json.parse(File.Read(filePath))
	local keys = keys or CTS.saving.keys
	for key in keys do
		if tbl[key] ~= nil then
			CTS.saving.set(key, tbl[key])
		end
	end
	return json.parse(File.Read(filePath))
end

-- Saves to file
CTS.saving.save = function (keys, filePath)
	local filePath = filePath or CTS.saving.savePath
	
	local tbl = {}
	if keys ~= nil then tbl = json.parse(File.Read(filePath)) end
	local keys = keys or CTS.saving.keys
	for key in keys do
		tbl[key] = CTS.saving.get(key)
	end
	File.Write(filePath, json.serialize(tbl))
	return json.serialize(tbl)
end

-- Print save file
CTS.saving.debug = function ()
	CTS.tablePrint(json.parse(File.Read(CTS.saving.savePath)), nil, 1)
end

-- Does setup. Then loads and updates save file if it exists
CTS.saving.boot = function ()
	if not File.Exists(CTS.saving.savePath) then
		CTS.saving.save()
		print('No save file was found, so one was created at ' .. CTS.saving.savePath)
	else
		CTS.saving.load()
		CTS.saving.save()
	end
end

-- Commands
-- Debug console cts_toggleoxygen
local func = function (args)
	local bool = not CTS.NoWaterClass.Type.OutsideHasAir
	CTS.setOutsideHasOxygen(bool)
	if bool then
		print('Enabled oxygen outside.')
	else
		print('Disabled oxygen outside.')
	end

	if SERVER then
		local message = Networking.Start("cts_setOutsideHasOxygen")
		message.WriteBoolean(CTS.NoWaterClass.Type.OutsideHasAir)
		Networking.Send(message)
	end

	CTS.saving.save()
end
if CLIENT and Game.IsMultiplayer then
	func = function () return end
end
Game.AddCommand('cts_toggleoxygen', 'Toggles whether there is or isn\'t oxygen outside.', func, nil, false)