ffxiv_task_gather = inheritsFrom(ml_task)
ffxiv_task_gather.name = "LT_GATHER"

function ffxiv_task_gather:Create()
    local newinst = inheritsFrom(ffxiv_task_gather)
    
    --ml_task members
    newinst.valid = true
    newinst.completed = false
    newinst.subtask = nil
    newinst.auxiliary = false
    newinst.process_elements = {}
    newinst.overwatch_elements = {}
    
    --ffxiv_task_gather members
    newinst.name = "LT_GATHER"
    newinst.gatherid = 0
	newinst.markerTime = 0
	newinst.currentMarker = false
	newinst.previousMarker = false
	newinst.gatherTimer = 0
	
    return newinst
end

---------------------------------------------------------------------------------------------
--FINDGATHERABLE: If (no current gathering target) Then (find the nearest gatherable target)
--Gets a gathering target by searching entity list for objectType = 6?
---------------------------------------------------------------------------------------------

c_findgatherable = inheritsFrom( ml_cause )
e_findgatherable = inheritsFrom( ml_effect )
function c_findgatherable:evaluate()
	if ( ml_task_hub.CurrentTask().gatherid == nil or ml_task_hub.CurrentTask().gatherid == 0 ) then
		return true
    end
    
    local gatherable = EntityList:Get(ml_task_hub.CurrentTask().gatherid)
    if (gatherable ~= nil) then
        if (not gatherable.cangather) then
            return true 
        end
    elseif (gatherable == nil) then
        return true
    end
    
    return false
end
function e_findgatherable:execute()
	ml_debug( "Getting new gatherable target" )
	local gatherable = GetNearestGatherable()
	if (gatherable ~= nil) then
		ml_task_hub.CurrentTask().gatherid = gatherable.id
	else
		if (ml_task_hub:CurrentTask().currentMarker ~= nil and ml_task_hub:CurrentTask().currentMarker ~= 0) then
			if ( os.difftime(os.time(), ml_task_hub:CurrentTask().gatherTimer) > 3 ) then
				local markerInfo = mm.GetMarkerInfo(ml_task_hub:CurrentTask().currentMarker)
				if (markerInfo ~= nil and markerInfo ~= 0) then
					Player:MoveTo(markerInfo.x, markerInfo.y, markerInfo.z, 10)
				end
			end
		end
	end
end

c_movetogatherable = inheritsFrom( ml_cause )
e_movetogatherable = inheritsFrom( ml_effect )
function c_movetogatherable:evaluate()
	if ( os.difftime(os.time(), ml_task_hub:CurrentTask().gatherTimer) < 3 ) then
		return false
	end
	
	if ( ml_task_hub:CurrentTask().gatherid ~= nil and ml_task_hub:CurrentTask().gatherid ~= 0 ) then
		local gatherable = EntityList:Get(ml_task_hub.CurrentTask().gatherid)
		if (gatherable ~= nil and gatherable.distance > 3) then
			return true
		end
	end
	
	return false
end
function e_movetogatherable:execute()
	local pos = EntityList:Get(ml_task_hub.CurrentTask().gatherid).pos
	if (pos ~= nil and pos ~= 0) then
		if (gGatherTP == "1") then
			GameHacks:TeleportToXYZ(pos.x,pos.y,pos.z)
		else
			local newTask = ffxiv_task_movetopos:Create()
			newTask.pos = pos
			newTask.range = 1.5
            newTask.gatherRange = 1.0
			ml_task_hub:CurrentTask():AddSubTask(newTask)
		end
	end
end

c_nextmarker = inheritsFrom( ml_cause )
e_nextmarker = inheritsFrom( ml_effect )
function c_nextmarker:evaluate()
	-- this function (along with the marker manager stuff in general) needs a major refactor
	-- for the purposes of beta I'm just doing all the marker checking shit for all modes here
	if (gBotMode == "Party-Grind" and not IsLeader() ) then
		return false
	end
	
	if ((gBotMode == "Gather" or gBotMode == "Fish") and gGMactive == "0") or
	   (gBotMode == "Grind" and gDoFates == "1" and gFatesOnly == "1")
	then
		return false
	end
	
	if gBotMode == "Gather" then
		local list = Player:GetGatherableSlotList()
		if (list ~= nil) then
			return false
		end
	end
	
	if ( ml_task_hub:CurrentTask().currentMarker ~= nil and ml_task_hub:CurrentTask().currentMarker ~= 0) then
        local marker = nil
        if (ml_task_hub:CurrentTask().currentMarker == false) then --default init value
            marker = GatherMgr.GetNextMarker(nil, nil)
        else
            local time = GatherMgr.GetMarkerTime(ml_task_hub:CurrentTask().currentMarker)
			if gBotMode == "Grind" then
				time = math.random(1800,3600)
			end
            if (time ~= 0 and os.difftime(os.time(),ml_task_hub:CurrentTask().markerTime) > time) then
                marker = GatherMgr.GetNextMarker(ml_task_hub:CurrentTask().currentMarker, ml_task_hub:CurrentTask().previousMarker)
            else
				return false
			end
        end
        
        if marker ~= nil then
            if marker ~= currentMarker then
                e_nextmarker.marker = marker
                return true
            end
        elseif (gBotMode == "Grind") then
			--ignore it so people don't whine about debug spam
			--ml_debug("No grind markers detected. Defaulting to local grinding at current position")
		else
            ml_error("The gather manager is enabled but no markers have been detected on mesh. Defaulting to random behavior and disabling gather manager")
            gGMactive = "0"
        end
	end
	
	return false
