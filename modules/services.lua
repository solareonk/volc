-- ================================================
--   Services & Cursor Fix
-- ================================================

local function init(ctx)
    local UIS      = game:GetService("UserInputService")
    local RS       = game:GetService("RunService")
    local Players  = game:GetService("Players")
    local Lighting = game:GetService("Lighting")

    local LocalPlayer = Players.LocalPlayer

    -- Cursor fix (BlueStacks compatibility)
    UIS.MouseIconEnabled = true
    UIS.MouseBehavior    = Enum.MouseBehavior.Default

    RS.RenderStepped:Connect(function()
        if not UIS.MouseIconEnabled then
            UIS.MouseIconEnabled = true
        end
        if UIS.MouseBehavior ~= Enum.MouseBehavior.Default then
            UIS.MouseBehavior = Enum.MouseBehavior.Default
        end
    end)

    local function getHumanoid()
        local char = LocalPlayer.Character
        return char and char:FindFirstChildOfClass("Humanoid")
    end

    -- Export ke ctx
    ctx.UIS         = UIS
    ctx.RS          = RS
    ctx.Players     = Players
    ctx.Lighting    = Lighting
    ctx.LocalPlayer = LocalPlayer
    ctx.getHumanoid = getHumanoid
end

return init
