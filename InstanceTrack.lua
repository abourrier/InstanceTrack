local IT = LibStub('AceAddon-3.0'):NewAddon('InstanceTrack', 'AceEvent-3.0', 'AceTimer-3.0')
IT.version = '2.1'

function IT:OnInitialize()
    self:InitDatabase()
    self:CreateState()
    self:InitUI()
    self:ScheduleRepeatingTimer('OneHertzCallback', 1)
    self:RegisterEvent('PLAYER_ENTERING_WORLD')
end

---------------------
-- Displayed state --
---------------------

function IT:CreateState()
    self.state = { nbHourInstances = 0, nbDayInstances = 0, nextHourReset, nextDayReset }
    self.time = time()
    self:UpdateState()
end

function IT:UpdateState()
    self.nextStateUpdate = nil
    local history = self.displayedHistory

    -- delete old instances --
    while next(history) and self.time - history[1].timestamp > 86400 do
        table.remove(history, 1)
    end

    -- day instances --
    self.state.nbDayInstances = table.getn(history)
    if self.state.nbDayInstances > 0 then
        local index = math.max(1, self.state.nbDayInstances - 29)
        self.state.nextDayReset = history[index]
        local nextDayReset = self.state.nextDayReset.timestamp + 86400
        if not self.nextStateUpdate or self.nextStateUpdate > nextDayReset then
            self.nextStateUpdate = nextDayReset
        end
    else
        self.state.nextDayReset = nil
    end

    -- hour instances --
    local i, nbHour = table.getn(history), 0
    while i > 0 and self.time - history[i].timestamp < 3600 do
        nbHour = nbHour + 1
        i = i - 1
    end
    self.state.nbHourInstances = nbHour
    if self.state.nbHourInstances > 0 then
        local indexDelta = math.max(1, self.state.nbHourInstances - 4)
        self.state.nextHourReset = history[i + indexDelta]
        local nextHourReset = self.state.nextHourReset.timestamp + 3600
        if not self.nextStateUpdate or self.nextStateUpdate > nextHourReset then
            self.nextStateUpdate = nextHourReset
        end
    else
        self.state.nextHourReset = nil
    end

end

--------
-- UI --
--------

IT.font = 'Fonts/FRIZQT__.TTF'
IT.fontHeight = 10
IT.padding = 6

function IT:CreateFrames()

    -- title frame --
    local titleFrame = CreateFrame('Frame', nil, UIParent)
    self.titleFrame = titleFrame
    titleFrame:SetHeight(26)
    local dbPoint = self.currentPlayerData.framePoint
    titleFrame:SetPoint(dbPoint.point, UIParent, dbPoint.relativePoint, dbPoint.xOfs, dbPoint.yOfs)
    titleFrame:SetBackdrop({ bgFile = 'Interface/DialogFrame/UI-DialogBox-Background-Dark' })

    local title = self:CreateFontString(titleFrame)
    title:SetPoint('LEFT', self.padding, 0)
    title:SetText('Instances')

    -- character choice dropdown --
    local dropdown = CreateFrame('Frame', 'InstanceTrackCharacterDropdown', titleFrame, 'UIDropDownMenuTemplate')
    dropdown:SetPoint('RIGHT', 10, -2)

    -- moving settings --
    titleFrame:SetMovable(true)
    titleFrame:EnableMouse(true)
    titleFrame:RegisterForDrag('LeftButton')
    titleFrame:SetScript('OnDragStart', titleFrame.StartMoving)
    titleFrame:SetScript('OnDragStop', function()
        titleFrame:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = titleFrame:GetPoint()
        self.currentPlayerData.framePoint = { point = point, relativePoint = relativePoint, xOfs = xOfs, yOfs = yOfs }
    end)

    -- summary frame --
    local summaryFrame = CreateFrame('Frame', nil, titleFrame)
    summaryFrame:SetBackdrop({ bgFile = 'Interface/DialogFrame/UI-DialogBox-Background' })
    summaryFrame:SetPoint('TOP', titleFrame, 'BOTTOM')
    summaryFrame:SetHeight(3 * self.fontHeight + 4 * self.padding)

    summaryFrame.titleRow = {}
    local summaryTitleTexts = { 'Period', 'Instances', 'Next reset', 'Details' }
    local xOfs = { self.padding, 0, 0, 0, 0 }
    local yOfs = { -self.padding, 0, 0, 0 }
    for i = 2, 4 do
        yOfs[i] = yOfs[i - 1] - (self.fontHeight + self.padding)
    end
    for i, text in ipairs(summaryTitleTexts) do
        local fontString = self:CreateFontString(summaryFrame)
        fontString:SetPoint('TOPLEFT', summaryFrame, 'TOPLEFT', xOfs[i], yOfs[1])
        fontString:SetText(text)
        xOfs[i + 1] = xOfs[i] + fontString:GetWidth() + self.padding
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
    local yOfsCorrection = (hourDetailsCheckbox:GetHeight() - self.fontHeight) / 2
    hourDetailsCheckbox:SetPoint('TOPLEFT', summaryFrame, 'TOPLEFT', xOfs[4], yOfs[2] + yOfsCorrection)
    hourDetailsCheckbox:SetChecked(self.currentPlayerData.hourDetailsShown)
    local dayDetailsCheckbox = CreateFrame('CheckButton', nil, summaryFrame, 'ChatConfigCheckButtonTemplate')
    dayDetailsCheckbox:SetPoint('TOPLEFT', summaryFrame, 'TOPLEFT', xOfs[4], yOfs[3] + yOfsCorrection)
    dayDetailsCheckbox:SetChecked(self.currentPlayerData.dayDetailsShown)

    -- details frame --
    local detailsFrame = CreateFrame('Frame', nil, titleFrame)
    self.detailsFrame = detailsFrame
    detailsFrame:SetPoint('TOP', summaryFrame, 'BOTTOM')
    detailsFrame:SetBackdrop({ bgFile = 'Interface/DialogFrame/UI-DialogBox-Background' })
    if self.currentPlayerData.hourDetailsShown or self.currentPlayerData.dayDetailsShown then
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
    UIDropDownMenu_SetWidth(dropdown, width / 2)

    -- callbacks --

    hourDetailsCheckbox:SetScript('OnClick', function()
        dayDetailsCheckbox:SetChecked(false)
        self.currentPlayerData.hourDetailsShown = hourDetailsCheckbox:GetChecked()
        self.currentPlayerData.dayDetailsShown = false
        self:DisplayDetails()
        if self.currentPlayerData.hourDetailsShown then
            detailsFrame:Show()
        else
            detailsFrame:Hide()
        end
    end)

    dayDetailsCheckbox:SetScript('OnClick', function()
        hourDetailsCheckbox:SetChecked(false)
        self.currentPlayerData.hourDetailsShown = false
        self.currentPlayerData.dayDetailsShown = dayDetailsCheckbox:GetChecked()
        self:DisplayDetails()
        if self.currentPlayerData.dayDetailsShown then
            detailsFrame:Show()
        else
            detailsFrame:Hide()
        end
    end)

