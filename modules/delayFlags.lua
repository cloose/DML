delayFlag = {}
delayFlag.version = "1.0.4"
delayFlag.verbose = false  
delayFlag.requiredLibs = {
	"dcsCommon", -- always
	"cfxZones", -- Zones, of course 
}
delayFlag.flags = {}

--[[--
	delay flags - simple flag switch & delay, allows for randomize
	and dead man switching 
	
	Copyright (c) 2022 by Christian Franz and cf/x AG
	
	Version History
	1.0.0 - Initial Version 
	1.0.1 - message attribute 
	1.0.2 - slight spelling correction 
		  - using cfxZones for polling 
		  - removed pollFlag 
	1.0.3 - bug fix for config zone name
		  - removed message attribute, moved to own module 
		  - triggerFlag --> triggerDelayFlag
	1.0.4 - startDelay
	
--]]--

function delayFlag.addDelayZone(theZone)
	table.insert(delayFlag.flags, theZone)
end

function delayFlag.getDelayZoneByName(aName) 
	for idx, aZone in pairs(delayFlag.flags) do 
		if aName == aZone.name then return aZone end 
	end
	if delayFlag.verbose then 
		trigger.action.outText("+++dlyF: no delay flag with name <" .. aName ..">", 30)
	end 
	
	return nil 
end

--
-- read attributes 
-- 
--
-- create rnd gen from zone 
--
function delayFlag.createTimerWithZone(theZone)
	-- delay
	theZone.delayMin, theZone.delayMax = cfxZones.getPositiveRangeFromZoneProperty(theZone, "timeDelay", 1) -- same as zone signature 
	if delayFlag.verbose then 
		trigger.action.outText("+++dlyF: time delay is <" .. theZone.delayMin .. ", " .. theZone.delayMax .. "> seconds", 30)
	end
	

	-- trigger flag 
	if cfxZones.hasProperty(theZone, "f?") then 
		theZone.triggerDelayFlag = cfxZones.getStringFromZoneProperty(theZone, "f?", "none")
	end
	
	if cfxZones.hasProperty(theZone, "in?") then 
		theZone.triggerDelayFlag = cfxZones.getStringFromZoneProperty(theZone, "in?", "none")
	end
	
	if cfxZones.hasProperty(theZone, "startDelay?") then 
		theZone.triggerDelayFlag = cfxZones.getStringFromZoneProperty(theZone, "startDelay?", "none")
	end
	
	if theZone.triggerDelayFlag then 
		theZone.lastDelayTriggerValue = trigger.misc.getUserFlag(theZone.triggerDelayFlag) -- save last value
	end
	
	
	theZone.method = cfxZones.getStringFromZoneProperty(theZone, "method", "flip")
	
	-- out flag 
	if cfxZones.hasProperty(theZone, "out!") then 
		theZone.outFlag = cfxZones.getNumberFromZoneProperty(theZone, "out!", -1)
	end
	
	-- on start
	if cfxZones.hasProperty(theZone, "onStart") then 
		theZone.onStart = cfxZones.getBoolFromZoneProperty(theZone, "onStart", false)
	end
	
	
	-- init 
	theZone.running = false 
	theZone.timeLimit = -1 

end


--
-- update 
-- 

function delayFlag.startDelay(theZone) 
	-- refresh timer 
	theZone.running = true
	
	-- set new expiry date 
	local delayMax = theZone.delayMax
	local delayMin = theZone.delayMin
	local delay = delayMax 
	
	if delayMin ~= delayMax then 
		-- pick random in range , say 3-7 --> 5 s!
		local delayDiff = (delayMax - delayMin) + 1 -- 7-3 + 1
		delay = dcsCommon.smallRandom(delayDiff) - 1 --> 0-4
		delay = delay + delayMin 
		if delay > theZone.delayMax then delay = theZone.delayMax end 
		if delay < 1 then delay = 1 end 
		
		if delayFlag.verbose then 
			trigger.action.outText("+++dlyF: delay " .. theZone.name .. " range " .. delayMin .. "-" .. delayMax .. ": selected " .. delay, 30)
		end
	end
	
	theZone.timeLimit = timer.getTime() + delay 
end

function delayFlag.update()
	-- call me in a second to poll triggers
	timer.scheduleFunction(delayFlag.update, {}, timer.getTime() + 1)
	
	local now = timer.getTime() 
	
	for idx, aZone in pairs(delayFlag.flags) do
		-- make sure to re-start before reading time limit
		if aZone.triggerDelayFlag then 
			local currTriggerVal = trigger.misc.getUserFlag(aZone.triggerDelayFlag)
			if currTriggerVal ~= aZone.lastDelayTriggerValue
			then 
				if delayFlag.verbose then 
					if aZone.running then 
						trigger.action.outText("+++dlyF: re-starting timer " .. aZone.name, 30)	
					else 
						trigger.action.outText("+++dlyF: init timer for " .. aZone.name, 30)
					end
				end 
				delayFlag.startDelay(aZone) -- we restart even if running 
				aZone.lastDelayTriggerValue = currTriggerVal
			end
		end
		
		if aZone.running then 
			-- check expiry 
			if now > aZone.timeLimit then 
				-- end timer 
				aZone.running = false 
				-- poll flag 
				cfxZones.pollFlag(aZone.outFlag, aZone.method)
				-- say message
				--if aZone.myMessage then 
				--	trigger.action.outText(aZone.myMessage, 30)
				--end
			end
		end
		
	end
end

--
-- START 
--
function delayFlag.readConfigZone()
	local theZone = cfxZones.getZoneByName("delayZonesConfig") 
	if not theZone then 
		if delayFlag.verbose then 
			trigger.action.outText("+++dlyF: NO config zone!", 30)
		end 
		return 
	end 
	
	delayFlag.verbose = cfxZones.getBoolFromZoneProperty(theZone, "verbose", false)
	
	if delayFlag.verbose then 
		trigger.action.outText("+++dlyF: read config", 30)
	end 
end

function delayFlag.onStart()
	for idx, theZone in pairs(delayFlag.flags) do 
		if theZone.onStart then 
			if delayFlag.verbose then 
				trigger.action.outText("+++dlyF: onStart for <"..theZone.name .. ">", 30)
			end
			delayFlag.startDelay(theZone) 
		end 
	end
end

function delayFlag.start()
	-- lib check
	if not dcsCommon.libCheck then 
		trigger.action.outText("cfx Delay Flags requires dcsCommon", 30)
		return false 
	end 
	if not dcsCommon.libCheck("cfx Delay Flags", 
		delayFlag.requiredLibs) then
		return false 
	end
	
	-- read config 
	delayFlag.readConfigZone()
	
	-- process cloner Zones 
	local attrZones = cfxZones.getZonesWithAttributeNamed("timeDelay")
	for k, aZone in pairs(attrZones) do 
		delayFlag.createTimerWithZone(aZone) -- process attributes
		delayFlag.addDelayZone(aZone) -- add to list
	end
	
	-- kick onStart
	delayFlag.onStart()
	
	-- start update 
	delayFlag.update()
	
	trigger.action.outText("cfx Delay Flag v" .. delayFlag.version .. " started.", 30)
	return true 
end

-- let's go!
if not delayFlag.start() then 
	trigger.action.outText("cfx Delay Flag aborted: missing libraries", 30)
	delayFlag = nil 
end