local InstanceTrack = LibStub("AceAddon-3.0"):NewAddon("InstanceTrack", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

function InstanceTrack:OnInitialize()
    self:CreateDB()
    self:CreateState()
    self:RegisterChatCommand("itrack", "ChatCommand")
    self:RegisterChatCommand("instancetrack", "ChatCommand")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function InstanceTrack:OnEnable()
    self:CreateFrames()
    if self:IsDisplayed() then
        self:Display()
    else
        self:Hide()
    end
end
