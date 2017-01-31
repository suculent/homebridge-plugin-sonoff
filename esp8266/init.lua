-- init.lua
local IDLE_AT_STARTUP_MS = 3000
print("Will bootstrap in " .. IDLE_AT_STARTUP_MS .. " milliseconds...")
tmr.alarm(1,IDLE_AT_STARTUP_MS,0,function()
    dofile("sonoff.lua") -- Security delay in case the app locks CPU
end)
