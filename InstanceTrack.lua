local InstanceTrack = LibStub('AceAddon-3.0'):NewAddon('InstanceTrack', 'AceConsole-3.0', 'AceEvent-3.0', 'AceTimer-3.0')

function InstanceTrack:OnInitialize()
    self:CreateDB()
    self:CreateState()
    self:RegisterChatCommand('itrack', 'ChatCommand')
    self:RegisterChatCommand('instancetrack', 'ChatCommand')
    self:RegisterEvent('PLAYER_ENTERING_WORLD')
end

function InstanceTrack:OnEnable()
    self:CreateFrames()
    if self:IsDisplayed() then
        self:Display()
    else
        self:Hide()
    end
end

InstanceTrack.defaults = {
    char = {
        framePoint = { point = 'CENTER', relativePoint = 'CENTER', xOfs = 0, yOfs = 0 },
        isDisplayed = true,
        hourDetailsShown = false,
        dayDetailsShown = false,
        instanceHistory = {}
    }
}

function InstanceTrack:ChatCommand(input)
    if input == 'show' then
        self:Display()
    elseif input == 'hide' then
        self:Hide()
    elseif input == 'reset' then
        self.db.char.framePoint = self.defaults.char.framePoint
        self:Print('Reload to reset position.')
    else
        self:Print('Available commands: \'show\', \'hide\' and \'reset\'.')
    end
end

function InstanceTrack:CreateDB()
    self.db = LibStub('AceDB-3.0'):New('InstanceTrackDB', self.defaults)

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
    self.displayTimer = self:ScheduleRepeatingTimer('DisplayState', 1)
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
    self.currentInstanceTimestampTimer = self:ScheduleRepeatingTimer('SetCurrentInstanceTime', 1)
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
        self:ScheduleTimer('UpdateState', self.state.nextDayReset.timestamp + 86400 - time())
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
        self:ScheduleTimer('UpdateState', self.state.nextHourReset.timestamp + 3600 - time())
    else
        self.state.nextHourReset = nil
    end

end

function InstanceTrack:PLAYER_ENTERING_WORLD()
    self:CancelTimer(self.currentInstanceTimestampTimer)
    self.state.isInTrackedInstance = false
    local _, instanceType = IsInInstance()
    if instanceType == 'party' or instanceType == 'raid' then
        self:RegisterEvent('PLAYER_TARGET_CHANGED')
    else
        self:UnregisterEvent('PLAYER_TARGET_CHANGED')
    end
end

function InstanceTrack:PLAYER_TARGET_CHANGED()
    local targetGUID = UnitGUID('target')
    if (targetGUID ~= nil) and (targetGUID:sub(1, 8) == 'Creature') then
        local _, _, _, _, zoneUID, _, _ = strsplit('-', targetGUID)
        self:InsertCurrentInstanceInHistory({ zoneText = GetRealZoneText(), zoneUID = zoneUID })
        self:UnregisterEvent('PLAYER_TARGET_CHANGED')
    end
end

local nbSummaryLines, padding, fontHeight, titleFontHeight = 3, 6, 10, 11
local font = 'Fonts/FRIZQT__.TTF'

local function format(number)
    if number < 10 then
        return '0' .. number
    else
        return number
    end
end

function InstanceTrack:TimerToText(timer)
    local seconds = timer % 60
    timer = timer - seconds
    local minutes = (timer / 60) % 60
    timer = timer - 60 * minutes
    local hours = timer / 3600

    if hours > 0 then
        return format(hours) .. ':' .. format(minutes) .. ':' .. format(seconds)
    elseif minutes > 0 then
        return format(minutes) .. ':' .. format(seconds)
    else
        return format(seconds)
    end
end

function InstanceTrack:CreateFontString(parent)
    local fontString = parent:CreateFontString()
    fontString:SetFont(font, fontHeight)
    fontString:SetJustifyH('LEFT')
    return fontString
end

