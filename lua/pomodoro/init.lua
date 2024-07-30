local M = {}

local pomodoro_duration = 25 * 60 -- 25 minutes
local break_duration = 5 * 60 -- 5 minutes
local timer = nil
local is_break = false
local time_left = pomodoro_duration
local autostart = true
local icon_path = nil
local timer_file = vim.fn.stdpath("cache") .. "/pomodoro_timer"

local function save_timer()
	local file = io.open(timer_file, "w")
	if file then
		file:write(time_left .. "\n")
		file:write(is_break and "break" or "pomodoro")
		file:close()
	end
end

local function load_timer()
	local file = io.open(timer_file, "r")
	if file then
		local saved_time = file:read("*n")
		local saved_state = file:read("*l")
		file:close()
		if saved_time and saved_state then
			time_left = saved_time
			is_break = (saved_state == "break")
		end
	end
end

local function get_status()
	local status = string.format("%02d:%02d", math.floor(time_left / 60), time_left % 60)
	if is_break then
		return "Break: " .. status
	else
		return "Pomodoro: " .. status
	end
end

local function update_status()
	-- Update internal status but do not display it automatically
	save_timer()
end

local function play_beep()
	for _ = 1, 3 do -- Number of beeps
		os.execute("echo -e '\\a'")
	end
end

local function send_notification(message)
	local icon_option = icon_path and "-i " .. icon_path or ""
	os.execute("notify-send " .. icon_option .. " 'Pomodoro' '" .. message .. "'")
end

local function tick()
	time_left = time_left - 1
	update_status()

	if time_left <= 0 then
		play_beep()
		if is_break then
			is_break = false
			time_left = pomodoro_duration
			send_notification("Break over, back to work!")
			vim.api.nvim_command('echohl WarningMsg | echom "Break over, back to work!" | echohl None')
		else
			is_break = true
			time_left = break_duration
			send_notification("Pomodoro over, take a break!")
			vim.api.nvim_command('echohl Directory | echom "Pomodoro over, take a break!" | echohl None')
		end
		save_timer()
	end
end

function M.start()
	if timer == nil then
		timer = vim.uv.new_timer()
		timer:start(0, 1000, vim.schedule_wrap(tick))
		save_timer()
	end
end

function M.stop()
	if timer then
		timer:stop()
		timer:close()
		timer = nil
		save_timer()
	end
end

function M.toggle()
	if timer then
		M.stop()
	else
		M.start()
	end
end

local function get_progress_bar()
	local total_duration = is_break and break_duration or pomodoro_duration
	local progress = (total_duration - time_left) / total_duration
	local bar_length = 20 -- Length of the progress bar in characters
	local filled_length = math.floor(bar_length * progress)
	local bar = string.rep("█", filled_length) .. string.rep("░", bar_length - filled_length)
	return bar
end

function M.show_status()
	local status = get_status()
	local progress_bar = get_progress_bar()
	vim.api.nvim_command('echohl None | echom "' .. status .. " [" .. progress_bar .. ']" | echohl None')
end

function M.setup(opts)
	if opts then
		if opts.autostart ~= nil then
			autostart = opts.autostart
		end
		if opts.icon_path then
			icon_path = opts.icon_path
		end
	end

	load_timer()
	if autostart and time_left > 0 then
		M.start()
	end
end

return M
