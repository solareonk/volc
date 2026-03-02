-- ================================================
--   Helper Kevz  |  Fluent UI
--   Entry Point — loads all modules
-- ================================================

local BASE = "https://raw.githubusercontent.com/solareonk/volc/main/modules/"

local function loadModule(name)
    return loadstring(game:HttpGet(BASE .. name .. ".lua"))()
end


-- ================================================
-- SHARED CONTEXT
-- ================================================

local ctx = {}


-- ================================================
-- SERVICES (cursor fix, helpers)
-- ================================================

loadModule("services")(ctx)


-- ================================================
-- LOAD LIBRARY
-- ================================================

local Fluent          = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager     = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

ctx.Fluent           = Fluent
ctx.Options          = Fluent.Options
ctx.SaveManager      = SaveManager
ctx.InterfaceManager = InterfaceManager


-- ================================================
-- WINDOW & TABS
-- ================================================

local Window = Fluent:CreateWindow({
    Title       = "Helper Kevz",
    SubTitle    = "by Kevz",
    TabWidth    = 160,
    Size        = UDim2.fromOffset(580, 460),
    Acrylic     = false,
    Theme       = "Dark",
    MinimizeKey = Enum.KeyCode.RightShift,
})

ctx.Window = Window

ctx.Tabs = {
    Main     = Window:AddTab({ Title = "Main",     Icon = "home" }),
    Visual   = Window:AddTab({ Title = "Visual",   Icon = "eye" }),
    Movement = Window:AddTab({ Title = "Movement", Icon = "move" }),
    Collect  = Window:AddTab({ Title = "Collect",  Icon = "package" }),
    PnB      = Window:AddTab({ Title = "PnB",      Icon = "hammer" }),
    Harvest  = Window:AddTab({ Title = "Harvest",  Icon = "axe" }),
    Plant    = Window:AddTab({ Title = "Plant",    Icon = "sprout" }),
    Clear    = Window:AddTab({ Title = "Clear",    Icon = "trash-2" }),
    Misc     = Window:AddTab({ Title = "Misc",     Icon = "wrench" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}


-- ================================================
-- GAME MODULES
-- ================================================

local LocalPlayer = ctx.LocalPlayer

ctx.WorldTiles   = require(game.ReplicatedStorage.WorldTiles)
ctx.WorldManager = require(game.ReplicatedStorage.Managers.WorldManager)
ctx.ItemsManager = require(game.ReplicatedStorage.Managers.ItemsManager)
ctx.PM           = require(LocalPlayer.PlayerScripts:WaitForChild("PlayerMovement"))
ctx.Inventory    = require(game.ReplicatedStorage.Modules.Inventory)

local Remotes     = game.ReplicatedStorage.Remotes
ctx.Remotes       = Remotes
ctx.RemoteFist    = Remotes.PlayerFist
ctx.RemotePlace   = Remotes.PlayerPlaceItem

-- Helper: cari stack index di inventory
ctx.findStack = function(itemId)
    for i, stack in pairs(ctx.Inventory.Stacks) do
        if stack and stack.Id == itemId and (stack.Amount or 1) > 0 then
            return i
        end
    end
    return nil
end


-- ================================================
-- LOAD TAB MODULES
-- ================================================

loadModule("fly")(ctx)           -- A* pathfinding & fly system
loadModule("tab_main")(ctx)      -- Tab Main
loadModule("tab_visual")(ctx)    -- Tab Visual
loadModule("tab_movement")(ctx)  -- Tab Movement (fly UI)
loadModule("tab_collect")(ctx)   -- Tab Collect (auto collect items)
loadModule("tab_pnb")(ctx)       -- Tab PnB (put & break)
loadModule("tab_harvest")(ctx)   -- Tab Harvest
loadModule("tab_plant")(ctx)     -- Tab Plant
loadModule("tab_clear")(ctx)     -- Tab Clear
loadModule("tab_misc")(ctx)      -- Tab Misc
loadModule("tab_settings")(ctx)  -- Tab Settings + open button + keybinds


-- ================================================
-- INIT
-- ================================================

Window:SelectTab(1)

Fluent:Notify({
    Title    = "Helper Kevz",
    Content  = "Berhasil dimuat! RightShift untuk minimize.",
    Duration = 4,
})

SaveManager:LoadAutoloadConfig()