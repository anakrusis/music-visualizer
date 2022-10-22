-- song specific properties
CHANNELCOUNT = 28;
TICKS_PER_ROW = 3;
ROWS_PER_BEAT = 16;
SEMITONE_VALUES = {
	["C-"] = 0, ["C#"] = 1, ["D-"] = 2, ["D#"] = 3,
	["E-"] = 4, ["F-"] = 5, ["F#"] = 6, ["G-"] = 7,
	["G#"] = 8, ["A-"] = 9, ["A#"] = 10,["B-"] = 11,
}
ACTIVE_CHANNELS = { 
	false, true,  true,  true,  true,  true,  true, 
	true,  true,  true,  false, false, false, false, -- starting fourth in this row are drums
	false, false, true,  true,  true,  true,  true,
	false, false, false, false, false, false, false
}
OFFSET = -5;
BEATS_PER_MINUTE = 140.19;
rowsperminute 	= BEATS_PER_MINUTE * ROWS_PER_BEAT;
ticksperminute 	= rowsperminute * TICKS_PER_ROW;
tickspersecond	= ticksperminute / 60;

OCTAVE_DIFFS = {
	0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, -2, -2, -2, -2, -2, 0, 0, 0, 0, 0, 0, 0
}

-- visual properties
-- how many intermediate rectangles to draw between the notes in a bend
BEND_SEGMENTS = 16;
SEGMENT_WIDTH = 0.25;
NOW_LINE = false;
DEBUG_TEXT = false;

PIANOROLL_ZOOMX = {2, 2.5, 3, 3.5, 4};
PIANOROLL_ZOOMY = {11, 12, 16, 18, 20};
PIANOROLL_SCROLLX = 0;
PIANOROLL_SCROLLY = 0;

local zoomycoeff = 1.15
for i = 1, #PIANOROLL_ZOOMY do
	PIANOROLL_ZOOMY[i] = PIANOROLL_ZOOMY[i] * zoomycoeff;
end

PARALLAX_LAYERS = {
	1, 2, 2, 2, 2, 2, 2,
	2, 1, 1, 1, 1, 1, 1,
	1, 1, 3, 5, 4, 3, 4,
	3, 3, 3, 3, 3, 3, 3
}
COLORS = {
	NONE		= {1,	1,	1},
	-- continuo
	CONT_BASS	= {0,	0,	0.5},
	CONT_CHORD	= {0.4,	0,	0.4},
	CONT_STAB	= {0.7,	0.3,0.8},
	-- voices
	THEME1		= {1, 0.3, 0.3},
	THEME2		= {1, 1, 0},
	THEME3		= {0, 1, 0},
	THEME4		= {0, 1, 1},
	
	MOTIF1		= {0.45, 0.10, 1},
	M1FRAG		= {0.66, 0.50, 1},
	-- octave blips
	MOTIF2		= {0.33, 0.5, 1},
	
	MOTIF3		= {1, 0.5, 0.2},
	
	MOTIF4		= {1,0,1},
	M4FRAG		= {1,0.5,1},
	
	MOTIF5		= {0.66, 0.85, 0},
	
	VOC_OTHER	= {1, 0.75, 0.5}
}
-- initial default colors for the channels
CHANNEL_COLORS = {
	COLORS.NONE, COLORS.CONT_BASS, COLORS.CONT_CHORD, COLORS.CONT_CHORD, COLORS.CONT_CHORD, COLORS.CONT_CHORD, COLORS.CONT_CHORD,
	COLORS.CONT_CHORD, COLORS.CONT_STAB, COLORS.CONT_STAB, COLORS.CONT_CHORD, COLORS.CONT_CHORD, COLORS.CONT_CHORD, COLORS.CONT_CHORD,
	COLORS.CONT_CHORD, COLORS.CONT_CHORD, COLORS.THEME1, COLORS.THEME2, COLORS.THEME3, COLORS.THEME4, COLORS.VOC_OTHER
}
-- each table has sub tables with two items { tick of occurence,  }
colorchanges = {
	{},{},{},{},{},{},{},
	{},{},{},{},{},{},{},
	{},{},
	-- -- voice 1
	{},
	-- -- voice 2
	{},
	-- -- voice 3
	{},
	-- -- voice 4
	{},
	-- -- supplementary voice "5"
	{}
}