function InstanceTrack:CreateFrames()

    -- title frame --
    local titleFrame = CreateFrame('Frame', nil, UIParent)
    self.titleFrame = titleFrame
    titleFrame:SetHeight(2 * padding + titleFontHeight)
    local dbPoint = self.db.char.framePoint
    titleFrame:SetPoint(dbPoint.point, UIParent, dbPoint.relativePoint, dbPoint.xOfs, dbPoint.yOfs)
    titleFrame:SetBackdrop({ bgFile = 'Interface/DialogFrame/UI-DialogBox-Background-Dark' })

    local title = self:CreateFontString(titleFrame)
    title:SetPoint('TOPLEFT', titleFrame, 'TOPLEFT', padding, -padding)
    title:SetText('InstanceTrack')

    -- moving settings --
    titleFrame:SetMovable(true)
    titleFrame:EnableMouse(true)
    titleFrame:RegisterForDrag('LeftButton')
    titleFrame:SetScript('OnDragStart', titleFrame.StartMoving)
    titleFrame:SetScript('OnDragStop', function()
        titleFrame:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = titleFrame:GetPoint()
        self.db.char.framePoint = { point = point, relativePoint = relativePoint, xOfs = xOfs, yOfs = yOfs }
    end)

    -- summary frame --
    local summaryFrame = CreateFrame('Frame', nil, titleFrame)
    summaryFrame:SetBackdrop({ bgFile = 'Interface/DialogFrame/UI-DialogBox-Background' })
    summaryFrame:SetPoint('TOP', titleFrame, 'BOTTOM')
    summaryFrame:SetHeight(nbSummaryLines * fontHeight + (nbSummaryLines + 1) * padding)

    summaryFrame.titleRow = {}
    local summaryTitleTexts = { 'Period', 'Instances', 'Next reset', 'Details' }
    local xOfs = { padding, 0, 0, 0, 0 }
    local yOfs = { -padding, 0, 0, 0 }
    for i = 2, 4 do
        yOfs[i] = yOfs[i - 1] - (fontHeight + padding)
    end
    for i, text in ipairs(summaryTitleTexts) do
        local fontString = self:CreateFontString(summaryFrame)
        fontString:SetPoint('TOPLEFT', summaryFrame, 'TOPLEFT', xOfs[i], yOfs[1])
        fontString:SetText(text)
        xOfs[i + 1] = xOfs[i] + fontString:GetWidth() + padding
        summaryFrame.titleRow[i] = fontString
    end

    local hourText = self:CreateFontString(summaryFrame)
    hourText:SetText('1h')
    hourText:SetPoint('TOPLEFT', summaryFrame, 'TOPLEFT', xOfs[1], yOfs[2])
    local dayText = self:CreateFontString(summaryFrame)
    dayText:SetText('24h')
    dayText:SetPoint('TOPLEFT', summaryFrame, 'TOPLEFT', xOfs[1], yOfs[3])

    local hourInstances = self:CreateFontString(summaryFrame)
    self.hourInstances = hourInstances
    hourInstances:SetPoint('TOPLEFT', summaryFrame, 'TOPLEFT', xOfs[2], yOfs[2])
    local dayInstances = self:CreateFontString(summaryFrame)
    self.dayInstances = dayInstances
    dayInstances:SetPoint('TOPLEFT', summaryFrame, 'TOPLEFT', xOfs[2], yOfs[3])

    local hourNext = self:CreateFontString(summaryFrame)
    self.hourNext = hourNext
    hourNext:SetPoint('TOPLEFT', summaryFrame, 'TOPLEFT', xOfs[3], yOfs[2])
    local dayNext = self:CreateFontString(summaryFrame)
    self.dayNext = dayNext
    dayNext:SetPoint('TOPLEFT', summaryFrame, 'TOPLEFT', xOfs[3], yOfs[3])

    local hourDetailsCheckbox = CreateFrame('CheckButton', nil, summaryFrame, 'ChatConfigCheckButtonTemplate')
    local yOfsCorrection = (hourDetailsCheckbox:GetHeight() - fontHeight) / 2
    hourDetailsCheckbox:SetPoint('TOPLEFT', summaryFrame, 'TOPLEFT', xOfs[4], yOfs[2] + yOfsCorrection)
    hourDetailsCheckbox:SetChecked(self.db.char.hourDetailsShown)
    local dayDetailsCheckbox = CreateFrame('CheckButton', nil, summaryFrame, 'ChatConfigCheckButtonTemplate')
    dayDetailsCheckbox:SetPoint('TOPLEFT', summaryFrame, 'TOPLEFT', xOfs[4], yOfs[3] + yOfsCorrection)
    dayDetailsCheckbox:SetChecked(self.db.char.dayDetailsShown)

    -- details frame --
    local detailsFrame = CreateFrame('Frame', nil, titleFrame)
    self.detailsFrame = detailsFrame
    detailsFrame:SetPoint('TOP', summaryFrame, 'BOTTOM')
    detailsFrame:SetBackdrop({ bgFile = 'Interface/DialogFrame/UI-DialogBox-Background' })
    if self.db.char.hourDetailsShown or self.db.char.dayDetailsShown then
        detailsFrame:Show()
    else
        detailsFrame:Hide()
    end
    detailsFrame.rows = {}
    detailsFrame:SetHeight(200)

    -- set width --
    local width = xOfs[5]
    titleFrame:SetWidth(width)
    summaryFrame:SetWidth(width)
    detailsFrame:SetWidth(width)

    -- callbacks --

    hourDetailsCheckbox:SetScript('OnClick', function()
        dayDetailsCheckbox:SetChecked(false)
        self.db.char.hourDetailsShown = hourDetailsCheckbox:GetChecked()
        self.db.char.dayDetailsShown = false
        self:DisplayDetails()
        if self.db.char.hourDetailsShown then
            detailsFrame:Show()
        else
            detailsFrame:Hide()
        end
    end)

    dayDetailsCheckbox:SetScript('OnClick', function()
        hourDetailsCheckbox:SetChecked(false)
        self.db.char.hourDetailsShown = false
        self.db.char.dayDetailsShown = dayDetailsCheckbox:GetChecked()
        self:DisplayDetails()
        if self.db.char.dayDetailsShown then
            detailsFrame:Show()
        else
            detailsFrame:Hide()
        end
    end)

