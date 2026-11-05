-- JarForever: combo points on rogue and cat druid
-- only class resource forever has, stored on the target

local _, ns = ...

ns.RegisterModule("rc", "Combo Points", function()

local DB = ns.db.rc
local DEFAULTS = {
    displayMode = "SEGMENTS",
    segmentSize = 22,
    segmentGap  = 3,
    numericSize = 64,
    position    = { point = "CENTER", x = 0, y = -175 },
}
for k, v in pairs(DEFAULTS) do
    if DB[k] == nil then
        DB[k] = type(v) == "table" and CopyTable(v) or v
    end
end

local COL_LOW   = { 0.20, 0.85, 0.20 }
local COL_MID   = { 1.00, 0.78, 0.10 }
local COL_HIGH  = { 1.00, 0.22, 0.22 }
local COL_EMPTY = { 0.15, 0.15, 0.18 }
local COMBO = Enum.PowerType.ComboPoints

local function SegmentColor(i, max)
    local frac = i / max
    if frac <= 0.40 then return COL_LOW end
    if frac <= 0.70 then return COL_MID end
    return COL_HIGH
end

local mainFrame, numericText, dragBorder
local segments = {}
local numSegs, shownMode = 0, nil
local tracked = false

-- druid only has them in cat, same check blizz uses
local function RefreshTracked()
    local _, class = UnitClass("player")
    if class == "ROGUE" then
        tracked = true
    elseif class == "DRUID" then
        tracked = UnitPowerType("player") == Enum.PowerType.Energy
    else
        tracked = false
    end
end

local function GetPoints()
    local points = GetComboPoints("player", "target")
    if issecretvalue(points) then return UnitPower("player", COMBO) end
    return points
end

local function ClearWidgets()
    for _, s in ipairs(segments) do s:Hide() end
    numSegs = 0
    if numericText then numericText:Hide() end
    shownMode = nil
end

local function BuildSegments(n)
    ClearWidgets()
    local sz, gap = DB.segmentSize, DB.segmentGap
    mainFrame:SetSize(n * sz + (n - 1) * gap, sz)
    for i = 1, n do
        local seg = segments[i]
        if not seg then
            seg = mainFrame:CreateTexture(nil, "ARTWORK")
            segments[i] = seg
        end
        seg:ClearAllPoints()
        seg:SetSize(sz, sz)
        seg:SetPoint("LEFT", mainFrame, "LEFT", (i - 1) * (sz + gap), 0)
        seg:SetTexture(ns.GetTexture())
        seg:SetVertexColor(unpack(COL_EMPTY))
        seg:Show()
    end
    numSegs = n
    shownMode = "SEG"
end

local function BuildNumeric()
    ClearWidgets()
    local sz = DB.numericSize
    mainFrame:SetSize(sz * 1.4, sz * 1.4)
    if not numericText then
        numericText = mainFrame:CreateFontString(nil, "OVERLAY")
        numericText:SetPoint("CENTER")
    end
    numericText:SetFont(ns.GetFont(), sz, "OUTLINE")
    numericText:SetText("0")
    numericText:Show()
    shownMode = "NUM"
end

local function RebuildDisplay()
    if not mainFrame then return end
    local max = UnitPowerMax("player", COMBO)
    if not tracked or max <= 0 then
        ClearWidgets()
        mainFrame:Hide()
        return
    end
    if DB.displayMode == "SEGMENTS" then
        BuildSegments(max)
    else
        BuildNumeric()
    end
    mainFrame:Show()
end

local function UpdateDisplay()
    if not mainFrame or not tracked then return end
    local max = UnitPowerMax("player", COMBO)
    if max <= 0 then
        mainFrame:Hide()
        return
    end

    local useSegments = DB.displayMode == "SEGMENTS"
    if (useSegments and (shownMode ~= "SEG" or max ~= numSegs)) or (not useSegments and shownMode ~= "NUM") then
        RebuildDisplay()
    end
    mainFrame:Show()

    local cur = GetPoints()
    -- cant compare a secret, shouldnt happen for combo points
    if useSegments then
        if issecretvalue(cur) then return end
        for i = 1, numSegs do
            segments[i]:SetVertexColor(unpack(i <= cur and SegmentColor(i, max) or COL_EMPTY))
        end
    elseif issecretvalue(cur) then
        numericText:SetFormattedText("%d", cur)
    else
        local c = cur > 0 and SegmentColor(cur, max) or { 0.4, 0.4, 0.4 }
        numericText:SetTextColor(c[1], c[2], c[3], 1)
        numericText:SetText(tostring(cur))
    end
end

local function ApplyPosition()
    local pos = DB.position
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
end

local function ApplyShared()
    if not mainFrame then return end
    local unlocked = ns.db.general.unlocked
    mainFrame.bg:SetColorTexture(0, 0, 0, ns.db.general.bgAlpha)
    mainFrame:EnableMouse(unlocked)
    dragBorder:SetShown(unlocked)
    RebuildDisplay()
    UpdateDisplay()
end
ns.OnShared(ApplyShared)

local function CreateMainFrame()
    mainFrame = CreateFrame("Frame", "JarsResourceCounterFrame", UIParent)
    mainFrame:SetSize(100, 30)
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetMovable(true)
    mainFrame:Hide()

    mainFrame.bg = mainFrame:CreateTexture(nil, "BACKGROUND")
    mainFrame.bg:SetAllPoints()

    dragBorder = mainFrame:CreateTexture(nil, "OVERLAY")
    dragBorder:SetAllPoints()
    dragBorder:SetColorTexture(1, 0.85, 0, 0.5)

    ApplyPosition()

    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(self)
        if ns.db.general.unlocked then self:StartMoving() end
    end)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        DB.position.point, DB.position.x, DB.position.y = point, x, y
        ns.RefreshPanel("Combo Points")
    end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
