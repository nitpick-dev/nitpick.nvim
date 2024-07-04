print("installing libnitpick...")

local os = vim.loop.os_uname()

---@type string The system name cast to lowercase
local sysname = os.sysname:lower()
if sysname == "linux" then
	-- FIXME: this does not account for musl.. but we're not building for musl yet
	sysname = "linux-gnu"
end

local filename = string.format("%s-%s.tar.gz", os.machine, sysname)

vim.fn.system({
	"curl",
	"https://github.com/nitpick-dev/nvim/releases/download/dev/" .. filename,
	"-LOv",
})

print("unpacking libnitpick...")

vim.fn.system({
	"tar",
	"xvf",
	filename,
})

print("done\n")
