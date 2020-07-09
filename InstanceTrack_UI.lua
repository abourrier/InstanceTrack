local InstanceTrack = LibStub("AceAddon-3.0"):GetAddon("InstanceTrack")

function InstanceTrack:TimerToText(timer)
    local remainder = timer
    local seconds = remainder % 60
    remainder = remainder - seconds
    local minutes = (remainder / 60) % 60
    remainder = remainder - 60 * minutes
    local hours = remainder / 3600

    local function format(number)
        if number < 10 then
            return "0" .. number
        else
            return number
        end
    end

    if hours > 0 then
        return format(hours) .. ":" .. format(minutes) .. ":" .. format(seconds)
    elseif minutes > 0 then
        return format(minutes) .. ":" .. format(seconds)
    else
        return format(seconds)
    end
end

function InstanceTrack:CreateFontString(parent, font, fontHeight)
    local fontString = parent:CreateFontString()
    fontString:SetFont(font, fontHeight)
    fontString:SetJustifyH("LEFT")
    return fontString
end

function InstanceTrack:CreateFrames()
    local nbSummaryLines, padding, fontHeight, titleFontHeight = 3, 6, 10, 11
    local font = "Fonts/FRIZQT__.TTF"

    -- title frame --
    local titleFrame = CreateFrame("Frame", nil, UIParent)
    self.titleFrame = titleFrame
    titleFrame:SetHeight(2 * padding + titleFontHeight)
    local dbPoint = self.db.char.framePoint
    titleFrame:SetPoint(dbPoint.point, UIParent, dbPoint.relativePoint, dbPoint.xOfs, dbPoint.yOfs)
    titleFrame:SetBackdrop({ bgFile = "Interface/DialogFrame/UI-DialogBox-Background-Dark" })

    local title = self:CreateFontString(titleFrame, font, titleFontHeight)
    title:SetPoint("TOPLEFT", titleFrame, "TOPLEFT", padding, -padding)
    title:SetText("InstanceTrack")

    -- moving settings --
    titleFrame:SetMovable(true)
    titleFrame:EnableMouse(true)
    titleFrame:RegisterForDrag("LeftButton")
    titleFrame:SetScript("OnDragStart", titleFrame.StartMoving)
    titleFrame:SetScript("OnDragStop", function()
        titleFrame:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = titleFrame:GetPoint()
        self.db.char.framePoint = { point = point, relativePoint = relativePoint, xOfs = xOfs, yOfs = yOfs }
    end)

    -- summary frame --
    local summaryFrame = CreateFrame("Frame", nil, titleFrame)
    summaryFrame:SetBackdrop({ bgFile = "Interface/DialogFrame/UI-DialogBox-Background" })
    summaryFrame:SetPoint("TOP", titleFrame, "BOTTOM")
    summaryFrame:SetHeight(nbSummaryLines * fontHeight + (nbSummaryLines + 1) * padding)

    summaryFrame.titleRow = {}
    local summaryTitleTexts = { "Period", "Instances", "Next reset", "Details" }
    local xOfs = { padding, 0, 0, 0, 0 }
    local yOfs = { -padding, 0, 0, 0 }
    for i = 2, 4 do
        yOfs[i] = yOfs[i - 1] - (fontHeight + padding)
    end
    for i, text in ipairs(summaryTitleTexts) do
        local fontString = self:CreateFontString(summaryFrame, font, fontHeight)
        fontString:SetPoint("TOPLEFT", summaryFrame, "TOPLEFT", xOfs[i], yOfs[1])
        fontString:SetText(text)
        xOfs[i + 1] = xOfs[i] + fontString:GetWidth() + padding
        summaryFrame.titleRow[i] = fontString
    end

    local hourText = self:CreateFontString(summaryFrame, font, fontHeight)
    hourText:SetText("1h")
    hourText:SetPoint("TOPLEFT", summaryFrame, "TOPLEFT", xOfs[1], yOfs[2])
    local dayText = self:CreateFontString(summaryFrame, font, fontHeight)
    dayText:SetText("24h")
    dayText:SetPoint("TOPLEFT", summaryFrame, "TOPLEFT", xOfs[1], yOfs[3])

    local hourInstances = self:CreateFontString(summaryFrame, font, fontHeight)
    self.hourInstances = hourInstances
    hourInstances:SetPoint("TOPLEFT", summaryFrame, "TOPLEFT", xOfs[2], yOfs[2])
    local dayInstances = self:CreateFontString(summaryFrame, font, fontHeight)
    self.dayInstances = dayInstances
    dayInstances:SetPoint("TOPLEFT", summaryFrame, "TOPLEFT", xOfs[2], yOfs[3])

    local hourNext = self:CreateFontString(summaryFrame, font, fontHeight)
    self.hourNext = hourNext
    hourNext:SetPoint("TOPLEFT", summaryFrame, "TOPLEFT", xOfs[3], yOfs[2])
    local dayNext = self:CreateFontString(summaryFrame, font, fontHeight)
    self.dayNext = dayNext
    dayNext:SetPoint("TOPLEFT", summaryFrame, "TOPLEFT", xOfs[3], yOfs[3])

    local hourDetailsCheckbox = CreateFrame("CheckButton", nil, summaryFrame, "ChatConfigCheckButtonTemplate")
    local yOfsCorrection = (hourDetailsCheckbox:GetHeight() - fontHeight) / 2
    hourDetailsCheckbox:SetPoint("TOPLEFT", summaryFrame, "TOPLEFT", xOfs[4], yOfs[2] + yOfsCorrection)
    hourDetailsCheckbox:SetChecked(self.db.char.hourDetailsShown)
    local dayDetailsCheckbox = CreateFrame("CheckButton", nil, summaryFrame, "ChatConfigCheckButtonTemplate")
    dayDetailsCheckbox:SetPoint("TOPLEFT", summaryFrame, "TOPLEFT", xOfs[4], yOfs[3] + yOfsCorrection)
    dayDetailsCheckbox:SetChecked(self.db.char.dayDetailsShown)

    -- details frame --
    local detailsFrame = CreateFrame("Frame", nil, titleFrame)
    self.detailsFrame = detailsFrame
    detailsFrame:SetPoint("TOP", summaryFrame, "BOTTOM")
    detailsFrame:SetBackdrop({ bgFile = "Interface/DialogFrame/UI-DialogBox-Background" })
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

    hourDetailsCheckbox:SetScript("OnClick", function()
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

    dayDetailsCheckbox:SetScript("OnClick", function()
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

    function self:DisplayDetails()
        local iRow, start, stop, resetDuration = 0, 1, table.getn(self.db.char.instanceHistory), 86400
        if self.db.char.hourDetailsShown then
            start = stop - self.state.nbHourInstances + 1
            resetDuration = 3600
        end
        for i = start, stop do
            iRow = iRow + 1
            local instance = self.db.char.instanceHistory[i]
            if iRow > table.getn(self.detailsFrame.rows) then
                local row = self:CreateFontString(self.detailsFrame, font, fontHeight)
                row:SetPoint("TOPLEFT", self.detailsFrame, "TOPLEFT", padding, -padding * iRow - fontHeight * (iRow - 1))
                self.detailsFrame.rows[iRow] = row
            end
            self.detailsFrame.rows[iRow]:SetText(iRow .. ". " .. instance.zoneText .. " " .. self:TimerToText(instance.timestamp + resetDuration - time()))
        end
        if self.state.isInTrackedInstance then
            local instance, timerText = self.db.char.instanceHistory[table.getn(self.db.char.instanceHistory)], "01:00:00"
            if self.db.char.dayDetailsShown then
                timerText = "24:00:00"
            end
            self.detailsFrame.rows[iRow]:SetText(iRow .. ". " .. instance.zoneText .. " " .. timerText)
        end
        for i = iRow + 1, table.getn(self.detailsFrame.rows) do
            self.detailsFrame.rows[i]:SetText("")
        end
        self.detailsFrame:SetHeight(iRow * fontHeight + (iRow + 1) * padding)
    end

end

function InstanceTrack:DisplayState()
    self.hourInstances:SetText(self.state.nbHourInstances .. "/5")
    if self.state.nbHourInstances > 4 then
        self.hourInstances:SetTextColor(1, 0, 0)
    elseif self.state.nbHourInstances > 3 then
        self.hourInstances:SetTextColor(1, 0.647, 0)
    else
        self.hourInstances:SetTextColor(0, 1, 0)
    end

    self.dayInstances:SetText(self.state.nbDayInstances .. "/30")
    if self.state.nbDayInstances > 29 then
        self.dayInstances:SetTextColor(1, 0, 0)
    elseif self.state.nbDayInstances > 24 then
        self.dayInstances:SetTextColor(1, 0.647, 0)
    else
        self.dayInstances:SetTextColor(0, 1, 0)
    end

    if self.state.nextHourReset ~= nil then
        if self.state.nbHourInstances == 1 and self.state.isInTrackedInstance then
            self.hourNext:SetText("01:00:00")
        else
            self.hourNext:SetText(self:TimerToText(self.state.nextHourReset.timestamp + 3600 - time()))
        end
    else
        self.hourNext:SetText("")
    end

    if self.state.nextDayReset ~= nil then
        if self.state.nbDayInstances == 1 and self.state.isInTrackedInstance then
            self.dayNext:SetText("24:00:00")
        else
            self.dayNext:SetText(self:TimerToText(self.state.nextDayReset.timestamp + 86400 - time()))
        end
    else
        self.dayNext:SetText("")
    end

    if self.db.char.dayDetailsShown or self.db.char.hourDetailsShown then
        self:DisplayDetails()
    end
end
