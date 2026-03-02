-- ================================================
--   Tab Settings + Open Button + Keybinds
-- ================================================

local function init(ctx)
    local Tabs             = ctx.Tabs
    local Fluent           = ctx.Fluent
    local UIS              = ctx.UIS
    local Window           = ctx.Window
    local SaveManager      = ctx.SaveManager
    local InterfaceManager = ctx.InterfaceManager

    -- --------- Settings ---------

    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    InterfaceManager:SetFolder("HelperKevz")
    SaveManager:SetFolder("HelperKevz/config")

    InterfaceManager:BuildInterfaceSection(Tabs.Settings)
    SaveManager:BuildConfigSection(Tabs.Settings)

    -- --------- Open Button (muncul saat minimize) ---------

    do
        local CoreGui  = game:GetService("CoreGui")
        local openGui  = Instance.new("ScreenGui")
        openGui.Name   = "HelperKevzOpenBtn"
        openGui.ResetOnSpawn = false
        openGui.Parent = CoreGui

        local btn          = Instance.new("TextButton")
        btn.Name           = "OpenBtn"
        btn.Text           = "HK"
        btn.Font           = Enum.Font.GothamBold
        btn.TextSize       = 18
        btn.TextColor3     = Color3.fromRGB(255, 255, 255)
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        btn.Size           = UDim2.fromOffset(40, 40)
        btn.Position       = UDim2.new(0, 10, 0.5, -20)
        btn.BorderSizePixel = 0
        btn.ZIndex         = 999
        btn.Parent         = openGui

        local corner       = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent      = btn

        local stroke         = Instance.new("UIStroke")
        stroke.Color         = Color3.fromRGB(100, 100, 255)
        stroke.Thickness     = 1.5
        stroke.Parent        = btn

        -- Draggable
        local dragging, dragStart, startPos
        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging  = true
                dragStart = input.Position
                startPos  = btn.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)

        UIS.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)

        btn.MouseButton1Click:Connect(function()
            Window:Minimize()
        end)

        btn.Visible = true
    end

    -- --------- Keybind: F9 = cursor fix ---------

    UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.F9 then
            UIS.MouseIconEnabled = true
            UIS.MouseBehavior    = Enum.MouseBehavior.Default
        end
    end)
end

return init
