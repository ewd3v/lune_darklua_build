local dirs = require("@pkg/dirs")
local pathfs = require("@pkg/pathfs")
local glob = require("@pkg/glob")

local stdio = require("@lune/stdio")
local task = require("@lune/task")
local process = require("@lune/process")

local fs = pathfs.fs
local Path = pathfs.Path

local progressbar = require("@self/progress")
local clr = stdio.color

type AsPath = pathfs.AsPath
type Path = pathfs.Path

type Files = { Path }

type Script<T...> = string | { string } | (T...) -> ()
export type Options = {
	cwd: AsPath?,
	include: { string }?,
	ignore: { string }?,
	darklua_config: AsPath?,

	silent: boolean?,
	watch: boolean?,

	temp_dir_location: AsPath?,
	-- temp_dir_name: string?, -- TODO: Figure out a "safe" way to add this without the risk of deleting user's files. Prompting would work, but is in the way of automation (another config like --yes flag?)
	temp_dir_keep: boolean?,

	scripts: {
		preProcess: Script<string>?,
		postProcess: Script<string>?,
	}?,
}

local function reconcileFiles(files: { Path }, into: Path, cwd: Path)
	for _, path in ipairs(files) do
		local destPath = into:join(assert(path:stripPrefix(cwd)))
		local destParentPath = destPath:parent()

		if destParentPath and not fs.isDir(destParentPath) then
			fs.writeDir(destParentPath)
		end

		if fs.isFile(path) then
			-- Copy whole files (if we use fs.copy, we may copy over read-only files)
			fs.writeFile(destPath, fs.readFile(path))
		elseif fs.isDir(path) then
			if fs.isDir(destPath) then
				continue
			end

			-- But don't copy folder contents
			fs.writeDir(destPath)
		end
	end
end

local function getBuildTime(start: number)
	return `{math.round((os.clock() - start) * 1000 * 10000) / 10000} ms`
end

local function runScript(script: Script<any>, cwd: string?)
	if type(script) == "function" then
		return script(cwd)
	end

	for _, str in ipairs(if type(script) == "string" then { script } else script) do
		local args = string.split(str, " ")
		local command = table.remove(args, 1)

		local result = process.exec(assert(command, "No command provided"), args, {
			cwd = cwd,
		})

		if not result.ok then -- No idea if this is actually accurate for all cli's
			error(`{stdio.color("red")}Error while running command: {str}\n{stdio.color("reset")}{result.stderr}`, 0)
		end
	end
end

