local activity = {}

---@param events Event[]
---@return string[] activity
function activity.parse(events)
	local log = {}

	for _, event in ipairs(events) do
		table.insert(log, string.format("%s added a comment:", event.actor))
		table.insert(log, event.description)
		table.insert(log, "")
	end

	return log
end

return activity

