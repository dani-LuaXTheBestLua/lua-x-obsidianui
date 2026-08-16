--[[
================================================================================
  ThemeSaver Addon for Obsidian UI
  Separate module — NOT part of the main library source.
================================================================================
]]

local cloneref = (cloneref or clonereference or function(instance: any)
    return instance
end)

local HttpService = cloneref(game:GetService("HttpService"))
local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))

local ThemeSaver = {}
ThemeSaver.__index = ThemeSaver
ThemeSaver.Version = "1.2.0"
ThemeSaver.Folder = "ObsidianThemes"
ThemeSaver.Extension = ".txt"

local function SafeGet(Name)
    local Ok, Value = pcall(function()
        if getgenv then return getgenv()[Name] end
        return nil
    end)
    if Ok and Value ~= nil then return Value end
    Ok, Value = pcall(function() return _G[Name] end)
    if Ok and Value ~= nil then return Value end
    Ok, Value = pcall(function() return shared[Name] end)
    if Ok and Value ~= nil then return Value end
    return nil
end

local writefile = SafeGet("writefile")
local readfile = SafeGet("readfile")
local isfile = SafeGet("isfile")
local isfolder = SafeGet("isfolder")
local makefolder = SafeGet("makefolder")
local listfiles = SafeGet("listfiles")
local delfile = SafeGet("delfile")

local BuiltInPresets = {
    BlackAndWhite = {
        BackgroundColor = Color3.fromRGB(13, 13, 16),
        MainColor = Color3.fromRGB(22, 22, 27),
        AccentColor = Color3.fromRGB(255, 255, 255),
        OutlineColor = Color3.fromRGB(48, 48, 58),
        FontColor = Color3.fromRGB(250, 250, 255),
    },
    DarkPurple = {
        BackgroundColor = Color3.fromRGB(15, 15, 15),
        MainColor = Color3.fromRGB(25, 25, 25),
        AccentColor = Color3.fromRGB(125, 85, 255),
        OutlineColor = Color3.fromRGB(40, 40, 40),
        FontColor = Color3.fromRGB(255, 255, 255),
    },
    OceanBlue = {
        BackgroundColor = Color3.fromRGB(8, 12, 18),
        MainColor = Color3.fromRGB(14, 20, 28),
        AccentColor = Color3.fromRGB(0, 170, 255),
        OutlineColor = Color3.fromRGB(30, 40, 50),
        FontColor = Color3.fromRGB(255, 255, 255),
    },
    Crimson = {
        BackgroundColor = Color3.fromRGB(12, 6, 6),
        MainColor = Color3.fromRGB(20, 12, 12),
        AccentColor = Color3.fromRGB(255, 50, 50),
        OutlineColor = Color3.fromRGB(40, 25, 25),
        FontColor = Color3.fromRGB(255, 255, 255),
    },
    Emerald = {
        BackgroundColor = Color3.fromRGB(8, 14, 10),
        MainColor = Color3.fromRGB(14, 22, 16),
        AccentColor = Color3.fromRGB(50, 220, 120),
        OutlineColor = Color3.fromRGB(30, 45, 35),
        FontColor = Color3.fromRGB(255, 255, 255),
    },
    Sunset = {
        BackgroundColor = Color3.fromRGB(18, 10, 8),
        MainColor = Color3.fromRGB(28, 16, 12),
        AccentColor = Color3.fromRGB(255, 140, 60),
        OutlineColor = Color3.fromRGB(50, 35, 25),
        FontColor = Color3.fromRGB(255, 250, 240),
    },
    Midnight = {
        BackgroundColor = Color3.fromRGB(6, 6, 12),
        MainColor = Color3.fromRGB(12, 12, 22),
        AccentColor = Color3.fromRGB(100, 140, 255),
        OutlineColor = Color3.fromRGB(28, 28, 45),
        FontColor = Color3.fromRGB(230, 235, 255),
    },
    Pink = {
        BackgroundColor = Color3.fromRGB(16, 10, 14),
        MainColor = Color3.fromRGB(24, 16, 22),
        AccentColor = Color3.fromRGB(255, 100, 180),
        OutlineColor = Color3.fromRGB(45, 30, 40),
        FontColor = Color3.fromRGB(255, 245, 250),
    },
    Cyber = {
        BackgroundColor = Color3.fromRGB(5, 10, 8),
        MainColor = Color3.fromRGB(10, 18, 15),
        AccentColor = Color3.fromRGB(0, 255, 180),
        OutlineColor = Color3.fromRGB(20, 40, 35),
        FontColor = Color3.fromRGB(220, 255, 240),
    },
    Gold = {
        BackgroundColor = Color3.fromRGB(14, 12, 6),
        MainColor = Color3.fromRGB(22, 20, 12),
        AccentColor = Color3.fromRGB(255, 200, 60),
        OutlineColor = Color3.fromRGB(45, 40, 25),
        FontColor = Color3.fromRGB(255, 250, 230),
    },
}

