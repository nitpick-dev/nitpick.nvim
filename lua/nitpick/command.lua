local nitpick = require("nitpick")

local command = {}

---@class Cmd
---@field name string
---@field fn string
---@field args string[]

---Maps a user command to the function name used in `nitpick`.
local dispatch_map = {
	--FIXME: it'd be cooler to be able to use the nitpick function directly here,
	--but there's an issue with stubbing in the tests where the stub doesn't
	--stub..
	["authorize"] = "authorize",
	["activity"] = "load_activity",
	["comment"] = "add_comment",
	["end"] = "end_review",
	["start"] = "start_review",
}

---@param args string[]
---@return Cmd
function command.parse(args)
	local cmd_name = table.remove(args, 1)
	return {
		name = cmd_name,
		fn = dispatch_map[cmd_name],
		args = args,
	}
end

---@param cmd_line string Unparsed command line
---@return string[] commands Filtered list of possible commands
function command.complete(cmd_line)
	local available_commands = { "comment", "start", "end", "activity", "authorize" }
	local sub_commands = {
		["authorize"] = { "github" },
	}

	local tokens = vim.split(cmd_line, "%s+")
	local prefix = #tokens == 2 and tokens[2] or tokens[3]
	local options = #tokens == 2 and available_commands or sub_commands[tokens[2]]

	return vim.tbl_filter(
		function(cmd)
			return vim.startswith(cmd, prefix)
		end,
		options)
end

---@param args string[] Args pass from the user
---@return boolean status Status for dispatching. `true` if successful, `false` otherwise
function command.dispatch(args)
	local cmd = command.parse(args)

	if cmd.fn == nil then
		--FIXME: this error is processed in the test.. figure out how to turn it off
		vim.notify(
			string.format("Invalid command %s", cmd.name),
			vim.log.levels.ERROR
		)
		return false
	end

	nitpick[cmd.fn](unpack(cmd.args))

	return true
end

return command
