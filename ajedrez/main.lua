-- song specific properties
CHANNELCOUNT = 28;
TICKS_PER_ROW = 3;
SEMITONE_VALUES = {
	["C-"] = 0, ["C#"] = 1, ["D-"] = 2, ["D#"] = 3,
	["E-"] = 4, ["F-"] = 5, ["F#"] = 6, ["G-"] = 7,
	["G#"] = 8, ["A-"] = 9, ["A#"] = 10,["B-"] = 11,
}
ACTIVE_CHANNELS = { 
	false, true,  true,  true,  true,  true,  true, 
	true,  true,  true,  false, false, false, false,
	false, false, true,  true,  true,  true,  true,
	false, false, false, false, false, false, false
}

-- visual properties
NOTE_HEIGHT = 4;

function love.load()		
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
	
	for i = 1, 4 do
		print("parsing pattern " .. PATTERN_ORDER[i]);
		-- this first line only indicates the number of rows to the pattern
		-- TODO: I assumed that every line is 64 rows long, which in reality can vary freely
		local ptrnstrtlinenum = 3 + (65 * PATTERN_ORDER[i]);
		local ptrnstrtline = inlines[ptrnstrtlinenum];
		local rowcount = string.sub(ptrnstrtline, 7);
		print("rows: " .. rowcount);
		
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
		
		if currchar == "|" then
			channelnum = channelnum + 1;
			charsincepipe = 0;
		else
			charsincepipe = charsincepipe + 1;
			-- first two characters of channel are the pitch class "C-", "C#", etc.
			if charsincepipe == 2 then
				local lastchar = (string.sub(rowdata, i-1, i-1));
				local pitchclassstring = lastchar .. currchar;
				
				local currtick = (64 * (patternpos - 1) * TICKS_PER_ROW) + ((rowpos - 1) * TICKS_PER_ROW)
				
				if pitchclassstring == ".." then
				
				-- note cuts and releases end the current note of the given channel
				elseif pitchclassstring == "==" or pitchclassstring == "^^" then
					if currentnote[channelnum] then
						currentnote[channelnum].endtick = currtick;
					end
				
				-- PLACE A NOTE if something is here in the first two columns of the channel
				else
					noteindex = noteindex + 1;
					-- character inmediately after the first two is the octave number
					local nextchar = (string.sub(rowdata, i+1, i+1));
					
					-- puts an endtick on notes that continue right up till the onset of the next one
					if currentnote[channelnum] then
						currentnote[channelnum].endtick = currtick;
					end
					
					print(pitchclassstring);
					local NewNote = {
						pitchclass = SEMITONE_VALUES[pitchclassstring],
						octave = nextchar,
						starttick = currtick,
						-- absurdly large default value which will be inevitably trimmed
						-- this, I guess, is better than leaving it nil and having to check for nil
						endtick  = 100000000
					};
					currentnote[channelnum] = NewNote;
					table.insert(CHANNELS[channelnum], NewNote);
				end
			end
			
			-- effects column starts here. doesn't matter if a note onset is present here or not
			-- so it gets its own section down here
			if charsincepipe == 9 then
			
			end
		end
	end
end

function love.update()

end

function love.draw()
	local wh = love.graphics.getHeight();

	for ch = 1, CHANNELCOUNT do
		if ACTIVE_CHANNELS[ch] then
			for i = 1, #CHANNELS[ch] do
				local currnote = CHANNELS[ch][i]
				local notelength = currnote.endtick - currnote.starttick;
				local pitch = (12 * currnote.octave) + currnote.pitchclass;
				
				local notey = wh - (pitch * NOTE_HEIGHT);
					
				love.graphics.rectangle("fill", currnote.starttick, notey, notelength, NOTE_HEIGHT);
		end
		end
	end
end