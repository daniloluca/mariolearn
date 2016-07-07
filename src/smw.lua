-- variables
local player = {
	x = 0x0094,
	y = 0x0096,
	speed = 0x007b,
	animation_trigger = 0x0071,
	on_air = 0x0072,
	on_ground = 0x13ef,
	reaction = {
		x = 32,
		y = 32,
	},
	blocked_status = 0x0077,
};

function getPlayer()
	return {
		x = memory.readwordsigned(player.x)+8,
		y = memory.readwordsigned(player.y)+16
	};
end

local sprite = {
	number = 0x009e,
	status = 0x14c8,
	x_high = 0x14e0,
	x_low = 0x00e4,
	y_high = 0x14d4,
	y_low = 0x00d8,
	x_offscreen = 0x15a0,
  	y_offscreen = 0x186c,
};

local extended_sprite = {
	number = 0x170b,
    x_high = 0x1733,
    x_low = 0x171f,
    y_high = 0x1729,
    y_low = 0x1715,
    x_speed = 0x1747,
    y_speed = 0x173d,
};

function Set (list)
	local set = {}
	for _, l in ipairs(list) do set[l] = true end
	return set
end

local block = {
	semi = Set {0, 1, 3, 4},
	solid = Set {51, 52, 53, 54, 69}
};

local camera = {
	x = 0x001a,
	y = 0x001c,
	screens_number = 0x005d,
	hscreen_number = 0x005e,
	vscreen_number = 0x005f,
	vertical_scroll = 0x1412,
	camera_scroll_timer = 0x1401,
}

local commands = {
	{button = "A", states = {false, true}},
	{button = "Y", states = {false, true}},
	{button = "B", states = {false, true}},
	{button = "right", states = {true, false}},
}

local variations = {};
local reactions = {};

-- functions
-- function to turn a reference variable in a new variable.
function new(var)
	local new_var = {};
	for k, v in pairs(var) do
		new_var[k] = v; -- or new_var[k] = var[k]
	end

	return new_var;
end

function generateVariations(action, index)
	local command = commands[index];
	for i=1, #command.states, 1 do
		action[command.button] = command.states[i];
		if index < #commands then
			generateVariations(action, index+1);
		else
			local variation = {
				action = new(action),
				weight = 1,
			};
			table.insert(variations, variation);
		end
	end
end

-- file IO functions
function saveFile(filename, obj)
	local file = io.open(filename, "w");
	file:write(tostring(obj));
	file:flush();
	file:close();
end

function loadFile(filename)
	local file = io.open(filename, "r");
	if file == nil then
		saveFile(filename, {});
		file = io.open(filename, "r");
	end
	local response = file:read();
	file:close();
	return response;
end

function cleanFile(filename)
	local file = io.open(filename, "w");
	file:write("");
	file:flush();
	file:close();
end

function removeFile(filename)
	os.remove(filename);
end

function getFilePath(filename)
	local info = debug.getinfo(1, "S");
	local path = info.source:sub(2);

	path = path:gsub("smw.lua", filename);

	return path;
end

function reload(save_num)
	local save_state = savestate.create(save_num);
	savestate.load(save_state);
end

function signed(num, bits)
    local maxval = 2^(bits - 1);

    if num < maxval then
    	return num;
    else
    	return num - 2*maxval;
    end
end

function console()
	gui.text(10, 200, "X: " .. getPlayer().x);
	gui.text(10, 210, "Y: " .. getPlayer().y);
	gui.text(50, 210, "Speed: " .. memory.readbyte(player.speed));
end

function screenCoordinates(x, y, camera_x, camera_y)
    local x_screen = (x - camera_x);
    local y_screen = (y - camera_y) - 1;

    return x_screen, y_screen;
end

function drawSprite(screen_x, screen_y, color, num, st)
	gui.line(screen_x-8, screen_y, screen_x+8, screen_y, color);
	gui.line(screen_x, screen_y-8, screen_x, screen_y+8, color);
	gui.text(screen_x-8, screen_y, num);
	gui.text(screen_x+8, screen_y, st);
end

function drawExtendedSprite(screen_x, screen_y, color, num, st)
	gui.line(screen_x-8, screen_y, screen_x+8, screen_y, color);
	gui.line(screen_x, screen_y-8, screen_x, screen_y+8, color);
	gui.text(screen_x-8, screen_y, num);
	gui.text(screen_x+8, screen_y, st);
end

function drawBlock(screen_x, screen_y, width, height, color)
	local x, y = screen_x-(width/2), screen_y-(width/2);

	gui.line(x, y, x+width, y, color);
	gui.line(x, y+height, x+width, y+height, color);

	gui.line(x, y, x, y+height, color);
	gui.line(x+width, y, x+width, y+height, color);
end

