ml_task_queue = inheritsFrom(nil)

ml_task_queue.rootTask = nil
ml_task_queue.pendingTask = nil
ml_task_queue.pendingPrio = 0

function ml_task_queue:Add(task, prio)
    self:DeletePending()
    self.pendingTask = task
    self.pendingPrio = prio
end

function ml_task_queue:Update()
    if (self.rootTask ~= nil and self.rootTask ~= false) then
        local status = self.rootTask:Update()
        if (status ~= TS_PROGRESSING) then
            self:Delete()
        end
    end
end

function ml_task_queue:HasOrders()
    return self.rootTask ~= nil and self.rootTask ~= false
end

function ml_task_queue:HasPending()
    return self.pendingTask ~= nil and self.pendingTask ~= false
end

function ml_task_queue:IsGoodToAbort()
    local currTask = self.rootTask
    while (currTask ~= nil) do
        if (not currTask:IsGoodToAbort()) then
            return false
        end
        currTask = currTask.subtask
    end
end

function ml_task_queue:Delete()
    if (self.rootTask ~= nil) then
        self.rootTask = nil
    end
end

function ml_task_queue:Sleep()
    local foundTopLevel = false
    local currTask = self.rootTask
    while (currTask ~= nil) do
        currTask:OnSleep()
        if (not currTask:IsAuxiliary()) then
            currTask:OnSleep()
            currTask:DeleteSubTasks()
            break
        end
        
        currTask = currTask.subtask
    end
end

function ml_task_queue:PromotePending()
    if (not self.rootTask) then
        self.rootTask = self.pendingTask
        self.pendingTask = nil
		self.rootTask:Init()
    else
        ml_debug("Root task still alive, can't promote pending task")
    end
end

function ml_task_queue:PendingPriority()
	return self.pendingPrio
end

function ml_task_queue:DeletePending()
    if (self.pendingTask ~= nil) then
        self.pendingTask = nil
    end
end

function ml_task_queue:create( name )
	local newinst = inheritsFrom( ml_task_queue )
	newinst.name = name
    newinst.rootTask = false
    newinst.pendingTask = false
    newinst.pendingPrio = 0
	return newinst
end

function ml_task_queue:ShowDebugWindow()
	if ( self.DebugWindowCreated == nil ) then
		ml_debug( "Opening Queue Debug Window" )
		GUI_NewWindow( self.name, 140, 10, 100, 50 + #self.kelement_list * 14 )

		for k, elem in pairs( self.kelement_list ) do
			GUI_NewButton( self.name, elem.name , self.name .."::" .. elem.name )
		end
		self.DebugWindowCreated  = true
	end
end