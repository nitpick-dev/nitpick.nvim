local stub = require("luassert.stub")

local nitpick = require("nitpick")
local command = require("nitpick.command")

local test = it

describe("parse", function()
	test("parse all args", function()
		local cmd = command.parse({ "command", "first", "second" })
		assert.are_same({
			name = "command",
			-- NOTE: command doesn't map to anything so it's nil. this should never be
			-- the case though. we could add a real command, but then the args
			-- wouldn't make sense.
			fn = nil,
			args = { "first", "second" },
		}, cmd)
	end)
end)

describe("command", function()
	describe("completions", function()
		test("return all completions when cmd is emtpy", function()
			local cmp = command.complete("Nitpick ")
			assert.are_same({ "comment", "start", "rstart", "end", "activity", "notes", "authorize", "next" }, cmp)
		end)

		test("filter by leading characters", function()
			local cmp = command.complete("Nitpick s")
			assert.are_same({ "start" }, cmp)

			cmp = command.complete("Nitpick e")
			assert.are_same({ "end" }, cmp)

			cmp = command.complete("Nitpick friggin")
			assert.are_same({}, cmp)
		end)

		test("filter sub command", function()
			local cmp = command.complete("Nitpick authorize ")
			assert.are_same({ "github" }, cmp)

			cmp = command.complete("Nitpick authorize b")
			assert.are_same({}, cmp)
		end)
	end)

	describe("dispatch", function()
		test("start command", function()
			local start = stub(nitpick, "start_review")

			assert.is_true(command.dispatch({ "start" }))
			assert.is_true(start:called(1))
		end)

		test("start command with an arg", function()
			local start = stub(nitpick, "start_review")

			assert.is_true(command.dispatch({ "start", "abc123" }))
			assert.is_true(start:called(1))
			assert.stub(start).was.called_with({ args = { "abc123" } })
		end)

		test("end command", function()
			local end_cmd = stub(nitpick, "end_review")

			assert.is_true(command.dispatch({ "end" }))
			assert.is_true(end_cmd:called(1))
		end)

		test("authorize command", function()
			local authorize = stub(nitpick, "authorize")

			assert.is_true(command.dispatch({ "authorize", "github", "some_token" }))
			assert.stub(authorize).was.called_with({
				args = { "github", "some_token" },
			})
		end)

		test("activity command", function()
			local activity = stub(nitpick, "load_activity")

			assert.is_true(command.dispatch({ "activity" }))
			assert.stub(activity).was.called(1)
		end)

		test("add a comment", function()
			local comment = stub(nitpick, "add_comment")

			assert.is_true(command.dispatch({ "comment" }))
			assert.stub(comment).was.called(1)
		end)

		test("notes command", function()
			local notes = stub(nitpick, "open_notes")

			assert.is_true(command.dispatch({ "notes" }))
			assert.stub(notes).was.called(1)
		end)

		test("unknown command fails", function()
			assert.is_false(command.dispatch({ "notarealcommand" }))
		end)
	end)
end)