function drawFieldOfView()
	local x_screen, y_screen = screenCoordinates(getPlayer().x, getPlayer().y, memory.readwordsigned(camera.x), memory.readwordsigned(camera.y));

	gui.box(x_screen, y_screen, x_screen+player.reaction.x, y_screen-player.reaction.y, 0,"blue");
	gui.box(x_screen, y_screen, x_screen-player.reaction.x, y_screen-player.reaction.y, 0,"blue");
	gui.box(x_screen, y_screen, x_screen-player.reaction.x, y_screen+player.reaction.y, 0,"blue");
	gui.box(x_screen, y_screen, x_screen+player.reaction.x, y_screen+player.reaction.y, 0,"blue");
end

-- highlight quadrant
function hlQuadrant(quad)
	local x_screen, y_screen = screenCoordinates(getPlayer().x, getPlayer().y, memory.readwordsigned(camera.x), memory.readwordsigned(camera.y));

	gui.transparency(2);

	if quad == 1 then
		gui.box(x_screen, y_screen, x_screen+player.reaction.x, y_screen-player.reaction.y, "blue");
	elseif quad == 2 then
		gui.box(x_screen, y_screen, x_screen-player.reaction.x, y_screen-player.reaction.y, "blue");
	elseif quad == 3 then
		gui.box(x_screen, y_screen, x_screen-player.reaction.x, y_screen+player.reaction.y, "blue");
	elseif quad == 4 then
		gui.box(x_screen, y_screen, x_screen+player.reaction.x, y_screen+player.reaction.y, "blue");
	end

	gui.transparency(0);
end

-- debug by game position
function debugger(game_x, game_y, text)
	local screen_x, screen_y = screenCoordinates(game_x, game_y, memory.readwordsigned(camera.x), memory.readwordsigned(camera.y));
	drawBlock(screen_x, screen_y, 15, 15, "purple");
	gui.text(screen_x+3, screen_y+5, text);
end

function getSprites()
	local sprites = {};

	for i=0, 12, 1 do
		local s = {
			x = 256*memory.readbyte(sprite.x_high + i) + memory.readbyte(sprite.x_low + i),
			y = 256*memory.readbyte(sprite.y_high + i) + memory.readbyte(sprite.y_low + i),
			num = memory.readbyte(sprite.number + i),
			st = memory.readbyte(sprite.status + i)
		};

		s.x = signed(s.x, 16)+8;
    	s.y = signed(s.y, 16)+8;

    	local screen_x, screen_y = screenCoordinates(s.x, s.y, memory.readwordsigned(camera.x), memory.readwordsigned(camera.y));

		if s.st ~= 0 then
			table.insert(sprites, s);
			drawSprite(screen_x, screen_y, "red", s.num, s.st);
		end
	end

	return sprites;
end

function getExtendedSprites()
	local extended = {};

	for i=0, 11, 1 do
		local e = {
			x = 256*memory.readbyte(extended_sprite.x_high + i) + memory.readbyte(extended_sprite.x_low + i),
			y = 256*memory.readbyte(extended_sprite.y_high + i) + memory.readbyte(extended_sprite.y_low + i),
			num = memory.readbyte(extended_sprite.number + i),
			st = 0
		}

		e.x = signed(e.x, 16)+8;
    	e.y = signed(e.y, 16)+8;

    	local screen_x, screen_y = screenCoordinates(e.x, e.y, memory.readwordsigned(camera.x), memory.readwordsigned(camera.y));

		if e.num ~= 0 then
			table.insert(extended, e);
			drawExtendedSprite(screen_x, screen_y, "red", e.num, e.st);
		end
	end

	return extended;
end

function getTile(map16_x, map16_y)
	local game_x = math.floor((getPlayer().x+map16_x+8)/16);
	local game_y = math.floor((getPlayer().y+map16_y)/16);
	local id = math.floor(game_x/0x10)*0x1B0 + game_y*0x10 + game_x%0x10;

	return (game_x*16)+8, (game_y*16)+8, memory.readbyte(0x7EC800 + id);
end

function getBlocks()
	local blocks = {};

	-- size = 6*16
	local size = 160;

	for m16_y=-size, size, 16 do
		for m16_x=-size, size, 16 do
			local game_x, game_y, tile = getTile(m16_x, m16_y);

			-- debugger(game_x, game_y, tile);

			-- Green ground
			if block.semi[tile] then
				local screen_x, screen_y = screenCoordinates(game_x, game_y, memory.readwordsigned(camera.x), memory.readwordsigned(camera.y));
				drawBlock(screen_x, screen_y, 16, 16, "green");
			end

			if block.solid[tile] then
				local screen_x, screen_y = screenCoordinates(game_x, game_y, memory.readwordsigned(camera.x), memory.readwordsigned(camera.y));
				drawBlock(screen_x, screen_y, 16, 16, "red");

				local b = {
					x = game_x,
					y = game_y,
					st = 0,
					num = tile
				};

				table.insert(blocks, b);
			end
		end
	end

	return blocks;
