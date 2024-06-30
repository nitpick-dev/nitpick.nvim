local nitpick = require("nitpick")

local command = {}

---@class Cmd
---@field name "start" | "end"
---@field args string?

---@param args string[]
---@return Cmd
local function parse(args)
	---@type Cmd
	local cmd = {
		name = args[1],
		args = args[2],
	}

	return cmd
end

--FIXME: do we want to parse the command line before passing it through?
---@param cmd_line string Unparsed command line
---@return string[] commands Filtered list of possible commands
function command.complete(cmd_line)
	local available_commands = {"start_review", "end_review",}

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

	if nitpick[cmd.name] == nil then
		--FIXME: this error is processed in the test.. figure out how to turn it off
		vim.notify(
			string.format("Invalid command %s", cmd.name),
			vim.log.levels.ERROR
		)
		return false
	end

	nitpick[cmd.name](cmd.args)

	return true
end

return command