-- playback properties
playing = false;
rendering = false;
currentframe = 0;
currentsongtick  = 0;
dtt = 0;

local moonshine = require 'moonshine'

function love.load()
	love.window.setTitle("Music Visualizer");
	success = love.window.setMode( 1500, 1020, {fullscreen=true, minwidth=800, minheight=600} )
	love.graphics.setDefaultFilter( "nearest", "nearest");
	
	timerthread = love.thread.newThread( "timerthread.lua" )
	
	audiosource = love.audio.newSource( "assets/song.wav", "stream" )
	
	IMG_GLOW	= love.graphics.newImage("assets/sqrglow.png");
	IMG_TITLE	= love.graphics.newImage("assets/title.png");
	SPRITES		= {
		-- substantial theme portions
		KL = love.graphics.newImage("assets/wK.png"), -- king large (main subject)
		QL = love.graphics.newImage("assets/wQ.png"), -- queen large
		RL = love.graphics.newImage("assets/wR.png"), -- rook large
		NL = love.graphics.newImage("assets/wN.png"), -- knight large
		
		-- insubstantial theme fragments
		KS = love.graphics.newImage("assets/wKSmall.png"), -- king small
		QS = love.graphics.newImage("assets/wQSmall.png"), -- queen small
		RS = love.graphics.newImage("assets/wRSmall.png"), -- rook small
		NS = love.graphics.newImage("assets/wNSmall.png"), -- knight small
	}
	
	spritechanges = {
		{},{},{},{},{},{},{},
		{},{},{},{},{},{},{},
		{},{},
		-- -- voice 1
		{
		{1530, SPRITES.KL}, {2320, false}, {3080, SPRITES.QL}, {3860, false},
		{5360, SPRITES.RL}, {6180, false}, {7904, SPRITES.KS}, {8261, false}, 
		{8636, SPRITES.KS}, {9308, SPRITES.KS}, {9655, false},
		{9785, SPRITES.KS}, {11336, false}, {12107, SPRITES.QS}, {12260, false},
		{12690, SPRITES.NS}, {12945, false}, {13111, SPRITES.RS},{13916, SPRITES.KS},
		{14776, SPRITES.QL},
		{15416, SPRITES.RS}, {15879, false}, {16136, SPRITES.NL},
		},
		-- voice 2
		{
		{-5, SPRITES.KL}, {1473, SPRITES.NL}, {2320, false}, {3080, SPRITES.NL},
		{3860, false}, {5360, SPRITES.QL}, {6100, false}, {11531, SPRITES.QS},
		{12307, SPRITES.KL}, {13116, SPRITES.KS}, {13813, SPRITES.KL}, 
		{15110, false}, {15563, SPRITES.RS}, {15944, false},
		{16111, SPRITES.KL},
		},
		-- voice 3
		{
		{3064, SPRITES.KL},{4074, false},{5360, SPRITES.NL}, {6180, false},
		{7673, SPRITES.NL}, {8275, false}, {9213, SPRITES.KS}, {9655, false},
		{9882, SPRITES.KS}, {11380, false}, {11540, SPRITES.NL}, {12178, false},
		{14604, SPRITES.KS}, {15991, false}, {16136, SPRITES.RL},
		},
		-- voice 4
		{
		{5360, SPRITES.KL},{6180, false},{7673, SPRITES.KL},{8469, false},
		{8824, SPRITES.KS}, {9401, SPRITES.KL}, {10000, SPRITES.KS},
		{10677, false},{11721, SPRITES.QS},{11906, false},
		{12307, SPRITES.NL},{12652, false},{13916, SPRITES.KS},{14604, SPRITES.QL},
		{15374, SPRITES.NL}, {15991, false}, {16136, SPRITES.QL},
		},
		-- supplementary voice "5"
		{{12934, SPRITES.KS}, {13105, false}}
	}
	
	
	local inlines = {};
	for line in io.lines("data/rrr.txt") do
		table.insert(inlines, line)
    end
	
	-- each note entry in the table will have the following attributes:
	-- pitch class, octave, start tick, end tick, bends[ semitones, tick ]
	CHANNELS = {};
	for i = 1, CHANNELCOUNT do
		CHANNELS[i] = {};
	end
	
	--print(inlines[2])
	
	-- first thing to do is figure out the order of the patterns
	-- starting at index 9 because the first 8 indices are the word "Order: "
	PATTERN_ORDER = {};
	local ptrnstr = inlines[2] .. ",";
	local currentword = "";
	for i = 9, #ptrnstr do
		local currchar = (string.sub(ptrnstr,i,i));
		if currchar == "," then
			-- plus signs are just pattern seperators, ignore em
			if currentword == "+" then
			else
				table.insert(PATTERN_ORDER, currentword);
			end
			currentword = ""
		else
			currentword = currentword .. currchar;
		end
	end
	
	-- pointer to the current notes we are modifying for each channel
	-- (it can actually hold over from the previous parsed pattern, thats why its only initialized once here)
	currentnote = {};
	for j = 1, CHANNELCOUNT do
		currentnote[j] = {};
	end
	
	for i = 1, 103 do
		--print("parsing pattern " .. PATTERN_ORDER[i]);
		-- this first line only indicates the number of rows to the pattern
		-- TODO: I assumed that every line is 64 rows long, which in reality can vary freely
		local ptrnstrtlinenum = 3 + (65 * PATTERN_ORDER[i]);
		local ptrnstrtline = inlines[ptrnstrtlinenum];
		local rowcount = string.sub(ptrnstrtline, 7);
		--print("rows: " .. rowcount);
		
		for j = 1, rowcount do
			local currentline = inlines[ptrnstrtlinenum + j]
			parseLine(i, rowcount, j, currentline);
		end
	end
	
	-- Notes with lengths longer than two beats (32 rows) will be trimmed.
	-- in the tracker files they just naturally fade out, so here we gotta cut them off for the visuals
	for ch = 1, CHANNELCOUNT do
		for i = 1, #CHANNELS[ch] do
			local currnote = CHANNELS[ch][i];
			local currnotelength = currnote.endtick - currnote.starttick
			if currnotelength > 32 * TICKS_PER_ROW then
				currnote.endtick = currnote.starttick + ( 32 * TICKS_PER_ROW );
			end
		end
	end