end
function e_nextmarker:execute()
    ml_task_hub:CurrentTask().previousMarker = ml_task_hub:CurrentTask().currentMarker
    ml_task_hub:CurrentTask().currentMarker = e_nextmarker.marker
    ml_task_hub:CurrentTask().markerTime = os.time()

	local markerInfo = mm.GetMarkerInfo(ml_task_hub:CurrentTask().currentMarker)
    local markerType = mm.GetMarkerType(ml_task_hub:CurrentTask().currentMarker)
    
    -- handle switching jobs (not implemented yet)
	if (gChangeJobs and (markerType == "miningSpot" or markerType == "botanySpot")) then
		if (markerType == "miningSpot" and Player.job == FFXIV.JOBS.BOTANIST) then
			--change job
		elseif (markerType == "botanySpot" and Player.job == FFXIV.JOBS.MINER) then
			--change job
		end
	end
end

c_gather = inheritsFrom( ml_cause )
e_gather = inheritsFrom( ml_effect )
function c_gather:evaluate()
	local node = EntityList:Get(ml_task_hub:CurrentTask().gatherid)
	if (node ~= nil and node.distance < 3) then
        return true
    end
	
	return false
end
function e_gather:execute()
    local list = Player:GetGatherableSlotList()
    if (list ~= nil) then
		-- first check to see if we have a gathermanager marker
		if (gGMactive == "1") then
			if (ml_task_hub:CurrentTask().currentMarker ~= nil) then
				local markerData = GatherMgr.GetMarkerData(ml_task_hub:CurrentTask().currentMarker)
				if (markerData ~= nil and markerData ~= 0) then
                    -- do 2 loops to allow prioritization of first item
					for i, item in pairs(list) do
						if item.name == markerData[1] then
							Player:Gather(item.index)
							ml_task_hub:CurrentTask().gatherTimer = os.time()
							return
						end
					end
                    
                    for i, item in pairs(list) do
						if item.name == markerData[2] then
							Player:Gather(item.index)
							ml_task_hub:CurrentTask().gatherTimer = os.time()
							return
						end
					end
				end
			end
		end
		
		-- otherwise just grab a random item 
		for i, item in pairs(list) do
			if item.chance > 50 then
				Player:Gather(item.index)
				ml_task_hub:CurrentTask().gatherTimer = os.time()
                return
			end
		end
    else
        local node = EntityList:Get(ml_task_hub:CurrentTask().gatherid)
        if ( node ) then
			local target = Player:GetTarget()
			if ( (target ~=nil and target.id ~= node.id) or target == nil or target == {} ) then
				Player:SetTarget(node.id)
			else
				Player:Interact(node.id)
			end

			if (gGatherTP == "1") then
				Player:MoveToStraight(Player.pos.x+2, Player.pos.y, Player.pos.z+2)
			end
		else
			wt_error("If you can see this, I was right hahaha")
		end
    end
end

---------------------------------------------------------------------------------------------
--STEALTH: If (distance to aggro < 18) Then (cast stealth)
--Uses stealth when gathering to avoid aggro
---------------------------------------------------------------------------------------------
c_stealth = inheritsFrom( ml_cause )
e_stealth = inheritsFrom( ml_effect )
function c_stealth:evaluate()
	if (gDoStealth == "0") then
		return false
	end
	local action = nil
	if (Player.job == FFXIV.JOBS.BOTANIST) then
		action = ActionList:Get(212)
	elseif (Player.job == FFXIV.JOBS.MINER) then
		action = ActionList:Get(229)
	end
	
	if (action and action.isready) then
	local mobList = EntityList("attackable,onmesh,aggressive,notincombat,maxdistance=17")
		if(TableSize(mobList) > 0 and not HasBuff(Player.id, 47)) or
		  (TableSize(mobList) == 0 and HasBuff(Player.id, 47)) 
		then
			return true
		end
	end
 
	return false
end
function e_stealth:execute()
	local action = nil
	if (Player.job == FFXIV.JOBS.BOTANIST) then
		action = ActionList:Get(212)
	elseif (Player.job == FFXIV.JOBS.MINER) then
		action = ActionList:Get(229)
	end
	if(action and action.isready) then
        if HasBuff(Player.id, 47) then
            Player:Stop()
        end
		action:Cast()
	end
