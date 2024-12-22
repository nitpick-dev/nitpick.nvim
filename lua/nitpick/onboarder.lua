local has_fzf, fzf = pcall(require, "fzf-lua")
local has_telescope, telescope = pcall(require, "telescope.builtin")

local title = "nitpick onboard"

---@param onboard_cb fun(commit: string) Callback with selected commit as the first parameter
local function start_fzf(onboard_cb)
	fzf.git_commits({
		header = "Select a commit to begin the review",
		winopts = {
			title = title,
		},
		actions = {
			["default"] = function(selections)
				assert(selections[1] ~= nil, "[onboarder:fzf]: invalid selection")

				local commit = selections[1]:match("^(%S+)")
				onboard_cb(commit)
			end,
		},
	})
end

---@param onboard_cb fun(commit: string) Callback with selected commit as the first parameter
local function start_telescope(onboard_cb)
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	telescope.git_commits({
		prompt_title = title,
		attach_mappings = function()
			actions.select_default:replace(function(bufnr)
				actions.close(bufnr)

				local selection = action_state.get_selected_entry()
				assert(selection ~= nil, "[onboarder:telescope]: invalid selection")
				onboard_cb(selection.value)
			end)

			-- NOTE: `attach_mappings` must return true or false. True keeps
			-- previously defined mappings, false removes them. We want to preserve as
			-- much about the user's config as possible, so this should stay marked as
			-- true. This does leave a few mappings available.
			return true
		end,
	})
end

local onboarder = {}

---Opens a picker to select from available commits to begin a review. This is
---inteded to be called if no commit is returned from `start_review` command.
---The picker depends on what the user has installed and available.
---@param onboard_cb fun(commit: string) Callback with selected commit as the first parameter
function onboarder.start(onboard_cb)
	assert(has_fzf or has_telescope, "No picker available")

	if has_fzf then
		return start_fzf(onboard_cb)
	elseif has_telescope then
		return start_telescope(onboard_cb)
	end
end

return onboarder
