local command = require("nitpick.command")

vim.api.nvim_create_user_command(
	"Nitpick",
	function(data) command.dispatch(data.fargs) end,
	{
		nargs = "*",
		complete = function(_, line) return command.complete(line) end,
	}
)

vim.api.nvim_create_user_command(
	"NitpickSignup",
	function(data) command.dispatch(command.build_signup(data.fargs)) end,
	{ nargs = 1 }
)
