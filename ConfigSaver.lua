--[[
================================================================================
  ConfigSaver Addon for Obsidian UI
  Separate module — NOT part of the main library source.
================================================================================
]]

local cloneref = (cloneref or clonereference or function(instance: any)
    return instance
end)

local HttpService = cloneref(game:GetService("HttpService"))
local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))

local ConfigSaver = {}
ConfigSaver.__index = ConfigSaver
ConfigSaver.Version = "1.2.0"
ConfigSaver.Folder = "ObsidianConfigs"
ConfigSaver.Extension = ".txt"

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

local function Log(self, ...)
    if self.Debug then
        print("[ConfigSaver]", ...)
    end
end

local function GetTables(Library)
    local Toggles = Library.Toggles
    local Options = Library.Options
    if not Toggles and getgenv then
        pcall(function() Toggles = getgenv().Toggles end)
    end
    if not Options and getgenv then
        pcall(function() Options = getgenv().Options end)
    end
    return Toggles or {}, Options or {}
end

local function Snapshot(Library)
    local Toggles, Options = GetTables(Library)
    local Data = {
        Version = 1,
        Timestamp = os.time(),
        Toggles = {},
        Options = {},
        Keybinds = {},
        Meta = {
            PlaceId = game.PlaceId,
            JobId = game.JobId,
        },
    }
    for Idx, Toggle in pairs(Toggles) do
        pcall(function()
            Data.Toggles[Idx] = Toggle.Value
        end)
    end
    for Idx, Option in pairs(Options) do
        pcall(function()
            if Option.Type == "Slider" or Option.Type == "Input" or Option.Type == "Dropdown" then
                Data.Options[Idx] = Option.Value
            elseif Option.Type == "KeyPicker" then
                Data.Keybinds[Idx] = { Key = Option.Value, Mode = Option.Mode }
            elseif Option.Type == "ColorPicker" then
                Data.Options[Idx] = {
                    Hex = Option.Value:ToHex(),
                    Transparency = Option.Transparency or 0,
                }
            end
        end)
    end
    return Data
end

local function Apply(Library, Data)
    if type(Data) ~= "table" then return false end
    local Toggles, Options = GetTables(Library)
    if type(Data.Toggles) == "table" then
        for Idx, Value in pairs(Data.Toggles) do
            if Toggles[Idx] then
                pcall(function() Toggles[Idx]:SetValue(Value) end)
            end
        end
    end
    if type(Data.Options) == "table" then
        for Idx, Value in pairs(Data.Options) do
            if Options[Idx] then
                pcall(function()
                    local Opt = Options[Idx]
                    if Opt.Type == "ColorPicker" and type(Value) == "table" then
                        local Hex = Value.Hex or Value[1] or "FFFFFF"
                        local Trans = Value.Transparency or Value[2] or 0
                        if Opt.SetValueRGB then
                            Opt:SetValueRGB(Color3.fromHex(Hex), Trans)
                        elseif Opt.SetValue then
                            Opt:SetValue(Color3.fromHex(Hex))
                        end
                    else
                        Opt:SetValue(Value)
                    end
                end)
            end
        end
    end
    if type(Data.Keybinds) == "table" then
        for Idx, Value in pairs(Data.Keybinds) do
            if Options[Idx] and Options[Idx].Type == "KeyPicker" then
                pcall(function()
                    if type(Value) == "table" then
                        Options[Idx]:SetValue({ Value.Key or Value[1], Value.Mode or Value[2] })
                    else
                        Options[Idx]:SetValue(Value)
                    end
                end)
            end
        end
    end
    return true
end

local function Encode(Data)
    local Ok, Result = pcall(function()
        return HttpService:JSONEncode(Data)
    end)
    if Ok then return Result end
    return nil
end

local function Decode(Text)
    local Ok, Result = pcall(function()
        return HttpService:JSONDecode(Text)
    end)
    if Ok and type(Result) == "table" then return Result end
    return nil
end

function ConfigSaver.new(Overrides)
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
        Folder = ConfigSaver.Folder,
        Extension = ConfigSaver.Extension,
        Version = ConfigSaver.Version,
    }, ConfigSaver)
    if type(Overrides) == "table" then
        if Overrides.Folder then self.Folder = Overrides.Folder end
        if Overrides.Extension then self.Extension = Overrides.Extension end
        if Overrides.Debug ~= nil then self.Debug = Overrides.Debug end
        if Overrides.AutoSaveName then self.AutoSaveName = Overrides.AutoSaveName end
    end
    return self
