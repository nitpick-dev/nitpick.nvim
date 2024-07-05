local stub = require("luassert.stub")

local nitpick = require("nitpick")
local command = require("nitpick.command")

local test = it

describe("command", function()
	describe("completions", function()
		test("return all completions when cmd is emtpy", function()
			local cmp = command.complete("Nitpick ")
			assert.are_same({ "start", "end" }, cmp)
		end)

		test("filter by leading characters", function()
			local cmp = command.complete("Nitpick s")
			assert.are_same({ "start" }, cmp)

			cmp = command.complete("Nitpick e")
			assert.are_same({ "end" }, cmp)

			cmp = command.complete("Nitpick friggin")
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

		test("unknown command fails", function()
			assert.is_false(command.dispatch({ "notarealcommand" }))
		end)
	end)
end)
