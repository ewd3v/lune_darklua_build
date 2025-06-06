-- Ripped from: https://github.com/pesde-pkg/tooling/blob/865bfe1859f4967c4e4b0bd93b5664afd94b6a2c/toolchainlib/src/utils/progress.luau
--> Inspired by Rokit's progress bar: https://github.com/rojo-rbx/rokit/blob/a303faf/src/util/progress.rs

local task = require("@lune/task")
local stdio = require("@lune/stdio")

local Result = require("../../lune_packages/result")
local Option = require("../../lune_packages/option")
type Option<T> = Option.Option<T>
type Result<T, E> = Result.Result<T, E>

-- FORMAT: {SPINNER} {MESSAGE} {BAR} {STAGE}
local SPINNERS = { "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local BAR_COMPONENT = "▇"
local MAX_BAR_LENGTH = 30

local ProgressBar = {}
type ProgressBar = {
	stages: { { tag: string, message: string } },
	currentStageIndex: number,
	finished: boolean,
	thread: thread?,
}
export type ProgressBarImpl = typeof(setmetatable({} :: ProgressBar, { __index = ProgressBar }))

function ProgressBar.new(): ProgressBarImpl
	return setmetatable(
		{
			stages = {},
			currentStageIndex = 1,
			finished = false,
		} :: ProgressBar,
		{
			__index = ProgressBar,
		}
	)
end

function ProgressBar.withStage(self: ProgressBarImpl, tag: string, msg: string): ProgressBarImpl
	table.insert(self.stages, { tag = tag, message = msg })
	return self
end

function ProgressBar.start(self: ProgressBarImpl): ()
	local BAR_LENGTH = MAX_BAR_LENGTH // #self.stages
	local TOTAL_BAR_LENGTH = BAR_LENGTH * #self.stages
	local BAR = string.rep(BAR_COMPONENT, BAR_LENGTH)
	local MAX_MESSAGE_LENGTH = 0
	for _, stage in self.stages do
		local len = #stage.message
		if len > MAX_MESSAGE_LENGTH then
			MAX_MESSAGE_LENGTH = len
		end
	end

	self.thread = task.spawn(function()
		while true do
			for _, spinner in SPINNERS do
				if self.finished then
					return
				end

				local stage = self.stages[self.currentStageIndex]
				stdio.ewrite(
					`\x1b[2K\x1b[0G{stdio.color("cyan")}{spinner} {stage.message}{stdio.color("reset")}{string.rep(
						" ",
						MAX_MESSAGE_LENGTH - #stage.message
					)} [{stdio.style("dim")}{string.rep(BAR, self.currentStageIndex)}{string.rep(
						" ",
						TOTAL_BAR_LENGTH - (BAR_LENGTH * self.currentStageIndex)
					)}{stdio.style("reset")}] {stdio.style("bold")}{self.currentStageIndex} / {#self.stages}{stdio.style(
						"reset"
					)}`
				)

				task.wait(0.1)
			end
		end
	end)
end

function ProgressBar.stop(self: ProgressBarImpl): ()
	-- Trigger upvalue, kill thread and clean progress bar remnant
	self.finished = true
	stdio.ewrite("\x1b[2K\x1b[0G")
end

function ProgressBar.nextStage(self: ProgressBarImpl): Result<nil, string>
	local inc = self.currentStageIndex + 1
	if inc > #self.stages then
		-- TODO: Make this a result
		self.finished = true
		return Result.Err("OutOfBounds - Attempted to advance past last stage")
	end

	self.currentStageIndex = inc
	return Result.Ok(nil)
end

return ProgressBar