end

function parseLine(patternpos, patternsize, rowpos, rowdata)
	-- channel we are currently writing data into
	local channelnum = 0;
	-- index to the current note within the channel data
	local noteindex  = 0;
	local charsincepipe = 0;
	
	for i = 1, #rowdata do
		local currchar = (string.sub(rowdata,i,i));
		local currtick = (64 * (patternpos - 1) * TICKS_PER_ROW) + ((rowpos - 1) * TICKS_PER_ROW)
		
		if currchar == "|" then
			channelnum = channelnum + 1;
			charsincepipe = 0;
		else
			charsincepipe = charsincepipe + 1;
			-- first two characters of channel are the pitch class "C-", "C#", etc.
			if charsincepipe == 2 then
				local lastchar = (string.sub(rowdata, i-1, i-1));
				local pitchclassstring = lastchar .. currchar;
				
				if pitchclassstring == ".." then
				
				-- note cuts and releases end the current note of the given channel
				elseif pitchclassstring == "==" or pitchclassstring == "^^" then
					if currentnote[channelnum] then
						currentnote[channelnum].endtick = currtick;
						currentnote[channelnum] = nil;
					end
				
				-- PLACE A NOTE if something is here in the first two columns of the channel
				else
					noteindex = noteindex + 1;
					-- character inmediately after the first two is the octave number
					local nextchar = (string.sub(rowdata, i+1, i+1));
					
					-- puts an endtick on notes that continue right up till the onset of the next one
					if currentnote[channelnum] then
						currentnote[channelnum].endtick = currtick;
						currentnote[channelnum] = nil;
					end
					
					-- COLOR ASSIGNMENT:
					-- defaults to the initial color in the CHANNEL_COLORS table (or white if there is none)
					local notecolor;
					if CHANNEL_COLORS[channelnum] then
						notecolor = CHANNEL_COLORS[channelnum];
					else
						notecolor = COLORS.NONE;
					end
					local changes = colorchanges[channelnum];
					-- iterates through the color changes to see if any of them apply
					if changes then
						for q = 1, #changes do
							if changes[q][1] < currtick then
								notecolor = changes[q][2];
							end
						end
					end
					local csprite = false;
					local schanges = spritechanges[channelnum];
					-- iterates through sprite changes to see if any apply
					if schanges then
						for q = 1, #schanges do
							if schanges[q][1] < currtick then
								csprite = schanges[q][2];
							end
						end
					end

					local NewNote = {
						pitchclass = SEMITONE_VALUES[pitchclassstring],
						octave = nextchar,
						starttick = currtick,
						-- absurdly large default value which will be inevitably trimmed
						-- this, I guess, is better than leaving it nil and having to check for nil
						endtick  = 100000000,
						bends = {},
						-- this will turn true on note onset during playback
						glow = false,
						color = notecolor,
						squareshape = true,
						sprite = csprite
					};
					currentnote[channelnum] = NewNote;
					table.insert(CHANNELS[channelnum], NewNote);
				end
			end
			
			-- instrument column starts here, only two digits long
			if charsincepipe == 4 then
				local nextchar     = (string.sub(rowdata, i+1, i+1));
				-- the not square wave instrument will be drawn different in the visualizer
				-- everything else will get square noteheads
				if currchar .. nextchar == "11" then
					if currentnote[channelnum] then
						currentnote[channelnum].squareshape = false;
					end
				end
				-- theres literally one orch hit... im gonna display it up an octave so the glow fx dont stack oddly
				if currchar .. nextchar == "33" then
					if currentnote[channelnum] then
						--currentnote[channelnum].octave = currentnote[channelnum].octave + 1; -- add ++ please lua im beging you
						--currentnote[channelnum].color = COLORS.NONE; currentnote[channelnum].squareshape = false;
					end
				end
			end
			
			-- effects column starts here. doesn't matter if a note onset is present here or not
			-- so it gets its own section down here
			if charsincepipe == 9 then
			
				-- the digits will be in hex, so we have to convert now
				local nextchar     = (string.sub(rowdata, i+1, i+1));
				local nextnextchar = (string.sub(rowdata, i+2, i+2));
				local pbparamhex   = nextchar .. nextnextchar;
				local pbparam	   = tonumber(pbparamhex, 16);
			
				-- PITCH BEND UP
				if currchar == "F" then
					if currentnote[channelnum] then
						local semitones = math.floor(pbparam / 8)
						local newbend = { semitones, currtick }
						table.insert(currentnote[channelnum].bends, newbend);
					end
				-- PITCH BEND DOWN
				elseif currchar == "E" then
					if currentnote[channelnum] then
						local semitones = -math.floor(pbparam / 8)
						local newbend = { semitones, currtick }
						table.insert(currentnote[channelnum].bends, newbend);
					end
				end
			end
		end
	end
