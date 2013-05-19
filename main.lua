require("config")
require("resources")
require("util")
require("map")
require("player")
require("human")
require("enemy")
require("boss")
require("magmahulk")
require("gasleak")
require("gasghost")
require("charcoal")
require("coalball")
require("door")
require("item")
require("fire")
require("particles")
-- gamestates
require("splash")
require("mainmenu")
require("ingame")
require("ingame_menu")
require("options")
require("keyboard")
require("joystick")
require("levelselection")
require("summary")
require("highscore_entry")
require("highscore_list")
require("howto")
require("history")
-- 3rd party libraries
require("AnAL")
require("slam")
require("TSerial")

WIDTH = 256
HEIGHT = 200
MAPW = 41*16
MAPH = 16*16
show_debug = false

local MAX_FRAMETIME = 1/20
local MIN_FRAMETIME = 1/60

local AXIS_COOLDOWN = 0.2
local xacc = 0
local yacc = 0
local xacccool = 0
local yacccool = 0

STATE_SPLASH, STATE_INGAME, STATE_MAINMENU, STATE_LEVELSELECTION, STATE_OPTIONS, STATE_KEYBOARD, STATE_JOYSTICK,
STATE_HOWTO, STATE_HIGHSCORE_LIST, STATE_HIGHSCORE_ENTRY, STATE_INGAME_MENU, STATE_HISTORY, STATE_SUMMARY = 0,1,2,3,4,5,6,7,8,9,10,11,12

gamestates = {[0]=splash, [1]=ingame, [2]=mainmenu, [3]=levelselection, [4]=options, [5]=keyboard,
[6]=joystick, [7]=howto, [8]=highscore_list, [9]=highscore_entry, [10]=ingame_menu, [11]=history, [12]=summary}

function love.load()
	loadConfig()
	loadHighscores()
	loadStats()

	love.graphics.setBackgroundColor(0,0,0)

	love.graphics.setDefaultImageFilter("nearest","nearest")
	loadResources()

	setMode()

	splash.enter()
end

function love.update(dt)
	if xacccool > 0 then
		xacccool = xacccool - dt
	end
	if yacccool > 0 then
		yacccool = yacccool - dt
	end
	gamestates[state].update(dt)
end

function love.draw()
	-- Draw border and enable scissoring for fullscreen
	if config.fullscreen == true then
		--[[
		lg.setScissor()
		lg.drawq(img.border, quad.border, -5*config.scale+fs_translatex, -5*config.scale+fs_translatey, 0, config.scale, config.scale)
		lg.setScissor(fs_translatex, fs_translatey, WIDTH*config.scale, HEIGHT*config.scale)
		lg.translate(fs_translatex,fs_translatey)
		]]
	end
	setView()
	gamestates[state].draw()
end

function setView()
	if config.fullscreen == true then
		local sw = love.graphics.getWidth()/WIDTH/config.scale
		local sh = love.graphics.getHeight()/HEIGHT/config.scale
		lg.scale(sw,sh)
	end
end

function love.keypressed(k, uni)
	gamestates[state].keypressed(k, uni)
end

function love.joystickpressed(joy, k)
	if joy == config.joystick then
		if gamestates[state].joystickpressed then
			gamestates[state].joystickpressed(joy, k)
		else
			for a, key in pairs(config.joykeys) do
				if k == key then
					gamestates[state].action(a)
				end
			end
		end
	end
end

--- Updates keystates of ingame keys.
--  Should only be called when ingame, as it
--  makes call to Player
function updateKeys()
	-- Check keyboard keys
	for action, key in pairs(config.keys) do
		if love.keyboard.isDown(key) then
			keystate[action] = true
		else
			keystate[action] = false
		end
	end

	-- Check joystick axes
	local axis1, axis2 = love.joystick.getAxes(config.joystick)
	if axis1 and axis2 then
		if axis1 < -0.5 then
			keystate.left = true
		elseif axis1 > 0.5 then
			keystate.right = true
		end
		if axis2 < -0.5 then
			keystate.up = true
		elseif axis2 > 0.5 then
			keystate.down = true
		end

		-- Check sudden movements in axes
		-- (for ladders and menus)
		xacc = xacc*0.50 + axis1*0.50
		yacc = yacc*0.50 + axis2*0.50

		if math.abs(axis1) < 0.1 then
			xacccool = 0
		end
		if math.abs(axis2) < 0.1 then
			yacccool = 0
		end

		if xacccool <= 0 then
			if axis1 < -0.90 then
				gamestates[state].action("left")
				xacccool = AXIS_COOLDOWN
			elseif axis1 > 0.90 then
				gamestates[state].action("right")
				xacccool = AXIS_COOLDOWN
			end
		end

		if yacccool <= 0 then
			if axis2 < -0.90 then
				gamestates[state].action("up")
				yacccool = AXIS_COOLDOWN
			elseif axis2 > 0.90 then
				gamestates[state].action("down")
				yacccool = AXIS_COOLDOWN
			end
		end
	end

	-- Check joystick keys
	for action, key in pairs(config.joykeys) do
		if love.joystick.isDown(config.joystick, key) then
			keystate[action] = true
		end
	end
end

function love.run()
    math.randomseed(os.time())
    math.random() math.random()

    if love.load then love.load(arg) end
    local dt = 0
	local acc = 0

    -- Main loop time.
    while true do
		local frame_start = love.timer.getMicroTime()
        -- Process events.
        if love.event then
            love.event.pump()
            for e,a,b,c,d in love.event.poll() do
                if e == "quit" then
                    if not love.quit or not love.quit() then
                        if love.audio then
                            love.audio.stop()
                        end
                        return
                    end
                end
                love.handlers[e](a,b,c,d)
            end
        end

		love.timer.step()
		dt = love.timer.getDelta()
		dt = math.min(dt, MAX_FRAMETIME)
		acc = acc + dt

		while acc >= MIN_FRAMETIME do
			love.update(MIN_FRAMETIME)
			acc = acc - MIN_FRAMETIME
		end

		-- Update screen
		love.graphics.clear()
		love.draw()

		love.graphics.present()
		love.timer.sleep(0.001)
    end
end

function love.quit()
	saveConfig()
	saveHighscores()
	saveStats()
end