end

function ffxiv_task_gather:Init()
	--init ProcessOverWatch cnes
	local ke_stealth = ml_element:create( "Stealth", c_stealth, e_stealth, 15 )
	self:add( ke_stealth, self.overwatch_elements)
	
	--init Process cnes
    --in descending priority order just for you stefan
    local ke_returnToMarker = ml_element:create( "ReturnToMarker", c_returntomarker, e_returntomarker, 25 )
	self:add( ke_returnToMarker, self.process_elements)
    
    local ke_nextMarker = ml_element:create( "NextMarker", c_nextmarker, e_nextmarker, 20 )
	self:add( ke_nextMarker, self.process_elements)
    
	local ke_findGatherable = ml_element:create( "FindGatherable", c_findgatherable, e_findgatherable, 15 )
	self:add(ke_findGatherable, self.process_elements)
	
	local ke_moveToGatherable = ml_element:create( "MoveToGatherable", c_movetogatherable, e_movetogatherable, 10 )
	self:add( ke_moveToGatherable, self.process_elements)
	
	local ke_gather = ml_element:create( "Gather", c_gather, e_gather, 5 )
	self:add(ke_gather, self.process_elements)
    
	self:AddTaskCheckCEs()
end

function ffxiv_task_gather:OnSleep()

end

function ffxiv_task_gather:OnTerminate()

end

function ffxiv_task_gather:IsGoodToAbort()

end

function ffxiv_task_gather.GUIVarUpdate(Event, NewVals, OldVals)
	for k,v in pairs(NewVals) do
		if (	k == "gGatherPS"	) then
			if (v == "1") then
				GameHacks:SetPermaSprint(true)
			else
				GameHacks:SetPermaSprint(false)
			end
		end
		if ( 	k == "gDoStealth" or
				k == "gRandomMarker" or
				k == "gChangeJobs" or
				k == "gGatherPS" or
				k == "gGatherTP" or
                k == "gIgnoreGatherLvl" ) then
			Settings.FFXIVMINION[tostring(k)] = v
		end
	end
	GUI_RefreshWindow(ml_global_information.MainWindow.Name)
end

-- UI settings etc
function ffxiv_task_gather.UIInit()
	GUI_NewCheckbox(ml_global_information.MainWindow.Name, "Use Stealth", "gDoStealth","Gather")
	GUI_NewCheckbox(ml_global_information.MainWindow.Name, "Randomize Markers", "gRandomMarker","Gather")
    GUI_NewCheckbox(ml_global_information.MainWindow.Name, "Ignore Marker Lvl", "gIgnoreGatherLvl","Gather")
	GUI_NewCheckbox(ml_global_information.MainWindow.Name, "Change Jobs (Not Working)", "gChangeJobs","Gather")
	GUI_NewCheckbox(ml_global_information.MainWindow.Name, "Teleport (HACK!)", "gGatherTP","Gather")
	GUI_NewCheckbox(ml_global_information.MainWindow.Name, "PermaSprint (HACK!)", "gGatherPS","Gather")
	
	GUI_SizeWindow(ml_global_information.MainWindow.Name,250,400)
	
	if (Settings.FFXIVMINION.gDoStealth == nil) then
		Settings.FFXIVMINION.gDoStealth = "0"
	end
	
	if (Settings.FFXIVMINION.gRandomMarker == nil) then
		Settings.FFXIVMINION.gRandomMarker = "0"
	end
	
	if (Settings.FFXIVMINION.gChangeJobs == nil) then
		Settings.FFXIVMINION.gChangeJobs = "0"
	end
	
	if (Settings.FFXIVMINION.gGatherTP == nil) then
		Settings.FFXIVMINION.gGatherTP = "0"
	end
	
	if (Settings.FFXIVMINION.gGatherPS == nil) then
		Settings.FFXIVMINION.gGatherPS = "0"
	end
    
    if (Settings.FFXIVMINION.gIgnoreGatherLvl == nil) then
		Settings.FFXIVMINION.gIgnoreGatherLvl = "1"
	end
	
	gDoStealth = Settings.FFXIVMINION.gDoStealth
	gRandomMarker = Settings.FFXIVMINION.gRandomMarker
	gChangeJobs = Settings.FFXIVMINION.gChangeJobs
	gGatherTP = Settings.FFXIVMINION.gGatherTP
	gGatherPS = Settings.FFXIVMINION.gGatherPS
    gIgnoreGatherLvl = Settings.FFXIVMINION.gIgnoreGatherLvl
    if(gGatherPS == "1") then
        GameHacks:SetPermaSprint(true)
    end
	
	RegisterEventHandler("GUI.Update",ffxiv_task_gather.GUIVarUpdate)
end