end

function love.keypressed(key, scancode, isrepeat)
	if key == "space" and not rendering then
		playing = not playing;
		timerthread:start()
	end
	if key == "r" and not playing then
		--audiosource:play();
		rendering = not rendering;
	end
	
	if key == "d" then
		love.thread.getChannel( 'endtimer' ):push( true )
	end
end

function love.resize( width, height )
	print(("Window resized to width: %d and height: %d."):format(width, height))
end

function love.update(dt)
	-- real time playback
	-- (cannot go on at the same time as rendering)
	if not rendering then
		local lastsongtick = 0;
		local stchan = love.thread.getChannel( 'songtick' );
		local s;
		for i = 1, stchan:getCount() do 
			s = stchan:pop();
		end
		if s then
			lastsongtick = currentsongtick;
			currentsongtick = s;
			PIANOROLL_SCROLLX = currentsongtick;
		end
		
		if playing then
			lastframe = currentframe;
			currentframe = currentframe + 1;
			
			-- whatever tick that crosses the zero line gets to start the audio playback
			if lastsongtick < 0 and currentsongtick >= 0 then
				audiosource:play();
			end
		end
		
	-- rendering
	else
		currentsongtick = tickspersecond * (OFFSET + ( currentframe / 60 ));
		PIANOROLL_SCROLLX = currentsongtick;
		
		love.graphics.captureScreenshot( screenshotFinished )
		
		currentframe = currentframe + 1;
	end
	
	dtt = dt;
