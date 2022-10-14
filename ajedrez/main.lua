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
	false, true,  true,  true,  true,  true,  false, 
	false,  false,  false,  false, false, false, false, -- starting fourth in this row are drums
	false, false, true,  true,  true,  true,  true,
	false, false, false, false, false, false, false
}
BEATS_PER_MINUTE = 140;

OCTAVE_DIFFS = {
	0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, -2, -2, -2, -2, -2, 0, 0, 0, 0, 0, 0, 0
}

-- visual properties
-- how many intermediate rectangles to draw between the notes in a bend
BEND_SEGMENTS = 1;
SEGMENT_WIDTH = 2;

PIANOROLL_ZOOMX = {3, 2.5};
PIANOROLL_ZOOMY = {16, 12};
PIANOROLL_SCROLLX = 0;
PIANOROLL_SCROLLY = 0;

PARALLAX_LAYERS = {
	1, 2, 2, 2, 2, 2, 2,
	2, 2, 2, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1
}
COLORS = {
	NONE		= {1,	1,	1},
	-- continuo
	CONT_BASS	= {0,	0,	0.6},
	CONT_CHORD	= {0.6,	0,	0.6},
	-- voices
	VOC_SOP		= {1, 0.5, 0.5},
	VOC_ALT		= {1, 1, 0},
	VOC_TEN		= {0, 1, 0},
	VOC_BAS		= {0, 1, 1}
}
CHANNEL_COLORS = {
	COLORS.NONE, COLORS.CONT_BASS, COLORS.CONT_CHORD, COLORS.CONT_CHORD, COLORS.CONT_CHORD, COLORS.CONT_CHORD, COLORS.CONT_CHORD,
	COLORS.CONT_CHORD, COLORS.CONT_CHORD, COLORS.CONT_CHORD, COLORS.CONT_CHORD, COLORS.CONT_CHORD, COLORS.CONT_CHORD, COLORS.CONT_CHORD,
	COLORS.CONT_CHORD, COLORS.CONT_CHORD, COLORS.VOC_SOP, COLORS.VOC_ALT, COLORS.VOC_TEN, COLORS.VOC_BAS
}

-- playback properties
playing = false
currentframetick = 0;
currentsongtick  = 0;
dtt = 0;

local moonshine = require 'moonshine'

function love.load()
	love.window.setTitle("Music Visualizer");
	success = love.window.setMode( 1500, 800, {resizable=true, minwidth=800, minheight=600} )
	
	chain = moonshine.chain(moonshine.effects.glow)
	chain.glow.min_luma = 0.5;
	
	timerthread = love.thread.newThread( "timerthread.lua" )
	
	audiosource = love.audio.newSource( "song.wav", "stream" )
	
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
	
	for i = 1, 96 do
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
					
					--print(pitchclassstring);
					local NewNote = {
						pitchclass = SEMITONE_VALUES[pitchclassstring],
						octave = nextchar,
						starttick = currtick,
						-- absurdly large default value which will be inevitably trimmed
						-- this, I guess, is better than leaving it nil and having to check for nil
						endtick  = 100000000,
						bends = {}
					};
					currentnote[channelnum] = NewNote;
					table.insert(CHANNELS[channelnum], NewNote);
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
	if key == "space" then
		playing = not playing;
		timerthread:start()
		audiosource:play();
		
	end
	if key == "d" then
		love.thread.getChannel( 'endtimer' ):push( true )
	end
	if key == "f" then
	end
end

function love.resize( width, height )
	print(("Window resized to width: %d and height: %d."):format(width, height))
	chain = chain.resize(width, height)
end

function love.update(dt)
	local stchan = love.thread.getChannel( 'songtick' );
	local s;
	
	for i = 1, stchan:getCount() do 
		s = stchan:pop();
	end
	
	if s then
		currentsongtick = s;
		PIANOROLL_SCROLLX = currentsongtick;
		print(currentsongtick);
	end
	
	
	if playing then
	end
	dtt = dt;
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
		PIANOROLL_SCROLLX = PIANOROLL_SCROLLX - (dx / PIANOROLL_ZOOMX[1]);
		PIANOROLL_SCROLLY = PIANOROLL_SCROLLY - (dy / PIANOROLL_ZOOMY[1]);
	end
end

function love.quit()
	