end

-- situation model
------------------------------
-- situation_number
	-- situation_state
		-- situation_quadrant
			-- action
			-- index
------------------------------
function getQuadrant(element_x, element_y)
	-- debugger(element_x, element_y, element_y); -- cool

	local player_x, player_y = getPlayer().x, getPlayer().y;

	if (player_x - element_x) <= 0 and (player_y - element_y) > 0 then
		hlQuadrant(1);
		return 1;
	elseif (player_x - element_x) > 0 and (player_y - element_y) > 0 then
		hlQuadrant(2);
		return 2;
	elseif (player_x - element_x) > 0 and (player_y - element_y) <= 0 then
		hlQuadrant(3);
		return 3;
	elseif (player_x - element_x) <= 0 and (player_y - element_y) <= 0 then
		hlQuadrant(4);
		return 4;
	end
end

function generateSituation(elements)
	local s = {
		num = "",
		st = "",
		quad = ""
	};

	for i=1, #elements, 1 do
		s.num = s.num .. tostring(elements[i].num);
		s.st = s.st .. tostring(elements[i].st);
		s.quad = s.quad .. tostring(getQuadrant(elements[i].x, elements[i].y));
	end

   	return s;
end

function getClosestElements()
	local cs = {};

	local sprites = getSprites();
	local blocks = getBlocks();
	local extended = getExtendedSprites();

	for i=1, #sprites, 1 do
		if math.abs(getPlayer().x - sprites[i].x) <= player.reaction.x and math.abs(getPlayer().y - sprites[i].y) <= player.reaction.y then
			table.insert(cs, sprites[i]);
		end
	end

	for i=1, #blocks, 1 do
		if block.solid[blocks[i].num] ~= nil and math.abs(getPlayer().x - blocks[i].x) <= player.reaction.x and math.abs(getPlayer().y - blocks[i].y) <= player.reaction.y then
			table.insert(cs, blocks[i]);
		end
	end

	for i=1, #extended, 1 do
		if math.abs(getPlayer().x - extended[i].x) <= player.reaction.x and math.abs(getPlayer().y - extended[i].y) <= player.reaction.y then
			table.insert(cs, extended[i]);
		end
	end

	return cs;
end

function playerDeath(situation)
	local newReact = {
		action = variations[1].action,
		index = 1
	};

	if reactions[situation.num] == nil then
		reactions[situation.num] = {
			[situation.st] = {
				[situation.quad] = newReact;
			}
		};
	elseif reactions[situation.num][situation.st] == nil then
		reactions[situation.num][situation.st] = {
			[situation.quad] = newReact;
		}
	elseif reactions[situation.num][situation.st][situation.quad] == nil then
		reactions[situation.num][situation.st][situation.quad] = newReact;
	else
		local index = reactions[situation.num][situation.st][situation.quad].index;

		if index < #variations then
			index = index + 1;
			reactions[situation.num][situation.st][situation.quad].action = variations[index].action;
			reactions[situation.num][situation.st][situation.quad].index = index;
		else
			print("you shall not pass!");
		end
	end

	print(situation, reactions[situation.num][situation.st][situation.quad].action);

	-- save new values in the base
	saveFile(getFilePath("db.lua"), reactions);

	reload(1);
end

-- player stuck validation
local stuckCount = 0;
local stuckDelay = 100;
local player_last_x = getPlayer().x;

function frameCount()
	stuckCount = stuckCount + 1;

	if stuckCount >= stuckDelay then
		if getPlayer().x <= player_last_x then
			playerDeath(generateSituation(getClosestElements()));
		else
			player_last_x = getPlayer().x;
		end

		stuckCount = 0;
	end
end

-- such a main function.
function playerAction()
	-- reaction exec
	local situation = generateSituation(getClosestElements());

	if reactions[situation.num] ~= nil then
		if reactions[situation.num][situation.st] ~= nil then
			if reactions[situation.num][situation.st][situation.quad] ~= nil then
				joypad.set(reactions[situation.num][situation.st][situation.quad].action);
			else
				joypad.set(variations[1].action);
			end
		else
			joypad.set(variations[1].action);
		end
	else
		joypad.set(variations[1].action);
	end

	-- player die
	if memory.readbyte(player.animation_trigger) == 9 then
		playerDeath(situation);
	end

	-- player stuck
	if memory.readbyte(player.speed) <= 7 then
		frameCount();
	else
		stuckCount = 0;
		player_last_x = getPlayer().x;
	end
end

-- start
-- loading reactions from file.
local data_base_file = loadFile("db.lua");
reactions = loadstring("return ".. data_base_file)();
generateVariations({}, 1);

-- update
while true do
	playerAction();
	console();
	drawFieldOfView();

	emu.frameadvance();-- important
end