end

function screenshotFinished(imagedata)
	dataOut = imagedata:encode("png")
	str_out = dataOut:getString()
	
	file = io.open ("out/" .. currentframe .. ".png", "wb")
	file:write(str_out)
	file:close()
end

function frametick()
	currentframetick = currentframetick + 1;
	-- 140 beats per minute:
	-- the ratio is 3 and 44/60 song ticks per 60hz frame
	-- so 44 of the 60 will be four ticks, and the others three ticks
	if ( currentframetick % 60 > 43 ) then
		songtick(); songtick(); songtick();
	else
		songtick(); songtick(); songtick(); songtick();
	end
end

function songtick()
	--PIANOROLL_SCROLLX = PIANOROLL_SCROLLX + 1;
	--currentsongtick = currentsongtick + 1;
end

function love.mousemoved( x, y, dx, dy, istouch )
	-- middle click and dragging: pans the view
	if love.mouse.isDown( 3 ) then
		PIANOROLL_SCROLLX = PIANOROLL_SCROLLX - (dx / PIANOROLL_ZOOMX[2]);
		PIANOROLL_SCROLLY = PIANOROLL_SCROLLY - (dy / PIANOROLL_ZOOMY[2]);
	end
end

function love.quit()
	
end

function love.draw()
	WINDOW_WIDTH  = love.graphics.getWidth();
	WINDOW_HEIGHT = love.graphics.getHeight();
	
	if DEBUG_TEXT then
		love.graphics.setColor(1,1,1);
		love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 15)
		love.graphics.print("frametick: " .. currentframe, 10, 30);
		love.graphics.print("songtick: " .. currentsongtick, 10, 45);
		love.graphics.print("campos: " .. piano_roll_untrax(WINDOW_WIDTH/2, 2),10,60);
	end
	
	love.graphics.setColor(1,1,1)
	-- every other beat is marked (32 ticks is two beats long)
	local pixelsperbeat = 32 * PIANOROLL_ZOOMX[2] * 3
	for i = -16, 16 do
		local linex = i * pixelsperbeat - ((PIANOROLL_SCROLLX * PIANOROLL_ZOOMX[2]) % pixelsperbeat) + WINDOW_WIDTH/2;
		--love.graphics.line(linex, 0, linex, WINDOW_HEIGHT);
	end
	
	-- now line
	if NOW_LINE then
		love.graphics.line(WINDOW_WIDTH/2, 0, WINDOW_WIDTH/2, WINDOW_HEIGHT);
	end

	-- left and right bounds of screen for each parallax layer
	leftbounds = {}; rightbounds = {};
	for i = 1, #PIANOROLL_ZOOMX do
		leftbounds[i]  = piano_roll_untrax(0,i);
		rightbounds[i] = piano_roll_untrax(WINDOW_WIDTH,i);
	end
	
	notesdrawn = 0;
	
	-- channels must be drawn in order from back to front
	for pl = 1, #PIANOROLL_ZOOMX do
		for ch = 1, CHANNELCOUNT do
			if ACTIVE_CHANNELS[ch] and PARALLAX_LAYERS[ch] == pl then
				for i = 1, #CHANNELS[ch] do
					drawNote(ch, i);
				end
			end
		end
	end
	
	local opacity = 2.7 - (currentframe / 120);
	love.graphics.setColor(1,1,1, opacity);
	love.graphics.draw(IMG_TITLE);
	
	if DEBUG_TEXT then
		love.graphics.print("Notes drawn: " .. notesdrawn)
	end