local function build(input: AsPath, output: AsPath, options: Options?)
	local uoptions = (options or {}) :: Options

	local workingDirPath = Path.from(if uoptions.cwd and #uoptions.cwd > 0 then uoptions.cwd else pathfs.cwd())

	local inputFileGlobs = { Path.from(input):toString() .. "/**/*" }
	local buildFileGlobs = uoptions.include or {}
	local globOptions = {
		cwd = workingDirPath,
		ignore = uoptions.ignore,
	}

	local function doBuild(inputFiles: Files?, buildFiles: Files?): (Files, Files)
		local buildStart = os.clock()

		local bar: progressbar.ProgressBarImpl
		local resolvedInputFiles: Files
		local resolvedBuildFiles: Files
		local buildDir: pathfs.DirectoryPath

		local success, err = pcall(function()
			bar = progressbar
				.new()
				:withStage("resolve", "Resolving files")
				:withStage("preProcess", "Running pre-process script(s)")
				:withStage("process", "Processing with Darklua")
				:withStage("postProcess", "Running post-process script(s)")
				:withStage("output", "Copying files to output")

			if not uoptions.silent then
				bar:start()
			end

			local outputPath = workingDirPath:join(output)
			local darkluaConfigPath = if uoptions.darklua_config
				then workingDirPath:join(uoptions.darklua_config)
				else nil

			resolvedInputFiles = inputFiles or glob(inputFileGlobs, globOptions)
			resolvedBuildFiles = buildFiles or glob(buildFileGlobs, globOptions)

			local buildDirPath = if (uoptions.temp_dir_location or uoptions.temp_dir_keep)
				then workingDirPath:join(uoptions.temp_dir_location or ".")
				else nil

			buildDir = dirs.createTempDir(buildDirPath, "darklua_build_")

			reconcileFiles(resolvedInputFiles, buildDir.path, workingDirPath)
			reconcileFiles(resolvedBuildFiles, buildDir.path, workingDirPath)

			bar:nextStage() -- preProcess
			if uoptions.scripts and uoptions.scripts.preProcess then
				runScript(uoptions.scripts.preProcess, buildDir.path:toString())
			end

			bar:nextStage() -- process

			local processDir = buildDir.path:join(input):toString()
			local configPath = if darkluaConfigPath then darkluaConfigPath:toString() else nil

			if not configPath then
				if fs.isFile(buildDir.path:join(".darklua.json")) then
					configPath = buildDir.path:join(".darklua.json"):toString()
				elseif fs.isFile(buildDir.path:join(".darklua.json5")) then
					configPath = buildDir.path:join(".darklua.json5"):toString()
				end
			end

			local args = {
				"process",
				processDir,
				processDir,
			}

			if configPath then
				table.insert(args, "--config")
				table.insert(args, configPath)
			end

			local result = process.exec("darklua", args)
			if not result.ok or (#result.stderr > 0 and string.find(string.lower(result.stderr), "error")) then
				error(result.stderr, 0)
			end

			bar:nextStage() -- postProcess
			if uoptions.scripts and uoptions.scripts.postProcess then
				runScript(uoptions.scripts.postProcess, buildDir.path:toString())
			end

			bar:nextStage() -- output

			local outDir = pathfs.DirectoryPath.new(outputPath)
			outDir:writeDir()

			fs.copy(processDir, outDir.path:join(input), true)
			reconcileFiles(resolvedBuildFiles, outDir.path, workingDirPath)
		end)

		if not uoptions.silent and bar then
			bar:stop()
		end

		if not uoptions.temp_dir_keep and buildDir then
			buildDir:removeDir()
		end

		if success and not uoptions.silent then
			stdio.write(`{clr("green")}Built in {getBuildTime(buildStart)}{clr("reset")}`)
			if uoptions.temp_dir_keep and buildDir then
				stdio.write(` (build: {buildDir.path:toString()})`)
			end

			stdio.write("\n")
		elseif not success then
			stdio.write(clr("red") .. string.rep("-", 20) .. clr("reset") .. "\n")
			stdio.write(tostring(err))
			stdio.write(clr("red") .. string.rep("-", 20) .. clr("reset") .. "\n")
		end

		return assert(resolvedInputFiles or inputFiles, "recieved no inputFiles"),
			assert(resolvedBuildFiles or buildFiles, "recieved no buildFiles")
	end

	local inputFiles, buildFiles = doBuild()
	if not uoptions.watch then
		return
	end

	-- WATCH THREAD
	task.defer(function()
		local lastModified = {}
		local function refreshModified(filesArray: { Files })
			table.clear(lastModified)
			for _, files in ipairs(filesArray) do
				for _, path in ipairs(files) do
					lastModified[path:toString()] = fs.metadata(path).modifiedAt
				end
			end
		end

		refreshModified({ inputFiles, buildFiles })

		stdio.write("Watching for changes...\n")
		while task.wait(1) do
			local newInputFiles = glob(inputFileGlobs, globOptions)
			local newBuildFiles = glob(buildFileGlobs, globOptions)
			local filesArray = { newInputFiles, newBuildFiles }

			local modified = #inputFiles ~= #newInputFiles or #buildFiles ~= #newBuildFiles
			if not modified then
				for _, files in ipairs(filesArray) do
					for _, path in ipairs(files) do
						local modifiedAt = fs.metadata(path).modifiedAt
						local lastModifiedAt = lastModified[path:toString()]
						if modifiedAt ~= lastModifiedAt then
							modified = true
							break
						end
					end

					if modified then
						break
					end
				end
			end

			-- There's no need to check if any files got deleted, as we check if they length has changed, and if a file has gotten added.
			-- There's no way a file could've been deleted without either modifying the length of the scanned files, or adding a new file to make up for that.

			if modified then
				refreshModified(filesArray)
				inputFiles, buildFiles = doBuild(newInputFiles, newBuildFiles)
			end
		end
	end)
end

return build
