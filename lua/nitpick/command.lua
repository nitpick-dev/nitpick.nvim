local nitpick = require("nitpick")

local command = {}

---@class Cmd
---@field name string
---@field fn string
---@field args string?

---Maps a user command to the function name used in `nitpick`.
local dispatch_map = {
	--FIXME: it'd be cooler to be able to use the nitpick function directly here,
	--but there's an issue with stubbing in the tests where the stub doesn't
	--stub..
	["start"] = "start_review",
	["end"] = "end_review",
}

---@param args string[]
---@return Cmd
local function parse(args)
	return {
		name = args[1],
		fn = dispatch_map[args[1]],
		args = args[2],
	}
end


---@param cmd_line string Unparsed command line
---@return string[] commands Filtered list of possible commands
function command.complete(cmd_line)
	local available_commands = { "start", "end" }

	local tokens = vim.split(cmd_line, "%s+")
	local commands = vim.tbl_filter(
		function(cmd)
			return vim.startswith(cmd, tokens[2])
		end,
		available_commands)

	return commands
end

---@param args string[] Args pass from the user
---@return boolean status Status for dispatching. `true` if successful, `false` otherwise
function command.dispatch(args)
	local cmd = parse(args)

	if cmd.fn == nil then
		--FIXME: this error is processed in the test.. figure out how to turn it off
		vim.notify(
			string.format("Invalid command %s", cmd.name),
			vim.log.levels.ERROR
		)
		return false
	end

	nitpick[cmd.fn](cmd.args)

	return true
end

return command