end

function IT:InitUI()
    self:CreateFrames()
    if self.currentPlayerData.isDisplayed then
        self:Display()
    else
        self:Hide()
    end
end

function IT:Display()
    self.currentPlayerData.isDisplayed = true
    self.titleFrame:Show()
end

function IT:Hide()
    self.currentPlayerData.isDisplayed = false
    self.titleFrame:Hide()
end

function IT:formatNumber(number)
    if number < 10 then
        return '0' .. number
    else
        return number
    end
end

function IT:TimerToText(timer)
    local seconds = timer % 60
    timer = timer - seconds
    local minutes = (timer / 60) % 60
    timer = timer - 60 * minutes
    local hours = timer / 3600

    if hours > 0 then
        return self:formatNumber(hours) .. ':' .. self:formatNumber(minutes) .. ':' .. self:formatNumber(seconds)
    elseif minutes > 0 then
        return self:formatNumber(minutes) .. ':' .. self:formatNumber(seconds)
    else
        return self:formatNumber(seconds)
    end
end

function IT:CreateFontString(parent)
    local fontString = parent:CreateFontString()
    fontString:SetFont(self.font, self.fontHeight)
    fontString:SetJustifyH('LEFT')
    return fontString
end

function IT:DisplayState()
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

    if self.state.nextHourReset then
        self.hourNext:SetText(self:TimerToText(self.state.nextHourReset.timestamp + 3600 - self.time))
    else
        self.hourNext:SetText('')
    end

    if self.state.nextDayReset then
        self.dayNext:SetText(self:TimerToText(self.state.nextDayReset.timestamp + 86400 - self.time))
    else
        self.dayNext:SetText('')
    end

    if self.currentPlayerData.dayDetailsShown or self.currentPlayerData.hourDetailsShown then
        self:DisplayDetails()
    end
end

function IT:DisplayDetails()
    local iRow, start, stop, resetDuration = 0, 1, table.getn(self.displayedHistory), 86400

    if self.currentPlayerData.hourDetailsShown then
        start = stop - self.state.nbHourInstances + 1
        resetDuration = 3600
    end

    for i = start, stop do
        iRow = iRow + 1
        local instance = self.displayedHistory[i]
        if iRow > table.getn(self.detailsFrame.rows) then
            local row = self:CreateFontString(self.detailsFrame)
            row:SetPoint('TOPLEFT', self.detailsFrame, 'TOPLEFT', self.padding, -self.padding * iRow - self.fontHeight * (iRow - 1))
            self.detailsFrame.rows[iRow] = row
        end
        self.detailsFrame.rows[iRow]:SetText(iRow .. '. ' .. instance.zoneText .. ' ' .. self:TimerToText(instance.timestamp + resetDuration - self.time))
    end

    for i = iRow + 1, table.getn(self.detailsFrame.rows) do
        self.detailsFrame.rows[i]:SetText('')
    end

    self.detailsFrame:SetHeight(iRow * self.fontHeight + (iRow + 1) * self.padding)