end

function love.draw()
	WINDOW_WIDTH  = love.graphics.getWidth();
	WINDOW_HEIGHT = love.graphics.getHeight();

	love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 15)
	love.graphics.print("frametick: " .. currentframetick, 10, 30);
	love.graphics.print("songtick: " .. currentsongtick, 10, 45);

	love.graphics.setColor(1,1,1)
	-- every other beat is marked (32 ticks is two beats long)
	local pixelsperbeat = 32 * PIANOROLL_ZOOMX[1] * 3
	for i = -16, 16 do
		local linex = i * pixelsperbeat - ((PIANOROLL_SCROLLX * PIANOROLL_ZOOMX[1]) % pixelsperbeat) + WINDOW_WIDTH/2;
		love.graphics.line(linex, 0, linex, WINDOW_HEIGHT);
	end
	
	-- now line
	love.graphics.line(WINDOW_WIDTH/2, 0, WINDOW_WIDTH/2, WINDOW_HEIGHT);

	-- left and right bounds of screen for each parallax layer
	leftbounds = {}; rightbounds = {};
	for i = 1, #PIANOROLL_ZOOMX do
		leftbounds[i]  = piano_roll_untrax(0,i);
		rightbounds[i] = piano_roll_untrax(WINDOW_WIDTH,i);
	end
	
	notesdrawn = 0;
	
	for ch = 1, CHANNELCOUNT do
		if ACTIVE_CHANNELS[ch] then
			for i = 1, #CHANNELS[ch] do
				drawNote(ch, i);
			end
		end
	end
	
	love.graphics.print("Notes drawn: " .. notesdrawn)
end

function drawNote(chnum, notenum)
	local currnote = CHANNELS[chnum][notenum];
	local layer = PARALLAX_LAYERS[chnum]
	
	if currnote.starttick > rightbounds[layer] or currnote.endtick < leftbounds[layer] then
		return
	end
	
	if CHANNEL_COLORS[chnum] then
		love.graphics.setColor(CHANNEL_COLORS[chnum])
	else
		love.graphics.setColor(COLORS.NONE)
	end

	
	local notelength = currnote.endtick - currnote.starttick;
	-- base pitch before any bends
	local pitch = (12 * (currnote.octave + OCTAVE_DIFFS[chnum])) + currnote.pitchclass;
	local cx = currnote.starttick
	
	if #currnote.bends > 0 then
		for i = 1, #currnote.bends do
			local cb = currnote.bends[i];
			
			-- first, the rectangle that comes before the bend			
			drawTraRect(cx, pitch, cb[2] - cx, 1, layer);
			
			pitch = pitch + cb[1];
			cx = cb[2]
			
			-- after the last bend, we draw one more rect to the end of the note
			if i == #currnote.bends then
				drawTraRect(cx, pitch, currnote.endtick - cx, 1, layer);
			end
		end
		
		return
	end
	drawTraRect(currnote.starttick, pitch, notelength, 1, layer);
	
	notesdrawn = notesdrawn + 1;
end

-- draw transformed rectangle
function drawTraRect(x,y,w,h,layer)
	local rectx = pianoroll_trax(x, layer);   local recty = pianoroll_tray(y, layer);
	local rectw = w * PIANOROLL_ZOOMX[layer]; local recth = h * PIANOROLL_ZOOMY[layer];
	--chain.draw(function()
		love.graphics.rectangle("fill", rectx, recty, rectw, recth);
	--end)
end

function pianoroll_trax(x, lyr)
	return PIANOROLL_ZOOMX[lyr] * (x - PIANOROLL_SCROLLX) + (WINDOW_WIDTH / 2); 
end
function pianoroll_tray(y, lyr)
	return PIANOROLL_ZOOMY[lyr] * (60 - y - PIANOROLL_SCROLLY ) + (WINDOW_HEIGHT / 2); 
end
function piano_roll_untrax(x, lyr)
	return ((x - (WINDOW_WIDTH / 2) ) / PIANOROLL_ZOOMX[lyr]) + PIANOROLL_SCROLLX;
end
function piano_roll_untray(y, lyr)
	return -((( y - ( WINDOW_HEIGHT / 2 ) ) / PIANOROLL_ZOOMY[lyr] ) + PIANOROLL_SCROLLY) + 60
end