eventFrame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
eventFrame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("COMBO_TARGET_CHANGED")

local function FullRefresh()
    RefreshTracked()
    RebuildDisplay()
    UpdateDisplay()
end

eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        CreateMainFrame()
        ApplyShared()
    elseif event == "PLAYER_ENTERING_WORLD" then
        FullRefresh()
        -- power isnt always ready at zone in
        C_Timer.After(1.5, FullRefresh)
    elseif event == "UPDATE_SHAPESHIFT_FORM" then
        C_Timer.After(0.1, FullRefresh)
    else
        UpdateDisplay()
    end
end)

ns.RegisterPanel(60, "Combo Points", function(b)
    b:Text("Rogue, and druids in cat form. Other classes dont show anything.")
    b:Header("Display")
    b:Toggle("Mode", { { "Segments", "SEGMENTS" }, { "Number", "NUMERIC" } },
        function() return DB.displayMode end,
        function(v) DB.displayMode = v; RebuildDisplay(); UpdateDisplay() end)
    b:Slider("Segment Size", 10, 40, 1,
        function() return DB.segmentSize end,
        function(v) DB.segmentSize = v; RebuildDisplay(); UpdateDisplay() end)
    b:Slider("Segment Gap", 0, 12, 1,
        function() return DB.segmentGap end,
        function(v) DB.segmentGap = v; RebuildDisplay(); UpdateDisplay() end)
    b:Slider("Number Font Size", 20, 120, 2,
        function() return DB.numericSize end,
        function(v) DB.numericSize = v; RebuildDisplay(); UpdateDisplay() end)

    b:Header("Position")
    b:Text("Turn on Unlock Frames in General to drag it.")
    b:Slider("Left / Right", -1000, 1000, 1,
        function() return DB.position.x end,
        function(v) DB.position.x = v; if mainFrame then ApplyPosition() end end)
    b:Slider("Up / Down", -600, 600, 1,
        function() return DB.position.y end,
        function(v) DB.position.y = v; if mainFrame then ApplyPosition() end end)
    b:Buttons({ { "Reset Position", function()
        DB.position.point, DB.position.x, DB.position.y = "CENTER", 0, -175
        if mainFrame then ApplyPosition() end
        ns.RefreshPanel("Combo Points")
    end } })
end)

SLASH_JARSRESOURCECOUNTER1 = "/jrc"
SlashCmdList["JARSRESOURCECOUNTER"] = function() ns.OpenConfig("Combo Points") end

end)