end

------------------
-- Update Timer --
------------------

function IT:OneHertzCallback()
    self.time = time()

    if self.currentInstance then
        self.currentInstance.timestamp = self.time
    end

    if self.currentPlayerData.isDisplayed then
        self:DisplayState()
    end

    if self.nextStateUpdate == self.time then
        self:UpdateState()
    end
end

--------------
-- Tracking --
--------------

function IT:PLAYER_ENTERING_WORLD()
    self.currentInstance = nil
    local _, instanceType = IsInInstance()
    if instanceType == 'party' or instanceType == 'raid' then
        self:RegisterEvent('PLAYER_TARGET_CHANGED')
    else
        self:UnregisterEvent('PLAYER_TARGET_CHANGED')
    end
end

function IT:PLAYER_TARGET_CHANGED()
    local targetGUID = UnitGUID('target')
    if (targetGUID ~= nil) and (targetGUID:sub(1, 8) == 'Creature') then
        local _, _, _, _, zoneUID, _, _ = strsplit('-', targetGUID)
        self:InsertCurrentInstanceInHistory({ zoneText = GetRealZoneText(), zoneUID = zoneUID })
        self:UnregisterEvent('PLAYER_TARGET_CHANGED')
    end
end

function IT:InsertCurrentInstanceInHistory(currentInstance)
    local instanceFound = false
    local history = self.currentPlayerData.instanceHistory

    for _, instance in ipairs(history) do
        if instance.zoneUID == currentInstance.zoneUID and instance.zoneText == currentInstance.zoneText then
            instanceFound = true
            instance.timestamp = time()
            break
        end
    end

    if not instanceFound then
        table.insert(history, { timestamp = time(), zoneUID = currentInstance.zoneUID, zoneText = currentInstance.zoneText })
    end

    table.sort(history, function(a, b)
        return a.timestamp < b.timestamp
    end)

    self.currentInstance = history[table.getn(history)]
    self:UpdateState()
end


--------------
-- Database --
--------------

function IT:GetDefaultDatabase()
    return { char = {}, version = self.version }
end

function IT:GetDefaultFramePoint()
    return { point = 'CENTER', relativePoint = 'CENTER', xOfs = 0, yOfs = 0 }
end

function IT:GetDefaultCharData(currentPlayerString)
    return {
        framePoint = self:GetDefaultFramePoint(),
        hourDetailsShown = false,
        dayDetailsShown = false,
        isDisplayed = true,
        displayedCharacter = currentPlayerString,
        instanceHistory = {}
    }
end

function IT:MigrateFromOldVersion(old_version)
    for key, _ in pairs(self.db) do
        if key ~= 'char' then
            self.db[key] = nil
        end
    end

    if not old_version then
        for key, val in pairs(self.db.char) do
            val.displayedCharacter = key
            val.instanceHistory = val.instanceHistory or {}
        end
    end

    self.db.version = self.version
end

function IT:InitDatabase()
    if InstanceTrackDB == nil then
        InstanceTrackDB = self:GetDefaultDatabase()
    end

    self.db = InstanceTrackDB

    if self.db.version ~= self.version then
        self:MigrateFromOldVersion(self.db.version)
    end

    local currentPlayerString = UnitName('player') .. ' - ' .. GetRealmName()
    if self.db.char[currentPlayerString] == nil then
        self.db.char[currentPlayerString] = self:GetDefaultCharData(currentPlayerString)
    end
    self.currentPlayerData = self.db.char[currentPlayerString]
    self.displayedHistory = self.db.char[self.currentPlayerData.displayedCharacter].instanceHistory
end

----------
-- Chat --
----------

function IT:Print(message)
    print('|cFF00A0FFInstanceTrack: |r' .. message)
end

function IT:SlashCommand(input)
    if input == 'show' then
        self:Display()
    elseif input == 'hide' then
        self:Hide()
    elseif input == 'reset' then
        self.currentPlayerData.framePoint = self:GetDefaultFramePoint()
        self.currentPlayerData.isDisplayed = true
        self:Print('Reload to reset position.')
    else
        self:Print('Available commands: \'show\', \'hide\' and \'reset\'.')
    end
end

do
    local function SlashCommand(input)
        IT:SlashCommand(input)
    end

    SLASH_INSTANCETRACK1 = '/itrack'
    SLASH_INSTANCETRACK2 = '/instancetrack'
    SlashCmdList['INSTANCETRACK'] = SlashCommand
end