end

function ConfigSaver:GetList()
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

function ConfigSaver:RefreshList()
    if not self.ListDropdown then
        return self:GetList()
    end
    local List = self:GetList()
    if #List == 0 then List = { "None" } end
    pcall(function()
        self.ListDropdown:SetValues(List)
    end)
    return List
end

function ConfigSaver:Exists(Name)
    Name = tostring(Name or "")
    if self.Cache[Name] then return true end
    if isfile then
        if isfile(PathFor(self, Name)) or isfile(PathJson(self, Name)) then
            return true
        end
    end
    return false
end

function ConfigSaver:Create(Name)
    Name = tostring(Name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if not self.Library then
        warn("[ConfigSaver] Init first")
        return false
    end
    if Name == "" then
        self.Library:Notify({ Title = "Config", Description = "Enter a name first", Time = 3 })
        return false
    end
    if self:Exists(Name) then
        self.Library:Notify({
            Title = "Config",
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
        Title = "Config Created",
        Description = "Created config: " .. Name,
        Time = 3,
    })
    self:RefreshList()
    Log(self, "Created", Name)
    return true
end

function ConfigSaver:Save(Name)
    Name = tostring(Name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if not self.Library then return false end
    if Name == "" or Name == "None" then
        self.Library:Notify({ Title = "Config", Description = "Enter or select a name", Time = 3 })
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
        Title = "Config Saved",
        Description = "Saved config: " .. Name,
        Time = 3,
    })
    self:RefreshList()
    Log(self, "Saved", Name)
    return true
end

function ConfigSaver:Load(Name)
    Name = tostring(Name or "")
    if not self.Library then return false end
    if Name == "" or Name == "None" then
        self.Library:Notify({ Title = "Config", Description = "Select a config first", Time = 3 })
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
        self.Library:Notify({ Title = "Config", Description = Name .. " not found", Time = 3 })
        return false
    end
    Apply(self.Library, Data)
    self.LastLoaded = Name
    self.Library:Notify({
        Title = "Config Loaded",
        Description = "Loaded config: " .. Name,
        Time = 3,
    })
    Log(self, "Loaded", Name)
    return true
end

function ConfigSaver:Delete(Name)
    Name = tostring(Name or "")
    if not self.Library then return false end
    if Name == "" or Name == "None" then
        self.Library:Notify({ Title = "Config", Description = "Select a config first", Time = 3 })
        return false
    end
    if delfile then
        pcall(delfile, PathFor(self, Name))
        pcall(delfile, PathJson(self, Name))
    end
    self.Cache[Name] = nil
    self.Data[Name] = nil
    self.Library:Notify({
        Title = "Config Deleted",
        Description = "Deleted config: " .. Name,
        Time = 3,
    })
    self:RefreshList()
    Log(self, "Deleted", Name)
    return true
end

function ConfigSaver:AutoSave()
    return self:Save(self.AutoSaveName)
end

function ConfigSaver:AutoLoad()
    return self:Load(self.AutoSaveName)
end

function ConfigSaver:Export(Name)
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

function ConfigSaver:Import(Name, JsonString)
    Name = tostring(Name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if Name == "" or type(JsonString) ~= "string" then return false end
    local Data = Decode(JsonString)
    if not Data then
        if self.Library then
            self.Library:Notify({ Title = "Config", Description = "Invalid import data", Time = 3 })
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
            Title = "Config Imported",
            Description = "Imported config: " .. Name,
            Time = 3,
        })
    end
    self:RefreshList()
    return true
end

function ConfigSaver:GetInfo()
    return {
        Version = self.Version,
        Folder = self.Folder,
        Count = #self:GetList(),
        LastCreated = self.LastCreated,
        LastSaved = self.LastSaved,
        LastLoaded = self.LastLoaded,
        HasWritefile = writefile ~= nil,
        HasReadfile = readfile ~= nil,
    }
end

function ConfigSaver:PrintInfo()
    local Info = self:GetInfo()
    print("========== ConfigSaver ==========")
    for K, V in pairs(Info) do
        print(tostring(K) .. ":", tostring(V))
    end
    print("=================================")
end

function ConfigSaver:SetDebug(Enabled)
    self.Debug = Enabled and true or false