local function EnsureFolder(Folder)
    if makefolder then
        if isfolder then
            if not isfolder(Folder) then pcall(makefolder, Folder) end
        else
            pcall(makefolder, Folder)
        end
    end
end

local function PathFor(self, Name)
    return self.Folder .. "/" .. tostring(Name) .. self.Extension
end

local function PathJson(self, Name)
    return self.Folder .. "/" .. tostring(Name) .. ".json"
end

local function ColorToTable(C)
    return { C.R, C.G, C.B }
end

local function TableToColor(T)
    if type(T) ~= "table" then return Color3.new(1, 1, 1) end
    return Color3.new(T[1] or 0, T[2] or 0, T[3] or 0)
end

local function Snapshot(Library)
    return {
        Version = 1,
        Timestamp = os.time(),
        BackgroundColor = ColorToTable(Library.Scheme.BackgroundColor),
        MainColor = ColorToTable(Library.Scheme.MainColor),
        AccentColor = ColorToTable(Library.Scheme.AccentColor),
        OutlineColor = ColorToTable(Library.Scheme.OutlineColor),
        FontColor = ColorToTable(Library.Scheme.FontColor),
    }
end

local function Apply(Library, Data)
    if type(Data) ~= "table" then return false end
    if Data.BackgroundColor then Library.Scheme.BackgroundColor = TableToColor(Data.BackgroundColor) end
    if Data.MainColor then Library.Scheme.MainColor = TableToColor(Data.MainColor) end
    if Data.AccentColor then Library.Scheme.AccentColor = TableToColor(Data.AccentColor) end
    if Data.OutlineColor then Library.Scheme.OutlineColor = TableToColor(Data.OutlineColor) end
    if Data.FontColor then Library.Scheme.FontColor = TableToColor(Data.FontColor) end
    if Library.UpdateColorsUsingRegistry then
        Library:UpdateColorsUsingRegistry()
    end
    return true
end

local function Encode(Data)
    local Ok, Result = pcall(function() return HttpService:JSONEncode(Data) end)
    if Ok then return Result end
    return nil
end

local function Decode(Text)
    local Ok, Result = pcall(function() return HttpService:JSONDecode(Text) end)
    if Ok and type(Result) == "table" then return Result end
    return nil
end

local function Log(self, ...)
    if self.Debug then print("[ThemeSaver]", ...) end
end

function ThemeSaver.new(Overrides)
    local self = setmetatable({
        Cache = {},
        Data = {},
        Library = nil,
        ListDropdown = nil,
        LastCreated = nil,
        LastLoaded = nil,
        LastSaved = nil,
        AutoSaveName = "autosave",
        Debug = false,
        Folder = ThemeSaver.Folder,
        Extension = ThemeSaver.Extension,
        Version = ThemeSaver.Version,
    }, ThemeSaver)
    if type(Overrides) == "table" then
        if Overrides.Folder then self.Folder = Overrides.Folder end
        if Overrides.Extension then self.Extension = Overrides.Extension end
        if Overrides.Debug ~= nil then self.Debug = Overrides.Debug end
        if Overrides.AutoSaveName then self.AutoSaveName = Overrides.AutoSaveName end
    end
    return self
end

