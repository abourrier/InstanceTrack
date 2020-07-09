local InstanceTrack = LibStub("AceAddon-3.0"):GetAddon("InstanceTrack")

InstanceTrack.defaults = {
    char = {
        framePoint = { point = "CENTER", relativePoint = "CENTER", xOfs = 0, yOfs = 0 },
        isDisplayed = true,
        hourDetailsShown = false,
        dayDetailsShown = false,
        instanceHistory = {}
    }
}

function InstanceTrack:ChatCommand(input)
    if input == "show" then
        self:Display()
    elseif input == "hide" then
        self:Hide()
    elseif input == "reset" then
        self.db.char.framePoint = self.defaults.char.framePoint
        self:Print("Reload to reset position.")
    else
        self:Print("Available commands: 'show', 'hide' and 'reset'.")
    end
end

function InstanceTrack:CreateDB()
    self.db = LibStub("AceDB-3.0"):New("InstanceTrackDB", self.defaults)

    for key, _ in pairs(self.db.char) do
        if self.defaults.char[key] == nil then
            self.db[key] = nil
        end
    end

    for key, value in pairs(self.defaults.char) do
        if self.db.char[key] == nil then
            self.db.char[key] = value
        end
    end
end

function InstanceTrack:CreateState()
    self.state = { nbHourInstances = 0, nbDayInstances = 0, nextHourReset, nextDayReset, isInTrackedInstance }
    self:UpdateState()
end

function InstanceTrack:Display()
    self.displayTimer = self:ScheduleRepeatingTimer("DisplayState", 1)
    self.titleFrame:Show()
    self.db.char.isDisplayed = true
end

function InstanceTrack:Hide()
    self.titleFrame:Hide()
    self.db.char.isDisplayed = false
    self:CancelTimer(self.displayTimer)
end

function InstanceTrack:InsertCurrentInstanceInHistory(currentInstance)
    local instanceFound = false
    self.state.isInTrackedInstance = true
    for _, instance in ipairs(self.db.char.instanceHistory) do
        if instance.zoneUID == currentInstance.zoneUID and instance.zoneText == currentInstance.zoneText then
            instanceFound = true
            instance.timestamp = time()
            break
        end
    end
    if not instanceFound then
        table.insert(self.db.char.instanceHistory, { timestamp = time(), zoneUID = currentInstance.zoneUID, zoneText = currentInstance.zoneText })
    end
    table.sort(self.db.char.instanceHistory, function(a, b)
        return a.timestamp < b.timestamp
    end)
    self.currentInstanceTimestampTimer = self:ScheduleRepeatingTimer("SetCurrentInstanceTime", 1)
    self:UpdateState()
end

function InstanceTrack:SetCurrentInstanceTime()
    local history = self.db.char.instanceHistory
    history[table.getn(history)].timestamp = time()
end

function InstanceTrack:IsDisplayed()
    return self.db.char.isDisplayed
end

function InstanceTrack:UpdateState()
    local history = self.db.char.instanceHistory

    -- delete old instances --
    while next(history) ~= nil and time() - history[1].timestamp > 86400 do
        table.remove(history, 1)
    end

    -- day instances --
    self.state.nbDayInstances = table.getn(history)
    if self.state.nbDayInstances > 0 then
        local index = math.max(1, self.state.nbDayInstances - 29)
        self.state.nextDayReset = history[index]
        self:ScheduleTimer("UpdateState", self.state.nextDayReset.timestamp + 86400 - time())
    else
        self.state.nextDayReset = nil
    end

    -- hour instances --
    local i, nbHour = table.getn(history), 0
    while i > 0 and time() - history[i].timestamp < 3600 do
        nbHour = nbHour + 1
        i = i - 1
    end
    self.state.nbHourInstances = nbHour
    if self.state.nbHourInstances > 0 then
        local indexDelta = math.max(1, self.state.nbHourInstances - 4)
        self.state.nextHourReset = history[i + indexDelta]
        self:ScheduleTimer("UpdateState", self.state.nextHourReset.timestamp + 3600 - time())
    else
        self.state.nextHourReset = nil
    end

end

function InstanceTrack:PLAYER_ENTERING_WORLD()
    self:CancelTimer(self.currentInstanceTimestampTimer)
    self.state.isInTrackedInstance = false
    local _, instanceType = IsInInstance()
    if instanceType == "party" or instanceType == "raid" then
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
    else
        self:UnregisterEvent("PLAYER_TARGET_CHANGED")
    end
end

function InstanceTrack:PLAYER_TARGET_CHANGED()
    local targetGUID = UnitGUID("target")
    if (targetGUID ~= nil) and (targetGUID:sub(1, 8) == "Creature") then
        local _, _, _, _, zoneUID, _, _ = strsplit("-", targetGUID)
        self:InsertCurrentInstanceInHistory({ zoneText = GetRealZoneText(), zoneUID = zoneUID })
        self:UnregisterEvent("PLAYER_TARGET_CHANGED")
    end
end
