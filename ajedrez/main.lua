-- song specific properties
CHANNELCOUNT = 28;
TICKS_PER_ROW = 3;
SEMITONE_VALUES = {
	["C-"] = 0, ["C#"] = 1, ["D-"] = 2, ["D#"] = 3,
	["E-"] = 4, ["F-"] = 5, ["F#"] = 6, ["G-"] = 7,
	["G#"] = 8, ["A-"] = 9, ["A#"] = 10,["B-"] = 11,
}
ACTIVE_CHANNELS = { 
	false, true,  false,  false,  false,  false,  false, 
	false,  false,  false,  false, false, false, false, -- starting fourth in this row are drums
	false, false, true,  true,  true,  true,  true,
	false, false, false, false, false, false, false
}

OCTAVE_DIFFS = {
	0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, -2, -2, -2, -2, -2, 0, 0, 0, 0, 0, 0, 0
}

-- visual properties
-- how many intermediate rectangles to draw between the notes in a bend
BEND_SEGMENTS = 1;
SEGMENT_WIDTH = 2;

PIANOROLL_ZOOMX = 1;
PIANOROLL_ZOOMY = 8;
PIANOROLL_SCROLLX = 0;
PIANOROLL_SCROLLY = 0;

function love.load()
	love.window.setTitle("Music Visualizer");
	success = love.window.setMode( 800, 800, {resizable=true, minwidth=800, minheight=600} )
	
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
	
	for i = 1, 64 do
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

function love.update()

end

function love.mousemoved( x, y, dx, dy, istouch )
	-- middle click and dragging: pans the view
	if love.mouse.isDown( 3 ) then
		PIANOROLL_SCROLLX = PIANOROLL_SCROLLX - (dx / PIANOROLL_ZOOMX);
		PIANOROLL_SCROLLY = PIANOROLL_SCROLLY - (dy / PIANOROLL_ZOOMY);
	end
end

function love.draw()
	WINDOW_WIDTH  = love.graphics.getWidth();
	WINDOW_HEIGHT = love.graphics.getHeight();

	-- beat marks
	for i = 1, 32 do
		love.graphics.line(i*32*3 - (PIANOROLL_SCROLLX%96), 0, i*32*3 - (PIANOROLL_SCROLLX%96), WINDOW_HEIGHT);
	end

	for ch = 1, CHANNELCOUNT do
		if ACTIVE_CHANNELS[ch] then
			for i = 1, #CHANNELS[ch] do
				drawNote(ch, i);
			end
		end
	end
end

function drawNote(chnum, notenum)
	local currnote = CHANNELS[chnum][notenum];
	local notelength = currnote.endtick - currnote.starttick;
	-- base pitch before any bends
	local pitch = (12 * (currnote.octave + OCTAVE_DIFFS[chnum])) + currnote.pitchclass;
	local cx = currnote.starttick
	
	if #currnote.bends > 0 then
		for i = 1, #currnote.bends do
			local cb = currnote.bends[i];
			
			-- first, the rectangle that comes before the bend
			local rectwidth = (cb[2] - cx) * PIANOROLL_ZOOMX;
			local recty = pianoroll_tray(pitch);
			love.graphics.rectangle("fill", pianoroll_trax(cx), recty, rectwidth, PIANOROLL_ZOOMY);
			
			pitch = pitch + cb[1];
			cx = cb[2]
			
			-- after the last bend, we draw one more rect to the end of the note
			if i == #currnote.bends then
				local rectwidth = (currnote.endtick - cx) * PIANOROLL_ZOOMX;
				local recty = pianoroll_tray(pitch);
				love.graphics.rectangle("fill", pianoroll_trax(cx), recty, rectwidth, PIANOROLL_ZOOMY);
			end
		end
		
		return
	end
	local rectx = pianoroll_trax(currnote.starttick);
	local recty = pianoroll_tray(pitch);
	love.graphics.rectangle("fill", rectx, recty, notelength * PIANOROLL_ZOOMX, PIANOROLL_ZOOMY);
end

function pianoroll_trax(x)
	return PIANOROLL_ZOOMX * (x - PIANOROLL_SCROLLX) + (WINDOW_WIDTH / 2); 
end
function pianoroll_tray(y)
	return PIANOROLL_ZOOMY * (60 - y - PIANOROLL_SCROLLY ) + (WINDOW_HEIGHT / 2); 
end