end

function ConfigSaver:SetFolder(Folder)
    if type(Folder) == "string" and Folder ~= "" then
        self.Folder = Folder
    end
end

function ConfigSaver:ClearCache()
    self.Cache = {}
    self.Data = {}
    self:RefreshList()
end

function ConfigSaver:Rename(OldName, NewName)
    OldName = tostring(OldName or "")
    NewName = tostring(NewName or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if OldName == "" or NewName == "" then return false end
    if self:Exists(NewName) then
        if self.Library then
            self.Library:Notify({ Title = "Config", Description = NewName .. " already exists", Time = 3 })
        end
        return false
    end
    local Data = self.Data[OldName]
    if not Data then
        local Exported = self:Export(OldName)
        if Exported then Data = Decode(Exported) end
    end
    if not Data then return false end
    self.Data[NewName] = Data
    self.Cache[NewName] = true
    if writefile then
        local Enc = Encode(Data)
        if Enc then pcall(writefile, PathFor(self, NewName), Enc) end
    end
    self:Delete(OldName)
    if self.Library then
        self.Library:Notify({
            Title = "Config",
            Description = "Renamed " .. OldName .. " → " .. NewName,
            Time = 3,
        })
    end
    self:RefreshList()
    return true
end

function ConfigSaver:Count()
    return #self:GetList()
end

function ConfigSaver:Has(Name)
    return self:Exists(Name)
end

function ConfigSaver:GetLastCreated()
    return self.LastCreated
end

function ConfigSaver:GetLastSaved()
    return self.LastSaved
end

function ConfigSaver:GetLastLoaded()
    return self.LastLoaded
end

function ConfigSaver:Init(Library, Parent)
    assert(Library, "ConfigSaver:Init requires Library")
    self.Library = Library
    local Options = Library.Options
    if not Options and getgenv then
        pcall(function() Options = getgenv().Options end)
    end
    Options = Options or {}

    local Box
    if Parent.AddLeftGroupbox then
        Box = Parent:AddLeftGroupbox("Configs")
    elseif Parent.AddTab then
        local Tab = Parent:AddTab("Configs", "save")
        Box = Tab:AddLeftGroupbox("Configs")
    else
        error("ConfigSaver:Init needs a Tab or Window with AddLeftGroupbox")
    end

    Box:AddInput("CS_ConfigName", {
        Text = "Config Name",
        Default = "default",
        Placeholder = "Type name...",
    })

    self.ListDropdown = Box:AddDropdown("CS_ConfigList", {
        Text = "Saved Configs",
        Values = { "None" },
        Default = 1,
    })

    task.defer(function()
        self:RefreshList()
    end)

    Box:AddButton("Refresh", function()
        self:RefreshList()
        Library:Notify({ Title = "Configs", Description = "List refreshed", Time = 2 })
    end)

    Box:AddButton("Create", function()
        local Name = Options.CS_ConfigName and Options.CS_ConfigName.Value or ""
        self:Create(Name)
    end)

    Box:AddButton("Save", function()
        local Name = Options.CS_ConfigName and Options.CS_ConfigName.Value or ""
        if (not Name or Name == "") and Options.CS_ConfigList then
            Name = Options.CS_ConfigList.Value
        end
        self:Save(Name)
    end)

    Box:AddButton("Load", function()
        local Name = Options.CS_ConfigList and Options.CS_ConfigList.Value
        self:Load(Name)
    end)

    Box:AddButton("Delete", function()
        local Name = Options.CS_ConfigList and Options.CS_ConfigList.Value
        self:Delete(Name)
    end)

    Box:AddButton("Auto Save", function()
        self:AutoSave()
    end)

    Box:AddButton("Auto Load", function()
        self:AutoLoad()
    end)

    return self
end

-- Extra compatibility helpers
function ConfigSaver:CreateConfig(Name)
    return self:Create(Name)
end

function ConfigSaver:SaveConfig(Name)
    return self:Save(Name)
end

function ConfigSaver:LoadConfig(Name)
    return self:Load(Name)
end

function ConfigSaver:DeleteConfig(Name)
    return self:Delete(Name)
end

function ConfigSaver:GetConfigs()
    return self:GetList()
end

local Instance = ConfigSaver.new()

pcall(function()
    if getgenv then
        getgenv().ConfigSaver = Instance
    end
end)

return Instance
