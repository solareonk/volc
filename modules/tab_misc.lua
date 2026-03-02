-- ================================================
--   Tab Misc — Script & Remote Explorer
-- ================================================

local function init(ctx)
    local Tabs    = ctx.Tabs
    local Fluent  = ctx.Fluent
    local Options = ctx.Options

    -- Helper: get full path of an instance
    local function getPath(obj)
        local parts = {}
        local current = obj
        while current and current ~= game do
            table.insert(parts, 1, current.Name)
            current = current.Parent
        end
        return "game." .. table.concat(parts, ".")
    end

    -- ==================== SCRIPTS ====================

    Tabs.Misc:AddParagraph({
        Title   = "Script Explorer",
        Content = "Cari semua script yang ada di game ini.",
    })

    local scriptList = {}
    local scriptDropdown

    local function scanScripts()
        scriptList = {}
        local ok, scripts = pcall(getscripts)
        if ok and scripts then
            for _, obj in pairs(scripts) do
                if obj and obj.Parent then
                    table.insert(scriptList, getPath(obj))
                end
            end
        end
        table.sort(scriptList)
        return scriptList
    end

    scriptDropdown = Tabs.Misc:AddDropdown("ScriptList", {
        Title   = "Scripts (tekan Refresh)",
        Values  = {},
        Multi   = false,
        Default = nil,
    })

    Tabs.Misc:AddButton({
        Title       = "Refresh Scripts",
        Description = "Scan ulang semua script di game",
        Callback    = function()
            local list = scanScripts()
            scriptDropdown:SetValues(list)
            Fluent:Notify({ Title = "Scripts", Content = "Ditemukan " .. #list .. " scripts.", Duration = 3 })
        end,
    })

    Tabs.Misc:AddButton({
        Title       = "Save Scripts to File",
        Description = "Simpan daftar script ke file txt",
        Callback    = function()
            local list = scanScripts()
            if #list == 0 then
                Fluent:Notify({ Title = "Error", Content = "Tidak ada script ditemukan!", Duration = 2 })
                return
            end
            local gameName = tostring(game.PlaceId)
            local fileName = "HelperKevz/scripts_" .. gameName .. ".txt"
            pcall(makefolder, "HelperKevz")
            writefile(fileName, "-- Scripts for Place ID: " .. gameName .. "\n-- Total: " .. #list .. "\n\n" .. table.concat(list, "\n"))
            Fluent:Notify({ Title = "Tersimpan!", Content = fileName, Duration = 4 })
        end,
    })

    Tabs.Misc:AddButton({
        Title       = "Copy Script Path",
        Description = "Salin path script yang dipilih",
        Callback    = function()
            local val = Options.ScriptList and Options.ScriptList.Value
            if val and val ~= "" then
                setclipboard(val)
                Fluent:Notify({ Title = "Disalin!", Content = val, Duration = 2 })
            else
                Fluent:Notify({ Title = "Error", Content = "Pilih script dulu!", Duration = 2 })
            end
        end,
    })

    Tabs.Misc:AddButton({
        Title       = "Decompile Script",
        Description = "Decompile dan salin source script",
        Callback    = function()
            local val = Options.ScriptList and Options.ScriptList.Value
            if not val or val == "" then
                Fluent:Notify({ Title = "Error", Content = "Pilih script dulu!", Duration = 2 })
                return
            end
            local success, obj = pcall(function()
                local parts = val:split(".")
                local current = game
                for i = 2, #parts do
                    current = current:FindFirstChild(parts[i])
                    if not current then error("Not found") end
                end
                return current
            end)
            if not success or not obj then
                Fluent:Notify({ Title = "Error", Content = "Script tidak ditemukan!", Duration = 2 })
                return
            end
            local ok, source = pcall(decompile, obj)
            if ok and source then
                setclipboard(source)
                Fluent:Notify({ Title = "Decompiled!", Content = "Source disalin ke clipboard.", Duration = 3 })
            else
                Fluent:Notify({ Title = "Gagal", Content = "Tidak bisa decompile script ini.", Duration = 3 })
            end
        end,
    })

    -- ==================== REMOTES ====================

    Tabs.Misc:AddParagraph({
        Title   = "Remote Explorer",
        Content = "Cari semua RemoteEvent & RemoteFunction.",
    })

    local remoteList = {}
    local remoteDropdown

    local function scanRemotes()
        remoteList = {}
        local services = { game:GetService("ReplicatedStorage"), game:GetService("Workspace"), game:GetService("Players") }
        for _, svc in pairs(services) do
            local ok, descendants = pcall(function() return svc:GetDescendants() end)
            if ok and descendants then
                for _, obj in pairs(descendants) do
                    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                        local tag = obj:IsA("RemoteEvent") and "[Event] " or "[Func] "
                        table.insert(remoteList, tag .. getPath(obj))
                    end
                end
            end
        end
        table.sort(remoteList)
        return remoteList
    end

    remoteDropdown = Tabs.Misc:AddDropdown("RemoteList", {
        Title   = "Remotes (tekan Refresh)",
        Values  = {},
        Multi   = false,
        Default = nil,
    })

    Tabs.Misc:AddButton({
        Title       = "Refresh Remotes",
        Description = "Scan ulang semua remote di game",
        Callback    = function()
            local list = scanRemotes()
            remoteDropdown:SetValues(list)
            Fluent:Notify({ Title = "Remotes", Content = "Ditemukan " .. #list .. " remotes.", Duration = 3 })
        end,
    })

    Tabs.Misc:AddButton({
        Title       = "Save Remotes to File",
        Description = "Simpan daftar remote ke file txt",
        Callback    = function()
            local list = scanRemotes()
            if #list == 0 then
                Fluent:Notify({ Title = "Error", Content = "Tidak ada remote ditemukan!", Duration = 2 })
                return
            end
            local gameName = tostring(game.PlaceId)
            local fileName = "HelperKevz/remotes_" .. gameName .. ".txt"
            pcall(makefolder, "HelperKevz")
            writefile(fileName, "-- Remotes for Place ID: " .. gameName .. "\n-- Total: " .. #list .. "\n\n" .. table.concat(list, "\n"))
            Fluent:Notify({ Title = "Tersimpan!", Content = fileName, Duration = 4 })
        end,
    })

    Tabs.Misc:AddButton({
        Title       = "Copy Remote Path",
        Description = "Salin path remote yang dipilih",
        Callback    = function()
            local val = Options.RemoteList and Options.RemoteList.Value
            if val and val ~= "" then
                local path = val:gsub("^%[%w+%] ", "")
                setclipboard(path)
                Fluent:Notify({ Title = "Disalin!", Content = path, Duration = 2 })
            else
                Fluent:Notify({ Title = "Error", Content = "Pilih remote dulu!", Duration = 2 })
            end
        end,
    })

    Tabs.Misc:AddButton({
        Title       = "Copy FireServer Code",
        Description = "Salin contoh kode FireServer",
        Callback    = function()
            local val = Options.RemoteList and Options.RemoteList.Value
            if not val or val == "" then
                Fluent:Notify({ Title = "Error", Content = "Pilih remote dulu!", Duration = 2 })
                return
            end
            local path = val:gsub("^%[%w+%] ", "")
            local code
            if val:find("^%[Event%]") then
                code = path .. ":FireServer()"
            else
                code = path .. ":InvokeServer()"
            end
            setclipboard(code)
            Fluent:Notify({ Title = "Disalin!", Content = code, Duration = 3 })
        end,
    })
end

return init
