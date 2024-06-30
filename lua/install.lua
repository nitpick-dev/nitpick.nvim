print("installing libnitpick...")

vim.fn.system({
	"curl",
	"https://github.com/nitpick-dev/editors/releases/download/dev/libnitpick.so",
	"-LOv",
})

print("done\n")
