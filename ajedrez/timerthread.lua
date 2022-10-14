require("love.timer")

TICKS_PER_ROW = 3;
ROWS_PER_BEAT = 16;
BEATS_PER_MINUTE = 140.19;

rowsperminute 	= BEATS_PER_MINUTE * ROWS_PER_BEAT;
ticksperminute 	= rowsperminute * TICKS_PER_ROW;
tickspersecond	= ticksperminute / 60;
secondspertick 	= 1 / tickspersecond;

songtick = 0;
playing = true;
starttime = love.timer.getTime();

while true do
	currenttime = love.timer.getTime() - starttime;
	
	songtick = tickspersecond * currenttime;
	love.thread.getChannel( 'songtick' ):push( songtick )
	
	love.timer.sleep( 1 / tickspersecond );
	
	local endtimer = love.thread.getChannel( 'endtimer' ):pop();
	if (endtimer) then
		break;
	end
end