end

function drawNote(chnum, notenum)
	local currnote = CHANNELS[chnum][notenum];
	local layer = PARALLAX_LAYERS[chnum];
	local gl = currnote.glow;
	
	if currnote.starttick > rightbounds[layer] or currnote.endtick < leftbounds[layer] then
		return
	end
	if currnote.starttick < currentsongtick then
		gl = true;
	end
	
	local lightcolor = currnote.color; local darkcolor = {};
	-- must deep copy table to darken the color
	darkcolor[1] = 0.5 * lightcolor[1];
	darkcolor[2] = 0.5 * lightcolor[2];
	darkcolor[3] = 0.5 * lightcolor[3];
	
	if not gl then
		love.graphics.setColor(darkcolor)
	else
		love.graphics.setColor(lightcolor)
	end
	
	
	local notelength = currnote.endtick - currnote.starttick;
	-- base pitch before any bends
	local basepitch = (12 * (currnote.octave + OCTAVE_DIFFS[chnum])) + currnote.pitchclass;
	local cx = currnote.starttick
	
	local pitch = basepitch;
	
	if #currnote.bends > 0 then
		for i = 1, #currnote.bends do
			local cb = currnote.bends[i];
			
			initialnoteend = cb[2] - ((1/2) * BEND_SEGMENTS * SEGMENT_WIDTH );
			-- first, the rectangle that comes before the bend
			if (cx < currentsongtick) then love.graphics.setColor(lightcolor) else love.graphics.setColor(darkcolor) end
			-- local shape;
			-- -- the first segment of a bendy note can have a special onset shape
			-- if i == 1 and not currnote.squareshape then shape = 3 end
			drawTraRect(cx, pitch, initialnoteend - cx, 1, layer, cx < currentsongtick);
			
			-- can draw sprite at the first segment
			if (cx < currentsongtick and initialnoteend > currentsongtick) then
				drawSprite(currnote, pitch, layer)
			end
			
			cx = initialnoteend;
			-- now a set of rectangles acting as segments of the ebnd
			for q = 1, BEND_SEGMENTS do
				-- old linear slide
				--pitch = pitch + (cb[1] / (BEND_SEGMENTS + 1));
				
				-- new cosine based interpolation
				local ycoeff = -(1/2) * cb[1]
				local offset = (1/2) * cb[1]
				pitch = basepitch + (ycoeff * math.cos( math.pi * ( 1 / BEND_SEGMENTS ) * q )) + offset;
				
				drawTraRect(cx, pitch, SEGMENT_WIDTH, 1, layer);
				
				-- can draw sprites in this between part too
				if (cx < currentsongtick and cx+SEGMENT_WIDTH > currentsongtick) then
					drawSprite(currnote, pitch, layer)
				end
				
				cx = cx + SEGMENT_WIDTH;
			end
			
			pitch = basepitch + cb[1];
			basepitch = pitch;
			
			-- after the last bend, we draw one more rect to the end of the note
			if i == #currnote.bends then
				if (cx < currentsongtick) then love.graphics.setColor(lightcolor) else love.graphics.setColor(darkcolor) end
				local shape;
				if (currnote.squareshape) then shape = 1 else shape = 4 end
				drawTraRect(cx, pitch, (currnote.endtick - 1) - cx, 1, layer, cx < currentsongtick, shape);
				
				-- and can draw sprites in the last segment too
				if (cx < currentsongtick and currnote.endtick > currentsongtick) then
					drawSprite(currnote, pitch, layer)
				end
			end
		end
		
		return
	end
	-- non bending notes just get the regular single rectangle
	local shape;
	if (currnote.squareshape) then shape = 1 else shape = 4 end
	drawTraRect(currnote.starttick, pitch, notelength-1, 1, layer, gl, shape);
	
	if (currnote.starttick < currentsongtick and currnote.endtick > currentsongtick) then
		drawSprite(currnote, pitch, layer)
	end
	
	notesdrawn = notesdrawn + 1;
