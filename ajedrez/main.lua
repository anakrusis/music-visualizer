CHANNELCOUNT = 28;
SEMITONE_VALUES = {
	["C-"] = 0,
	["C#"] = 1,
	["D-"] = 2,
	["D#"] = 3,
	["E-"] = 4,
	["F-"] = 5,
	["F#"] = 6,
	["G-"] = 7,
	["G#"] = 8,
	["A-"] = 9,
	["A#"] = 10,
	["B-"] = 11,
}

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
	
	for i = 1, 1 do
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
end

function parseLine(patternpos, patternsize, rowpos, rowdata)
	-- channel we are currently writing data into
	local channelnum = 0;
	-- index to the current note within the channel data
	local noteindex  = 0;
	-- pointer to the current note we are modifying
	local currentnote = {};
	local charsincepipe = 0;
	
	for i = 1, #rowdata do
		local currchar = (string.sub(rowdata,i,i));
		
		if currchar == "|" then
			channelnum = channelnum + 1;
			charsincepipe = 0;
		else
			charsincepipe = charsincepipe + 1;
			-- first two characters of channel data are the pitch class "C-", "C#", etc.
			if charsincepipe == 2 then
				local lastchar = (string.sub(rowdata, i-1, i-1));
				local pitchclassstring = lastchar .. currchar
				print(pitchclassstring);
				
				if pitchclassstring == ".." then
				else
					noteindex = noteindex + 1;
					-- and the character inmediately after is the octave
					local nextchar = (string.sub(rowdata, i+1, i+1));
					
					currentnote = {
						pitchclass = SEMITONE_VALUES[pitchclassstring];
						octave = nextchar;
					};
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

end