end

function InstanceTrack:DisplayState()
    self.hourInstances:SetText(self.state.nbHourInstances .. '/5')
    if self.state.nbHourInstances > 4 then
        self.hourInstances:SetTextColor(1, 0, 0)
    elseif self.state.nbHourInstances > 3 then
        self.hourInstances:SetTextColor(1, 0.647, 0)
    else
        self.hourInstances:SetTextColor(0, 1, 0)
    end

    self.dayInstances:SetText(self.state.nbDayInstances .. '/30')
    if self.state.nbDayInstances > 29 then
        self.dayInstances:SetTextColor(1, 0, 0)
    elseif self.state.nbDayInstances > 24 then
        self.dayInstances:SetTextColor(1, 0.647, 0)
    else
        self.dayInstances:SetTextColor(0, 1, 0)
    end

    if self.state.nextHourReset ~= nil then
        if self.state.nbHourInstances == 1 and self.state.isInTrackedInstance then
            self.hourNext:SetText('01:00:00')
        else
            self.hourNext:SetText(self:TimerToText(self.state.nextHourReset.timestamp + 3600 - time()))
        end
    else
        self.hourNext:SetText('')
    end

    if self.state.nextDayReset ~= nil then
        if self.state.nbDayInstances == 1 and self.state.isInTrackedInstance then
            self.dayNext:SetText('24:00:00')
        else
            self.dayNext:SetText(self:TimerToText(self.state.nextDayReset.timestamp + 86400 - time()))
        end
    else
        self.dayNext:SetText('')
    end

    if self.db.char.dayDetailsShown or self.db.char.hourDetailsShown then
        self:DisplayDetails()
    end
end

function InstanceTrack:DisplayDetails()
    local iRow, start, stop, resetDuration = 0, 1, table.getn(self.db.char.instanceHistory), 86400
    if self.db.char.hourDetailsShown then
        start = stop - self.state.nbHourInstances + 1
        resetDuration = 3600
    end
    for i = start, stop do
        iRow = iRow + 1
        local instance = self.db.char.instanceHistory[i]
        if iRow > table.getn(self.detailsFrame.rows) then
            local row = self:CreateFontString(self.detailsFrame)
            row:SetPoint('TOPLEFT', self.detailsFrame, 'TOPLEFT', padding, -padding * iRow - fontHeight * (iRow - 1))
            self.detailsFrame.rows[iRow] = row
        end
        self.detailsFrame.rows[iRow]:SetText(iRow .. '. ' .. instance.zoneText .. ' ' .. self:TimerToText(instance.timestamp + resetDuration - time()))
    end
    if self.state.isInTrackedInstance then
        local instance, timerText = self.db.char.instanceHistory[table.getn(self.db.char.instanceHistory)], '01:00:00'
        if self.db.char.dayDetailsShown then
            timerText = '24:00:00'
        end
        self.detailsFrame.rows[iRow]:SetText(iRow .. '. ' .. instance.zoneText .. ' ' .. timerText)
    end
    for i = iRow + 1, table.getn(self.detailsFrame.rows) do
        self.detailsFrame.rows[i]:SetText('')
    end
    self.detailsFrame:SetHeight(iRow * fontHeight + (iRow + 1) * padding)
end
