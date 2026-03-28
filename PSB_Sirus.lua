-- Personal Status Bar для Sirus (аддон написан с нуля, функционал как у забытого аддона Personal Resource Display 3.3.5),актуальная версия под клиент WoW Sirus от 2026)
-- Исправления: отображения статуса для энергии и ярости,добавлено GUI-меню, корректная инициализация БД, вызов настроек по команде



-- PSB Sirus FINAL++ (позиция + рамка)

local addonName = ...

local frame = CreateFrame("Frame", "PSB_Frame", UIParent)

PSB_DB = PSB_DB or {}

local defaults = {
    x = 0,
    y = -150,
    scale = 1,
    alpha = 1,
    showPercent = true,
}

local function InitDB()
    for k, v in pairs(defaults) do
        if PSB_DB[k] == nil then PSB_DB[k] = v end
    end
end

-- Frame backdrop (рамка как в оригинале)
frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
frame:SetBackdropColor(0,0,0,0.6)

-- Bars
local healthBar = CreateFrame("StatusBar", nil, frame)
healthBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
healthBar:SetMinMaxValues(0,1)

local hpText = healthBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hpText:SetPoint("CENTER")

local powerBar = CreateFrame("StatusBar", nil, frame)
powerBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
powerBar:SetMinMaxValues(0,1)

local powerText = powerBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
powerText:SetPoint("CENTER")

local targetHealth, currentHealth = 1,1
local targetPower, currentPower = 1,1
local elapsedTotal = 0

local function Layout()
    frame:SetSize(210, 30)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", PSB_DB.x, PSB_DB.y)
    frame:SetScale(PSB_DB.scale)
    frame:SetAlpha(PSB_DB.alpha)

    healthBar:SetSize(200, 12)
    healthBar:SetPoint("TOP", 0, -4)

    powerBar:SetSize(200, 10)
    powerBar:SetPoint("TOP", healthBar, "BOTTOM", 0, -3)
end

local function GetUpdateInterval(pt)
    if pt == 3 then return 0.02
    elseif pt == 1 then return 0.05
    else return 0.1 end
end

local function UpdateTargets()
    local hp, hpMax = UnitHealth("player"), UnitHealthMax("player")
    if hpMax > 0 then targetHealth = hp / hpMax end

    local pt = UnitPowerType("player")
    local p, pMax = UnitPower("player", pt), UnitPowerMax("player", pt)
    if pMax > 0 then targetPower = p / pMax end
end

local function UpdateVisuals()
    healthBar:SetValue(currentHealth)
    powerBar:SetValue(currentPower)

    if PSB_DB.showPercent then
        hpText:SetText(string.format("%d%%", currentHealth*100))
        powerText:SetText(string.format("%d%%", currentPower*100))
    else
        hpText:SetText("")
        powerText:SetText("")
    end

    local _, class = UnitClass("player")
    local c = RAID_CLASS_COLORS[class]
    healthBar:SetStatusBarColor(c and c.r or 0, c and c.g or 1, c and c.b or 0)

    local pt = UnitPowerType("player")
    if pt == 0 then powerBar:SetStatusBarColor(0,0,1)
    elseif pt == 1 then powerBar:SetStatusBarColor(1,0,0)
    elseif pt == 3 then powerBar:SetStatusBarColor(1,1,0)
    else powerBar:SetStatusBarColor(0.7,0.7,0.7) end
end

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitDB()
        Layout()
        UpdateTargets()
        UpdateVisuals()
        return
    end

    if (event:find("UNIT_")) and arg1 and arg1 ~= "player" then return end

    UpdateTargets()
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("UNIT_MAXHEALTH")
frame:RegisterEvent("UNIT_POWER")
frame:RegisterEvent("UNIT_MANA")
frame:RegisterEvent("UNIT_RAGE")
frame:RegisterEvent("UNIT_ENERGY")
frame:RegisterEvent("UNIT_MAXPOWER")

frame:SetScript("OnUpdate", function(_, elapsed)
    local pt = UnitPowerType("player")
    local interval = GetUpdateInterval(pt)

    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal > interval then
        UpdateTargets()
        elapsedTotal = 0
    end

    local speed = (pt==3) and 12 or 8

    currentHealth = currentHealth + (targetHealth-currentHealth)*math.min(elapsed*speed,1)
    currentPower = currentPower + (targetPower-currentPower)*math.min(elapsed*speed,1)

    UpdateVisuals()
end)

-- Drag
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local _,_,_,x,y = self:GetPoint()
    PSB_DB.x, PSB_DB.y = x,y
end)

-- GUI
local gui = CreateFrame("Frame", "PSB_GUI", UIParent, "BasicFrameTemplateWithInset")
gui:SetSize(260, 260)
gui:SetPoint("CENTER")
gui:Hide()

gui.title = gui:CreateFontString(nil, "OVERLAY")
gui.title:SetFontObject("GameFontHighlight")
gui.title:SetPoint("TOP", 0, -10)
gui.title:SetText("PSB Settings")

local function CreateSlider(parent, name, min, max, step, y, valueFunc, setFunc)
    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetPoint("TOP", 0, y)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)

    _G[name.."Low"]:SetText(min)
    _G[name.."High"]:SetText(max)

    s:SetScript("OnValueChanged", function(self, val)
        setFunc(val)
        Layout()
        UpdateVisuals()
    end)

    s:SetValue(valueFunc())
    return s
end

CreateSlider(gui, "PSB_Scale", 0.5, 2, 0.1, -40,
    function() return PSB_DB.scale end,
    function(v) PSB_DB.scale = v end)

CreateSlider(gui, "PSB_Alpha", 0.1, 1, 0.05, -90,
    function() return PSB_DB.alpha end,
    function(v) PSB_DB.alpha = v end)

CreateSlider(gui, "PSB_PosX", -500, 500, 1, -140,
    function() return PSB_DB.x end,
    function(v) PSB_DB.x = v end)

CreateSlider(gui, "PSB_PosY", -500, 500, 1, -190,
    function() return PSB_DB.y end,
    function(v) PSB_DB.y = v end)

local cb = CreateFrame("CheckButton", nil, gui, "UICheckButtonTemplate")
cb:SetPoint("TOP", 0, -230)
cb.text:SetText("Show Percent")
cb:SetChecked(PSB_DB.showPercent)
cb:SetScript("OnClick", function(self)
    PSB_DB.showPercent = self:GetChecked()
    UpdateVisuals()
end)


--вызов настроек и их управление через чат-команду

SLASH_PSB1 = "/psb"
SlashCmdList["PSB"] = function(msg)
    local cmd, val = msg:match("^(%S*)%s*(.-)$")

    if cmd == "scale" and tonumber(val) then
        PSB_DB.scale = tonumber(val)
        Layout()

    elseif cmd == "alpha" and tonumber(val) then
        PSB_DB.alpha = tonumber(val)
        Layout()

    elseif cmd == "x" and tonumber(val) then
        PSB_DB.x = tonumber(val)
        Layout()

    elseif cmd == "y" and tonumber(val) then
        PSB_DB.y = tonumber(val)
        Layout()

    elseif cmd == "percent" then
        PSB_DB.showPercent = not PSB_DB.showPercent
        UpdateVisuals()
        print("PSB percent:", PSB_DB.showPercent and "ON" or "OFF")

    elseif cmd == "reset" then
        PSB_DB.x, PSB_DB.y = 0, -150
        Layout()

    else
        print("/psb scale 1.2 | alpha 0.8 | x 0 | y -150 | percent | reset")
    end
end
