local stub = require("luassert.stub")

local nitpick = require("nitpick")
local command = require("nitpick.command")

local test = it

describe("command", function()
	describe("completions", function()
		test("return all completions when cmd is emtpy", function()
			local cmp = command.complete("Nitpick ")
			assert.are_same({ "start", "end", "authorize" }, cmp)
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
			assert.stub(start).was.called_with("abc123")
		end)

		test("end command", function()
			local end_cmd = stub(nitpick, "end_review")

			assert.is_true(command.dispatch({ "end" }))
			assert.is_true(end_cmd:called(1))
		end)

		test("authorize command", function()
			local authorize = stub(nitpick, "authorize")

			assert.is_true(command.dispatch({ "authorize", "github", "some_token" }))
			assert.stub(authorize).was.called_with("github", "some_token")
		end)

		test("unknown command fails", function()
			assert.is_false(command.dispatch({ "notarealcommand" }))
		end)
	end)
end)
