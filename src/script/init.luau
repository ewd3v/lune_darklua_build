-- selene: allow(global_usage)
if not _G.LUA_ENV then
	_G.LUA_ENV = "lune"
end

local args = require("@lune/process").args
local lib = require("./lib")

local pathfs = require("@pkg/pathfs")

local serde = require("@lune/serde")
local supportedSerdeFormats = { "json", "toml", "yaml" }

local DEFAULT_CONFIG = ".darklua.build"

local config
local input = "src"
local output = "out"
local options: lib.Options = {}

local configIndex = table.find(args, "--config") or table.find(args, "-c")
if configIndex then
	config = assert(args[configIndex + 1], "no config provided")
end

local configFile
if config then
	configFile = pathfs.FilePath.new(config)
end

if not configFile or not configFile:isFile() then
	-- Search for default config files
	for _, format in ipairs(supportedSerdeFormats) do
		configFile = pathfs.FilePath.new(DEFAULT_CONFIG .. "." .. format)
		if (configFile :: pathfs.FilePath):isFile() then
			break
		end
	end
end

if configFile:isFile() then
	local workingDir = configFile.path:parent() or pathfs.cwd()
	options.cwd = workingDir

	local extension = configFile.path:extension() or "toml"
	if not table.find(supportedSerdeFormats, extension) then
		error(`Config extension ".{extension}" is not supported.`)
	end

	local configContent = serde.decode(extension :: any, configFile:readFile())
	if configContent.input then
		input = configContent.input
	end
	if configContent.output then
		output = configContent.output
	end

	if configContent.options then
		for option, value in configContent.options do
			if option == "cwd" then
				-- Set cwd relative to file
				value = configFile.path:join(value)
			end

			options[option] = value
		end
	end
end

local argOptions: { [string]: (string?) -> () } = {
	["--input -i"] = function(newInput)
		input = assert(newInput, "no input provided")
	end,
	["--output -o"] = function(newOutput)
		output = assert(newOutput, "no output provided")
	end,
	["--silent -s"] = function()
		options.silent = true
	end,
	["--watch -w"] = function()
		options.watch = true
	end,
}

for flags, callback in argOptions do
	for _, flag in ipairs(string.split(flags, " ")) do
		local index = table.find(args, flag)
		if not index then
			continue
		end

		callback(args[index + 1])
		break
	end
end

lib(input, output, options)
