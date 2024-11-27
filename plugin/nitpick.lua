local command = require("nitpick.command")

vim.api.nvim_create_user_command(
	"Nitpick",
	function(data) command.dispatch(data.fargs, data.line1, data.line2) end,
	{
		nargs = "*",
		range = true,
		complete = function(_, line) return command.complete(line) end,
	}
)