function ThemeSaver:GetList()
    EnsureFolder(self.Folder)
    if listfiles then
        local Ok, Files = pcall(listfiles, self.Folder)
        if Ok and type(Files) == "table" then
            for _, File in pairs(Files) do
                local Name = tostring(File):match("([^/\\]+)%.txt$")
                    or tostring(File):match("([^/\\]+)%.json$")
                if Name and Name ~= "" then
                    self.Cache[Name] = true
                end
            end
        end
    end
    local List = {}
    for Name in pairs(self.Cache) do
        table.insert(List, Name)
    end
    table.sort(List)
    return List
end

function ThemeSaver:RefreshList()
    if not self.ListDropdown then return self:GetList() end
    local List = self:GetList()
    if #List == 0 then List = { "None" } end
    pcall(function() self.ListDropdown:SetValues(List) end)
    return List
end

function ThemeSaver:Exists(Name)
    Name = tostring(Name or "")
    if self.Cache[Name] then return true end
    if isfile then
        if isfile(PathFor(self, Name)) or isfile(PathJson(self, Name)) then return true end
    end
    return false
end

function ThemeSaver:Create(Name)
    Name = tostring(Name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if not self.Library then
        warn("[ThemeSaver] Init first")
        return false
    end
    if Name == "" then
        self.Library:Notify({ Title = "Theme", Description = "Enter a name first", Time = 3 })
        return false
    end
    if self:Exists(Name) then
        self.Library:Notify({
            Title = "Theme",
            Description = Name .. " already exists — use Save",
            Time = 3,
        })
        return false
    end
    EnsureFolder(self.Folder)
    local Data = Snapshot(self.Library)
    self.Data[Name] = Data
    self.Cache[Name] = true
    self.LastCreated = Name
    if writefile then
        local Enc = Encode(Data)
        if Enc then pcall(writefile, PathFor(self, Name), Enc) end
    end
    self.Library:Notify({
        Title = "Theme Created",
        Description = "Created theme: " .. Name,
        Time = 3,
    })
    self:RefreshList()
    Log(self, "Created", Name)
    return true
end

function ThemeSaver:Save(Name)
    Name = tostring(Name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if not self.Library then return false end
    if Name == "" or Name == "None" then
        self.Library:Notify({ Title = "Theme", Description = "Enter or select a name", Time = 3 })
        return false
    end
    EnsureFolder(self.Folder)
    local Data = Snapshot(self.Library)
    self.Data[Name] = Data
    self.Cache[Name] = true
    self.LastSaved = Name
    if writefile then
        local Enc = Encode(Data)
        if Enc then pcall(writefile, PathFor(self, Name), Enc) end
    end
    self.Library:Notify({
        Title = "Theme Saved",
        Description = "Saved theme: " .. Name,
        Time = 3,
    })
    self:RefreshList()
    Log(self, "Saved", Name)
    return true
end

function ThemeSaver:Load(Name)
    Name = tostring(Name or "")
    if not self.Library then return false end
    if Name == "" or Name == "None" then
        self.Library:Notify({ Title = "Theme", Description = "Select a theme first", Time = 3 })
        return false
    end
    local Data = self.Data[Name]
    if not Data and readfile and isfile then
        local Path = PathFor(self, Name)
        if not isfile(Path) then Path = PathJson(self, Name) end
        if isfile(Path) then
            Data = Decode(readfile(Path))
            if Data then
                self.Data[Name] = Data
                self.Cache[Name] = true
            end
        end
    end
    if not Data then
        self.Library:Notify({ Title = "Theme", Description = Name .. " not found", Time = 3 })
        return false
    end
    Apply(self.Library, Data)
    self.LastLoaded = Name
    self.Library:Notify({
        Title = "Theme Loaded",
        Description = "Loaded theme: " .. Name,
        Time = 3,
    })
    Log(self, "Loaded", Name)
    return true
end

function ThemeSaver:Delete(Name)
    Name = tostring(Name or "")
    if not self.Library then return false end
    if Name == "" or Name == "None" then
        self.Library:Notify({ Title = "Theme", Description = "Select a theme first", Time = 3 })
        return false
    end
    if delfile then
        pcall(delfile, PathFor(self, Name))
        pcall(delfile, PathJson(self, Name))
    end
    self.Cache[Name] = nil
    self.Data[Name] = nil
    self.Library:Notify({
        Title = "Theme Deleted",
        Description = "Deleted theme: " .. Name,
        Time = 3,
    })
    self:RefreshList()
    Log(self, "Deleted", Name)
    return true
end

function ThemeSaver:ApplyPreset(Name)
    if not self.Library then return false end
    local Preset = BuiltInPresets[Name]
    if not Preset and self.Library.ThemePresets then
        Preset = self.Library.ThemePresets[Name]
    end
    if not Preset then
        self.Library:Notify({ Title = "Theme", Description = "Preset not found: " .. tostring(Name), Time = 3 })
        return false
    end
    for Key, Value in pairs(Preset) do
        if self.Library.Scheme[Key] ~= nil then
            self.Library.Scheme[Key] = Value
        end
    end
    if self.Library.UpdateColorsUsingRegistry then
        self.Library:UpdateColorsUsingRegistry()
    end
    self.Library:Notify({ Title = "Theme", Description = "Applied preset: " .. tostring(Name), Time = 2 })
    return true
end

function ThemeSaver:GetPresetNames()
    local Names = {}
    for Name in pairs(BuiltInPresets) do
        table.insert(Names, Name)
    end
    if self.Library and self.Library.ThemePresets then
        for Name in pairs(self.Library.ThemePresets) do
            if not BuiltInPresets[Name] then
                table.insert(Names, Name)
            end
        end
    end
    table.sort(Names)
    return Names
end

function ThemeSaver:Reset()
    return self:ApplyPreset("BlackAndWhite")
end

function ThemeSaver:AutoSave()
    return self:Save(self.AutoSaveName)
end

function ThemeSaver:AutoLoad()
    return self:Load(self.AutoSaveName)
end

function ThemeSaver:Export(Name)
    Name = tostring(Name or "")
    local Data = self.Data[Name]
    if not Data and readfile and isfile then
        local Path = PathFor(self, Name)
        if isfile(Path) then return readfile(Path) end
        Path = PathJson(self, Name)
        if isfile(Path) then return readfile(Path) end
    end
    if Data then return Encode(Data) end
    return nil
end

function ThemeSaver:Import(Name, JsonString)
    Name = tostring(Name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if Name == "" or type(JsonString) ~= "string" then return false end
    local Data = Decode(JsonString)
    if not Data then
        if self.Library then
            self.Library:Notify({ Title = "Theme", Description = "Invalid import data", Time = 3 })
        end
        return false
    end
    EnsureFolder(self.Folder)
    self.Data[Name] = Data
    self.Cache[Name] = true
    if writefile then
        pcall(writefile, PathFor(self, Name), JsonString)
    end
    if self.Library then
        self.Library:Notify({
            Title = "Theme Imported",
            Description = "Imported theme: " .. Name,
            Time = 3,
        })
    end
    self:RefreshList()
    return true
end

function ThemeSaver:GetInfo()
    return {
        Version = self.Version,
        Folder = self.Folder,
        Count = #self:GetList(),
        LastCreated = self.LastCreated,
        LastSaved = self.LastSaved,
        LastLoaded = self.LastLoaded,
        HasWritefile = writefile ~= nil,
        HasReadfile = readfile ~= nil,
        PresetCount = #self:GetPresetNames(),
    }
end

function ThemeSaver:PrintInfo()
    local Info = self:GetInfo()
    print("========== ThemeSaver ==========")
    for K, V in pairs(Info) do
        print(tostring(K) .. ":", tostring(V))
    end
    print("================================")
end

function ThemeSaver:SetDebug(Enabled)
    self.Debug = Enabled and true or false
end

function ThemeSaver:SetFolder(Folder)
    if type(Folder) == "string" and Folder ~= "" then
        self.Folder = Folder
    end
end

function ThemeSaver:ClearCache()
    self.Cache = {}
    self.Data = {}
    self:RefreshList()
end

function ThemeSaver:CopyCurrent()
    if not self.Library then return nil end
    return Snapshot(self.Library)
end

function ThemeSaver:ApplyTable(Data)
    if not self.Library then return false end
    return Apply(self.Library, Data)
end

function ThemeSaver:Count()
    return #self:GetList()
end

function ThemeSaver:Has(Name)
    return self:Exists(Name)
end

function ThemeSaver:CreateTheme(Name)
    return self:Create(Name)
end

function ThemeSaver:SaveTheme(Name)
    return self:Save(Name)
end

function ThemeSaver:LoadTheme(Name)
    return self:Load(Name)
end

function ThemeSaver:DeleteTheme(Name)
    return self:Delete(Name)
end

function ThemeSaver:GetThemes()
    return self:GetList()
end

function ThemeSaver:Init(Library, Parent)
    assert(Library, "ThemeSaver:Init requires Library")
    self.Library = Library
    local Options = Library.Options
    if not Options and getgenv then
        pcall(function() Options = getgenv().Options end)
    end
    Options = Options or {}

    local Box
    if Parent.AddRightGroupbox then
        Box = Parent:AddRightGroupbox("Themes")
    elseif Parent.AddLeftGroupbox then
        Box = Parent:AddLeftGroupbox("Themes")
    elseif Parent.AddTab then
        local Tab = Parent:AddTab("Themes", "palette")
        Box = Tab:AddLeftGroupbox("Themes")
    else
        error("ThemeSaver:Init needs a Tab or Window")
    end

    Box:AddInput("TS_ThemeName", {
        Text = "Theme Name",
        Default = "MyTheme",
        Placeholder = "Type name...",
    })

    self.ListDropdown = Box:AddDropdown("TS_ThemeList", {
        Text = "Saved Themes",
        Values = { "None" },
        Default = 1,
    })

    task.defer(function()
        self:RefreshList()
    end)

    Box:AddDropdown("TS_Preset", {
        Text = "Presets",
        Values = self:GetPresetNames(),
        Default = 1,
        Callback = function(Value)
            self:ApplyPreset(Value)
        end,
    })

    Box:AddLabel("Accent"):AddColorPicker("TS_Accent", {
        Default = Library.Scheme.AccentColor,
        Callback = function(V)
            Library.Scheme.AccentColor = V
            Library:UpdateColorsUsingRegistry()
        end,
    })

    Box:AddLabel("Background"):AddColorPicker("TS_Background", {
        Default = Library.Scheme.BackgroundColor,
        Callback = function(V)
            Library.Scheme.BackgroundColor = V
            Library:UpdateColorsUsingRegistry()
        end,
    })

    Box:AddLabel("Main"):AddColorPicker("TS_Main", {
        Default = Library.Scheme.MainColor,
        Callback = function(V)
            Library.Scheme.MainColor = V
            Library:UpdateColorsUsingRegistry()
        end,
    })

    Box:AddLabel("Outline"):AddColorPicker("TS_Outline", {
        Default = Library.Scheme.OutlineColor,
        Callback = function(V)
            Library.Scheme.OutlineColor = V
            Library:UpdateColorsUsingRegistry()
        end,
    })

    Box:AddButton("Refresh", function()
        self:RefreshList()
        Library:Notify({ Title = "Themes", Description = "List refreshed", Time = 2 })
    end)

    Box:AddButton("Create", function()
        local Name = Options.TS_ThemeName and Options.TS_ThemeName.Value or ""
        self:Create(Name)
    end)

    Box:AddButton("Save", function()
        local Name = Options.TS_ThemeName and Options.TS_ThemeName.Value or ""
        if (not Name or Name == "") and Options.TS_ThemeList then
            Name = Options.TS_ThemeList.Value
        end
        self:Save(Name)
    end)

    Box:AddButton("Load", function()
        local Name = Options.TS_ThemeList and Options.TS_ThemeList.Value
        self:Load(Name)
    end)

    Box:AddButton("Delete", function()
        local Name = Options.TS_ThemeList and Options.TS_ThemeList.Value
        self:Delete(Name)
    end)

    Box:AddButton("Reset Theme", function()
        self:Reset()
    end)

    Box:AddButton("Auto Save", function()
        self:AutoSave()
    end)

    Box:AddButton("Auto Load", function()
        self:AutoLoad()
    end)

    return self
end

local Instance = ThemeSaver.new()

pcall(function()
    if getgenv then
        getgenv().ThemeSaver = Instance
    end
end)

return Instance