end

function drawSprite(note, y, layer)
	local spr = note.sprite;
	if not spr then return end
	
	local spritedim = PIANOROLL_ZOOMY[layer] * 2
	local sx = WINDOW_WIDTH/2 - (spritedim / 2);
	
	local sy = pianoroll_tray(y, layer) - (spritedim) + ((1/4) * spritedim);
		
	local widthcoeff  = spritedim / spr:getWidth();
	local heigthcoeff = spritedim / spr:getHeight();
	
	sx = math.min(sx, pianoroll_trax(note.endtick,layer) - spr:getWidth() * widthcoeff );
	
	--love.graphics.setColor(1,1,1)
	--love.graphics.rectangle("fill", sx, sy, spr:getWidth() * widthcoeff, spr:getHeight() * heigthcoeff);
	
	love.graphics.draw(spr, sx, sy, 0, widthcoeff, heigthcoeff)
end

-- draw transformed rectangle
function drawTraRect(x,y,w,h,layer,glow,shape)
	local rectx = pianoroll_trax(x, layer);   local recty = pianoroll_tray(y, layer);
	local rectw = w * PIANOROLL_ZOOMX[layer]; local recth = h * PIANOROLL_ZOOMY[layer];
	local rectendx = rectx + rectw; local rectendy = recty + recth;
	
	-- glow slowly fades as it moves away from the center of screen
	local r, g, b, a = love.graphics.getColor();
	local newalpha = (rectx / (WINDOW_WIDTH/2)) + 0.1
	love.graphics.setColor(r,g,b,newalpha);
	
	if glow then
		local glowradiusx = 100;
		local glowradiusy = 45;
			
		local glowx = rectx - glowradiusx; 
		local glowy = recty - glowradiusy;
		local gloww = ((rectendx + glowradiusx) - (rectx - glowradiusx)) / IMG_GLOW:getWidth();
		local glowh = ((rectendy + glowradiusy) - (recty - glowradiusy)) / IMG_GLOW:getHeight();
		love.graphics.draw(IMG_GLOW, glowx, glowy, 0, gloww, glowh);
	else
	end
	love.graphics.setColor(r,g,b,a);
	
	if shape == 1 or not shape then
		love.graphics.rectangle("fill", rectx, recty, rectw, recth);
	
	-- diamond
	elseif shape == 2 then
		love.graphics.polygon( "fill", 
			rectx, (recty + rectendy) / 2,
			(rectx + rectendx) / 2, recty,
			rectendx, (recty + rectendy) / 2,
			(rectx + rectendx) / 2, rectendy
		)
	-- left pointing triangle
	elseif shape == 3 then
		love.graphics.polygon( "fill", 
			rectx, (recty + rectendy) / 2,
			rectendx, recty,
			rectendx, rectendy
		)
	
	-- right pointing triangle
	elseif shape == 4 then
		love.graphics.polygon( "fill", 
			rectx, recty,
			rectx, rectendy,
			rectendx, (recty + rectendy) / 2
		)
	end
	
	--love.graphics.setColor(1,0,0)
	--love.graphics.line(rectx,(recty+rectendy)/2,rectx+rectw,(recty+rectendy)/2)
end

function pianoroll_trax(x, lyr)
	return PIANOROLL_ZOOMX[lyr] * (x - PIANOROLL_SCROLLX) + (WINDOW_WIDTH / 2); 
end
function pianoroll_tray(y, lyr)
	return PIANOROLL_ZOOMY[lyr] * (52 - y - PIANOROLL_SCROLLY ) + (WINDOW_HEIGHT / 2); 
end
function piano_roll_untrax(x, lyr)
	return ((x - (WINDOW_WIDTH / 2) ) / PIANOROLL_ZOOMX[lyr]) + PIANOROLL_SCROLLX;
end
function piano_roll_untray(y, lyr)
	return -((( y - ( WINDOW_HEIGHT / 2 ) ) / PIANOROLL_ZOOMY[lyr] ) + PIANOROLL_SCROLLY) + 52
end