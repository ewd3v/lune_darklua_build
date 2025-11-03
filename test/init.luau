_G.LUA_ENV = "lune"

local darklua_build = require("./src/lib")

darklua_build("src", "out", {
	cwd = "test",
	include = {
		".darklua.json5",
		".luaurc",
		"*.project.json",
		"sourcemap.json",
	},
	temp_dir_location = ".",
	temp_dir_keep = false,
	silent = false,
	watch = true,

	scripts = {
		preProcess = "rojo sourcemap default.project.json -o sourcemap.json",
	},
})
