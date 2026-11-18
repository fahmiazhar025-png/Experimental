-- // === SHRIMP HUB - AUTO (Layout Sidebar) ===
-- HANYA UNTUK PEMBELAJARAN KONSEP ROBLOX STUDIO
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- ========== BERSIHKAN INSTANCE LAMA (eksekusi ulang) ==========
local env = (typeof(getgenv) == "function" and getgenv()) or _G
if env.ShrimpHubShutdown then
    pcall(env.ShrimpHubShutdown)
    env.ShrimpHubShutdown = nil
end
for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
    if gui.Name == "Shrimp_Hub_Auto" or gui.Name == "Shrimp_Hub_Logo" or gui.Name == "Shrimp_Hub_ESP" or gui.Name == "Shrimp_Hub_Marks" or gui.Name == "Shrimp_Hub_Zone" then
        pcall(function() gui:Destroy() end)
    end
end

-- Warna
local ORANGE = Color3.fromRGB(255, 140, 0)
local SALMON = Color3.fromRGB(255, 158, 125)
local HEADER_BG = Color3.fromRGB(255, 232, 214)   -- latar slot (krem peach)
local SLOT_HEADER = Color3.fromRGB(255, 208, 178)  -- header slot
local INPUT_BG = Color3.fromRGB(255, 249, 244)     -- kolom isian
local TEXT_DARK = Color3.fromRGB(90, 45, 25)       -- teks gelap (cokelat)
local PLACEHOLDER = Color3.fromRGB(175, 125, 105)
local LINE = Color3.fromRGB(190, 85, 45)           -- garis & border (oranye bata)
local LOCK_COLOR = Color3.fromRGB(110, 100, 220)
local UNLOCK_COLOR = Color3.fromRGB(176, 140, 120)
local TAB_IDLE = Color3.fromRGB(255, 255, 255)
local TAB_ACTIVE = Color3.fromRGB(255, 214, 170)
local TAB_SHADOW = Color3.fromRGB(200, 100, 70)
local STAR_ON = Color3.fromRGB(255, 190, 30)       -- bintang prioritas aktif
local BTN_ORANGE = Color3.fromRGB(215, 110, 50)
local BTN_GREEN = Color3.fromRGB(46, 160, 90)
local BTN_RED = Color3.fromRGB(205, 70, 70)
local BTN_RED_DARK = Color3.fromRGB(150, 40, 40)
local BTN_TEAL = Color3.fromRGB(40, 150, 170)
local BTN_BLUE = Color3.fromRGB(60, 130, 230)
local BTN_GRAY = Color3.fromRGB(150, 125, 110)

-- Ukuran layout
local HEADER_H = 52
local SIDEBAR_W = 110

-- Variabel Global Utama
local slots = {}
local slotCount = 0
local collectSlots = {}
local collectSlotCount = 0

-- Auto-Collect (penjadwal bergiliran)
local collectStartCounter = 0   -- urutan mulai: siapa yang dimulai duluan
local collectThread = nil
local collectStepSlot = nil
local collectTween = nil

local hubDestroyed = false
local hubMinimized = false
local hubLocked = false
local globalConns = {}
local cleanups = {}   -- fungsi pembersih tambahan yang dipanggil saat Shutdown
local antiAfkConn = nil

-- Auto-Teleport (state)
local TP = {
    points = {}, seq = {}, counter = 0,
    posMode = "tp", pickMode = false, busy = false,
    boxMark = false, posName = false, seeThrough = false, markFolder = nil, markThread = nil,
    farmActive = false, farmThread = nil, manualThread = nil,
    tween = nil, delThread = nil, onRespawn = nil,
}
local TabTeleportContainer = nil
local TabZoneContainer = nil
local ZoneStop = nil
local StopTeleport = nil

local function Track(conn)
    table.insert(globalConns, conn)
    return conn
end

-- ========== FUNGSI PENDUKUNG ==========
local function GetHumanoidRootPart()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function SaveCharacterCollision(targetCharacter)
    local state = {}
    if not targetCharacter then return state end
    for _, part in ipairs(targetCharacter:GetDescendants()) do
        if part:IsA("BasePart") then
            state[part] = part.CanCollide
        end
    end
    return state
end

local function RestoreCharacterCollision(state, targetCharacter)
    if not state or not targetCharacter then return end
    for part, oldValue in pairs(state) do
        if part:IsDescendantOf(targetCharacter) and part:IsDescendantOf(game) then
            part.CanCollide = oldValue
        end
    end
end

-- ========== NOCLIP BERSAMA (Collect & Teleport memakai satu pengelola) ==========
-- Tiap pemilik ("collect" / "teleport") hanya boleh memegang satu kali (idempoten).
-- Collision & state Humanoid disimpan saat pemilik pertama masuk, dipulihkan saat pemilik terakhir keluar.
local Noclip = {owners = {}, count = 0, conn = nil, backup = nil, char = nil, hum = nil, states = nil}

local function NoclipAcquire(owner)
    if Noclip.owners[owner] then return end
    local char = LocalPlayer.Character
    if not char then return end
    Noclip.owners[owner] = true
    Noclip.count += 1
    if Noclip.count > 1 then return end

    Noclip.char = char
    Noclip.backup = SaveCharacterCollision(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        Noclip.hum = hum
        Noclip.states = {
            [Enum.HumanoidStateType.Climbing] = hum:GetStateEnabled(Enum.HumanoidStateType.Climbing),
            [Enum.HumanoidStateType.FallingDown] = hum:GetStateEnabled(Enum.HumanoidStateType.FallingDown),
        }
        for st in pairs(Noclip.states) do
            hum:SetStateEnabled(st, false)
        end
    end
    Noclip.conn = RunService.Stepped:Connect(function()
        local c = Noclip.char
        if c and c.Parent then
            for _, part in ipairs(c:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end)
end

local function NoclipRelease(owner)
    if not Noclip.owners[owner] then return end
    Noclip.owners[owner] = nil
    Noclip.count -= 1
    if Noclip.count > 0 then return end
    Noclip.count = 0
    if Noclip.conn then
        Noclip.conn:Disconnect()
        Noclip.conn = nil
    end
    local char = Noclip.char
    if char and char:IsDescendantOf(game) then
        RestoreCharacterCollision(Noclip.backup, char)
        if Noclip.hum and Noclip.states then
            for st, value in pairs(Noclip.states) do
                Noclip.hum:SetStateEnabled(st, value)   -- kembali ke nilai ASLI, bukan dipaksa true
            end
        end
    end
    Noclip.backup, Noclip.char, Noclip.hum, Noclip.states = nil, nil, nil, nil
end

-- Dipakai saat respawn / shutdown: karakter lama sudah tidak ada, jadi tidak ada yang dipulihkan
local function NoclipReset()
    if Noclip.conn then
        Noclip.conn:Disconnect()
        Noclip.conn = nil
    end
    Noclip.owners = {}
    Noclip.count = 0
    Noclip.backup, Noclip.char, Noclip.hum, Noclip.states = nil, nil, nil, nil
end

-- Putar tween dan tunggu dengan aman: ada batas waktu, dan hasilnya true hanya jika benar-benar selesai
-- (Cancelled / karakter hancur -> false, jadi pemanggil tidak melanjutkan langkah berikutnya)
local function PlayAndWait(tween, duration)
    local finished, result = false, nil
    local conn = tween.Completed:Once(function(state)
        finished = true
        result = state
    end)
    tween:Play()
    local deadline = os.clock() + duration + 1
    while not finished and os.clock() < deadline and not hubDestroyed do
        task.wait()
    end
    conn:Disconnect()
    if not finished then
        pcall(function() tween:Cancel() end)
    end
    return finished and result == Enum.PlaybackState.Completed
end

-- ========== FORMAT PATH ==========
-- Seg1.Seg2.Seg3 dimulai dari service (Workspace, ReplicatedStorage, ...).
--   titik di dalam nama ditulis \.   |   backslash ditulis \\
--   beberapa anak dengan nama sama: Nama[2] = anak ke-2 yang bernama "Nama"
-- Path lama yang sederhana (Workspace.Folder.Part) tetap bekerja seperti biasa.
local function SplitPath(pathStr)
    local segs, cur = {}, {}
    local i, n = 1, #pathStr
    while i <= n do
        local ch = pathStr:sub(i, i)
        if ch == "\\" and i < n then
            table.insert(cur, pathStr:sub(i + 1, i + 1))
            i += 2
        elseif ch == "." then
            table.insert(segs, table.concat(cur))
            cur = {}
            i += 1
        else
            table.insert(cur, ch)
            i += 1
        end
    end
    table.insert(segs, table.concat(cur))
    return segs
end

local function ResolveSegs(segs, n)
    local current = game
    for i = 1, n do
        local seg = segs[i]
        if not current or seg == "" then return nil end
        local name, idx = seg, nil
        local base, num = seg:match("^(.*)%[(%d+)%]$")
        if base then
            name, idx = base, tonumber(num)
        end
        if idx then
            local found, count = nil, 0
            for _, child in ipairs(current:GetChildren()) do
                if child.Name == name then
                    count += 1
                    if count == idx then
                        found = child
                        break
                    end
                end
            end
            current = found
        else
            current = current:FindFirstChild(name)
        end
    end
    if not current or not current:IsDescendantOf(game) then
        return nil
    end
    return current
end

-- Path dengan wildcard: Nama[*] = SEMUA anak yang bernama "Nama" (mis. Workspace.Lobby.Decor.Palm[*].Trunk[*])
local function HasWild(segs)
    for _, seg in ipairs(segs) do
        if seg:match("%[%*%]$") then return true end
    end
    return false
end

local MAX_MATCH = 1000   -- batas pengaman jumlah objek yang dicakup satu path
local function ResolveAll(pathStr)
    local out = {}
    if not pathStr or pathStr == "" then return out end
    local segs = SplitPath(pathStr)
    if not HasWild(segs) then
        local one = ResolveSegs(segs, #segs)
        if one then out[1] = one end
        return out
    end
    local current = {game}
    for i = 1, #segs do
        local seg = segs[i]
        if seg == "" then return out end
        local wildName = seg:match("^(.*)%[%*%]$")
        local base, num = seg:match("^(.*)%[(%d+)%]$")
        local nxt = {}
        for _, parent in ipairs(current) do
            if wildName then
                for _, child in ipairs(parent:GetChildren()) do
                    if child.Name == wildName then
                        nxt[#nxt + 1] = child
                        if #nxt >= MAX_MATCH then break end
                    end
                end
            elseif base then
                local want, count = tonumber(num), 0
                for _, child in ipairs(parent:GetChildren()) do
                    if child.Name == base then
                        count += 1
                        if count == want then
                            nxt[#nxt + 1] = child
                            break
                        end
                    end
                end
            else
                local c = parent:FindFirstChild(seg)
                if c then nxt[#nxt + 1] = c end
            end
            if #nxt >= MAX_MATCH then break end
        end
        current = nxt
        if #current == 0 then return out end
    end
    for _, o in ipairs(current) do
        if o:IsDescendantOf(game) then out[#out + 1] = o end
    end
    return out
end

-- Satu objek (path biasa) / objek pertama (path wildcard)
local function ResolveSafePath(pathStr)
    if not pathStr or pathStr == "" then return nil end
    local segs = SplitPath(pathStr)
    if HasWild(segs) then return ResolveAll(pathStr)[1] end
    return ResolveSegs(segs, #segs)
end

-- Kebalikannya: objek -> path (selalu bisa dibaca balik oleh ResolveSafePath)
local PathTool = {}
PathTool.Of = function(obj)
    if not obj or obj == game or not obj:IsDescendantOf(game) then return nil end
    local parts = {}
    local node = obj
    while node and node ~= game do
        local name = node.Name
        local parent = node.Parent
        local idx = nil
        if parent then
            local count, pos = 0, nil
            for _, child in ipairs(parent:GetChildren()) do
                if child.Name == name then
                    count += 1
                    if child == node then pos = count end
                end
            end
            -- nomor urut dipakai bila nama ganda, atau bila nama sendiri berakhiran [angka]
            if count > 1 or name:match("%[%d+%]$") or name:match("%[%*%]$") then idx = pos end
        end
        local esc = name:gsub("\\", "\\\\"):gsub("%.", "\\.")
        if idx then esc = esc .. "[" .. idx .. "]" end
        table.insert(parts, 1, esc)
        node = parent
    end
    return table.concat(parts, ".")
end

-- Path KELOMPOK: setiap tingkat yang punya beberapa anak bernama sama ditulis Nama[*] (semua yang serupa),
-- sehingga satu path mencakup seluruh objek serupa (mis. semua Trunk di semua Palm).
-- Mengembalikan path dan jumlah tingkat yang memakai [*].
PathTool.Group = function(obj)
    if not obj or obj == game or not obj:IsDescendantOf(game) then return nil, 0 end
    local parts, wild = {}, 0
    local node = obj
    while node and node ~= game do
        local name = node.Name
        local parent = node.Parent
        local count, pos = 0, nil
        if parent then
            for _, child in ipairs(parent:GetChildren()) do
                if child.Name == name then
                    count += 1
                    if child == node then pos = count end
                end
            end
        end
        local esc = name:gsub("\\", "\\\\"):gsub("%.", "\\.")
        if count > 1 then
            esc = esc .. "[*]"
            wild += 1
        elseif name:match("%[%d+%]$") or name:match("%[%*%]$") then
            esc = esc .. "[" .. (pos or 1) .. "]"
        end
        table.insert(parts, 1, esc)
        node = parent
    end
    return table.concat(parts, "."), wild
end

-- Objek lain yang "sejenis" dengan path ini: anak-anak container yang namanya sama dengan segmen terakhir.
-- Dipakai mode Follow untuk pindah ke objek lain saat objek sekarang hilang.
PathTool.Siblings = function(pathStr)
    if not pathStr or pathStr == "" then return nil, {} end
    local segs = SplitPath(pathStr)
    if #segs < 2 then return nil, {} end
    local last = segs[#segs]
    local name = last:match("^(.*)%[%d+%]$") or last
    local container = ResolveSegs(segs, #segs - 1)
    if not container then return nil, {} end
    -- "sejenis" = nama sama, atau nama sama setelah angka di ujung dibuang (Coin1, Coin_2 -> Coin)
    local function Base(n) return (n:gsub("[%s_%-]*%d+$", "")) end
    local base = Base(name)
    local list = {}
    for _, child in ipairs(container:GetChildren()) do
        if child.Name == name or (base ~= "" and Base(child.Name) == base) then
            table.insert(list, child)
        end
    end
    return container, list
end

local function GetTargetPosition(targetObj)
    if not targetObj then return nil end
    if targetObj:IsA("BasePart") then
        return targetObj.Position
    elseif targetObj:IsA("Model") then
        if targetObj.PrimaryPart then
            return targetObj.PrimaryPart.Position
        end
        local firstPart = targetObj:FindFirstChildWhichIsA("BasePart", true)
        if firstPart then
            return firstPart.Position
        end
    end
    return nil
end

-- ========== ESP OBJEK ==========
-- Satu koneksi RenderStepped untuk semua entri ESP (kartu atas + tiap slot Collect).
-- Anti kebocoran memori:
--   * koneksi hanya ada selama minimal satu fitur ESP aktif, otomatis diputus saat semua mati
--   * Instance (garis, label, Highlight, SelectionBox) dibuat saat toggle ON dan dihancurkan saat OFF,
--     saat slot dihapus, dan saat Shutdown; tidak ada Instance baru dibuat per frame
--   * pencarian objek via path dibatasi 2x/detik, teks nama diperbarui 10x/detik
--   * ScreenGui ESP ikut dihancurkan saat tidak ada fitur yang aktif
local ESP = {list = {}, conn = nil, gui = nil, folder = nil}

ESP.Pos = function(obj)
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then return obj:GetPivot().Position end
    return GetTargetPosition(obj)
end

ESP.CF = function(obj)
    if obj:IsA("BasePart") then return obj.CFrame end
    if obj:IsA("Model") then return obj:GetPivot() end
    return nil
end

ESP.EnsureGui = function()
    if ESP.gui and ESP.gui.Parent then return end
    local g = Instance.new("ScreenGui")
    g.Name = "Shrimp_Hub_ESP"
    g.ResetOnSpawn = false
    g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    g.DisplayOrder = 999999
    g.IgnoreGuiInset = true
    g.Parent = LocalPlayer.PlayerGui
    local f = Instance.new("Folder")
    f.Name = "Adornments"
    f.Parent = g
    ESP.gui, ESP.folder = g, f
end

-- Satu entri bisa mencakup BANYAK objek (path dengan Nama[*]); tiap objek punya "item" sendiri
-- (garis, label, Highlight, SelectionBox). Item dibuat saat objek muncul dan dibuang saat objek hilang,
-- saat fitur dimatikan, saat entri dihapus, dan saat Shutdown.
ESP.MAX_ITEMS = 30   -- batas objek per entri (Highlight Roblox maks ±31; juga menjaga performa)
ESP.ITEM_KEYS = {"tracerLine", "nameLabel", "hl", "sb"}

ESP.NewEntry = function(getPath, getLabel)
    local e = {getPath = getPath, getLabel = getLabel, lastPath = nil, nextResolve = 0,
        color = ORANGE, rainbow = false, applied = nil,
        f = {tracer = false, name = false, highlight = false, box = false},
        items = {}}
    table.insert(ESP.list, e)
    return e
end

ESP.AnyFeature = function(e)
    local f = e.f
    return f.tracer or f.name or f.highlight or f.box
end

-- Buat / buang instance satu fitur pada satu item
ESP.ItemFeature = function(e, item, feature, on)
    if on then ESP.EnsureGui() end
    local col = e.applied or e.color
    if feature == "tracer" then
        if on and not item.tracerLine then
            local f = Instance.new("Frame")
            f.Name = "Tracer"
            f.AnchorPoint = Vector2.new(0.5, 0.5)
            f.BackgroundColor3 = col
            f.BorderSizePixel = 0
            f.Visible = false
            f.Parent = ESP.gui
            item.tracerLine = f
        elseif not on and item.tracerLine then
            item.tracerLine:Destroy()
            item.tracerLine = nil
        end
    elseif feature == "name" then
        if on and not item.nameLabel then
            local l = Instance.new("TextLabel")
            l.Name = "NameEsp"
            l.AnchorPoint = Vector2.new(0.5, 1)
            l.Size = UDim2.fromOffset(220, 16)
            l.BackgroundTransparency = 1
            l.Text = ""
            l.TextColor3 = col
            l.TextStrokeColor3 = Color3.new(0, 0, 0)
            l.TextStrokeTransparency = 0.3
            l.Font = Enum.Font.GothamBold
            l.TextSize = 12
            l.Visible = false
            l.Parent = ESP.gui
            item.nameLabel = l
            item.nextText = 0
        elseif not on and item.nameLabel then
            item.nameLabel:Destroy()
            item.nameLabel = nil
        end
    elseif feature == "highlight" then
        if on and not item.hl then
            local h = Instance.new("Highlight")
            h.Name = "HighlightEsp"
            h.FillColor = col
            h.FillTransparency = 0.6
            h.OutlineColor = col
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Adornee = item.obj
            h.Parent = ESP.folder
            item.hl = h
        elseif not on and item.hl then
            item.hl:Destroy()
            item.hl = nil
        end
    elseif feature == "box" then
        if on and not item.sb then
            local b = Instance.new("SelectionBox")   -- kerangka (jaring-jaring) kubus di sekeliling objek
            b.Name = "BoxEsp"
            b.Color3 = col
            b.LineThickness = 0.05
            b.SurfaceTransparency = 1
            b.Adornee = item.obj
            b.Parent = ESP.folder
            item.sb = b
        elseif not on and item.sb then
            item.sb:Destroy()
            item.sb = nil
        end
    end
end

ESP.DestroyItem = function(item)
    for _, k in ipairs(ESP.ITEM_KEYS) do
        local inst = item[k]
        if inst then
            pcall(function() inst:Destroy() end)
            item[k] = nil
        end
    end
end

-- Samakan item dengan daftar objek terbaru
ESP.Sync = function(e, objs)
    local keep = {}
    for _, o in ipairs(objs) do
        keep[o] = true
        if not e.items[o] then
            local item = {obj = o, nextText = 0}
            e.items[o] = item
            for feat, on in pairs(e.f) do
                if on then ESP.ItemFeature(e, item, feat, true) end
            end
        end
    end
    for o, item in pairs(e.items) do
        if not keep[o] then
            ESP.DestroyItem(item)
            e.items[o] = nil
        end
    end
end

ESP.Step = function()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local root = GetHumanoidRootPart()
    local origin = root and root.Position or cam.CFrame.Position
    local now = os.clock()
    local rainbow = Color3.fromHSV((now * 0.3) % 1, 1, 1)
    for _, e in ipairs(ESP.list) do
        if ESP.AnyFeature(e) then
            local ok, err = pcall(ESP.UpdateEntry, e, cam, vp, origin, now, rainbow)
            if not ok and not e.warned then
                e.warned = true
                print("[ESP] " .. tostring(err))
            end
        end
    end
end

ESP.UpdateEntry = function(e, cam, vp, origin, now, rainbow)
    local col = e.rainbow and rainbow or e.color
    if col ~= e.applied then ESP.Paint(e, col) end

    local path = e.getPath()
    if path ~= e.lastPath then          -- path diganti -> cari ulang
        e.lastPath = path
        e.nextResolve = 0
    end
    if now >= e.nextResolve then        -- pencarian dibatasi 2x/detik
        e.nextResolve = now + 0.5
        local objs = ResolveAll(path)
        if #objs > ESP.MAX_ITEMS then   -- terlalu banyak: ambil yang terdekat
            local dist = {}
            for _, o in ipairs(objs) do
                local p = ESP.Pos(o)
                dist[o] = p and (p - origin).Magnitude or math.huge
            end
            table.sort(objs, function(a, b) return dist[a] < dist[b] end)
            for i = #objs, ESP.MAX_ITEMS + 1, -1 do objs[i] = nil end
        end
        ESP.Sync(e, objs)
    end

    local f = e.f
    if not (f.tracer or f.name) then return end
    local ax, ay = vp.X * 0.5, vp.Y     -- tracer dari tengah bawah layar
    for o, item in pairs(e.items) do
        local line, label = item.tracerLine, item.nameLabel
        local pos = o:IsDescendantOf(game) and ESP.Pos(o) or nil
        if not pos then
            if line then line.Visible = false end
            if label then label.Visible = false end
        else
            local sp, onScreen = cam:WorldToViewportPoint(pos)
            local x, y = sp.X, sp.Y
            if sp.Z < 0 then            -- di belakang kamera: cerminkan agar garis tetap menunjuk arahnya
                x = vp.X - x
                y = vp.Y - y
            end
            if line then
                local dx, dy = x - ax, y - ay
                line.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), 2)
                line.Position = UDim2.fromOffset((ax + x) * 0.5, (ay + y) * 0.5)
                line.Rotation = math.deg(math.atan2(dy, dx))
                line.Visible = true
            end
            if label then
                if onScreen then
                    label.Position = UDim2.fromOffset(x, y)
                    if now >= item.nextText then
                        item.nextText = now + 0.1
                        local custom = e.getLabel and e.getLabel()      -- mis. nama slot
                        if custom == nil or custom == "" then custom = o.Name end
                        label.Text = string.format("%s [%dm]", custom, math.floor((pos - origin).Magnitude + 0.5))
                    end
                    label.Visible = true
                else
                    label.Visible = false
                end
            end
        end
    end
end

ESP.Refresh = function()
    local any = false
    for _, e in ipairs(ESP.list) do
        if ESP.AnyFeature(e) then
            any = true
            break
        end
    end
    if any then
        if not ESP.conn then
            ESP.conn = RunService.RenderStepped:Connect(ESP.Step)
        end
    else
        if ESP.conn then
            ESP.conn:Disconnect()
            ESP.conn = nil
        end
        if ESP.gui then
            ESP.gui:Destroy()
            ESP.gui, ESP.folder = nil, nil
        end
    end
end

-- feature: "tracer" | "name" | "highlight" | "box"
ESP.Set = function(e, feature, on)
    on = on and true or false
    if on then ESP.EnsureGui() end
    e.f[feature] = on
    for _, item in pairs(e.items) do
        ESP.ItemFeature(e, item, feature, on)
    end
    if not ESP.AnyFeature(e) then       -- semua fitur mati: lepaskan semua item
        for o, item in pairs(e.items) do
            ESP.DestroyItem(item)
            e.items[o] = nil
        end
    end
    e.nextResolve = 0                   -- cari objeknya segera
    ESP.Refresh()
end

ESP.SetAll = function(e, on)
    if not e then return end
    ESP.Set(e, "tracer", on)
    ESP.Set(e, "name", on)
    ESP.Set(e, "highlight", on)
    ESP.Set(e, "box", on)
end

ESP.Remove = function(e)
    if not e then return end
    for o, item in pairs(e.items) do
        ESP.DestroyItem(item)
        e.items[o] = nil
    end
    for k in pairs(e.f) do e.f[k] = false end
    local i = table.find(ESP.list, e)
    if i then table.remove(ESP.list, i) end
    ESP.Refresh()
end

ESP.Clear = function()
    for i = #ESP.list, 1, -1 do
        ESP.Remove(ESP.list[i])
    end
    if ESP.conn then
        ESP.conn:Disconnect()
        ESP.conn = nil
    end
    if ESP.gui then
        ESP.gui:Destroy()
        ESP.gui, ESP.folder = nil, nil
    end
end

-- Toggle berlingkaran: lingkaran kosong = mati, lingkaran hijau + latar peach = aktif.
-- onToggle(newState) boleh mengembalikan false untuk menolak perubahan (mis. slot sedang dikunci).
ESP.MakeToggle = function(parent, text, size, pos, onToggle)
    local btn = Instance.new("TextButton")
    btn.Parent = parent
    btn.Size = size
    btn.Position = pos
    btn.BackgroundColor3 = INPUT_BG
    btn.Text = ""
    btn.AutoLocalize = false
    btn.AutoButtonColor = false
    local c1 = Instance.new("UICorner")
    c1.CornerRadius = UDim.new(0, 5)
    c1.Parent = btn
    local s1 = Instance.new("UIStroke")
    s1.Color = LINE
    s1.Thickness = 1
    s1.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s1.Parent = btn

    local circle = Instance.new("Frame")
    circle.Parent = btn
    circle.Size = UDim2.new(0, 10, 0, 10)
    circle.Position = UDim2.new(0, 6, 0.5, -5)
    circle.BackgroundColor3 = INPUT_BG
    local c2 = Instance.new("UICorner")
    c2.CornerRadius = UDim.new(1, 0)
    c2.Parent = circle
    local s2 = Instance.new("UIStroke")
    s2.Color = LINE
    s2.Thickness = 1
    s2.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s2.Parent = circle

    local lbl = Instance.new("TextLabel")
    lbl.Parent = btn
    lbl.Size = UDim2.new(1, -22, 1, 0)
    lbl.Position = UDim2.new(0, 20, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = TEXT_DARK
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 9
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local t = {state = false, btn = btn, label = lbl}
    local function paint()
        circle.BackgroundColor3 = t.state and BTN_GREEN or INPUT_BG
        btn.BackgroundColor3 = t.state and TAB_ACTIVE or INPUT_BG
    end
    t.set = function(v)
        t.state = v and true or false
        paint()
    end
    btn.MouseButton1Click:Connect(function()
        local ns = not t.state
        if onToggle and onToggle(ns) == false then return end
        t.state = ns
        paint()
    end)
    paint()
    return t
end

-- ===== PEMILIH WARNA ESP (swatch) =====
-- Warna terpilih memengaruhi nama, highlight, tracer, dan box. Rainbow Mode menimpa warna terpilih.
ESP.COLORS = {
    Color3.fromRGB(255, 140, 0),   -- oranye (bawaan)
    Color3.fromRGB(235, 60, 60),   -- merah
    Color3.fromRGB(250, 220, 40),  -- kuning
    Color3.fromRGB(60, 210, 90),   -- hijau
    Color3.fromRGB(40, 200, 220),  -- cyan
    Color3.fromRGB(70, 130, 255),  -- biru
    Color3.fromRGB(160, 90, 240),  -- ungu
    Color3.fromRGB(255, 110, 190), -- pink
    Color3.fromRGB(255, 255, 255), -- putih
}

ESP.Paint = function(e, col)
    e.applied = col
    for _, item in pairs(e.items) do
        if item.tracerLine then item.tracerLine.BackgroundColor3 = col end
        if item.nameLabel then item.nameLabel.TextColor3 = col end
        if item.hl then
            item.hl.FillColor = col
            item.hl.OutlineColor = col
        end
        if item.sb then item.sb.Color3 = col end
    end
end

ESP.SetColor = function(e, col)
    e.color = col
    e.applied = nil
    if not e.rainbow then ESP.Paint(e, col) end
end

ESP.SetRainbow = function(e, on)
    e.rainbow = on and true or false
    e.applied = nil
    if not e.rainbow then ESP.Paint(e, e.color) end   -- kembali ke warna pilihan
end

-- canChange() boleh mengembalikan false untuk menolak (mis. slot dikunci)
ESP.MakeColorPicker = function(parent, pos, entry, canChange)
    local row = Instance.new("Frame")
    row.Parent = parent
    row.Size = UDim2.new(1, 0, 0, 22)
    row.Position = pos
    row.BackgroundTransparency = 1

    local lbl = Instance.new("TextLabel")
    lbl.Parent = row
    lbl.Size = UDim2.new(0, 40, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "Warna:"
    lbl.TextColor3 = TEXT_DARK
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 9
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local swatches = {}
    local picker = {}
    local function mark(col)
        for _, sw in ipairs(swatches) do
            local sel = (sw.color == col)
            sw.stroke.Thickness = sel and 2 or 1
            sw.stroke.Color = sel and TEXT_DARK or LINE
        end
    end

    for i, col in ipairs(ESP.COLORS) do
        local b = Instance.new("TextButton")
        b.Parent = row
        b.Size = UDim2.new(0, 20, 0, 20)
        b.Position = UDim2.new(0, 44 + (i - 1) * 24, 0.5, -10)
        b.BackgroundColor3 = col
        b.Text = ""
        b.AutoLocalize = false
        b.AutoButtonColor = false
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 5)
        c.Parent = b
        local s = Instance.new("UIStroke")
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Thickness = 1
        s.Color = LINE
        s.Parent = b
        table.insert(swatches, {btn = b, color = col, stroke = s})
        b.MouseButton1Click:Connect(function()
            if canChange and canChange() == false then return end
            ESP.SetColor(entry, col)
            mark(col)
        end)
    end

    picker.row = row
    picker.select = function(col) mark(col) end
    picker.dim = function(on)     -- Rainbow aktif -> swatch diredupkan
        for _, sw in ipairs(swatches) do
            sw.btn.BackgroundTransparency = on and 0.6 or 0
        end
    end
    mark(entry.color)
    return picker
end

-- ========== GUI UTAMA ==========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Shrimp_Hub_Auto"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 1000000
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = LocalPlayer.PlayerGui

local LogoGui = Instance.new("ScreenGui")
LogoGui.Name = "Shrimp_Hub_Logo"
LogoGui.ResetOnSpawn = false
LogoGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
LogoGui.DisplayOrder = 1000001
LogoGui.IgnoreGuiInset = true
LogoGui.Parent = LocalPlayer.PlayerGui

-- ===== Logo minimize =====
local ShrimpLogo = Instance.new("TextButton")
ShrimpLogo.Parent = LogoGui
ShrimpLogo.Size = UDim2.new(0, 50, 0, 50)
ShrimpLogo.Position = UDim2.new(0.02, 0, 0.5, -25)
ShrimpLogo.BackgroundTransparency = 1
ShrimpLogo.Text = ""
ShrimpLogo.AutoLocalize = false
ShrimpLogo.AutoButtonColor = false
ShrimpLogo.Active = true
ShrimpLogo.Visible = false

do
    local function Ring(size, pos, color, transparency)
        local f = Instance.new("Frame")
        f.Parent = ShrimpLogo
        f.Size = size
        f.Position = pos
        f.BackgroundColor3 = color
        f.BackgroundTransparency = transparency or 0
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(1, 0)
        c.Parent = f
        return f
    end
    Ring(UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), ORANGE, 0.15)
    Ring(UDim2.new(1, -8, 1, -8), UDim2.new(0, 4, 0, 4), Color3.new(1, 1, 1))
    Ring(UDim2.new(1, -16, 1, -16), UDim2.new(0, 8, 0, 8), ORANGE)
    local CenterWhite = Ring(UDim2.new(1, -24, 1, -24), UDim2.new(0, 12, 0, 12), Color3.new(1, 1, 1))

    local ShrimpEmoji = Instance.new("TextLabel")
    ShrimpEmoji.Parent = CenterWhite
    ShrimpEmoji.Size = UDim2.new(1, 0, 1, 0)
    ShrimpEmoji.BackgroundTransparency = 1
    ShrimpEmoji.Text = "🦐"
    ShrimpEmoji.Font = Enum.Font.GothamBold
    ShrimpEmoji.TextSize = 22
    ShrimpEmoji.TextColor3 = ORANGE
    ShrimpEmoji.TextXAlignment = Enum.TextXAlignment.Center
    ShrimpEmoji.TextYAlignment = Enum.TextYAlignment.Center
end

-- ===== Frame utama =====
local MainFrame = Instance.new("Frame")
MainFrame.Parent = ScreenGui
MainFrame.Size = UDim2.new(0.88, 0, 0.82, 0)
MainFrame.Position = UDim2.new(0.06, 0, 0.09, 0)
MainFrame.BackgroundColor3 = SALMON
MainFrame.Active = true
local UICornerMain = Instance.new("UICorner")
UICornerMain.CornerRadius = UDim.new(0, 8)
UICornerMain.Parent = MainFrame
local UIStrokeMain = Instance.new("UIStroke")
UIStrokeMain.Color = LINE
UIStrokeMain.Thickness = 2
UIStrokeMain.Parent = MainFrame

-- ===== HEADER (kiri atas: kotak "Shrimp 🦐 Hub Auto") =====
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Parent = MainFrame
Header.Size = UDim2.new(1, 0, 0, HEADER_H)
Header.Position = UDim2.new(0, 0, 0, 0)
Header.BackgroundTransparency = 1

local HubLockBtn, HubMinBtn, DestBtn
do
    local TitleBox = Instance.new("Frame")
    TitleBox.Parent = Header
    TitleBox.Size = UDim2.new(0, 190, 0, 38)
    TitleBox.Position = UDim2.new(0, 8, 0, 7)
    TitleBox.BackgroundColor3 = Color3.new(1, 1, 1)
    local c1 = Instance.new("UICorner")
    c1.CornerRadius = UDim.new(0, 10)
    c1.Parent = TitleBox
    local s1 = Instance.new("UIStroke")
    s1.Color = LINE
    s1.Thickness = 3
    s1.Parent = TitleBox

    local Title = Instance.new("TextLabel")
    Title.Parent = TitleBox
    Title.Size = UDim2.new(1, -10, 1, 0)
    Title.Position = UDim2.new(0, 5, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "Shrimp 🦐 Hub Auto"
    Title.TextColor3 = TEXT_DARK
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 15
    Title.TextXAlignment = Enum.TextXAlignment.Center

    local function HeaderBtn(text, color, xOffset, font, textSize)
        local b = Instance.new("TextButton")
        b.Parent = Header
        b.Size = UDim2.new(0, 26, 0, 26)
        b.Position = UDim2.new(1, xOffset, 0.5, -13)
        b.BackgroundColor3 = color
        b.Text = text
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = font
        b.TextSize = textSize
        b.AutoLocalize = false
        b.AutoButtonColor = false
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = b
        return b
    end
    HubLockBtn = HeaderBtn("🔓", Color3.fromRGB(40, 180, 80), -92, Enum.Font.GothamBold, 13)
    HubMinBtn = HeaderBtn("-", Color3.fromRGB(230, 150, 40), -61, Enum.Font.GothamBlack, 15)
    DestBtn = HeaderBtn("X", Color3.fromRGB(214, 70, 70), -30, Enum.Font.GothamBlack, 13)
end

-- ===== GARIS PEMISAH =====
local HLine = Instance.new("Frame")
HLine.Name = "HLine"
HLine.Parent = MainFrame
HLine.Size = UDim2.new(1, 0, 0, 2)
HLine.Position = UDim2.new(0, 0, 0, HEADER_H)
HLine.BackgroundColor3 = LINE
HLine.BorderSizePixel = 0

local VLine = Instance.new("Frame")
VLine.Name = "VLine"
VLine.Parent = MainFrame
VLine.Size = UDim2.new(0, 2, 1, -(HEADER_H + 2))
VLine.Position = UDim2.new(0, SIDEBAR_W, 0, HEADER_H + 2)
VLine.BackgroundColor3 = LINE
VLine.BorderSizePixel = 0

-- ===== SIDEBAR (kiri bawah: 4 tab) =====
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Parent = MainFrame
Sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, -(HEADER_H + 2))
Sidebar.Position = UDim2.new(0, 0, 0, HEADER_H + 2)
Sidebar.BackgroundTransparency = 1

local TAB_H = 40
local TAB_GAP = 46
local function CreateTabButton(text, order)
    local y = 8 + (order - 1) * TAB_GAP

    local Shadow = Instance.new("Frame")
    Shadow.Parent = Sidebar
    Shadow.Size = UDim2.new(0, SIDEBAR_W - 22, 0, TAB_H)
    Shadow.Position = UDim2.new(0, 8, 0, y + 4)
    Shadow.BackgroundColor3 = TAB_SHADOW
    local UICornerShadow = Instance.new("UICorner")
    UICornerShadow.CornerRadius = UDim.new(0, 8)
    UICornerShadow.Parent = Shadow

    local Btn = Instance.new("TextButton")
    Btn.Parent = Sidebar
    Btn.Size = UDim2.new(0, SIDEBAR_W - 22, 0, TAB_H)
    Btn.Position = UDim2.new(0, 12, 0, y)
    Btn.BackgroundColor3 = TAB_IDLE
    Btn.Text = text
    Btn.TextColor3 = TEXT_DARK
    Btn.Font = Enum.Font.GothamMedium
    Btn.TextSize = 11
    Btn.TextWrapped = true
    Btn.AutoLocalize = false
    Btn.AutoButtonColor = false
    local UICornerBtn = Instance.new("UICorner")
    UICornerBtn.CornerRadius = UDim.new(0, 8)
    UICornerBtn.Parent = Btn
    return Btn
end

local TabHomeBtn = CreateTabButton("Tab Home", 1)
local TabRemoteBtn = CreateTabButton("Tab Auto Remote", 2)
local TabCollectBtn = CreateTabButton("Tab Auto Collect", 3)
local TabTeleportBtn = CreateTabButton("Tab Auto Teleport", 4)
local TabZoneBtn = CreateTabButton("Tab Auto Zone", 5)

-- ===== WADAH KONTEN (kanan) =====
local TabContentWrapper = Instance.new("Frame")
TabContentWrapper.Name = "Content"
TabContentWrapper.Parent = MainFrame
TabContentWrapper.Size = UDim2.new(1, -(SIDEBAR_W + 10), 1, -(HEADER_H + 8))
TabContentWrapper.Position = UDim2.new(0, SIDEBAR_W + 6, 0, HEADER_H + 6)
TabContentWrapper.BackgroundTransparency = 1

-- ========== KONTEN TAB HOME ==========
local TabHomeContainer = Instance.new("Frame")
TabHomeContainer.Parent = TabContentWrapper
TabHomeContainer.Size = UDim2.new(1, 0, 1, 0)
TabHomeContainer.Visible = true
TabHomeContainer.BackgroundTransparency = 1

local HomeTitle = Instance.new("TextLabel")
HomeTitle.Parent = TabHomeContainer
HomeTitle.Size = UDim2.new(1, 0, 0, 28)
HomeTitle.Position = UDim2.new(0, 0, 0, 4)
HomeTitle.BackgroundTransparency = 1
HomeTitle.Text = "Selamat datang di Shrimp Hub 🦐"
HomeTitle.TextColor3 = TEXT_DARK
HomeTitle.Font = Enum.Font.GothamBold
HomeTitle.TextSize = 14
HomeTitle.TextXAlignment = Enum.TextXAlignment.Left

local HomeStatus = Instance.new("TextLabel")
HomeStatus.Parent = TabHomeContainer
HomeStatus.Size = UDim2.new(1, 0, 0, 84)
HomeStatus.Position = UDim2.new(0, 0, 0, 34)
HomeStatus.BackgroundTransparency = 1
HomeStatus.Text = ""
HomeStatus.TextColor3 = TEXT_DARK
HomeStatus.Font = Enum.Font.Gotham
HomeStatus.TextSize = 11
HomeStatus.TextWrapped = true
HomeStatus.TextXAlignment = Enum.TextXAlignment.Left
HomeStatus.TextYAlignment = Enum.TextYAlignment.Top

local HomeStopAllBtn = Instance.new("TextButton")
HomeStopAllBtn.Parent = TabHomeContainer
HomeStopAllBtn.Size = UDim2.new(0.48, 0, 0, 34)
HomeStopAllBtn.Position = UDim2.new(0, 0, 0, 122)
HomeStopAllBtn.BackgroundColor3 = BTN_RED
HomeStopAllBtn.Text = "■ BERHENTI SEMUA"
HomeStopAllBtn.TextColor3 = Color3.new(1, 1, 1)
HomeStopAllBtn.Font = Enum.Font.GothamBold
HomeStopAllBtn.TextSize = 10
local UICornerHomeStop = Instance.new("UICorner")
UICornerHomeStop.CornerRadius = UDim.new(0, 6)
UICornerHomeStop.Parent = HomeStopAllBtn

local AntiAfkBtn = Instance.new("TextButton")
AntiAfkBtn.Parent = TabHomeContainer
AntiAfkBtn.Size = UDim2.new(0.48, 0, 0, 34)
AntiAfkBtn.Position = UDim2.new(0.52, 0, 0, 122)
AntiAfkBtn.BackgroundColor3 = UNLOCK_COLOR
AntiAfkBtn.Text = "🛡 ANTI‑AFK: OFF"
AntiAfkBtn.TextColor3 = Color3.new(1, 1, 1)
AntiAfkBtn.Font = Enum.Font.GothamBold
AntiAfkBtn.TextSize = 10
local UICornerAntiAfk = Instance.new("UICorner")
UICornerAntiAfk.CornerRadius = UDim.new(0, 6)
UICornerAntiAfk.Parent = AntiAfkBtn

local HomeHint = Instance.new("TextLabel")
HomeHint.Parent = TabHomeContainer
HomeHint.Size = UDim2.new(1, 0, 0, 30)
HomeHint.Position = UDim2.new(0, 0, 0, 164)
HomeHint.BackgroundTransparency = 1
HomeHint.Text = "Tekan RightShift untuk sembunyikan / tampilkan hub (PC)\n★ di slot Collect = prioritas (jalan duluan)"
HomeHint.TextColor3 = TEXT_DARK
HomeHint.Font = Enum.Font.Gotham
HomeHint.TextSize = 10
HomeHint.TextWrapped = true
HomeHint.TextXAlignment = Enum.TextXAlignment.Left
HomeHint.TextYAlignment = Enum.TextYAlignment.Top

-- ========== KONTEN TAB REMOTE ==========
local TabRemoteContainer = Instance.new("Frame")
TabRemoteContainer.Parent = TabContentWrapper
TabRemoteContainer.Size = UDim2.new(1, 0, 1, 0)
TabRemoteContainer.Position = UDim2.new(0, 0, 0, 0)
TabRemoteContainer.Visible = false
TabRemoteContainer.BackgroundTransparency = 1

local RemoteSpyFrame = Instance.new("Frame")
RemoteSpyFrame.Parent = TabRemoteContainer
RemoteSpyFrame.Size = UDim2.new(1, 0, 0, 40)
RemoteSpyFrame.Position = UDim2.new(0, 0, 0, 0)
RemoteSpyFrame.BackgroundTransparency = 1

local SimpleSpyBtn = Instance.new("TextButton")
SimpleSpyBtn.Parent = RemoteSpyFrame
SimpleSpyBtn.Size = UDim2.new(0.48, 0, 1, 0)
SimpleSpyBtn.BackgroundColor3 = Color3.fromRGB(110, 100, 210)
SimpleSpyBtn.Text = "📌 SIMPLE SPY"
SimpleSpyBtn.TextColor3 = Color3.new(1, 1, 1)
SimpleSpyBtn.Font = Enum.Font.GothamBold
SimpleSpyBtn.TextSize = 9
local UICornerSS = Instance.new("UICorner")
UICornerSS.CornerRadius = UDim.new(0, 5)
UICornerSS.Parent = SimpleSpyBtn

local CobaltSpyBtn = Instance.new("TextButton")
CobaltSpyBtn.Parent = RemoteSpyFrame
CobaltSpyBtn.Size = UDim2.new(0.48, 0, 1, 0)
CobaltSpyBtn.Position = UDim2.new(0.52, 0, 0, 0)
CobaltSpyBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 150)
CobaltSpyBtn.Text = "🔷 COBALT SPY"
CobaltSpyBtn.TextColor3 = Color3.new(1, 1, 1)
CobaltSpyBtn.Font = Enum.Font.GothamBold
CobaltSpyBtn.TextSize = 9
local UICornerCB = Instance.new("UICorner")
UICornerCB.CornerRadius = UDim.new(0, 5)
UICornerCB.Parent = CobaltSpyBtn

local GlobalControl = Instance.new("Frame")
GlobalControl.Parent = TabRemoteContainer
GlobalControl.Size = UDim2.new(1, 0, 0, 32)
GlobalControl.Position = UDim2.new(0, 0, 0, 46)
GlobalControl.BackgroundTransparency = 1

local GlobalDelayLbl = Instance.new("TextLabel")
GlobalDelayLbl.Parent = GlobalControl
GlobalDelayLbl.Size = UDim2.new(0.14, 0, 1, 0)
GlobalDelayLbl.BackgroundTransparency = 1
GlobalDelayLbl.Text = "Delay:"
GlobalDelayLbl.TextColor3 = TEXT_DARK
GlobalDelayLbl.Font = Enum.Font.GothamBold
GlobalDelayLbl.TextSize = 9

local GlobalDelayBox = Instance.new("TextBox")
GlobalDelayBox.Parent = GlobalControl
GlobalDelayBox.Size = UDim2.new(0.10, 0, 1, 0)
GlobalDelayBox.Position = UDim2.new(0.15, 0, 0, 0)
GlobalDelayBox.BackgroundColor3 = INPUT_BG
GlobalDelayBox.Text = "0.5"
GlobalDelayBox.TextColor3 = TEXT_DARK
GlobalDelayBox.Font = Enum.Font.Gotham
GlobalDelayBox.TextSize = 10
GlobalDelayBox.ClearTextOnFocus = false
GlobalDelayBox.PlaceholderColor3 = PLACEHOLDER
local UICornerGlobalDelay = Instance.new("UICorner")
UICornerGlobalDelay.CornerRadius = UDim.new(0, 5)
UICornerGlobalDelay.Parent = GlobalDelayBox

local StartAllBtn = Instance.new("TextButton")
StartAllBtn.Parent = GlobalControl
StartAllBtn.Size = UDim2.new(0.36, 0, 1, 0)
StartAllBtn.Position = UDim2.new(0.27, 0, 0, 0)
StartAllBtn.BackgroundColor3 = Color3.fromRGB(46, 160, 90)
StartAllBtn.Text = "▶ MULAI SEMUA"
StartAllBtn.TextColor3 = Color3.new(1, 1, 1)
StartAllBtn.Font = Enum.Font.GothamBold
StartAllBtn.TextSize = 9
local UICornerStartAll = Instance.new("UICorner")
UICornerStartAll.CornerRadius = UDim.new(0, 5)
UICornerStartAll.Parent = StartAllBtn

local StopAllBtn = Instance.new("TextButton")
StopAllBtn.Parent = GlobalControl
StopAllBtn.Size = UDim2.new(0.36, 0, 1, 0)
StopAllBtn.Position = UDim2.new(0.64, 0, 0, 0)
StopAllBtn.BackgroundColor3 = Color3.fromRGB(205, 70, 70)
StopAllBtn.Text = "■ BERHENTI SEMUA"
StopAllBtn.TextColor3 = Color3.new(1, 1, 1)
StopAllBtn.Font = Enum.Font.GothamBold
StopAllBtn.TextSize = 9
local UICornerStopAll = Instance.new("UICorner")
UICornerStopAll.CornerRadius = UDim.new(0, 5)
UICornerStopAll.Parent = StopAllBtn

local AddRemoteSlotBtn = Instance.new("TextButton")
AddRemoteSlotBtn.Parent = GlobalControl
AddRemoteSlotBtn.Size = UDim2.new(0.23, 0, 1, 0)
AddRemoteSlotBtn.Position = UDim2.new(0.77, 0, 0, 0)
AddRemoteSlotBtn.BackgroundColor3 = Color3.fromRGB(60, 130, 230)
AddRemoteSlotBtn.Text = "+ SLOT REMOTE"
AddRemoteSlotBtn.TextColor3 = Color3.new(1, 1, 1)
AddRemoteSlotBtn.Font = Enum.Font.GothamBold
AddRemoteSlotBtn.TextSize = 9
local UICornerAddRemote = Instance.new("UICorner")
UICornerAddRemote.CornerRadius = UDim.new(0, 5)
UICornerAddRemote.Parent = AddRemoteSlotBtn

local RemoteScrollFrame = Instance.new("ScrollingFrame")
RemoteScrollFrame.Parent = TabRemoteContainer
RemoteScrollFrame.Size = UDim2.new(1, 0, 1, -90)
RemoteScrollFrame.Position = UDim2.new(0, 0, 0, 86)
RemoteScrollFrame.BackgroundTransparency = 1
RemoteScrollFrame.ScrollBarThickness = 6
RemoteScrollFrame.ScrollBarImageColor3 = LINE
RemoteScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
RemoteScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

local RemoteSlotList = Instance.new("UIListLayout")
RemoteSlotList.Parent = RemoteScrollFrame
RemoteSlotList.Padding = UDim.new(0, 6)
RemoteSlotList.FillDirection = Enum.FillDirection.Vertical
RemoteSlotList.HorizontalAlignment = Enum.HorizontalAlignment.Center
RemoteSlotList.SortOrder = Enum.SortOrder.LayoutOrder

-- Tombol tambah slot Remote: biru, selalu di bawah slot terakhir (dinamis)
AddRemoteSlotBtn.Parent = RemoteScrollFrame
AddRemoteSlotBtn.Size = UDim2.new(1, -12, 0, 32)
AddRemoteSlotBtn.LayoutOrder = 1000000
AddRemoteSlotBtn.BackgroundColor3 = BTN_BLUE
AddRemoteSlotBtn.Text = "+ TAMBAH SLOT REMOTE"
AddRemoteSlotBtn.TextSize = 10

-- ========== KONTEN TAB AUTO-COLLECT ==========
local TabCollectContainer = Instance.new("Frame")
TabCollectContainer.Parent = TabContentWrapper
TabCollectContainer.Size = UDim2.new(1, 0, 1, 0)
TabCollectContainer.Position = UDim2.new(0, 0, 0, 0)
TabCollectContainer.Visible = false
TabCollectContainer.BackgroundTransparency = 1

local AddCollectSlotBtn = Instance.new("TextButton")
AddCollectSlotBtn.Parent = TabCollectContainer
AddCollectSlotBtn.Size = UDim2.new(1, 0, 0, 34)
AddCollectSlotBtn.Position = UDim2.new(0, 0, 0, 0)
AddCollectSlotBtn.BackgroundColor3 = Color3.fromRGB(40, 170, 120)
AddCollectSlotBtn.Text = "+ TAMBAH SLOT COLLECT"
AddCollectSlotBtn.TextColor3 = Color3.new(1, 1, 1)
AddCollectSlotBtn.Font = Enum.Font.GothamBold
AddCollectSlotBtn.TextSize = 11
local UICornerAddCollect = Instance.new("UICorner")
UICornerAddCollect.CornerRadius = UDim.new(0, 6)
UICornerAddCollect.Parent = AddCollectSlotBtn

local CollectScrollFrame = Instance.new("ScrollingFrame")
CollectScrollFrame.Parent = TabCollectContainer
CollectScrollFrame.Size = UDim2.new(1, 0, 1, 0)
CollectScrollFrame.Position = UDim2.new(0, 0, 0, 0)
CollectScrollFrame.BackgroundTransparency = 1
CollectScrollFrame.ScrollBarThickness = 6
CollectScrollFrame.ScrollBarImageColor3 = LINE
CollectScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
CollectScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

local CollectSlotList = Instance.new("UIListLayout")
CollectSlotList.Parent = CollectScrollFrame
CollectSlotList.Padding = UDim.new(0, 8)
CollectSlotList.FillDirection = Enum.FillDirection.Vertical
CollectSlotList.HorizontalAlignment = Enum.HorizontalAlignment.Center
CollectSlotList.SortOrder = Enum.SortOrder.LayoutOrder

-- Tombol tambah slot Collect: biru, selalu di bawah slot terakhir (dinamis)
AddCollectSlotBtn.Parent = CollectScrollFrame
AddCollectSlotBtn.Size = UDim2.new(1, -12, 0, 34)
AddCollectSlotBtn.LayoutOrder = 1000000
AddCollectSlotBtn.BackgroundColor3 = BTN_BLUE

-- ===== DEX++ (paling atas Tab Auto Collect) =====
do
    local DEX_URL = "https://raw.githubusercontent.com/infyiff/backup/main/dex.lua"   -- ganti jika punya sumber Dex++ lain

    local Holder = Instance.new("Frame")
    Holder.Parent = CollectScrollFrame
    Holder.Size = UDim2.new(1, -12, 0, 34)
    Holder.BackgroundTransparency = 1
    Holder.LayoutOrder = -3

    local DexBtn = Instance.new("TextButton")
    DexBtn.Parent = Holder
    DexBtn.Size = UDim2.new(1, 0, 1, 0)
    DexBtn.BackgroundColor3 = BTN_TEAL
    DexBtn.Text = "🔎 DEX++ (Explorer)"
    DexBtn.TextColor3 = Color3.new(1, 1, 1)
    DexBtn.Font = Enum.Font.GothamBold
    DexBtn.TextSize = 11
    DexBtn.AutoLocalize = false
    DexBtn.AutoButtonColor = false
    local dc = Instance.new("UICorner")
    dc.CornerRadius = UDim.new(0, 6)
    dc.Parent = DexBtn

    local busy = false
    DexBtn.MouseButton1Click:Connect(function()
        if busy then return end
        busy = true
        DexBtn.Text = "Memuat Dex++..."
        task.spawn(function()
            local ok, err = pcall(function()
                loadstring(game:HttpGet(DEX_URL, true))()
            end)
            if hubDestroyed then return end
            if ok then
                DexBtn.Text = "✅ Dex++ dimuat"
            else
                DexBtn.Text = "⚠ Gagal memuat (cek URL / executor)"
                print("[Dex++] " .. tostring(err))
            end
            task.wait(2)
            if hubDestroyed then return end
            DexBtn.Text = "🔎 DEX++ (Explorer)"
            busy = false
        end)
    end)
end

-- ===== SELECT OBJECT (di bawah Dex++): ketuk objek di game -> tampil path & isinya =====
-- Tidak perlu membuka Dex++. Path yang dihasilkan selalu diuji balik (path -> objek) sebelum ditampilkan.
-- Anti kebocoran: koneksi input HANYA ada selama toggle ON, satu SelectionBox saja, dibersihkan saat Shutdown.
do
    local CARD_H = 172
    local Card = Instance.new("Frame")
    Card.Parent = CollectScrollFrame
    Card.Size = UDim2.new(1, -12, 0, CARD_H)
    Card.BackgroundColor3 = HEADER_BG
    Card.LayoutOrder = -2
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 7)
    cc.Parent = Card

    local Sel = {obj = nil, path = nil, matches = {}, group = true, conns = {}, boxes = {}, down = nil, downPos = nil, downTime = 0}

    -- Info objek
    local InfoPanel = Instance.new("Frame")
    InfoPanel.Parent = Card
    InfoPanel.Size = UDim2.new(1, -8, 0, CARD_H - 62)
    InfoPanel.Position = UDim2.new(0, 4, 0, 58)
    InfoPanel.BackgroundColor3 = INPUT_BG
    InfoPanel.ClipsDescendants = true
    local ci = Instance.new("UICorner")
    ci.CornerRadius = UDim.new(0, 5)
    ci.Parent = InfoPanel

    local InfoLbl = Instance.new("TextLabel")
    InfoLbl.Parent = InfoPanel
    InfoLbl.Size = UDim2.new(1, -8, 1, -6)
    InfoLbl.Position = UDim2.new(0, 4, 0, 3)
    InfoLbl.BackgroundTransparency = 1
    InfoLbl.Text = "Aktifkan Select Object, lalu ketuk objek di game."
    InfoLbl.TextColor3 = TEXT_DARK
    InfoLbl.Font = Enum.Font.Gotham
    InfoLbl.TextSize = 9
    InfoLbl.TextWrapped = true
    InfoLbl.TextXAlignment = Enum.TextXAlignment.Left
    InfoLbl.TextYAlignment = Enum.TextYAlignment.Top

    local function SetInfo(text)
        InfoLbl.Text = text
    end

    local function Short(inst)
        return inst.Name .. " (" .. inst.ClassName .. ")"
    end

    local MAX_SHOW = 30   -- jumlah objek yang dilingkari kotak biru

    -- Susun keterangan: path (kelompok bila "Semua Serupa" ON), jumlah objek yang dicakup, kelas, posisi, induk, isi, uji path
    local function Describe(inst)
        local path, nWild
        if Sel.group then
            path, nWild = PathTool.Group(inst)
        else
            path, nWild = PathTool.Of(inst), 0
        end
        Sel.path = path
        Sel.matches = {}
        if not path then
            return "Objek sudah tidak ada di game."
        end
        local matches = ResolveAll(path)
        Sel.matches = matches

        local L = {}
        table.insert(L, "Path: " .. path)
        if nWild and nWild > 0 then
            local note = (#matches > MAX_SHOW) and (", dilingkari " .. MAX_SHOW .. " pertama") or ""
            table.insert(L, "Serupa: path ini mencakup " .. #matches .. " objek" .. note .. "  ([*] = semua yang bernama itu)")
        end
        table.insert(L, "Nama: " .. inst.Name .. "  |  Class: " .. inst.ClassName)

        if inst:IsA("BasePart") then
            local p, sz = inst.Position, inst.Size
            table.insert(L, string.format("Pos: %.1f, %.1f, %.1f  |  Ukuran: %.1f x %.1f x %.1f", p.X, p.Y, p.Z, sz.X, sz.Y, sz.Z))
        elseif inst:IsA("Model") and inst ~= workspace then
            local p = inst:GetPivot().Position
            table.insert(L, string.format("Pos (pivot): %.1f, %.1f, %.1f", p.X, p.Y, p.Z))
        end

        local parent = inst.Parent
        if parent and parent ~= game then
            table.insert(L, "Induk: " .. Short(parent))
        end

        local kids = inst:GetChildren()
        if #kids == 0 then
            table.insert(L, "Isi: (kosong)")
        else
            local names = {}
            for i = 1, math.min(6, #kids) do
                table.insert(names, Short(kids[i]))
            end
            local extra = (#kids > 6) and (" +" .. (#kids - 6) .. " lagi") or ""
            table.insert(L, "Isi (" .. #kids .. "): " .. table.concat(names, ", ") .. extra)
        end

        if table.find(matches, inst) then
            table.insert(L, "Validasi: ✅ path cocok dan mencakup objek ini")
        else
            table.insert(L, "Validasi: ⚠ path tidak mencakup objek ini")
        end
        return table.concat(L, "\n")
    end

    -- Kotak biru untuk setiap objek yang dicakup path (dipakai ulang, maks MAX_SHOW)
    local function NewBox()
        local b = Instance.new("SelectionBox")
        b.Name = "SelectObjBox"
        b.Color3 = Color3.fromRGB(80, 200, 255)
        b.LineThickness = 0.05
        b.SurfaceColor3 = Color3.fromRGB(80, 200, 255)
        b.SurfaceTransparency = 0.8
        b.Parent = ScreenGui
        return b
    end

    local function UpdateBoxes(inst)
        local list = {inst}
        for _, o in ipairs(Sel.matches) do
            if #list >= MAX_SHOW then break end
            if o ~= inst then table.insert(list, o) end
        end
        local n = 0
        for _, o in ipairs(list) do
            if o ~= workspace and not o:IsA("Terrain") then   -- terlalu besar untuk digambar
                n += 1
                local b = Sel.boxes[n]
                if not b then
                    b = NewBox()
                    Sel.boxes[n] = b
                end
                b.Adornee = o
            end
        end
        for i = #Sel.boxes, n + 1, -1 do
            Sel.boxes[i]:Destroy()
            Sel.boxes[i] = nil
        end
    end

    local function Select(inst)
        Sel.obj = inst
        SetInfo(Describe(inst))
        UpdateBoxes(inst)
    end

    local function PickAt(pos)
        local cam = workspace.CurrentCamera
        if not cam then return end
        local ray = cam:ScreenPointToRay(pos.X, pos.Y)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        if LocalPlayer.Character then
            params.FilterDescendantsInstances = {LocalPlayer.Character}
        end
        local res = workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
        if not res or not res.Instance then
            SetInfo("Tidak ada objek di titik itu (langit / terlalu jauh).")
            return
        end
        Select(res.Instance)
    end

    local function StopSelect()
        for _, c in ipairs(Sel.conns) do
            c:Disconnect()
        end
        table.clear(Sel.conns)
        Sel.down, Sel.downPos = nil, nil
        for i = #Sel.boxes, 1, -1 do
            Sel.boxes[i]:Destroy()
            Sel.boxes[i] = nil
        end
    end

    -- Hanya "ketukan" yang dihitung (geser kamera / tahan lama tidak memilih)
    local function StartSelect()
        if #Sel.conns > 0 then return end
        table.insert(Sel.conns, UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end   -- ketukan di GUI (termasuk hub ini) diabaikan
            local t = input.UserInputType
            if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
                Sel.down = input
                Sel.downPos = input.Position
                Sel.downTime = os.clock()
            end
        end))
        table.insert(Sel.conns, UserInputService.InputEnded:Connect(function(input)
            if Sel.down ~= input then return end
            Sel.down = nil
            if (input.Position - Sel.downPos).Magnitude > 12 or os.clock() - Sel.downTime > 0.5 then return end
            PickAt(input.Position)
        end))
    end

    ESP.MakeToggle(Card, "Select Object", UDim2.new(0.5, -6, 0, 22), UDim2.new(0, 4, 0, 4), function(on)
        if on then
            StartSelect()
            SetInfo("Mode pilih aktif: ketuk sebuah objek di game.\n(Menggeser layar untuk kamera tidak memilih apa pun.)")
        else
            StopSelect()
        end
    end)

    local groupToggle = ESP.MakeToggle(Card, "Semua Serupa", UDim2.new(0.5, -6, 0, 22), UDim2.new(0.5, 2, 0, 4), function(on)
        Sel.group = on
        if Sel.obj and Sel.obj:IsDescendantOf(game) then
            Select(Sel.obj)          -- hitung ulang path untuk objek yang sedang dipilih
        end
    end)
    groupToggle.set(true)

    local CopyBtn = Instance.new("TextButton")
    CopyBtn.Parent = Card
    CopyBtn.Size = UDim2.new(0.64, -8, 0, 24)
    CopyBtn.Position = UDim2.new(0, 4, 0, 30)
    CopyBtn.BackgroundColor3 = BTN_TEAL
    CopyBtn.Text = "📋 COPY PATH"
    CopyBtn.TextColor3 = Color3.new(1, 1, 1)
    CopyBtn.Font = Enum.Font.GothamBold
    CopyBtn.TextSize = 10
    CopyBtn.AutoLocalize = false
    CopyBtn.AutoButtonColor = false
    local c1 = Instance.new("UICorner")
    c1.CornerRadius = UDim.new(0, 5)
    c1.Parent = CopyBtn

    local UpBtn = Instance.new("TextButton")
    UpBtn.Parent = Card
    UpBtn.Size = UDim2.new(0.36, -4, 0, 24)
    UpBtn.Position = UDim2.new(0.64, 0, 0, 30)
    UpBtn.BackgroundColor3 = BTN_BLUE
    UpBtn.Text = "↑ INDUK"
    UpBtn.TextColor3 = Color3.new(1, 1, 1)
    UpBtn.Font = Enum.Font.GothamBold
    UpBtn.TextSize = 10
    UpBtn.AutoLocalize = false
    UpBtn.AutoButtonColor = false
    local c2 = Instance.new("UICorner")
    c2.CornerRadius = UDim.new(0, 5)
    c2.Parent = UpBtn

    local flashToken = 0
    local function Flash(btn, text, restore)
        flashToken += 1
        local my = flashToken
        btn.Text = text
        task.delay(1.3, function()
            if my == flashToken and btn.Parent then btn.Text = restore end
        end)
    end

    CopyBtn.MouseButton1Click:Connect(function()
        if not Sel.path then
            Flash(CopyBtn, "⚠ Pilih objek dulu", "📋 COPY PATH")
            return
        end
        local ok = pcall(function()
            if not setclipboard then error("tanpa setclipboard") end
            setclipboard(Sel.path)
        end)
        if ok then
            Flash(CopyBtn, "✅ TERSALIN", "📋 COPY PATH")
        else
            print("[Select Object] Path: " .. Sel.path)
            Flash(CopyBtn, "⚠ Tanpa clipboard (path di konsol)", "📋 COPY PATH")
        end
    end)

    -- Naik ke induk (mis. dari Part ke Model-nya) -> path & isi ikut berubah
    UpBtn.MouseButton1Click:Connect(function()
        local obj = Sel.obj
        if not obj or not obj:IsDescendantOf(game) then
            Flash(UpBtn, "⚠ -", "↑ INDUK")
            return
        end
        local parent = obj.Parent
        if not parent or parent == game then
            Flash(UpBtn, "Teratas", "↑ INDUK")
            return
        end
        Select(parent)
    end)

    table.insert(cleanups, function()
        StopSelect()
        Sel.obj, Sel.path, Sel.matches = nil, nil, {}
    end)
end

-- ===== KARTU "ESP OBJEK" (paling atas Tab Auto Collect) =====
do
    local CARD_H = 162
    local Card = Instance.new("Frame")
    Card.Parent = CollectScrollFrame
    Card.Size = UDim2.new(1, -12, 0, CARD_H)
    Card.BackgroundColor3 = HEADER_BG
    Card.LayoutOrder = -1
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 7)
    cc.Parent = Card

    local Head = Instance.new("Frame")
    Head.Parent = Card
    Head.Size = UDim2.new(1, -6, 0, 26)
    Head.Position = UDim2.new(0, 3, 0, 3)
    Head.BackgroundColor3 = SLOT_HEADER
    local ch = Instance.new("UICorner")
    ch.CornerRadius = UDim.new(0, 5)
    ch.Parent = Head

    local Title = Instance.new("TextLabel")
    Title.Parent = Head
    Title.Size = UDim2.new(1, -40, 1, 0)
    Title.Position = UDim2.new(0, 8, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "ESP Objek"
    Title.TextColor3 = TEXT_DARK
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 11
    Title.TextXAlignment = Enum.TextXAlignment.Left

    local MinBtn = Instance.new("TextButton")
    MinBtn.Parent = Head
    MinBtn.Size = UDim2.new(0, 22, 0, 22)
    MinBtn.Position = UDim2.new(1, -26, 0.5, -11)
    MinBtn.BackgroundColor3 = Color3.fromRGB(230, 150, 40)
    MinBtn.Text = "−"
    MinBtn.TextColor3 = Color3.new(1, 1, 1)
    MinBtn.Font = Enum.Font.GothamBlack
    MinBtn.TextSize = 12
    local cm = Instance.new("UICorner")
    cm.CornerRadius = UDim.new(0, 4)
    cm.Parent = MinBtn

    local Content = Instance.new("Frame")
    Content.Parent = Card
    Content.Size = UDim2.new(1, -6, 1, -34)
    Content.Position = UDim2.new(0, 3, 0, 32)
    Content.BackgroundTransparency = 1

    local PathBox = Instance.new("TextBox")
    PathBox.Parent = Content
    PathBox.Size = UDim2.new(1, 0, 0, 22)
    PathBox.BackgroundColor3 = INPUT_BG
    PathBox.PlaceholderText = "Path Objek: Workspace.Benda"
    PathBox.PlaceholderColor3 = PLACEHOLDER
    PathBox.Text = ""
    PathBox.TextColor3 = TEXT_DARK
    PathBox.Font = Enum.Font.Gotham
    PathBox.TextSize = 9
    PathBox.ClearTextOnFocus = false
    local cp = Instance.new("UICorner")
    cp.CornerRadius = UDim.new(0, 4)
    cp.Parent = PathBox

    local entry = ESP.NewEntry(function() return PathBox.Text end)
    local function Tg(key, text, x, y)
        ESP.MakeToggle(Content, text, UDim2.new(0.49, 0, 0, 20), UDim2.new(x, 0, 0, y), function(on)
            ESP.Set(entry, key, on)
        end)
    end
    Tg("tracer", "Tracer", 0, 26)
    Tg("highlight", "Highlight", 0.51, 26)
    Tg("name", "Nama ESP", 0, 52)
    Tg("box", "Box ESP", 0.51, 52)
    local picker = ESP.MakeColorPicker(Content, UDim2.new(0, 0, 0, 78), entry)
    ESP.MakeToggle(Content, "Rainbow Mode", UDim2.new(0.49, 0, 0, 20), UDim2.new(0, 0, 0, 104), function(on)
        ESP.SetRainbow(entry, on)
        picker.dim(on)
    end)

    local collapsed = false
    MinBtn.MouseButton1Click:Connect(function()
        collapsed = not collapsed
        Content.Visible = not collapsed
        Card.Size = UDim2.new(1, -12, 0, collapsed and 34 or CARD_H)
        MinBtn.Text = collapsed and "+" or "−"
    end)
end

-- ==================================================
-- PENJADWAL AUTO-COLLECT (BERGILIRAN + PRIORITAS)
-- Aturan antrean:
--   1) Slot berbintang (prioritas) selalu di depan, urut siapa yang paling dulu dimulai
--   2) Setelah itu slot biasa, urut siapa yang paling dulu dimulai
--   3) Antrean diulang terus: A,B,C,A,B,C,...
-- ==================================================
local function SetSlotButton(slotData, running)
    if running then
        slotData.startStopBtn.Text = "■ BERHENTI"
        slotData.startStopBtn.BackgroundColor3 = BTN_RED
    else
        slotData.startStopBtn.Text = "▶ MULAI"
        slotData.startStopBtn.BackgroundColor3 = BTN_GREEN
    end
end

local function BuildQueue(kind)
    kind = kind or "collect"
    local pri, normal = {}, {}
    for _, s in ipairs(collectSlots) do
        if s.active and s.kind == kind then
            if s.priority then
                table.insert(pri, s)
            else
                table.insert(normal, s)
            end
        end
    end
    local function byStart(a, b) return a.startOrder < b.startOrder end
    table.sort(pri, byStart)
    table.sort(normal, byStart)
    for _, s in ipairs(normal) do
        table.insert(pri, s)
    end
    return pri
end

-- ==================================================
-- MODE FOLLOW
-- Karakter mengikuti objek terus-menerus menurut arah + Distance (stud).
--   * Satu koneksi Heartbeat untuk SEMUA slot Follow; hanya ada selama minimal satu slot Follow aktif
--   * Hanya satu slot yang memegang karakter: slot berbintang dulu, lalu yang paling dulu dimulai,
--     dan hanya slot yang sedang punya objek
--   * Objek hilang -> langsung pindah ke objek lain bernama sama di container yang sama (yang terdekat)
--   * Tidak ada objek sama sekali -> kembali ke posisi semula (posisi saat Follow mulai memegang karakter)
--   * Selama Follow memegang karakter, giliran Auto Collect dijeda
-- ==================================================
local Follow = {conn = nil, engaged = false, origin = nil, queue = {}, queueAt = 0, warned = false}

local function FollowOffset(slot, tcf)
    local d = slot.dir
    local v = Vector3.zero
    if d.vert == "up" then v += Vector3.yAxis elseif d.vert == "down" then v -= Vector3.yAxis end
    -- arah mendatar mengikuti hadap objek (diratakan), Atas/Bawah selalu sumbu Y dunia
    local lv = tcf.LookVector
    local look = Vector3.new(lv.X, 0, lv.Z)
    look = (look.Magnitude > 0.05) and look.Unit or Vector3.new(0, 0, -1)
    local right = look:Cross(Vector3.yAxis)
    if d.side == "right" then v += right elseif d.side == "left" then v -= right end
    if d.depth == "front" then v += look elseif d.depth == "back" then v -= look end
    if v.Magnitude < 0.001 then return Vector3.zero end
    local dist = tonumber(slot.distBox.Text) or 5
    return v.Unit * math.max(0, dist)
end

-- Objek yang diikuti slot ini; dicari ulang (maks 4x/detik) hanya bila objek lama sudah hilang
local function FollowAcquire(s, rootPos, now)
    local path = s.dexPath.Text
    if path ~= s.followPath then
        s.followPath = path
        s.followTarget = nil
        s.followNextScan = 0
    end
    local t = s.followTarget
    if t and t:IsDescendantOf(game) and ESP.CF(t) then return t end
    s.followTarget = nil
    if now < (s.followNextScan or 0) then return nil end
    s.followNextScan = now + 0.25

    -- path bisa mencakup banyak objek (Nama[*]) -> pilih yang terdekat; path biasa -> objeknya sendiri
    local cand, bestD = nil, math.huge
    for _, c in ipairs(ResolveAll(path)) do
        local p = ESP.CF(c) and ESP.Pos(c)
        if p then
            local dd = (p - rootPos).Magnitude
            if dd < bestD then
                cand, bestD = c, dd
            end
        end
    end
    if not cand then
        local _, list = PathTool.Siblings(path)
        for _, c in ipairs(list) do
            local p = ESP.Pos(c)
            if p then
                local dd = (p - rootPos).Magnitude
                if dd < bestD then
                    cand, bestD = c, dd
                end
            end
        end
    end
    s.followTarget = cand
    return cand
end

local function FollowStep()
    if hubDestroyed then return end
    local root = GetHumanoidRootPart()
    if not root then return end
    local now = os.clock()
    if now - Follow.queueAt > 0.2 then
        Follow.queue = BuildQueue("follow")
        Follow.queueAt = now
    end

    local leader, target
    for _, s in ipairs(Follow.queue) do
        if s.active then
            local t = FollowAcquire(s, root.Position, now)
            if t then
                leader, target = s, t
                break
            end
        end
    end

    if leader then
        if not Follow.engaged then
            Follow.engaged = true
            Follow.origin = root.CFrame
            if collectTween then pcall(function() collectTween:Cancel() end) end
            NoclipAcquire("follow")
        end
        NoclipAcquire("follow")      -- idempoten; menjaga noclip tetap ada setelah respawn
        local tcf = ESP.CF(target)
        if tcf then
            local pos = tcf.Position + FollowOffset(leader, tcf)
            local flat = Vector3.new(tcf.Position.X - pos.X, 0, tcf.Position.Z - pos.Z)
            if flat.Magnitude > 0.1 then
                root.CFrame = CFrame.lookAt(pos, pos + flat)      -- menghadap objek (hanya mendatar)
            else
                root.CFrame = CFrame.new(pos) * root.CFrame.Rotation
            end
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    elseif Follow.engaged then
        Follow.engaged = false
        NoclipRelease("follow")
        if Follow.origin then
            root.CFrame = Follow.origin                           -- tidak ada objek -> kembali ke posisi semula
            root.AssemblyLinearVelocity = Vector3.zero
        end
        Follow.origin = nil
    end
end

local function FollowStartDriver()
    if Follow.conn then return end
    Follow.conn = RunService.Heartbeat:Connect(function()
        local ok, err = pcall(FollowStep)
        if not ok and not Follow.warned then
            Follow.warned = true
            print("[Follow] " .. tostring(err))
        end
    end)
end

local function FollowStopDriver()
    if Follow.conn then
        Follow.conn:Disconnect()
        Follow.conn = nil
    end
    NoclipRelease("follow")
    Follow.engaged = false
    Follow.origin = nil
    Follow.queue = {}
end

-- ===== POSISI AWAL SESI AUTO COLLECT =====
-- Saat slot pertama (Collect maupun Follow) mulai berjalan, posisi karakter dicatat.
-- Saat slot terakhir berhenti (tombol Berhenti, Berhenti Semua, Reset, ganti mode, hapus slot, atau error),
-- karakter dikembalikan ke posisi itu + 2 stud ke atas. Tidak dikembalikan saat hub ditutup (X).
local AutoSession = {origin = nil}

local function AnySlotActive()
    for _, o in ipairs(collectSlots) do
        if o.active then return true end
    end
    return false
end

local function SessionBegin()
    if ZoneStop then ZoneStop(true) end      -- Auto Zona berhenti bila Collect/Follow dimulai (tidak rebutan kendali)
    if AutoSession.origin then return end
    local root = GetHumanoidRootPart()
    if root then AutoSession.origin = root.CFrame end
end

local function SessionEnd()
    if AnySlotActive() then return end          -- masih ada slot lain yang berjalan
    local origin = AutoSession.origin
    AutoSession.origin = nil
    if origin and not hubDestroyed then
        local root = GetHumanoidRootPart()
        if root then
            root.CFrame = origin + Vector3.new(0, 2, 0)
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end
end

local function StartFollowSlot(s)
    if hubDestroyed or s.active then return end
    if s.dexPath.Text == "" then
        print("[" .. s.nameBox.Text .. "] Isi path objek terlebih dahulu")
        return
    end
    if not GetHumanoidRootPart() then
        print("[" .. s.nameBox.Text .. "] Karakter tidak ditemukan")
        return
    end
    SessionBegin()
    collectStartCounter += 1
    s.startOrder = collectStartCounter
    s.active = true
    s.followTarget, s.followNextScan, s.followPath = nil, 0, nil
    Follow.queueAt = 0
    SetSlotButton(s, true)
    FollowStartDriver()
end

-- Berhenti: koneksi diputus bila tidak ada slot Follow aktif; bila tak ada slot aktif sama sekali, kembali ke posisi awal sesi (+2 stud)
local function StopFollowSlot(s)
    if not s or not s.active then return end
    s.active = false
    s.followTarget = nil
    SetSlotButton(s, false)
    local otherFollow = false
    for _, o in ipairs(collectSlots) do
        if o.active and o.kind == "follow" then
            otherFollow = true
            break
        end
    end
    if not otherFollow then FollowStopDriver() end
    SessionEnd()
end

local function StopCollectScheduler()
    if collectTween then
        pcall(function() collectTween:Cancel() end)
        collectTween = nil
    end
    if collectThread then
        if collectThread ~= coroutine.running() then
            pcall(task.cancel, collectThread)
        end
        collectThread = nil
    end
    NoclipRelease("collect")   -- idempoten: aman walau langkah tween juga melepasnya
    collectStepSlot = nil
end

local function StopCollectSlot(slotData)
    if not slotData or not slotData.active then return end
    slotData.active = false
    SetSlotButton(slotData, false)
    -- batalkan tween bila slot ini sedang berjalan
    if collectStepSlot == slotData and collectTween then
        pcall(function() collectTween:Cancel() end)
    end
    local anyActive = false
    for _, s in ipairs(collectSlots) do
        if s.active and s.kind == "collect" then anyActive = true break end
    end
    if not anyActive then
        StopCollectScheduler()
    end
    SessionEnd()
end

local function StopCollectAll()
    for _, s in ipairs(collectSlots) do
        if s.active then
            s.active = false
            s.followTarget = nil
            SetSlotButton(s, false)
        end
    end
    StopCollectScheduler()
    FollowStopDriver()
    SessionEnd()
end

-- Hanya slot mode Collect (dipakai saat scheduler Collect selesai; slot Follow tidak ikut berhenti)
local function StopCollectKind()
    for _, s in ipairs(collectSlots) do
        if s.active and s.kind == "collect" then
            s.active = false
            SetSlotButton(s, false)
        end
    end
    StopCollectScheduler()
    SessionEnd()
end

-- Berhenti / mulai sesuai mode slot
local function StopSlot(s)
    if s.kind == "follow" then
        StopFollowSlot(s)
    else
        StopCollectSlot(s)
    end
end

-- Satu langkah: pergi ke target milik satu slot
local function RunCollectStep(slotData)
    local path = slotData.dexPath.Text
    if path == "" then
        print("[Collect Slot " .. slotData.id .. "] Isi path objek terlebih dahulu")
        return
    end

    local root = GetHumanoidRootPart()
    if not root or not root:IsDescendantOf(game) then
        print("[Collect Slot " .. slotData.id .. "] Karakter tidak ditemukan / respawn, menunggu")
        return
    end

    local matches = ResolveAll(path)
    if #matches == 0 then
        print("[Collect Slot " .. slotData.id .. "] Target path tidak ditemukan")
        return
    end

    -- Path boleh mencakup banyak objek (Nama[*]): kunjungi yang TERDEKAT yang belum dikunjungi,
    -- lalu ulangi dari awal setelah semuanya pernah dikunjungi. Path berisi 1 objek berperilaku seperti biasa.
    local yLimit = tonumber(slotData.yLimitBox.Text)
    local multi = #matches > 1
    if multi and not slotData.visited then
        slotData.visited = setmetatable({}, {__mode = "k"})   -- kunci lemah: tidak menahan objek yang sudah dihapus
    end
    local function Pick(skipVisited)
        local bestObj, bestPos, bestD = nil, nil, math.huge
        for _, obj in ipairs(matches) do
            local p = GetTargetPosition(obj)
            if p and not (yLimit ~= nil and p.Y < yLimit) and not (skipVisited and slotData.visited[obj]) then
                local d = (p - root.Position).Magnitude
                if d < bestD then bestObj, bestPos, bestD = obj, p, d end
            end
        end
        return bestObj, bestPos
    end
    local pickedObj, targetPos
    if multi then
        pickedObj, targetPos = Pick(true)
        if not pickedObj then
            table.clear(slotData.visited)
            pickedObj, targetPos = Pick(false)
        end
        if pickedObj then slotData.visited[pickedObj] = true end
    else
        pickedObj, targetPos = Pick(false)
    end
    if not targetPos then
        print("[Collect Slot " .. slotData.id .. "] Tidak ada target valid (posisi tak terbaca / di bawah batas Y)")
        return
    end

    targetPos += Vector3.new(0, 2, 0)

    local goal = CFrame.new(targetPos, targetPos + root.CFrame.LookVector)

    if slotData.mode == "tween" then
        NoclipAcquire("collect")
        local tween = TweenService:Create(root, TweenInfo.new(2, Enum.EasingStyle.Linear), {CFrame = goal})
        collectTween = tween
        PlayAndWait(tween, 2)          -- Cancelled/timeout hanya mengembalikan false, tidak ada langkah lanjutan
        if collectTween == tween then collectTween = nil end
        NoclipRelease("collect")
    else
        root.CFrame = goal
    end
end

local function EnsureCollectScheduler()
    if collectThread then return end
    collectThread = task.spawn(function()
        local ok, err = xpcall(function()
            while not hubDestroyed do
                local queue = BuildQueue()          -- dibangun ulang tiap putaran
                if #queue == 0 then break end
                for _, s in ipairs(queue) do
                    if hubDestroyed then break end
                    if s.active then
                        if Follow.engaged then
                            task.wait(0.1)          -- Follow sedang memegang karakter: Collect dijeda
                        else
                            collectStepSlot = s
                            RunCollectStep(s)
                            collectStepSlot = nil
                            if s.active then
                                local d = tonumber(s.delayBox.Text)
                                if d == nil or d < 0 or d > 30 then d = 0.5 end
                                task.wait(d)
                            end
                        end
                    end
                end
            end
        end, debug.traceback)
        if not ok then
            print("[Collect] Error Runtime: " .. tostring(err))
        end
        StopCollectKind()
    end)
end

local function StartCollectSlot(slotData)
    if hubDestroyed or slotData.active then return end
    if slotData.dexPath.Text == "" then
        print("[Collect Slot " .. slotData.id .. "] Isi path objek terlebih dahulu")
        return
    end
    if not GetHumanoidRootPart() then
        print("[Collect Slot " .. slotData.id .. "] Karakter tidak ditemukan")
        return
    end
    SessionBegin()
    collectStartCounter += 1
    slotData.startOrder = collectStartCounter
    slotData.visited = nil
    slotData.active = true
    SetSlotButton(slotData, true)
    EnsureCollectScheduler()
end

local function StartSlot(s)
    if s.kind == "follow" then
        StartFollowSlot(s)
    else
        StartCollectSlot(s)
    end
end

local function QueueText()
    local q = BuildQueue()
    if #q == 0 then return "-" end
    local parts = {}
    for _, s in ipairs(q) do
        table.insert(parts, (s.priority and "★" or "") .. "#" .. s.id)
    end
    return table.concat(parts, " > ") .. "  ↻"
end

-- ========== FUNGSI BUAT SLOT (MODE COLLECT / FOLLOW) ==========
local function CreateCollectSlot()
    collectSlotCount += 1
    local slotId = collectSlotCount
    local H_COLLECT, H_FOLLOW = 250, 366

    local SlotWrapper = Instance.new("Frame")
    SlotWrapper.Parent = CollectScrollFrame
    SlotWrapper.Size = UDim2.new(1, -12, 0, H_COLLECT)
    SlotWrapper.BackgroundColor3 = HEADER_BG
    SlotWrapper.LayoutOrder = slotId
    local UICornerSlotW = Instance.new("UICorner")
    UICornerSlotW.CornerRadius = UDim.new(0, 7)
    UICornerSlotW.Parent = SlotWrapper

    local SlotHeader = Instance.new("Frame")
    SlotHeader.Parent = SlotWrapper
    SlotHeader.Size = UDim2.new(1, -6, 0, 28)
    SlotHeader.Position = UDim2.new(0, 3, 0, 3)
    SlotHeader.BackgroundColor3 = SLOT_HEADER
    local UICornerSlotH = Instance.new("UICorner")
    UICornerSlotH.CornerRadius = UDim.new(0, 5)
    UICornerSlotH.Parent = SlotHeader

    -- Header: Star | Mode | Nama | Minimize | Lock | X
    local StarBtn = Instance.new("TextButton")
    StarBtn.Parent = SlotHeader
    StarBtn.Size = UDim2.new(0, 22, 0, 22)
    StarBtn.Position = UDim2.new(0, 4, 0.5, -11)
    StarBtn.BackgroundColor3 = UNLOCK_COLOR
    StarBtn.Text = "☆"
    StarBtn.TextColor3 = Color3.new(1, 1, 1)
    StarBtn.Font = Enum.Font.GothamBold
    StarBtn.TextSize = 14
    StarBtn.AutoLocalize = false
    StarBtn.AutoButtonColor = false
    local UICornerStar = Instance.new("UICorner")
    UICornerStar.CornerRadius = UDim.new(0, 4)
    UICornerStar.Parent = StarBtn

    local ModeSwitchBtn = Instance.new("TextButton")
    ModeSwitchBtn.Parent = SlotHeader
    ModeSwitchBtn.Size = UDim2.new(0, 54, 0, 22)
    ModeSwitchBtn.Position = UDim2.new(0, 30, 0.5, -11)
    ModeSwitchBtn.BackgroundColor3 = BTN_ORANGE
    ModeSwitchBtn.Text = "Collect"
    ModeSwitchBtn.TextColor3 = Color3.new(1, 1, 1)
    ModeSwitchBtn.Font = Enum.Font.GothamBold
    ModeSwitchBtn.TextSize = 8
    ModeSwitchBtn.AutoLocalize = false
    ModeSwitchBtn.AutoButtonColor = false
    local UICornerModeSw = Instance.new("UICorner")
    UICornerModeSw.CornerRadius = UDim.new(0, 4)
    UICornerModeSw.Parent = ModeSwitchBtn

    local SlotNameBox = Instance.new("TextBox")
    SlotNameBox.Parent = SlotHeader
    SlotNameBox.Size = UDim2.new(1, -174, 1, -4)
    SlotNameBox.Position = UDim2.new(0, 88, 0, 2)
    SlotNameBox.BackgroundColor3 = INPUT_BG
    SlotNameBox.Text = "Collect Slot #" .. tostring(slotId)
    SlotNameBox.TextColor3 = TEXT_DARK
    SlotNameBox.Font = Enum.Font.GothamBold
    SlotNameBox.TextSize = 10
    SlotNameBox.ClearTextOnFocus = false
    SlotNameBox.PlaceholderColor3 = PLACEHOLDER
    local UICornerSlotName = Instance.new("UICorner")
    UICornerSlotName.CornerRadius = UDim.new(0, 4)
    UICornerSlotName.Parent = SlotNameBox

    local SlotMinBtn = Instance.new("TextButton")
    SlotMinBtn.Parent = SlotHeader
    SlotMinBtn.Size = UDim2.new(0, 22, 0, 22)
    SlotMinBtn.Position = UDim2.new(1, -78, 0.5, -11)
    SlotMinBtn.BackgroundColor3 = Color3.fromRGB(230, 150, 40)
    SlotMinBtn.Text = "−"
    SlotMinBtn.TextColor3 = Color3.new(1, 1, 1)
    SlotMinBtn.Font = Enum.Font.GothamBlack
    SlotMinBtn.TextSize = 12
    local UICornerSlotMin = Instance.new("UICorner")
    UICornerSlotMin.CornerRadius = UDim.new(0, 4)
    UICornerSlotMin.Parent = SlotMinBtn

    local SlotLockBtn = Instance.new("TextButton")
    SlotLockBtn.Parent = SlotHeader
    SlotLockBtn.Size = UDim2.new(0, 22, 0, 22)
    SlotLockBtn.Position = UDim2.new(1, -52, 0.5, -11)
    SlotLockBtn.BackgroundColor3 = UNLOCK_COLOR
    SlotLockBtn.Text = "🔓"
    SlotLockBtn.TextColor3 = Color3.new(1, 1, 1)
    SlotLockBtn.Font = Enum.Font.GothamBold
    SlotLockBtn.TextSize = 10
    local UICornerSlotLock = Instance.new("UICorner")
    UICornerSlotLock.CornerRadius = UDim.new(0, 4)
    UICornerSlotLock.Parent = SlotLockBtn

    local SlotDestroyBtn = Instance.new("TextButton")
    SlotDestroyBtn.Parent = SlotHeader
    SlotDestroyBtn.Size = UDim2.new(0, 22, 0, 22)
    SlotDestroyBtn.Position = UDim2.new(1, -26, 0.5, -11)
    SlotDestroyBtn.BackgroundColor3 = Color3.fromRGB(214, 70, 70)
    SlotDestroyBtn.Text = "X"
    SlotDestroyBtn.TextColor3 = Color3.new(1, 1, 1)
    SlotDestroyBtn.Font = Enum.Font.GothamBlack
    SlotDestroyBtn.TextSize = 10
    local UICornerSlotDestroy = Instance.new("UICorner")
    UICornerSlotDestroy.CornerRadius = UDim.new(0, 4)
    UICornerSlotDestroy.Parent = SlotDestroyBtn

    local SlotContent = Instance.new("Frame")
    SlotContent.Parent = SlotWrapper
    SlotContent.Size = UDim2.new(1, -6, 1, -60)
    SlotContent.Position = UDim2.new(0, 3, 0, 58)
    SlotContent.BackgroundTransparency = 1

    local DexPathBox = Instance.new("TextBox")
    DexPathBox.Parent = SlotContent
    DexPathBox.Size = UDim2.new(0.60, 0, 0, 22)
    DexPathBox.Position = UDim2.new(0, 0, 0, 26)
    DexPathBox.BackgroundColor3 = INPUT_BG
    DexPathBox.PlaceholderText = "Path Objek: Workspace.Benda"
    DexPathBox.Text = ""
    DexPathBox.TextColor3 = TEXT_DARK
    DexPathBox.Font = Enum.Font.Gotham
    DexPathBox.TextSize = 9
    DexPathBox.ClearTextOnFocus = false
    DexPathBox.PlaceholderColor3 = PLACEHOLDER
    local UICornerDex = Instance.new("UICorner")
    UICornerDex.CornerRadius = UDim.new(0, 4)
    UICornerDex.Parent = DexPathBox

    -- Khusus Collect: Mode TP/TW
    local ModeBtn = Instance.new("TextButton")
    ModeBtn.Parent = SlotContent
    ModeBtn.Size = UDim2.new(0.38, 0, 0, 22)
    ModeBtn.Position = UDim2.new(0.62, 0, 0, 26)
    ModeBtn.BackgroundColor3 = BTN_ORANGE
    ModeBtn.Text = "MODE: TELEPORT"
    ModeBtn.TextColor3 = Color3.new(1, 1, 1)
    ModeBtn.Font = Enum.Font.GothamBold
    ModeBtn.TextSize = 8
    local UICornerMode = Instance.new("UICorner")
    UICornerMode.CornerRadius = UDim.new(0, 4)
    UICornerMode.Parent = ModeBtn

    -- Khusus Collect: D / <Y
    local DLabel = Instance.new("TextLabel")
    DLabel.Parent = SlotContent
    DLabel.Size = UDim2.new(0.05, 0, 0, 18)
    DLabel.Position = UDim2.new(0, 0, 0, 168)
    DLabel.BackgroundTransparency = 1
    DLabel.Text = "D:"
    DLabel.TextColor3 = TEXT_DARK
    DLabel.Font = Enum.Font.GothamBold
    DLabel.TextSize = 9

    local DelayBox = Instance.new("TextBox")
    DelayBox.Parent = SlotContent
    DelayBox.Size = UDim2.new(0.10, 0, 0, 18)
    DelayBox.Position = UDim2.new(0.06, 0, 0, 168)
    DelayBox.BackgroundColor3 = INPUT_BG
    DelayBox.Text = "0.5"
    DelayBox.TextColor3 = TEXT_DARK
    DelayBox.Font = Enum.Font.Gotham
    DelayBox.TextSize = 8
    DelayBox.ClearTextOnFocus = false
    DelayBox.PlaceholderColor3 = PLACEHOLDER
    local UICornerDelay = Instance.new("UICorner")
    UICornerDelay.CornerRadius = UDim.new(0, 3)
    UICornerDelay.Parent = DelayBox

    local YLabel = Instance.new("TextLabel")
    YLabel.Parent = SlotContent
    YLabel.Size = UDim2.new(0.07, 0, 0, 18)
    YLabel.Position = UDim2.new(0.18, 0, 0, 168)
    YLabel.BackgroundTransparency = 1
    YLabel.Text = "<Y:"
    YLabel.TextColor3 = TEXT_DARK
    YLabel.Font = Enum.Font.GothamBold
    YLabel.TextSize = 9

    local YLimitBox = Instance.new("TextBox")
    YLimitBox.Parent = SlotContent
    YLimitBox.Size = UDim2.new(0.14, 0, 0, 18)
    YLimitBox.Position = UDim2.new(0.26, 0, 0, 168)
    YLimitBox.BackgroundColor3 = INPUT_BG
    YLimitBox.Text = ""
    YLimitBox.PlaceholderText = "Batas Y"
    YLimitBox.TextColor3 = TEXT_DARK
    YLimitBox.Font = Enum.Font.Gotham
    YLimitBox.TextSize = 8
    YLimitBox.ClearTextOnFocus = false
    YLimitBox.PlaceholderColor3 = PLACEHOLDER
    local UICornerYLim = Instance.new("UICorner")
    UICornerYLim.CornerRadius = UDim.new(0, 3)
    UICornerYLim.Parent = YLimitBox

    local ResetBtn = Instance.new("TextButton")
    ResetBtn.Parent = SlotContent
    ResetBtn.Size = UDim2.new(0.16, 0, 0, 18)
    ResetBtn.Position = UDim2.new(0.42, 0, 0, 168)
    ResetBtn.BackgroundColor3 = BTN_GRAY
    ResetBtn.Text = "RESET"
    ResetBtn.TextColor3 = Color3.new(1, 1, 1)
    ResetBtn.Font = Enum.Font.GothamBold
    ResetBtn.TextSize = 7
    local UICornerReset = Instance.new("UICorner")
    UICornerReset.CornerRadius = UDim.new(0, 3)
    UICornerReset.Parent = ResetBtn

    local StartStopBtn = Instance.new("TextButton")
    StartStopBtn.Parent = SlotContent
    StartStopBtn.Size = UDim2.new(0.38, 0, 0, 18)
    StartStopBtn.Position = UDim2.new(0.60, 0, 0, 168)
    StartStopBtn.BackgroundColor3 = BTN_GREEN
    StartStopBtn.Text = "▶ MULAI"
    StartStopBtn.TextColor3 = Color3.new(1, 1, 1)
    StartStopBtn.Font = Enum.Font.GothamBold
    StartStopBtn.TextSize = 7
    local UICornerSS2 = Instance.new("UICorner")
    UICornerSS2.CornerRadius = UDim.new(0, 3)
    UICornerSS2.Parent = StartStopBtn

    local ScanPosBtn = Instance.new("TextButton")
    ScanPosBtn.Parent = SlotContent
    ScanPosBtn.Size = UDim2.new(1, 0, 0, 22)
    ScanPosBtn.Position = UDim2.new(0, 0, 0, 0)
    ScanPosBtn.BackgroundColor3 = BTN_TEAL
    ScanPosBtn.Text = "📡 PINDAI LOKASI (Cetak X Y Z ke Konsol)"
    ScanPosBtn.TextColor3 = Color3.new(1, 1, 1)
    ScanPosBtn.Font = Enum.Font.GothamBold
    ScanPosBtn.TextSize = 8
    local UICornerScan = Instance.new("UICorner")
    UICornerScan.CornerRadius = UDim.new(0, 4)
    UICornerScan.Parent = ScanPosBtn

    -- Khusus Follow: arah karakter terhadap objek + Distance
    local DirLabel = Instance.new("TextLabel")
    DirLabel.Parent = SlotContent
    DirLabel.Size = UDim2.new(1, 0, 0, 14)
    DirLabel.Position = UDim2.new(0, 0, 0, 52)
    DirLabel.BackgroundTransparency = 1
    DirLabel.Text = "Arah Karakter kepada Objek:"
    DirLabel.TextColor3 = TEXT_DARK
    DirLabel.Font = Enum.Font.GothamBold
    DirLabel.TextSize = 9
    DirLabel.TextXAlignment = Enum.TextXAlignment.Left

    local DistLabel = Instance.new("TextLabel")
    DistLabel.Parent = SlotContent
    DistLabel.Size = UDim2.new(0.2, 0, 0, 20)
    DistLabel.Position = UDim2.new(0, 0, 0, 142)
    DistLabel.BackgroundTransparency = 1
    DistLabel.Text = "Distance:"
    DistLabel.TextColor3 = TEXT_DARK
    DistLabel.Font = Enum.Font.GothamBold
    DistLabel.TextSize = 9
    DistLabel.TextXAlignment = Enum.TextXAlignment.Left

    local DistBox = Instance.new("TextBox")
    DistBox.Parent = SlotContent
    DistBox.Size = UDim2.new(0.22, 0, 0, 20)
    DistBox.Position = UDim2.new(0.21, 0, 0, 142)
    DistBox.BackgroundColor3 = INPUT_BG
    DistBox.Text = "5"
    DistBox.PlaceholderText = "5"
    DistBox.TextColor3 = TEXT_DARK
    DistBox.Font = Enum.Font.Gotham
    DistBox.TextSize = 9
    DistBox.ClearTextOnFocus = false
    DistBox.PlaceholderColor3 = PLACEHOLDER
    local UICornerDist = Instance.new("UICorner")
    UICornerDist.CornerRadius = UDim.new(0, 4)
    UICornerDist.Parent = DistBox

    local DistUnit = Instance.new("TextLabel")
    DistUnit.Parent = SlotContent
    DistUnit.Size = UDim2.new(0.12, 0, 0, 20)
    DistUnit.Position = UDim2.new(0.45, 0, 0, 142)
    DistUnit.BackgroundTransparency = 1
    DistUnit.Text = "stud"
    DistUnit.TextColor3 = TEXT_DARK
    DistUnit.Font = Enum.Font.GothamBold
    DistUnit.TextSize = 9
    DistUnit.TextXAlignment = Enum.TextXAlignment.Left

    local slotData = {
        id = slotId,
        kind = "collect",            -- "collect" | "follow"
        wrapper = SlotWrapper,
        content = SlotContent,
        nameBox = SlotNameBox,
        dexPath = DexPathBox,
        delayBox = DelayBox,
        yLimitBox = YLimitBox,
        distBox = DistBox,
        modeBtn = ModeBtn,
        resetBtn = ResetBtn,
        startStopBtn = StartStopBtn,
        scanBtn = ScanPosBtn,
        starBtn = StarBtn,
        minBtn = SlotMinBtn,
        lockBtn = SlotLockBtn,
        destroyBtn = SlotDestroyBtn,
        minimized = false,
        locked = false,
        active = false,
        priority = false,
        startOrder = 0,
        mode = "teleport",
        dir = {vert = "up", side = nil, depth = nil},
        dirToggles = {},
    }
    table.insert(collectSlots, slotData)

    -- ===== ESP Objek slot ini (memakai Path Objek slot; dipakai kedua mode) =====
    local EspLabel = Instance.new("TextLabel")
    EspLabel.Parent = SlotContent
    EspLabel.Size = UDim2.new(1, 0, 0, 14)
    EspLabel.Position = UDim2.new(0, 0, 0, 52)
    EspLabel.BackgroundTransparency = 1
    EspLabel.Text = "ESP Objek"
    EspLabel.TextColor3 = TEXT_DARK
    EspLabel.Font = Enum.Font.GothamBold
    EspLabel.TextSize = 9
    EspLabel.TextXAlignment = Enum.TextXAlignment.Left

    slotData.useSlotName = false
    slotData.espEntry = ESP.NewEntry(function() return DexPathBox.Text end, function()
        if slotData.useSlotName then return SlotNameBox.Text end   -- nama ESP = nama slot
        return nil
    end)
    slotData.espToggles = {}
    slotData.nameToggle = ESP.MakeToggle(SlotWrapper, "Nama Objek sesuai Nama Slot", UDim2.new(1, -6, 0, 20), UDim2.new(0, 3, 0, 34), function(on)
        if slotData.locked then return false end
        slotData.useSlotName = on
    end)
    local function EspToggle(key, text, x, y)
        slotData.espToggles[key] = ESP.MakeToggle(SlotContent, text, UDim2.new(0.49, 0, 0, 20), UDim2.new(x, 0, 0, y), function(on)
            if slotData.locked then return false end
            ESP.Set(slotData.espEntry, key, on)
        end)
    end
    EspToggle("tracer", "Tracer", 0, 68)
    EspToggle("highlight", "Highlight", 0.51, 68)
    EspToggle("name", "Nama ESP", 0, 92)
    EspToggle("box", "Box ESP", 0.51, 92)
    slotData.espPicker = ESP.MakeColorPicker(SlotContent, UDim2.new(0, 0, 0, 116), slotData.espEntry, function()
        return not slotData.locked
    end)
    slotData.espToggles.rainbow = ESP.MakeToggle(SlotContent, "Rainbow Mode", UDim2.new(0.49, 0, 0, 20), UDim2.new(0, 0, 0, 142), function(on)
        if slotData.locked then return false end
        ESP.SetRainbow(slotData.espEntry, on)
        slotData.espPicker.dim(on)
    end)

    -- ===== Arah Follow: tiap pasangan saling meniadakan (boleh digabung antar pasangan, mis. Atas + Belakang) =====
    local function DirToggle(key, text, field, value, mate, x, y)
        slotData.dirToggles[key] = ESP.MakeToggle(SlotContent, text, UDim2.new(0.49, 0, 0, 20), UDim2.new(x, 0, 0, y), function(on)
            if slotData.locked then return false end
            slotData.dir[field] = on and value or nil
            if on and slotData.dirToggles[mate] then
                slotData.dirToggles[mate].set(false)
            end
        end)
    end
    DirToggle("up", "Atas", "vert", "up", "down", 0, 68)
    DirToggle("down", "Bawah", "vert", "down", "up", 0.51, 68)
    DirToggle("left", "Kiri", "side", "left", "right", 0, 92)
    DirToggle("right", "Kanan", "side", "right", "left", 0.51, 92)
    DirToggle("front", "Depan", "depth", "front", "back", 0, 116)
    DirToggle("back", "Belakang", "depth", "back", "front", 0.51, 116)
    slotData.dirToggles.up.set(true)   -- bawaan: di atas objek

    local function ResetDirections()
        slotData.dir.vert, slotData.dir.side, slotData.dir.depth = "up", nil, nil
        for key, tg in pairs(slotData.dirToggles) do
            tg.set(key == "up")
        end
    end

    local function UpdateStar()
        if slotData.priority then
            StarBtn.Text = "★"
            StarBtn.BackgroundColor3 = STAR_ON
        else
            StarBtn.Text = "☆"
            StarBtn.BackgroundColor3 = UNLOCK_COLOR
        end
    end

    local function UpdateModeBtn()
        if slotData.kind == "follow" then
            ModeSwitchBtn.Text = "Follow"
            ModeSwitchBtn.BackgroundColor3 = BTN_BLUE
        else
            ModeSwitchBtn.Text = "Collect"
            ModeSwitchBtn.BackgroundColor3 = BTN_ORANGE
        end
    end

    -- Susun ulang isi slot sesuai mode
    --   Collect : Pindai | Path + TP/TW | ESP | Warna | Rainbow | D, <Y, Reset, Mulai
    --   Follow  : Pindai | Path | Arah (3 baris) | Distance | ESP | Warna | Rainbow | Reset, Mulai
    local function ApplyLayout()
        local f = (slotData.kind == "follow")
        ModeBtn.Visible = not f
        DLabel.Visible = not f
        DelayBox.Visible = not f
        YLabel.Visible = not f
        YLimitBox.Visible = not f
        DirLabel.Visible = f
        for _, tg in pairs(slotData.dirToggles) do tg.btn.Visible = f end
        DistLabel.Visible = f
        DistBox.Visible = f
        DistUnit.Visible = f

        DexPathBox.Size = f and UDim2.new(1, 0, 0, 22) or UDim2.new(0.60, 0, 0, 22)

        local y = f and 168 or 52          -- blok ESP turun di mode Follow
        EspLabel.Position = UDim2.new(0, 0, 0, y)
        slotData.espToggles.tracer.btn.Position = UDim2.new(0, 0, 0, y + 16)
        slotData.espToggles.highlight.btn.Position = UDim2.new(0.51, 0, 0, y + 16)
        slotData.espToggles.name.btn.Position = UDim2.new(0, 0, 0, y + 40)
        slotData.espToggles.box.btn.Position = UDim2.new(0.51, 0, 0, y + 40)
        slotData.espPicker.row.Position = UDim2.new(0, 0, 0, y + 64)
        slotData.espToggles.rainbow.btn.Position = UDim2.new(0, 0, 0, y + 90)

        local by = y + 116
        DLabel.Position = UDim2.new(0, 0, 0, by)
        DelayBox.Position = UDim2.new(0.06, 0, 0, by)
        YLabel.Position = UDim2.new(0.18, 0, 0, by)
        YLimitBox.Position = UDim2.new(0.26, 0, 0, by)
        if f then
            ResetBtn.Size = UDim2.new(0.30, 0, 0, 18)
            ResetBtn.Position = UDim2.new(0, 0, 0, by)
            StartStopBtn.Size = UDim2.new(0.68, 0, 0, 18)
            StartStopBtn.Position = UDim2.new(0.32, 0, 0, by)
        else
            ResetBtn.Size = UDim2.new(0.16, 0, 0, 18)
            ResetBtn.Position = UDim2.new(0.42, 0, 0, by)
            StartStopBtn.Size = UDim2.new(0.38, 0, 0, 18)
            StartStopBtn.Position = UDim2.new(0.60, 0, 0, by)
        end

        UpdateModeBtn()
        if not slotData.minimized then
            SlotWrapper.Size = UDim2.new(1, -12, 0, f and H_FOLLOW or H_COLLECT)
        end
    end

    -- Kembalikan semua isian ke bawaan (dipakai RESET dan pergantian mode)
    local function ResetFields()
        StopSlot(slotData)
        DexPathBox.Text = ""
        DelayBox.Text = "0.5"
        YLimitBox.Text = ""
        DistBox.Text = "5"
        slotData.mode = "teleport"
        ModeBtn.Text = "MODE: TELEPORT"
        ResetDirections()
        slotData.priority = false
        UpdateStar()
        for _, tg in pairs(slotData.espToggles) do tg.set(false) end
        slotData.useSlotName = false
        slotData.nameToggle.set(false)
        ESP.SetAll(slotData.espEntry, false)
        ESP.SetRainbow(slotData.espEntry, false)
        ESP.SetColor(slotData.espEntry, ESP.COLORS[1])
        slotData.espPicker.select(ESP.COLORS[1])
        slotData.espPicker.dim(false)
    end

    -- Nama bawaan ikut mode (nama yang sudah kamu ubah sendiri tidak ditimpa)
    local function RenameForKind()
        local cur = SlotNameBox.Text
        if cur:match("^Collect Slot #%d+$") or cur:match("^Follow Slot #%d+$") then
            SlotNameBox.Text = ((slotData.kind == "follow") and "Follow" or "Collect") .. " Slot #" .. slotId
        end
    end

    local switchThread = nil
    local function DoSwitch()
        ResetFields()
        slotData.kind = (slotData.kind == "collect") and "follow" or "collect"
        RenameForKind()
        ApplyLayout()
    end

    -- Ada isian di textbox -> minta konfirmasi "Sure? [5]"; tekan lagi dalam 5 detik untuk lanjut
    ModeSwitchBtn.MouseButton1Click:Connect(function()
        if slotData.locked then return end
        if switchThread then
            pcall(task.cancel, switchThread)
            switchThread = nil
            DoSwitch()
            return
        end
        if DexPathBox.Text == "" and YLimitBox.Text == "" then
            DoSwitch()
            return
        end
        ModeSwitchBtn.BackgroundColor3 = BTN_RED
        switchThread = task.spawn(function()
            for sisa = 5, 1, -1 do
                ModeSwitchBtn.Text = "Sure? [" .. sisa .. "]"
                task.wait(1)
            end
            switchThread = nil
            UpdateModeBtn()
        end)
    end)

    StarBtn.MouseButton1Click:Connect(function()
        if slotData.locked then return end
        slotData.priority = not slotData.priority
        UpdateStar()
    end)

    ModeBtn.MouseButton1Click:Connect(function()
        if slotData.locked then return end
        if slotData.mode == "teleport" then
            slotData.mode = "tween"
            ModeBtn.Text = "MODE: TWEEN+NOCLIP"
        else
            slotData.mode = "teleport"
            ModeBtn.Text = "MODE: TELEPORT"
        end
    end)

    ScanPosBtn.MouseButton1Click:Connect(function()
        local root = GetHumanoidRootPart()
        if not root then
            ScanPosBtn.Text = "⚠ Karakter tidak ditemukan (tap untuk coba lagi)"
            ScanPosBtn.BackgroundColor3 = BTN_RED
            return
        end
        local pos = root.Position
        local coordText = string.format("X: %.2f  |  Y: %.2f  |  Z: %.2f", pos.X, pos.Y, pos.Z)
        ScanPosBtn.Text = "📍 " .. coordText
        ScanPosBtn.BackgroundColor3 = BTN_GREEN
        print("[Pindai Lokasi Slot " .. slotId .. "] " .. coordText)
        pcall(function()
            if setclipboard then setclipboard(coordText) end
        end)
    end)

    ResetBtn.MouseButton1Click:Connect(function()
        if slotData.locked then return end
        ResetFields()
    end)

    StartStopBtn.MouseButton1Click:Connect(function()
        if slotData.active then
            StopSlot(slotData)
        else
            StartSlot(slotData)
        end
    end)

    SlotLockBtn.MouseButton1Click:Connect(function()
        slotData.locked = not slotData.locked
        local editable = not slotData.locked
        if slotData.locked then
            SlotLockBtn.Text = "🔒"
            SlotLockBtn.BackgroundColor3 = LOCK_COLOR
        else
            SlotLockBtn.Text = "🔓"
            SlotLockBtn.BackgroundColor3 = UNLOCK_COLOR
        end
        SlotNameBox.TextEditable = editable
        DexPathBox.TextEditable = editable
        DelayBox.TextEditable = editable
        YLimitBox.TextEditable = editable
        DistBox.TextEditable = editable
    end)

    SlotMinBtn.MouseButton1Click:Connect(function()
        slotData.minimized = not slotData.minimized
        if slotData.minimized then
            SlotMinBtn.Text = "+"
            SlotContent.Visible = false
            slotData.nameToggle.btn.Visible = false
            SlotWrapper.Size = UDim2.new(1, -12, 0, 36)
        else
            SlotMinBtn.Text = "−"
            SlotContent.Visible = true
            slotData.nameToggle.btn.Visible = true
            SlotWrapper.Size = UDim2.new(1, -12, 0, (slotData.kind == "follow") and H_FOLLOW or H_COLLECT)
        end
    end)

    SlotDestroyBtn.MouseButton1Click:Connect(function()
        if switchThread then
            pcall(task.cancel, switchThread)
            switchThread = nil
        end
        StopSlot(slotData)
        for i, v in ipairs(collectSlots) do
            if v.id == slotData.id then
                table.remove(collectSlots, i)
                break
            end
        end
        ESP.Remove(slotData.espEntry)
        SlotWrapper:Destroy()
    end)

    ApplyLayout()
    return slotData
end

AddCollectSlotBtn.MouseButton1Click:Connect(CreateCollectSlot)
CreateCollectSlot()

-- ========== FUNGSI REMOTE SLOT (ISI SLOT TIDAK DIUBAH) ==========
local function CreateRemoteSlot()
    slotCount += 1
    local rid = slotCount

    local RWrapper = Instance.new("Frame")
    RWrapper.Parent = RemoteScrollFrame
    RWrapper.Size = UDim2.new(1, -12, 0, 90)
    RWrapper.BackgroundColor3 = HEADER_BG
    RWrapper.LayoutOrder = rid
    local UICornerRW = Instance.new("UICorner")
    UICornerRW.CornerRadius = UDim.new(0, 7)
    UICornerRW.Parent = RWrapper

    local RHeader = Instance.new("Frame")
    RHeader.Parent = RWrapper
    RHeader.Size = UDim2.new(1, -6, 0, 28)
    RHeader.Position = UDim2.new(0, 3, 0, 3)
    RHeader.BackgroundColor3 = SLOT_HEADER
    local UICornerRH = Instance.new("UICorner")
    UICornerRH.CornerRadius = UDim.new(0, 5)
    UICornerRH.Parent = RHeader

    local RName = Instance.new("TextBox")
    RName.Parent = RHeader
    RName.Size = UDim2.new(1, -86, 1, -4)
    RName.Position = UDim2.new(0, 4, 0, 2)
    RName.BackgroundColor3 = INPUT_BG
    RName.Text = "Remote Slot #" .. rid
    RName.TextColor3 = TEXT_DARK
    RName.Font = Enum.Font.GothamBold
    RName.TextSize = 10
    RName.ClearTextOnFocus = false
    RName.PlaceholderColor3 = PLACEHOLDER
    local UICornerRN = Instance.new("UICorner")
    UICornerRN.CornerRadius = UDim.new(0, 4)
    UICornerRN.Parent = RName

    local RMin = Instance.new("TextButton")
    RMin.Parent = RHeader
    RMin.Size = UDim2.new(0, 22, 0, 22)
    RMin.Position = UDim2.new(1, -78, 0.5, -11)
    RMin.BackgroundColor3 = Color3.fromRGB(230, 150, 40)
    RMin.Text = "−"
    RMin.TextColor3 = Color3.new(1, 1, 1)
    RMin.Font = Enum.Font.GothamBlack
    RMin.TextSize = 12
    local UICornerRMin = Instance.new("UICorner")
    UICornerRMin.CornerRadius = UDim.new(0, 4)
    UICornerRMin.Parent = RMin

    local RLock = Instance.new("TextButton")
    RLock.Parent = RHeader
    RLock.Size = UDim2.new(0, 22, 0, 22)
    RLock.Position = UDim2.new(1, -52, 0.5, -11)
    RLock.BackgroundColor3 = UNLOCK_COLOR
    RLock.Text = "🔓"
    RLock.TextColor3 = Color3.new(1, 1, 1)
    RLock.Font = Enum.Font.GothamBold
    RLock.TextSize = 10
    local UICornerRLock = Instance.new("UICorner")
    UICornerRLock.CornerRadius = UDim.new(0, 4)
    UICornerRLock.Parent = RLock

    local RDestroy = Instance.new("TextButton")
    RDestroy.Parent = RHeader
    RDestroy.Size = UDim2.new(0, 22, 0, 22)
    RDestroy.Position = UDim2.new(1, -26, 0.5, -11)
    RDestroy.BackgroundColor3 = Color3.fromRGB(214, 70, 70)
    RDestroy.Text = "X"
    RDestroy.TextColor3 = Color3.new(1, 1, 1)
    RDestroy.Font = Enum.Font.GothamBlack
    RDestroy.TextSize = 10
    local UICornerRDest = Instance.new("UICorner")
    UICornerRDest.CornerRadius = UDim.new(0, 4)
    UICornerRDest.Parent = RDestroy

    local RContent = Instance.new("Frame")
    RContent.Parent = RWrapper
    RContent.Size = UDim2.new(1, -6, 1, -34)
    RContent.Position = UDim2.new(0, 3, 0, 32)
    RContent.BackgroundTransparency = 1

    local RemoteCodeBox = Instance.new("TextBox")
    RemoteCodeBox.Parent = RContent
    RemoteCodeBox.Size = UDim2.new(1, -4, 0, 22)
    RemoteCodeBox.Position = UDim2.new(0, 2, 0, 0)
    RemoteCodeBox.BackgroundColor3 = INPUT_BG
    RemoteCodeBox.PlaceholderText = "Tempel kode remote di sini (dari Simple Spy / Cobalt)"
    RemoteCodeBox.PlaceholderColor3 = PLACEHOLDER
    RemoteCodeBox.Text = ""
    RemoteCodeBox.TextColor3 = TEXT_DARK
    RemoteCodeBox.Font = Enum.Font.Gotham
    RemoteCodeBox.TextSize = 9
    RemoteCodeBox.TextXAlignment = Enum.TextXAlignment.Left
    RemoteCodeBox.TextYAlignment = Enum.TextYAlignment.Top
    RemoteCodeBox.MultiLine = true
    RemoteCodeBox.ClipsDescendants = true
    RemoteCodeBox.ClearTextOnFocus = false
    local UICornerRCode = Instance.new("UICorner")
    UICornerRCode.CornerRadius = UDim.new(0, 4)
    UICornerRCode.Parent = RemoteCodeBox

    local RDelayLbl = Instance.new("TextLabel")
    RDelayLbl.Parent = RContent
    RDelayLbl.Size = UDim2.new(0.05, 0, 0, 18)
    RDelayLbl.Position = UDim2.new(0, 0, 0, 28)
    RDelayLbl.BackgroundTransparency = 1
    RDelayLbl.Text = "D:"
    RDelayLbl.TextColor3 = TEXT_DARK
    RDelayLbl.Font = Enum.Font.GothamBold
    RDelayLbl.TextSize = 9

    local RDelayBox = Instance.new("TextBox")
    RDelayBox.Parent = RContent
    RDelayBox.Size = UDim2.new(0.10, 0, 0, 18)
    RDelayBox.Position = UDim2.new(0.06, 0, 0, 28)
    RDelayBox.BackgroundColor3 = INPUT_BG
    RDelayBox.Text = "0.5"
    RDelayBox.TextColor3 = TEXT_DARK
    RDelayBox.Font = Enum.Font.Gotham
    RDelayBox.TextSize = 8
    RDelayBox.ClearTextOnFocus = false
    RDelayBox.PlaceholderColor3 = PLACEHOLDER
    local UICornerRD = Instance.new("UICorner")
    UICornerRD.CornerRadius = UDim.new(0, 3)
    UICornerRD.Parent = RDelayBox

    local RStartBtn = Instance.new("TextButton")
    RStartBtn.Parent = RContent
    RStartBtn.Size = UDim2.new(0.22, 0, 0, 18)
    RStartBtn.Position = UDim2.new(0.18, 0, 0, 28)
    RStartBtn.BackgroundColor3 = BTN_GREEN
    RStartBtn.Text = "MULAI"
    RStartBtn.TextColor3 = Color3.new(1, 1, 1)
    RStartBtn.Font = Enum.Font.GothamBold
    RStartBtn.TextSize = 8
    local UICornerRSt = Instance.new("UICorner")
    UICornerRSt.CornerRadius = UDim.new(0, 3)
    UICornerRSt.Parent = RStartBtn

    local RStopBtn = Instance.new("TextButton")
    RStopBtn.Parent = RContent
    RStopBtn.Size = UDim2.new(0.22, 0, 0, 18)
    RStopBtn.Position = UDim2.new(0.42, 0, 0, 28)
    RStopBtn.BackgroundColor3 = BTN_RED
    RStopBtn.Text = "BERHENTI"
    RStopBtn.TextColor3 = Color3.new(1, 1, 1)
    RStopBtn.Font = Enum.Font.GothamBold
    RStopBtn.TextSize = 8
    local UICornerRSto = Instance.new("UICorner")
    UICornerRSto.CornerRadius = UDim.new(0, 3)
    UICornerRSto.Parent = RStopBtn

    local RResetBtn = Instance.new("TextButton")
    RResetBtn.Parent = RContent
    RResetBtn.Size = UDim2.new(0.16, 0, 0, 18)
    RResetBtn.Position = UDim2.new(0.66, 0, 0, 28)
    RResetBtn.BackgroundColor3 = BTN_GRAY
    RResetBtn.Text = "RESET"
    RResetBtn.TextColor3 = Color3.new(1, 1, 1)
    RResetBtn.Font = Enum.Font.GothamBold
    RResetBtn.TextSize = 8
    local UICornerRReset = Instance.new("UICorner")
    UICornerRReset.CornerRadius = UDim.new(0, 3)
    UICornerRReset.Parent = RResetBtn

    local rData = {
        id = rid,
        wrapper = RWrapper,
        content = RContent,
        nameBox = RName,
        remoteCode = RemoteCodeBox,
        delayBox = RDelayBox,
        minBtn = RMin,
        lockBtn = RLock,
        destroyBtn = RDestroy,
        startBtn = RStartBtn,
        stopBtn = RStopBtn,
        minimized = false,
        locked = false,
        active = false,
        thread = nil
    }
    table.insert(slots, rData)

    -- Fungsi start/stop dipisah supaya "MULAI SEMUA" bisa memanggilnya langsung
    rData.start = function()
        if rData.locked or rData.active then return end
        local code = RemoteCodeBox.Text
        if code:match("^%s*$") then
            print("[Remote Slot " .. rid .. "] Tempel kode remote terlebih dahulu")
            return
        end
        local rawD = tonumber(RDelayBox.Text)
        if rawD == nil or rawD < 0 then rawD = 0.5 end
        local fn, compileErr = loadstring(code)
        if not fn then
            print("[Remote Slot " .. rid .. "] Kode tidak valid: " .. tostring(compileErr))
            return
        end
        rData.active = true
        rData.refresh()
        rData.thread = task.spawn(function()
            while rData.active and not hubDestroyed do
                local ok, runErr = pcall(fn)
                if not ok then
                    print("[Remote Slot " .. rid .. "] Error: " .. tostring(runErr))
                    break
                end
                task.wait(rawD)
            end
            rData.active = false
            rData.thread = nil
            if not hubDestroyed then rData.refresh() end
        end)
    end

    rData.stop = function()
        rData.active = false
        if rData.thread then
            pcall(task.cancel, rData.thread)
            rData.thread = nil
        end
        if not hubDestroyed then rData.refresh() end
    end

    -- Tampilan tombol mengikuti status
    rData.refresh = function()
        if rData.active then
            RStartBtn.Text = "● JALAN"
            RStartBtn.BackgroundColor3 = Color3.fromRGB(30, 110, 65)
        else
            RStartBtn.Text = "MULAI"
            RStartBtn.BackgroundColor3 = BTN_GREEN
        end
    end

    RLock.MouseButton1Click:Connect(function()
        rData.locked = not rData.locked
        if rData.locked then
            RLock.Text = "🔒"
            RLock.BackgroundColor3 = LOCK_COLOR
            RName.TextEditable = false
            RemoteCodeBox.TextEditable = false
            RDelayBox.TextEditable = false
        else
            RLock.Text = "🔓"
            RLock.BackgroundColor3 = UNLOCK_COLOR
            RName.TextEditable = true
            RemoteCodeBox.TextEditable = true
            RDelayBox.TextEditable = true
        end
    end)

    RMin.MouseButton1Click:Connect(function()
        rData.minimized = not rData.minimized
        if rData.minimized then
            RMin.Text = "+"
            RContent.Visible = false
            RWrapper.Size = UDim2.new(1, -12, 0, 36)
        else
            RMin.Text = "−"
            RContent.Visible = true
            RWrapper.Size = UDim2.new(1, -12, 0, 90)
        end
    end)

    RDestroy.MouseButton1Click:Connect(function()
        rData.stop()
        for i, v in ipairs(slots) do
            if v.id == rData.id then
                table.remove(slots, i)
                break
            end
        end
        RWrapper:Destroy()
    end)

    RStartBtn.MouseButton1Click:Connect(rData.start)
    RStopBtn.MouseButton1Click:Connect(rData.stop)

    -- RESET: hentikan slot lalu kosongkan kode dan kembalikan delay
    RResetBtn.MouseButton1Click:Connect(function()
        if rData.locked then return end
        rData.stop()
        RemoteCodeBox.Text = ""
        RDelayBox.Text = "0.5"
    end)

    return rData
end

AddRemoteSlotBtn.MouseButton1Click:Connect(CreateRemoteSlot)
CreateRemoteSlot()

-- ==================================================
-- ========== KONTEN TAB AUTO TELEPORT ==============
-- ==================================================
;(function()
    local function Corner(obj, r)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, r or 5)
        c.Parent = obj
    end

    local function MakeButton(parent, text, color, size, pos, textSize)
        local b = Instance.new("TextButton")
        b.Parent = parent
        b.Size = size
        b.Position = pos or UDim2.new(0, 0, 0, 0)
        b.BackgroundColor3 = color
        b.Text = text
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold
        b.TextSize = textSize or 9
        b.TextWrapped = true
        b.AutoLocalize = false
        b.AutoButtonColor = false
        Corner(b, 5)
        return b
    end

    local function MakeBox(parent, placeholder, text, size, pos)
        local t = Instance.new("TextBox")
        t.Parent = parent
        t.Size = size
        t.Position = pos or UDim2.new(0, 0, 0, 0)
        t.BackgroundColor3 = INPUT_BG
        t.PlaceholderText = placeholder
        t.PlaceholderColor3 = PLACEHOLDER
        t.Text = text or ""
        t.TextColor3 = TEXT_DARK
        t.Font = Enum.Font.Gotham
        t.TextSize = 10
        t.ClearTextOnFocus = false
        Corner(t, 4)
        return t
    end

    local function MakeLabel(parent, text, size, pos, textSize)
        local l = Instance.new("TextLabel")
        l.Parent = parent
        l.Size = size
        l.Position = pos or UDim2.new(0, 0, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = TEXT_DARK
        l.Font = Enum.Font.GothamBold
        l.TextSize = textSize or 10
        l.TextXAlignment = Enum.TextXAlignment.Left
        return l
    end

    local function Fmt(n)
        return string.format("%g", n)
    end

    -- Wadah tab
    TabTeleportContainer = Instance.new("Frame")
    TabTeleportContainer.Parent = TabContentWrapper
    TabTeleportContainer.Size = UDim2.new(1, 0, 1, 0)
    TabTeleportContainer.Visible = false
    TabTeleportContainer.BackgroundTransparency = 1

    local TeleScroll = Instance.new("ScrollingFrame")
    TeleScroll.Parent = TabTeleportContainer
    TeleScroll.Size = UDim2.new(1, 0, 1, 0)
    TeleScroll.BackgroundTransparency = 1
    TeleScroll.ScrollBarThickness = 6
    TeleScroll.ScrollBarImageColor3 = LINE
    TeleScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    TeleScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    local TeleList = Instance.new("UIListLayout")
    TeleList.Parent = TeleScroll
    TeleList.Padding = UDim.new(0, 6)
    TeleList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    TeleList.SortOrder = Enum.SortOrder.LayoutOrder

    -- Kartu bertinggi otomatis (anti tumpang-tindih)
    local function NewCard(order, title)
        local card = Instance.new("Frame")
        card.Parent = TeleScroll
        card.Size = UDim2.new(1, -12, 0, 0)
        card.AutomaticSize = Enum.AutomaticSize.Y
        card.BackgroundColor3 = HEADER_BG
        card.LayoutOrder = order
        Corner(card, 7)
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 5)
        pad.PaddingBottom = UDim.new(0, 6)
        pad.PaddingLeft = UDim.new(0, 5)
        pad.PaddingRight = UDim.new(0, 5)
        pad.Parent = card
        local list = Instance.new("UIListLayout")
        list.Padding = UDim.new(0, 5)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = card
        local lbl = MakeLabel(card, title, UDim2.new(1, 0, 0, 18), nil, 11)
        lbl.LayoutOrder = 0
        return card
    end

    local function NewRow(parent, order, height)
        local row = Instance.new("Frame")
        row.Parent = parent
        row.Size = UDim2.new(1, 0, 0, height)
        row.BackgroundTransparency = 1
        row.LayoutOrder = order
        return row
    end

    local RefreshGroups   -- diisi setelah kedua panel "Set All" dibuat

    -- ==================================================
    -- PANEL "SET ALL" (dipakai kartu Global & kartu Auto Farm)
    -- o.getTargets : daftar slot yang dipengaruhi
    -- Nilai berbeda antar-slot -> kolom dikosongkan (placeholder "beda"),
    -- kedua tombol Set All abu-abu, dan teks info menulis "Campur: ..."
    -- ==================================================
    local function Uniform(list, field)
        local first = list[1][field]
        for i = 2, #list do
            if list[i][field] ~= first then return nil end
        end
        return first
    end

    local function MakeGroup(card, o)
        local g = {}

        if o.orderDelay then
            local rowD = NewRow(card, o.orderDelay, 22)
            MakeLabel(rowD, "Delay semua:", UDim2.new(0.40, 0, 1, 0))
            g.delayBox = MakeBox(rowD, "beda", "", UDim2.new(0.30, 0, 1, 0), UDim2.new(0.42, 0, 0, 0))
        end

        local rowSet = NewRow(card, o.orderSet, 26)
        g.tpBtn = MakeButton(rowSet, "Set All Teleport", BTN_GRAY, UDim2.new(0.48, 0, 1, 0))
        g.walkBtn = MakeButton(rowSet, "Set All Jalan + Noclip", BTN_GRAY, UDim2.new(0.50, 0, 1, 0), UDim2.new(0.50, 0, 0, 0))

        local rowInfo = NewRow(card, o.orderInfo, 14)
        g.info = MakeLabel(rowInfo, "", UDim2.new(1, 0, 1, 0), nil, 9)
        g.info.Font = Enum.Font.Gotham

        g.speedRow = NewRow(card, o.orderSpeed, 22)
        MakeLabel(g.speedRow, "Kec:", UDim2.new(0.12, 0, 1, 0))
        g.speedBox = MakeBox(g.speedRow, "beda", "30", UDim2.new(0.28, 0, 1, 0), UDim2.new(0.13, 0, 0, 0))
        MakeLabel(g.speedRow, "Tinggi:", UDim2.new(0.16, 0, 1, 0), UDim2.new(0.46, 0, 0, 0))
        g.heightBox = MakeBox(g.speedRow, "beda", "12", UDim2.new(0.28, 0, 1, 0), UDim2.new(0.63, 0, 0, 0))
        g.speedRow.Visible = false

        g.refresh = function()
            local targets = o.getTargets()
            local n = #targets
            local walkT = {}
            for _, t in ipairs(targets) do
                if t.mode == "walk" then table.insert(walkT, t) end
            end
            local nWalk = #walkT
            local nTP = n - nWalk

            g.tpBtn.BackgroundColor3 = (n > 0 and nWalk == 0) and BTN_ORANGE or BTN_GRAY
            g.walkBtn.BackgroundColor3 = (n > 0 and nTP == 0) and BTN_BLUE or BTN_GRAY
            if n == 0 then
                g.info.Text = o.emptyText
            elseif nWalk == 0 then
                g.info.Text = "Semua slot: Teleport (" .. n .. ")"
            elseif nTP == 0 then
                g.info.Text = "Semua slot: Jalan + Noclip (" .. n .. ")"
            else
                g.info.Text = "Campur: " .. nTP .. " Teleport, " .. nWalk .. " Jalan + Noclip"
            end

            if g.delayBox and n > 0 then
                local d = Uniform(targets, "delay")
                g.delayBox.Text = d and Fmt(d) or ""
            end

            g.speedRow.Visible = nWalk > 0 or (o.forceSpeed ~= nil and o.forceSpeed())
            if nWalk > 0 then
                local sv = Uniform(walkT, "speed")
                local hv = Uniform(walkT, "height")
                g.speedBox.Text = sv and Fmt(sv) or ""
                g.heightBox.Text = hv and Fmt(hv) or ""
            end
        end

        local function SetAll(mode)
            local targets = o.getTargets()
            if #targets == 0 and o.flashEmpty then
                g.info.Text = o.flashEmpty
                task.delay(1.2, function() g.refresh() end)
                return
            end
            for _, t in ipairs(targets) do
                t.mode = mode
                t.sync()
            end
            if o.onSet then o.onSet(mode) end
            RefreshGroups()
        end
        g.tpBtn.MouseButton1Click:Connect(function() SetAll("tp") end)
        g.walkBtn.MouseButton1Click:Connect(function() SetAll("walk") end)

        local function ApplyBox(box, field, minv)
            box.FocusLost:Connect(function()
                local v = tonumber(box.Text)
                if v then
                    v = math.max(v, minv)
                    for _, t in ipairs(o.getTargets()) do
                        t[field] = v
                        t.sync()
                    end
                end
                RefreshGroups()
            end)
        end
        if g.delayBox then ApplyBox(g.delayBox, "delay", 0.5) end
        ApplyBox(g.speedBox, "speed", 1)
        ApplyBox(g.heightBox, "height", -math.huge)

        return g
    end

    -- ===== BOX MARK: tanda titik =====
    -- Memakai HandleAdornment + BillboardGui (bukan Part di workspace) -> tidak ada collision sama sekali,
    -- tidak menyentuh game, dan seluruhnya ada dalam satu Folder yang dihancurkan saat dimatikan / Shutdown.
    local MARK_COLOR = Color3.fromRGB(150, 80, 230)

    local function EnsureMarkFolder()
        if TP.markFolder and TP.markFolder.Parent then return end
        local f = Instance.new("Folder")
        f.Name = "Shrimp_Hub_Marks"
        f.Parent = LocalPlayer.PlayerGui
        TP.markFolder = f
    end

    local function MarkOrigin()
        local root = GetHumanoidRootPart()
        if root then return root.Position end
        local cam = workspace.CurrentCamera
        return cam and cam.CFrame.Position or nil
    end

    -- Jarak (di bawah nama): hanya menulis teks bila angkanya berubah
    local function UpdateMarkDistance(pt, origin)
        local m = pt.mark
        if not (m and m.dlbl and origin) then return end
        local d = math.floor((pt.markCF.Position - origin).Magnitude + 0.5)
        if d ~= m.lastDist then
            m.lastDist = d
            m.dlbl.Text = d .. "m"
        end
    end

    -- Nama titik + jarak di atas kotak (hanya jika Pos Name aktif)
    local function UpdateMarkName(pt)
        local m = pt.mark
        if not m then return end
        if TP.posName then
            if not m.bb then
                local base = workspace.Terrain
                local bb = Instance.new("BillboardGui")
                bb.Name = "PosName"
                bb.Adornee = base
                bb.AlwaysOnTop = TP.seeThrough
                bb.LightInfluence = 0
                bb.Size = UDim2.fromOffset(180, 34)
                bb.StudsOffsetWorldSpace = pt.markCF.Position + Vector3.new(0, pt.markSize.Y * 0.5 + 1.6, 0) - base.Position

                local lbl = Instance.new("TextLabel")
                lbl.Name = "Nama"
                lbl.Parent = bb
                lbl.Size = UDim2.new(1, 0, 0.56, 0)
                lbl.BackgroundTransparency = 1
                lbl.TextColor3 = Color3.new(1, 1, 1)
                lbl.TextStrokeColor3 = MARK_COLOR
                lbl.TextStrokeTransparency = 0.2
                lbl.Font = Enum.Font.GothamBold
                lbl.TextSize = 13

                local dlbl = Instance.new("TextLabel")   -- jarak, tepat di bawah nama
                dlbl.Name = "Jarak"
                dlbl.Parent = bb
                dlbl.Size = UDim2.new(1, 0, 0.44, 0)
                dlbl.Position = UDim2.new(0, 0, 0.56, 0)
                dlbl.BackgroundTransparency = 1
                dlbl.TextColor3 = Color3.fromRGB(225, 205, 255)
                dlbl.TextStrokeColor3 = MARK_COLOR
                dlbl.TextStrokeTransparency = 0.3
                dlbl.Font = Enum.Font.Gotham
                dlbl.TextSize = 11

                bb.Parent = m.root
                m.bb, m.lbl, m.dlbl, m.lastDist = bb, lbl, dlbl, nil
            end
            m.lbl.Text = pt.name
            UpdateMarkDistance(pt, MarkOrigin())
        elseif m.bb then
            m.bb:Destroy()
            m.bb, m.lbl, m.dlbl, m.lastDist = nil, nil, nil, nil
        end
    end

    local function BuildMark(pt)
        if pt.mark then return end
        EnsureMarkFolder()
        local base = workspace.Terrain
        local holder = Instance.new("Folder")
        holder.Name = "Mark_" .. pt.id
        holder.Parent = TP.markFolder

        local box = Instance.new("BoxHandleAdornment")      -- kotak transparan setinggi player
        box.Adornee = base
        box.Size = pt.markSize
        box.CFrame = base.CFrame:ToObjectSpace(pt.markCF)
        box.Color3 = MARK_COLOR
        box.Transparency = 0.65
        box.AlwaysOnTop = TP.seeThrough
        box.ZIndex = 1
        box.Parent = holder

        local ball = Instance.new("SphereHandleAdornment")  -- lingkaran di tengah kotak
        ball.Adornee = base
        ball.Radius = 0.6
        ball.CFrame = base.CFrame:ToObjectSpace(CFrame.new(pt.markCF.Position))
        ball.Color3 = MARK_COLOR
        ball.Transparency = 0.2
        ball.AlwaysOnTop = TP.seeThrough
        ball.ZIndex = 2
        ball.Parent = holder

        pt.mark = {root = holder, box = box, ball = ball, bb = nil, lbl = nil, dlbl = nil, lastDist = nil}
    end

    local function DestroyMark(pt)
        if pt.mark then
            pcall(function() pt.mark.root:Destroy() end)
            pt.mark = nil
        end
    end

    -- Tembus Tembok: ON = terlihat dari balik tembok/objek, OFF = tertutup tembok/objek
    local function ApplyOcclusion()
        for _, pt in ipairs(TP.points) do
            local m = pt.mark
            if m then
                m.box.AlwaysOnTop = TP.seeThrough
                m.ball.AlwaysOnTop = TP.seeThrough
                if m.bb then m.bb.AlwaysOnTop = TP.seeThrough end
            end
        end
    end

    -- Satu thread ringan (5x/detik) hanya untuk memperbarui jarak; berhenti otomatis bila tidak diperlukan
    local function StopMarkLoop()
        if TP.markThread then
            pcall(task.cancel, TP.markThread)
            TP.markThread = nil
        end
    end

    local function EnsureMarkLoop()
        if TP.markThread then return end
        TP.markThread = task.spawn(function()
            while TP.boxMark and TP.posName and not hubDestroyed do
                local origin = MarkOrigin()
                if origin then
                    for _, pt in ipairs(TP.points) do
                        UpdateMarkDistance(pt, origin)
                    end
                end
                task.wait(0.2)
            end
            TP.markThread = nil
        end)
    end

    local function SyncMarkLoop()
        if TP.boxMark and TP.posName and #TP.points > 0 then
            EnsureMarkLoop()
        else
            StopMarkLoop()
        end
    end

    local function RefreshMarks()
        for _, pt in ipairs(TP.points) do
            if TP.boxMark then
                BuildMark(pt)
                UpdateMarkName(pt)
            else
                DestroyMark(pt)
            end
        end
        if not TP.boxMark and TP.markFolder then     -- mati -> folder ikut dibuang
            TP.markFolder:Destroy()
            TP.markFolder = nil
        end
        SyncMarkLoop()
    end

    -- ===== Kartu 1: Posisi & Teleport =====
    local CardPos = NewCard(1, "📍 POSISI & TELEPORT")
    local RowCopy = NewRow(CardPos, 1, 24)
    local CopyPosBtn = MakeButton(RowCopy, "📋 SALIN POSISI SEKARANG", BTN_TEAL, UDim2.new(1, 0, 1, 0))
    local RowPos = NewRow(CardPos, 2, 24)
    local PosBox = MakeBox(RowPos, "X, Y, Z (pisah koma)", "", UDim2.new(0.62, 0, 1, 0))
    local GoPosBtn = MakeButton(RowPos, "TELEPORT", BTN_ORANGE, UDim2.new(0.36, 0, 1, 0), UDim2.new(0.64, 0, 0, 0))

    local function PosBtnText()
        GoPosBtn.Text = (TP.posMode == "walk") and "JALAN KE SINI" or "TELEPORT"
        GoPosBtn.BackgroundColor3 = (TP.posMode == "walk") and BTN_BLUE or BTN_ORANGE
    end

    -- ===== Kartu 2: Cara Perpindahan (GLOBAL: semua slot sekaligus) =====
    local CardMove = NewCard(2, "🚶 CARA PERPINDAHAN (GLOBAL)")
    local globalGroup = MakeGroup(CardMove, {
        orderSet = 1, orderInfo = 2, orderSpeed = 3,
        getTargets = function() return TP.points end,
        emptyText = "Belum ada slot tersimpan",
        forceSpeed = function() return TP.posMode == "walk" end,
        onSet = function(mode)            -- tombol "Teleport ke posisi input" mengikuti pilihan terakhir
            TP.posMode = mode
            PosBtnText()
        end,
    })
    local RowStop = NewRow(CardMove, 4, 24)
    local StopMoveBtn = MakeButton(RowStop, "⏹ BERHENTI", BTN_GRAY, UDim2.new(1, 0, 1, 0))

    -- ===== Kartu: Box Mark (di bawah Cara Perpindahan global) =====
    local CardMark = NewCard(3, "🟪 BOX MARK (TANDA TITIK)")
    local RowMark = NewRow(CardMark, 1, 22)
    local RowThrough = NewRow(CardMark, 2, 22)
    local posNameToggle
    ESP.MakeToggle(RowMark, "Box Mark", UDim2.new(0.49, 0, 1, 0), UDim2.new(0, 0, 0, 0), function(on)
        TP.boxMark = on
        posNameToggle.btn.Visible = on          -- Pos Name & Tembus Tembok hanya muncul saat Box Mark aktif
        RowThrough.Visible = on
        RefreshMarks()
    end)
    posNameToggle = ESP.MakeToggle(RowMark, "Pos Name", UDim2.new(0.49, 0, 1, 0), UDim2.new(0.51, 0, 0, 0), function(on)
        TP.posName = on
        RefreshMarks()
    end)
    posNameToggle.btn.Visible = false
    ESP.MakeToggle(RowThrough, "Tembus Tembok", UDim2.new(0.49, 0, 1, 0), UDim2.new(0, 0, 0, 0), function(on)
        TP.seeThrough = on
        ApplyOcclusion()
    end)
    RowThrough.Visible = false

    -- ===== Kartu 3: Titik Tersimpan (slot) =====
    local CardPoints = NewCard(4, "📋 TITIK TERSIMPAN")
    local RowAdd = NewRow(CardPoints, 1, 24)
    local AddPointBtn = MakeButton(RowAdd, "➕ SIMPAN POSISI SEKARANG", BTN_GREEN, UDim2.new(1, 0, 1, 0))
    local RowDel = NewRow(CardPoints, 9999, 24)
    local DelAllBtn = MakeButton(RowDel, "🗑 HAPUS SEMUA TITIK", BTN_RED, UDim2.new(1, 0, 1, 0))

    -- ===== Kartu 4: Auto Farm Berantai (hanya slot terpilih) =====
    local CardFarm = NewCard(5, "🔁 AUTO FARM BERANTAI")
    local RowPick = NewRow(CardFarm, 1, 24)
    local PickBtn = MakeButton(RowPick, "📝 PILIH URUTAN TITIK", BTN_BLUE, UDim2.new(1, 0, 1, 0))
    local farmGroup = MakeGroup(CardFarm, {
        orderDelay = 2, orderSet = 3, orderInfo = 4, orderSpeed = 5,
        getTargets = function() return TP.seq end,
        emptyText = "Belum ada slot dipilih",
        flashEmpty = "Pilih titik dulu (Pilih Urutan Titik)",
    })
    local RowFarm = NewRow(CardFarm, 6, 26)
    local FarmBtn = MakeButton(RowFarm, "▶ MULAI AUTO FARM", BTN_GREEN, UDim2.new(1, 0, 1, 0), nil, 10)

    RefreshGroups = function()
        globalGroup.refresh()
        farmGroup.refresh()
    end

    -- ===== Noclip: memakai pengelola bersama =====
    local function SetNoclip(on)
        if on then
            NoclipAcquire("teleport")
        else
            NoclipRelease("teleport")
        end
    end

    local function SetBusy(b)
        TP.busy = b
        StopMoveBtn.BackgroundColor3 = b and BTN_RED or BTN_GRAY
    end

    local function UpdateFarmBtn()
        if TP.farmActive then
            FarmBtn.Text = "⏹ HENTIKAN AUTO FARM"
            FarmBtn.BackgroundColor3 = BTN_RED
        else
            FarmBtn.Text = "▶ MULAI AUTO FARM"
            FarmBtn.BackgroundColor3 = BTN_GREEN
        end
    end

    -- Perpindahan (menunggu sampai selesai; false jika dibatalkan / karakter hilang)
    -- mode: "tp" = teleport langsung, "walk" = Jalan + Noclip
    local function MoveTo(targetCF, mode, speed, lift)
        local root = GetHumanoidRootPart()
        if not root then return false end
        SetBusy(true)

        if mode ~= "walk" then
            SetNoclip(false)
            root.CFrame = targetCF
            root.AssemblyLinearVelocity = Vector3.zero
            SetBusy(false)
            return true
        end

        speed = math.max(1, speed or 30)
        lift = lift or 12
        SetNoclip(true)

        local dist = (root.Position - targetCF.Position).Magnitude
        local dur = math.max(0.3, dist / speed)
        local midPos = root.Position:Lerp(targetCF.Position, 0.5) + Vector3.new(0, lift, 0)
        local midCF = CFrame.new(midPos) * targetCF.Rotation

        local function Leg(info, goal, duration)
            local tw = TweenService:Create(root, info, {CFrame = goal})
            TP.tween = tw
            local completed = PlayAndWait(tw, duration)
            if TP.tween == tw then TP.tween = nil end
            return completed
        end

        -- langkah kedua hanya jalan jika langkah pertama benar-benar selesai
        local ok = Leg(TweenInfo.new(dur * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), midCF, dur * 0.6)
            and Leg(TweenInfo.new(dur * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), targetCF, dur * 0.4)

        if ok and root.Parent then
            root.AssemblyLinearVelocity = Vector3.zero
        end
        SetNoclip(false)
        SetBusy(false)
        return ok and true or false
    end

    -- Kembali ke posisi saat Auto Farm dimulai, + 2 stud ke atas (sekali pakai)
    local function ReturnToFarmOrigin()
        local origin = TP.farmOrigin
        TP.farmOrigin = nil
        if origin and not hubDestroyed then
            local root = GetHumanoidRootPart()
            if root then
                root.CFrame = origin + Vector3.new(0, 2, 0)
                root.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end

    -- Hentikan semua perpindahan + Auto Farm. Jika Auto Farm sedang berjalan, karakter kembali ke posisi awalnya (+2 stud).
    -- noReturn = true dipakai saat perintah manual menggantikan Auto Farm (tidak perlu kembali dulu).
    StopTeleport = function(noReturn)
        local wasFarm = TP.farmActive
        if TP.tween then
            pcall(function() TP.tween:Cancel() end)
            TP.tween = nil
        end
        if TP.manualThread then
            pcall(task.cancel, TP.manualThread)
            TP.manualThread = nil
        end
        if TP.farmThread then
            if TP.farmThread ~= coroutine.running() then
                pcall(task.cancel, TP.farmThread)
            end
            TP.farmThread = nil
        end
        TP.farmActive = false
        UpdateFarmBtn()
        SetNoclip(false)
        SetBusy(false)
        if wasFarm and not noReturn then
            ReturnToFarmOrigin()
        elseif noReturn then
            TP.farmOrigin = nil
        end
    end

    local function RunManual(cf, mode, speed, lift)
        StopTeleport(true)   -- perintah manual menggantikan gerakan sebelumnya
        TP.manualThread = task.spawn(function()
            MoveTo(cf, mode, speed, lift)
            TP.manualThread = nil
        end)
    end

    -- Tanda urutan (+ / 1 / 2 / 3 ...) di tiap slot, lalu susun ulang baris & panel Set All
    local function RefreshSeq()
        for _, pt in ipairs(TP.points) do
            local idx = table.find(TP.seq, pt)
            pt.seqBtn.Visible = TP.pickMode or idx ~= nil
            if idx then
                pt.seqBtn.Text = tostring(idx)
                pt.seqBtn.BackgroundColor3 = ORANGE
            else
                pt.seqBtn.Text = "+"
                pt.seqBtn.BackgroundColor3 = BTN_ORANGE
            end
            pt.arrange()
        end
        RefreshGroups()
    end

    local function AddPoint(cf)
        TP.counter += 1
        local pt = {
            id = TP.counter, name = "Titik " .. TP.counter, cframe = cf,
            mode = "tp", delay = 3, speed = 30, height = 12,
        }
        table.insert(TP.points, pt)

        -- Data tanda: kotak setinggi karakter (pusat & tinggi diambil dari bounding box karakter saat disimpan)
        do
            local root = GetHumanoidRootPart()
            local char = LocalPlayer.Character
            local center, height = cf.Position, 5
            if root and char then
                local ok, bbCF, bbSize = pcall(function() return char:GetBoundingBox() end)
                if ok and bbCF then
                    center = (cf * root.CFrame:ToObjectSpace(bbCF)).Position
                    height = bbSize.Y
                end
            end
            local look = cf.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
            pt.markCF = CFrame.lookAt(center, center + flat.Unit)
            pt.markSize = Vector3.new(2, height, 1)
        end

        -- Baris slot: tinggi otomatis mengikuti isi (TP: 2 baris, Jalan + Noclip: 3 baris)
        local row = Instance.new("Frame")
        row.Name = "Point_" .. pt.id
        row.Parent = CardPoints
        row.Size = UDim2.new(1, 0, 0, 0)
        row.AutomaticSize = Enum.AutomaticSize.Y
        row.BackgroundColor3 = SLOT_HEADER
        row.LayoutOrder = 10 + pt.id
        Corner(row, 5)
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 3)
        pad.PaddingBottom = UDim.new(0, 4)
        pad.PaddingLeft = UDim.new(0, 3)
        pad.PaddingRight = UDim.new(0, 3)
        pad.Parent = row
        local list = Instance.new("UIListLayout")
        list.Padding = UDim.new(0, 3)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = row
        pt.row = row

        -- Baris 1: [Urutan] | TP / Jalan + Noclip | Nama Slot | GO | X
        local line1 = NewRow(row, 1, 26)
        local seqBtn = MakeButton(line1, "+", BTN_ORANGE, UDim2.new(0, 22, 0, 22), UDim2.new(0, 0, 0.5, -11), 11)
        seqBtn.Visible = false
        local modeBtn = MakeButton(line1, "TP", BTN_ORANGE, UDim2.new(0, 84, 0, 22), UDim2.new(0, 0, 0.5, -11), 8)
        local nameBox = MakeBox(line1, "Nama slot", pt.name, UDim2.new(1, -150, 0, 22), UDim2.new(0, 88, 0.5, -11))
        local goBtn = MakeButton(line1, "GO", BTN_TEAL, UDim2.new(0, 34, 0, 22), UDim2.new(1, -60, 0.5, -11), 10)
        local delBtn = MakeButton(line1, "X", Color3.fromRGB(214, 70, 70), UDim2.new(0, 22, 0, 22), UDim2.new(1, -22, 0.5, -11), 10)
        pt.seqBtn = seqBtn

        -- Tombol urutan hanya makan tempat saat terlihat (tidak ada celah kosong)
        pt.arrange = function()
            local x = 0
            if seqBtn.Visible then x = 26 end
            modeBtn.Position = UDim2.new(0, x, 0.5, -11)
            x += 88
            nameBox.Position = UDim2.new(0, x, 0.5, -11)
            nameBox.Size = UDim2.new(1, -(x + 64), 0, 22)
        end

        -- Baris 2: Delay
        local line2 = NewRow(row, 2, 22)
        MakeLabel(line2, "Delay:", UDim2.new(0.16, 0, 1, 0))
        local delayBox = MakeBox(line2, "3", "", UDim2.new(0.25, 0, 1, 0), UDim2.new(0.17, 0, 0, 0))

        -- Baris 3: Kec & Tinggi (hanya jika Jalan + Noclip)
        local line3 = NewRow(row, 3, 22)
        MakeLabel(line3, "Kec:", UDim2.new(0.12, 0, 1, 0))
        local speedBox = MakeBox(line3, "30", "", UDim2.new(0.25, 0, 1, 0), UDim2.new(0.13, 0, 0, 0))
        MakeLabel(line3, "Tinggi:", UDim2.new(0.16, 0, 1, 0), UDim2.new(0.44, 0, 0, 0))
        local heightBox = MakeBox(line3, "12", "", UDim2.new(0.25, 0, 1, 0), UDim2.new(0.61, 0, 0, 0))
        line3.Visible = false

        pt.sync = function()
            if pt.mode == "walk" then
                modeBtn.Text = "Jalan + Noclip"
                modeBtn.BackgroundColor3 = BTN_BLUE
                line3.Visible = true
            else
                modeBtn.Text = "TP"
                modeBtn.BackgroundColor3 = BTN_ORANGE
                line3.Visible = false
            end
            delayBox.Text = Fmt(pt.delay)
            speedBox.Text = Fmt(pt.speed)
            heightBox.Text = Fmt(pt.height)
        end

        local function BindBox(box, field, minv)
            box.FocusLost:Connect(function()
                local v = tonumber(box.Text)
                if v then pt[field] = math.max(v, minv) end
                box.Text = Fmt(pt[field])
                RefreshGroups()
            end)
        end
        BindBox(delayBox, "delay", 0.5)
        BindBox(speedBox, "speed", 1)
        BindBox(heightBox, "height", -math.huge)

        nameBox.FocusLost:Connect(function()
            pt.name = nameBox.Text
            UpdateMarkName(pt)
        end)

        modeBtn.MouseButton1Click:Connect(function()
            pt.mode = (pt.mode == "walk") and "tp" or "walk"
            pt.sync()
            RefreshGroups()
        end)

        seqBtn.MouseButton1Click:Connect(function()
            if not TP.pickMode then return end
            local pos = table.find(TP.seq, pt)
            if pos then
                table.remove(TP.seq, pos)
            else
                table.insert(TP.seq, pt)
            end
            RefreshSeq()
        end)

        goBtn.MouseButton1Click:Connect(function()
            RunManual(pt.cframe, pt.mode, pt.speed, pt.height)
        end)

        delBtn.MouseButton1Click:Connect(function()
            local i = table.find(TP.points, pt)
            if i then table.remove(TP.points, i) end
            local j = table.find(TP.seq, pt)
            if j then table.remove(TP.seq, j) end
            DestroyMark(pt)
            row:Destroy()
            RefreshSeq()
            SyncMarkLoop()
        end)

        pt.sync()
        pt.arrange()
        RefreshSeq()
        if TP.boxMark then
            BuildMark(pt)
            UpdateMarkName(pt)
            SyncMarkLoop()
        end
    end

    local function ClearAllPoints()
        for _, pt in ipairs(TP.points) do
            DestroyMark(pt)
            if pt.row then pt.row:Destroy() end
        end
        table.clear(TP.points)
        table.clear(TP.seq)
        RefreshSeq()
        SyncMarkLoop()
    end

    -- Auto Farm berantai: slot terpilih dikunjungi berulang, memakai mode/delay/kec/tinggi masing-masing
    local function ToggleFarm()
        if TP.farmActive then
            StopTeleport()
            return
        end
        if #TP.seq == 0 then
            FarmBtn.Text = "⚠ PILIH TITIK DULU"
            task.delay(1.2, UpdateFarmBtn)
            return
        end
        local startRoot = GetHumanoidRootPart()
        if not startRoot then return end
        if ZoneStop then ZoneStop(true) end

        TP.farmOrigin = startRoot.CFrame      -- posisi awal (kembali ke sini + 2 stud saat berhenti)
        TP.farmActive = true
        UpdateFarmBtn()
        TP.farmThread = task.spawn(function()
            while TP.farmActive and not hubDestroyed do
                local seq = table.clone(TP.seq)   -- perubahan urutan berlaku di putaran berikutnya
                if #seq == 0 then break end
                for _, pt in ipairs(seq) do
                    if not TP.farmActive or hubDestroyed then break end
                    MoveTo(pt.cframe, pt.mode, pt.speed, pt.height)
                    task.wait(math.max(0.5, pt.delay))
                end
            end
            TP.farmActive = false
            TP.farmThread = nil
            UpdateFarmBtn()
            ReturnToFarmOrigin()              -- selesai sendiri (mis. urutan kosong) -> kembali juga
        end)
    end

    -- Dipanggil saat karakter respawn: batalkan gerakan lama (Auto Farm tetap lanjut dengan karakter baru)
    TP.onRespawn = function()
        if TP.tween then
            pcall(function() TP.tween:Cancel() end)
            TP.tween = nil
        end
        if TP.manualThread then
            pcall(task.cancel, TP.manualThread)
            TP.manualThread = nil
        end
        SetBusy(false)
    end

    -- ===== Sambungkan tombol =====
    CopyPosBtn.MouseButton1Click:Connect(function()
        local root = GetHumanoidRootPart()
        if not root then return end
        local p = root.Position
        local txt = string.format("%.2f, %.2f, %.2f", p.X, p.Y, p.Z)
        pcall(function()
            if setclipboard then setclipboard(txt) end
        end)
        PosBox.Text = txt
        CopyPosBtn.Text = "✅ TERSALIN"
        task.delay(1, function()
            CopyPosBtn.Text = "📋 SALIN POSISI SEKARANG"
        end)
    end)

    GoPosBtn.MouseButton1Click:Connect(function()
        local nums = {}
        for n in PosBox.Text:gmatch("[^,%s]+") do
            local v = tonumber(n)
            if v then table.insert(nums, v) end
        end
        if #nums < 3 then
            GoPosBtn.Text = "⚠ X,Y,Z?"
            task.delay(1.2, PosBtnText)
            return
        end
        local spd = tonumber(globalGroup.speedBox.Text) or 30
        local lft = tonumber(globalGroup.heightBox.Text) or 12
        RunManual(CFrame.new(nums[1], nums[2], nums[3]), TP.posMode, spd, lft)
    end)

    StopMoveBtn.MouseButton1Click:Connect(function()
        StopTeleport()
    end)

    AddPointBtn.MouseButton1Click:Connect(function()
        local root = GetHumanoidRootPart()
        if not root then return end
        AddPoint(root.CFrame)
    end)

    -- Hapus semua: tekan sekali lalu konfirmasi dalam 5 detik
    local delConfirm = false
    local function ResetDelBtn()
        delConfirm = false
        DelAllBtn.Text = "🗑 HAPUS SEMUA TITIK"
        DelAllBtn.BackgroundColor3 = BTN_RED
    end
    DelAllBtn.MouseButton1Click:Connect(function()
        if delConfirm then
            if TP.delThread then
                pcall(task.cancel, TP.delThread)
                TP.delThread = nil
            end
            StopTeleport()
            ClearAllPoints()
            ResetDelBtn()
            return
        end
        delConfirm = true
        DelAllBtn.BackgroundColor3 = BTN_RED_DARK
        TP.delThread = task.spawn(function()
            for sisa = 5, 1, -1 do
                DelAllBtn.Text = "KONFIRMASI HAPUS [" .. sisa .. "s]"
                task.wait(1)
            end
            TP.delThread = nil
            ResetDelBtn()
        end)
    end)

    PickBtn.MouseButton1Click:Connect(function()
        TP.pickMode = not TP.pickMode
        if TP.pickMode then
            PickBtn.Text = "✅ SELESAI MEMILIH"
            PickBtn.BackgroundColor3 = BTN_GREEN
        else
            PickBtn.Text = "📝 PILIH URUTAN TITIK"
            PickBtn.BackgroundColor3 = BTN_BLUE
        end
        RefreshSeq()
    end)

    FarmBtn.MouseButton1Click:Connect(ToggleFarm)

    PosBtnText()
    RefreshGroups()
end)()

-- ==================================================
-- ========== TAB AUTO ZONE =========================
-- ==================================================
-- Zona bisa ditentukan 5 cara: Deteksi Zona (Part di sekitar karakter), Ketuk Part, Path Part (boleh Nama[*]),
-- 2 sudut (kotak), titik tengah + radius (bola), atau Poligon (bentuk bebas dari titik-titik).
-- Isi zona dipindai, dikelompokkan per jenis (Box x19, Chest x11, ...), lalu dikunjungi satu per satu,
-- diambil (sentuh / prompt tahan tombol / klik / tahan E), dan boleh disetor ke Titik Setor.
-- Dibungkus fungsi sendiri supaya jumlah local di tingkat atas tidak melewati batas 200 Lua.
;(function()
    local function Corner(obj, r)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, r or 5)
        c.Parent = obj
    end

    local function MakeButton(parent, text, color, size, pos, textSize)
        local b = Instance.new("TextButton")
        b.Parent = parent
        b.Size = size
        b.Position = pos or UDim2.new(0, 0, 0, 0)
        b.BackgroundColor3 = color
        b.Text = text
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold
        b.TextSize = textSize or 9
        b.TextWrapped = true
        b.AutoLocalize = false
        b.AutoButtonColor = false
        Corner(b, 5)
        return b
    end

    local function MakeBox(parent, placeholder, text, size, pos)
        local t = Instance.new("TextBox")
        t.Parent = parent
        t.Size = size
        t.Position = pos or UDim2.new(0, 0, 0, 0)
        t.BackgroundColor3 = INPUT_BG
        t.PlaceholderText = placeholder
        t.PlaceholderColor3 = PLACEHOLDER
        t.Text = text or ""
        t.TextColor3 = TEXT_DARK
        t.Font = Enum.Font.Gotham
        t.TextSize = 10
        t.ClearTextOnFocus = false
        Corner(t, 4)
        return t
    end

    local function MakeLabel(parent, text, size, pos, textSize)
        local l = Instance.new("TextLabel")
        l.Parent = parent
        l.Size = size
        l.Position = pos or UDim2.new(0, 0, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = TEXT_DARK
        l.Font = Enum.Font.GothamBold
        l.TextSize = textSize or 10
        l.TextXAlignment = Enum.TextXAlignment.Left
        return l
    end

    local function Fmt(n)
        return string.format("%g", n)
    end

    -- ===== Wadah tab =====
    TabZoneContainer = Instance.new("Frame")
    TabZoneContainer.Parent = TabContentWrapper
    TabZoneContainer.Size = UDim2.new(1, 0, 1, 0)
    TabZoneContainer.Visible = false
    TabZoneContainer.BackgroundTransparency = 1

    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Parent = TabZoneContainer
    Scroll.Size = UDim2.new(1, 0, 1, 0)
    Scroll.BackgroundTransparency = 1
    Scroll.ScrollBarThickness = 6
    Scroll.ScrollBarImageColor3 = LINE
    Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    local ScrollList = Instance.new("UIListLayout")
    ScrollList.Parent = Scroll
    ScrollList.Padding = UDim.new(0, 6)
    ScrollList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    ScrollList.SortOrder = Enum.SortOrder.LayoutOrder

    local function NewCard(order, title)
        local card = Instance.new("Frame")
        card.Parent = Scroll
        card.Size = UDim2.new(1, -12, 0, 0)
        card.AutomaticSize = Enum.AutomaticSize.Y
        card.BackgroundColor3 = HEADER_BG
        card.LayoutOrder = order
        Corner(card, 7)
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 5)
        pad.PaddingBottom = UDim.new(0, 6)
        pad.PaddingLeft = UDim.new(0, 5)
        pad.PaddingRight = UDim.new(0, 5)
        pad.Parent = card
        local list = Instance.new("UIListLayout")
        list.Padding = UDim.new(0, 5)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = card
        local lbl = MakeLabel(card, title, UDim2.new(1, 0, 0, 18), nil, 11)
        lbl.LayoutOrder = 0
        return card
    end

    local function NewRow(parent, order, height)
        local row = Instance.new("Frame")
        row.Parent = parent
        row.Size = UDim2.new(1, 0, 0, height)
        row.BackgroundTransparency = 1
        row.LayoutOrder = order
        return row
    end

    local function NewList(parent, order)
        local f = Instance.new("Frame")
        f.Parent = parent
        f.Size = UDim2.new(1, 0, 0, 0)
        f.AutomaticSize = Enum.AutomaticSize.Y
        f.BackgroundTransparency = 1
        f.LayoutOrder = order
        local l = Instance.new("UIListLayout")
        l.Padding = UDim.new(0, 3)
        l.SortOrder = Enum.SortOrder.LayoutOrder
        l.Parent = f
        return f
    end

    -- ===== State zona =====
    local Z = {
        kind = nil,                       -- "parts" | "box" | "sphere" | "poly"
        parts = {}, partSet = {},
        cA = nil, cB = nil, extraH = 25,
        center = nil, radius = 40,
        poly = {},
        show = true, vis = nil,
        sel = {}, rows = {}, maxSize = 40,
        autoScan = false, scanThread = nil,
        candRows = {}, candMap = {},
        method = "auto", pickDelay = 0.4, holdTime = 1.5,
        depositCF = nil, depositEvery = 1, depositWait = 1.5,
        running = false, thread = nil, origin = nil,
        stats = {picked = 0, gone = 0, deposits = 0},
        visited = setmetatable({}, {__mode = "k"}),
        tapConns = {}, tapOn = false, tapDown = nil, tapPos = nil, tapTime = 0,
    }

    -- ===== KARTU 1: ZONA =====
    local CardZone = NewCard(1, "🗺 ZONA")
    local StatusLbl = MakeLabel(NewRow(CardZone, 1, 44), "", UDim2.new(1, 0, 1, 0), nil, 9)
    StatusLbl.Font = Enum.Font.Gotham
    StatusLbl.TextWrapped = true
    StatusLbl.TextYAlignment = Enum.TextYAlignment.Top

    local RowKinds = NewRow(CardZone, 2, 22)
    local KindBtns = {}
    for i, d in ipairs({{"parts", "PART"}, {"box", "KOTAK"}, {"sphere", "BOLA"}, {"poly", "POLIGON"}}) do
        KindBtns[d[1]] = MakeButton(RowKinds, d[2], BTN_GRAY, UDim2.new(0.24, 0, 1, 0), UDim2.new((i - 1) * 0.253, 0, 0, 0), 9)
    end

    local RowDetect = NewRow(CardZone, 3, 24)
    local DetectBtn = MakeButton(RowDetect, "🔍 DETEKSI ZONA", BTN_TEAL, UDim2.new(0.49, 0, 1, 0))
    local TapBtn = MakeButton(RowDetect, "👆 KETUK PART", BTN_GRAY, UDim2.new(0.49, 0, 1, 0), UDim2.new(0.51, 0, 0, 0))

    local RowPath = NewRow(CardZone, 4, 24)
    local PathBox = MakeBox(RowPath, "Path Part zona (boleh Nama[*])", "", UDim2.new(0.64, 0, 1, 0))
    local PathAddBtn = MakeButton(RowPath, "+ PATH", BTN_BLUE, UDim2.new(0.34, 0, 1, 0), UDim2.new(0.66, 0, 0, 0))

    local CandHead = NewRow(CardZone, 5, 14)
    local CandLbl = MakeLabel(CandHead, "", UDim2.new(1, 0, 1, 0), nil, 9)
    CandHead.Visible = false
    local CandHolder = NewList(CardZone, 6)

    local RowAB = NewRow(CardZone, 7, 24)
    local BtnA = MakeButton(RowAB, "Set Sudut A", BTN_ORANGE, UDim2.new(0.49, 0, 1, 0))
    local BtnB = MakeButton(RowAB, "Set Sudut B", BTN_ORANGE, UDim2.new(0.49, 0, 1, 0), UDim2.new(0.51, 0, 0, 0))
    local RowH = NewRow(CardZone, 8, 22)
    MakeLabel(RowH, "Tinggi di atas sudut / Part pipih:", UDim2.new(0.55, 0, 1, 0), nil, 9)
    local HBox = MakeBox(RowH, "25", "25", UDim2.new(0.25, 0, 1, 0), UDim2.new(0.57, 0, 0, 0))
    local RowC = NewRow(CardZone, 9, 24)
    local BtnC = MakeButton(RowC, "Set Titik Tengah", BTN_ORANGE, UDim2.new(0.46, 0, 1, 0))
    MakeLabel(RowC, "Radius:", UDim2.new(0.16, 0, 1, 0), UDim2.new(0.48, 0, 0, 0))
    local RBox = MakeBox(RowC, "40", "40", UDim2.new(0.32, 0, 1, 0), UDim2.new(0.66, 0, 0, 0))
    local RowP = NewRow(CardZone, 10, 24)
    local BtnPAdd = MakeButton(RowP, "+ Titik Poligon (posisi sekarang)", BTN_ORANGE, UDim2.new(0.64, 0, 1, 0))
    local BtnPReset = MakeButton(RowP, "Reset", BTN_GRAY, UDim2.new(0.34, 0, 1, 0), UDim2.new(0.66, 0, 0, 0))
    local RowShow = NewRow(CardZone, 11, 22)
    local ShowToggle = ESP.MakeToggle(RowShow, "Tampilkan Zona", UDim2.new(0.6, 0, 1, 0), UDim2.new(0, 0, 0, 0), function(on)
        Z.show = on
        Z.updateVisual()
    end)
    ShowToggle.set(true)
    local BtnClear = MakeButton(RowShow, "Hapus Zona", BTN_RED, UDim2.new(0.38, 0, 1, 0), UDim2.new(0.62, 0, 0, 0))

    -- ===== KARTU 2: ISI ZONA =====
    local CardScan = NewCard(2, "📦 ISI ZONA")
    local RowScan = NewRow(CardScan, 1, 24)
    local ScanBtn = MakeButton(RowScan, "🔄 SCAN", BTN_TEAL, UDim2.new(0.3, 0, 1, 0))
    local AutoScanToggle = ESP.MakeToggle(RowScan, "Auto Scan (0,5 dtk)", UDim2.new(0.68, 0, 1, 0), UDim2.new(0.32, 0, 0, 0), function(on)
        Z.setAutoScan(on)
    end)
    local RowMax = NewRow(CardScan, 2, 22)
    MakeLabel(RowMax, "Abaikan objek lebih besar dari (stud):", UDim2.new(0.62, 0, 1, 0), nil, 9)
    local MaxBox = MakeBox(RowMax, "40", "40", UDim2.new(0.25, 0, 1, 0), UDim2.new(0.64, 0, 0, 0))
    local SummaryLbl = MakeLabel(NewRow(CardScan, 3, 40), "Atur zona dulu, lalu tekan SCAN.", UDim2.new(1, 0, 1, 0), nil, 9)
    SummaryLbl.Font = Enum.Font.Gotham
    SummaryLbl.TextWrapped = true
    SummaryLbl.TextYAlignment = Enum.TextYAlignment.Top
    local GroupHolder = NewList(CardScan, 4)

    -- ===== KARTU 3: PENGAMBILAN & SETOR =====
    local CardPick = NewCard(3, "🎒 PENGAMBILAN & SETOR")
    local METHODS = {
        {"auto", "Auto (deteksi per barang)"},
        {"approach", "Dekati saja"},
        {"press", "Tekan E (sekali)"},
        {"hold", "Tahan E"},
        {"prompt", "Prompt (otomatis)"},
        {"touch", "Sentuh"},
        {"click", "Klik"},
    }
    local MethodRow = NewRow(CardPick, 1, 14 + 4 * 24)
    MakeLabel(MethodRow, "Cara ambil (pilih satu):", UDim2.new(1, 0, 0, 14), nil, 9)
    local methodToggles = {}
    for i, m in ipairs(METHODS) do
        local key = m[1]
        local col, rowN = (i - 1) % 2, math.floor((i - 1) / 2)
        methodToggles[key] = ESP.MakeToggle(MethodRow, m[2], UDim2.new(0.49, 0, 0, 22), UDim2.new(col * 0.51, 0, 0, 16 + rowN * 24), function(on)
            if not on then return false end          -- harus selalu ada satu yang terpilih
            Z.method = key
            for k, t in pairs(methodToggles) do
                if k ~= key then t.set(false) end
            end
        end)
    end
    methodToggles.auto.set(true)
    local function BoxRow(order, label, default)
        local row = NewRow(CardPick, order, 22)
        MakeLabel(row, label, UDim2.new(0.62, 0, 1, 0), nil, 9)
        return MakeBox(row, default, default, UDim2.new(0.3, 0, 1, 0), UDim2.new(0.64, 0, 0, 0))
    end
    local PickBox = BoxRow(2, "Jeda setelah ambil (dtk):", "0.4")
    local HoldBox = BoxRow(3, "Lama Tahan E (dtk, 0 = ikuti prompt):", "1.5")
    local RowDep = NewRow(CardPick, 4, 24)
    local BtnDep = MakeButton(RowDep, "📍 SET TITIK SETOR (posisi sekarang)", BTN_ORANGE, UDim2.new(0.64, 0, 1, 0))
    local BtnDepClr = MakeButton(RowDep, "✖ Hapus", BTN_GRAY, UDim2.new(0.34, 0, 1, 0), UDim2.new(0.66, 0, 0, 0))
    local DepLbl = MakeLabel(NewRow(CardPick, 5, 14), "Titik setor: belum diatur (barang tidak disetor)", UDim2.new(1, 0, 1, 0), nil, 9)
    DepLbl.Font = Enum.Font.Gotham
    local EveryBox = BoxRow(6, "Setor tiap (barang):", "1")
    local WaitBox = BoxRow(7, "Jeda di titik setor (dtk):", "1.5")

    -- ===== KARTU 4: JALANKAN =====
    local CardRun = NewCard(4, "▶ AUTO ZONA")
    local RunBtn = MakeButton(NewRow(CardRun, 1, 30), "▶ MULAI AUTO ZONA", BTN_GREEN, UDim2.new(1, 0, 1, 0), nil, 11)
    local RunLbl = MakeLabel(NewRow(CardRun, 2, 44), "Status: berhenti", UDim2.new(1, 0, 1, 0), nil, 9)
    RunLbl.Font = Enum.Font.Gotham
    RunLbl.TextWrapped = true
    RunLbl.TextYAlignment = Enum.TextYAlignment.Top

    -- ==================================================
    -- GEOMETRI ZONA
    -- ==================================================
    local ZCOL = Color3.fromRGB(60, 220, 120)

    local function Flash(btn, text, restore)
        btn:SetAttribute("flash", (btn:GetAttribute("flash") or 0) + 1)
        local my = btn:GetAttribute("flash")
        btn.Text = text
        task.delay(1.3, function()
            if btn.Parent and btn:GetAttribute("flash") == my then btn.Text = restore end
        end)
    end

    local function ValidParts()
        for i = #Z.parts, 1, -1 do
            local p = Z.parts[i]
            if not p:IsDescendantOf(game) then
                Z.partSet[p] = nil
                table.remove(Z.parts, i)
            end
        end
    end

    local function Defined(kind)
        if kind == "parts" then
            ValidParts()
            return #Z.parts > 0
        elseif kind == "box" then
            return Z.cA ~= nil and Z.cB ~= nil
        elseif kind == "sphere" then
            return Z.center ~= nil
        elseif kind == "poly" then
            return #Z.poly >= 3
        end
        return false
    end

    local function BoxGeom()
        local a, b = Z.cA, Z.cB
        local lo = Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y) - 3, math.min(a.Z, b.Z))
        local hi = Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y) + Z.extraH, math.max(a.Z, b.Z))
        local size = Vector3.new(math.max(hi.X - lo.X, 4), math.max(hi.Y - lo.Y, 4), math.max(hi.Z - lo.Z, 4))
        return CFrame.new((lo + hi) / 2), size
    end

    local function PolyBounds()
        local lo = Vector3.new(math.huge, math.huge, math.huge)
        local hi = Vector3.new(-math.huge, -math.huge, -math.huge)
        for _, p in ipairs(Z.poly) do
            lo = Vector3.new(math.min(lo.X, p.X), math.min(lo.Y, p.Y), math.min(lo.Z, p.Z))
            hi = Vector3.new(math.max(hi.X, p.X), math.max(hi.Y, p.Y), math.max(hi.Z, p.Z))
        end
        lo = Vector3.new(lo.X, lo.Y - 3, lo.Z)
        hi = Vector3.new(hi.X, hi.Y + Z.extraH, hi.Z)
        return lo, hi
    end

    -- titik di dalam poligon (bidang X-Z), algoritma ray casting; bentuk cekung pun benar
    local function InPoly(x, z)
        local inside = false
        local pts = Z.poly
        local j = #pts
        for i = 1, #pts do
            local a, b = pts[i], pts[j]
            if ((a.Z > z) ~= (b.Z > z)) and (x < (b.X - a.X) * (z - a.Z) / (b.Z - a.Z) + a.X) then
                inside = not inside
            end
            j = i
        end
        return inside
    end

    local function PartContains(p, pos)
        local lp = p.CFrame:PointToObjectSpace(pos)
        local h = p.Size / 2
        if p:IsA("Part") and p.Shape == Enum.PartType.Ball then
            return lp.Magnitude <= h.X
        end
        return math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y and math.abs(lp.Z) <= h.Z
    end

    local function Contains(pos)
        local kind = Z.kind
        if kind == "parts" then
            for _, p in ipairs(Z.parts) do
                if p:IsDescendantOf(game) then
                    if PartContains(p, pos) then return true end
                    -- Part pipih (mis. lantai zona): ruang di atasnya sampai Z.extraH juga bagian zona
                    if Z.extraH > 0 and p.Size.Y <= 8 then
                        local lp = p.CFrame:PointToObjectSpace(pos)
                        local h = p.Size / 2
                        if math.abs(lp.X) <= h.X and math.abs(lp.Z) <= h.Z and lp.Y >= -h.Y and lp.Y <= h.Y + Z.extraH then
                            return true
                        end
                    end
                end
            end
            return false
        elseif kind == "box" and Defined("box") then
            local cf, size = BoxGeom()
            local lp = cf:PointToObjectSpace(pos)
            return math.abs(lp.X) <= size.X / 2 and math.abs(lp.Y) <= size.Y / 2 and math.abs(lp.Z) <= size.Z / 2
        elseif kind == "sphere" and Defined("sphere") then
            return (pos - Z.center).Magnitude <= Z.radius
        elseif kind == "poly" and Defined("poly") then
            local lo, hi = PolyBounds()
            return pos.Y >= lo.Y and pos.Y <= hi.Y and InPoly(pos.X, pos.Z)
        end
        return false
    end

    -- titik di dalam zona untuk dituju saat belum ada barang (supaya barang acak mulai muncul)
    local function ZoneAnchor()
        local kind = Z.kind
        if kind == "parts" then
            ValidParts()
            local p = Z.parts[1]
            if p then return p.Position + Vector3.new(0, 3, 0) end
        elseif kind == "box" and Defined("box") then
            local cf = BoxGeom()
            return cf.Position
        elseif kind == "sphere" and Defined("sphere") then
            return Z.center + Vector3.new(0, 3, 0)
        elseif kind == "poly" and Defined("poly") then
            local sum = Vector3.zero
            for _, p in ipairs(Z.poly) do sum += p end
            local c = sum / #Z.poly
            return c + Vector3.new(0, 3, 0)
        end
        return nil
    end

    -- ==================================================
    -- STATUS & VISUAL
    -- ==================================================
    local function UpdateStatus()
        local t
        if Z.kind == "parts" then
            t = "Zona aktif: PART - " .. #Z.parts .. " bagian (bentuk mengikuti Part aslinya)"
        elseif Z.kind == "box" then
            local _, size = BoxGeom()
            t = string.format("Zona aktif: KOTAK dari 2 sudut (%d x %d x %d stud)", math.floor(size.X), math.floor(size.Y), math.floor(size.Z))
        elseif Z.kind == "sphere" then
            t = "Zona aktif: BOLA radius " .. Fmt(Z.radius) .. " stud"
        elseif Z.kind == "poly" then
            t = "Zona aktif: POLIGON " .. #Z.poly .. " titik (bentuk bebas)"
        else
            t = "Belum ada zona. Pakai Deteksi Zona, Ketuk Part, Path, 2 sudut, titik tengah, atau Poligon."
        end
        if #Z.poly > 0 and #Z.poly < 3 then
            t = t .. "\nPoligon: " .. #Z.poly .. " titik (minimal 3)."
        end
        StatusLbl.Text = t
        for k, b in pairs(KindBtns) do
            if Z.kind == k then
                b.BackgroundColor3 = BTN_BLUE
            elseif Defined(k) then
                b.BackgroundColor3 = BTN_TEAL
            else
                b.BackgroundColor3 = BTN_GRAY
            end
        end
    end

    local function AddSphere(folder, base, pos, radius, color)
        local s = Instance.new("SphereHandleAdornment")
        s.Adornee = base
        s.Radius = radius
        s.CFrame = base.CFrame:ToObjectSpace(CFrame.new(pos))
        s.Color3 = color
        s.Transparency = 0.1
        s.AlwaysOnTop = true
        s.ZIndex = 2
        s.Parent = folder
    end

    -- Garis tebal & hampir tidak transparan (terlihat jelas, tembus tembok)
    local function AddBar(folder, base, a, b, color, thick)
        local d = (b - a).Magnitude
        if d < 0.1 then return end
        local dir = (b - a) / d
        local upv = (math.abs(dir.Y) > 0.99) and Vector3.xAxis or Vector3.yAxis   -- garis tegak lurus: hindari lookAt degenerat
        local t = thick or 0.5
        local bar = Instance.new("BoxHandleAdornment")
        bar.Adornee = base
        bar.Size = Vector3.new(t, t, d)
        bar.CFrame = base.CFrame:ToObjectSpace(CFrame.lookAt((a + b) / 2, b, upv))
        bar.Color3 = color
        bar.Transparency = 0.02
        bar.AlwaysOnTop = true
        bar.ZIndex = 1
        bar.Parent = folder
    end

    -- Jaring-jaring kubus: 12 rusuk
    local function AddWireBox(folder, base, cf, size, color, thick)
        local h = size / 2
        local c = {}
        for ix = 0, 1 do
            for iy = 0, 1 do
                for iz = 0, 1 do
                    c[ix * 4 + iy * 2 + iz] = cf * Vector3.new(
                        (ix == 0 and -1 or 1) * h.X,
                        (iy == 0 and -1 or 1) * h.Y,
                        (iz == 0 and -1 or 1) * h.Z)
                end
            end
        end
        for i = 0, 7 do
            for _, bit in ipairs({1, 2, 4}) do
                if i % (bit * 2) < bit then
                    AddBar(folder, base, c[i], c[i + bit], color, thick)
                end
            end
        end
    end

    -- Penanda sudut A / B: bola besar + jaring kubus + tiang tinggi + huruf besar di atasnya
    local function AddCornerMarker(folder, base, pos, color, letter)
        AddSphere(folder, base, pos, 1.5, color)
        AddWireBox(folder, base, CFrame.new(pos), Vector3.new(4, 4, 4), color, 0.4)
        AddBar(folder, base, pos - Vector3.new(0, 4, 0), pos + Vector3.new(0, 9, 0), color, 0.6)
        local bb = Instance.new("BillboardGui")
        bb.Name = "Label" .. letter
        bb.Adornee = base
        bb.AlwaysOnTop = true
        bb.LightInfluence = 0
        bb.Size = UDim2.fromOffset(48, 48)
        bb.StudsOffsetWorldSpace = pos + Vector3.new(0, 11, 0) - base.Position
        local lbl = Instance.new("TextLabel")
        lbl.Parent = bb
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = letter
        lbl.TextColor3 = Color3.new(1, 1, 1)
        lbl.TextStrokeColor3 = color
        lbl.TextStrokeTransparency = 0
        lbl.Font = Enum.Font.GothamBlack
        lbl.TextSize = 34
        bb.Parent = folder
    end

    local function UpdateVisual()
        if Z.vis then
            Z.vis:Destroy()
            Z.vis = nil
        end
        if not Z.show then return end
        if not (Z.kind or Z.cA or Z.cB or Z.center or #Z.poly > 0 or Z.depositCF) then return end
        local folder = Instance.new("Folder")
        folder.Name = "Shrimp_Hub_Zone"
        folder.Parent = LocalPlayer.PlayerGui
        Z.vis = folder
        local base = workspace.Terrain

        if Z.kind == "parts" then
            for i, p in ipairs(Z.parts) do
                if i > 28 then break end          -- batas Highlight Roblox
                local h = Instance.new("Highlight")
                h.FillColor = ZCOL
                h.FillTransparency = 0.82
                h.OutlineColor = ZCOL
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.Adornee = p
                h.Parent = folder
            end
        elseif Z.kind == "box" and Defined("box") then
            local cf, size = BoxGeom()
            local box = Instance.new("BoxHandleAdornment")
            box.Adornee = base
            box.Size = size
            box.CFrame = base.CFrame:ToObjectSpace(cf)
            box.Color3 = ZCOL
            box.Transparency = 0.82
            box.AlwaysOnTop = true
            box.ZIndex = 1
            box.Parent = folder
            AddWireBox(folder, base, cf, size, ZCOL, 0.5)     -- rangka kotak zona yang tegas
        elseif Z.kind == "sphere" and Defined("sphere") then
            local s = Instance.new("SphereHandleAdornment")
            s.Adornee = base
            s.Radius = Z.radius
            s.CFrame = base.CFrame:ToObjectSpace(CFrame.new(Z.center))
            s.Color3 = ZCOL
            s.Transparency = 0.88
            s.AlwaysOnTop = true
            s.ZIndex = 1
            s.Parent = folder
        end

        -- penanda titik (sudut, tengah, poligon, setor)
        if Z.cA then AddCornerMarker(folder, base, Z.cA, ORANGE, "A") end
        if Z.cB then AddCornerMarker(folder, base, Z.cB, Color3.fromRGB(60, 170, 255), "B") end
        if Z.center then AddSphere(folder, base, Z.center, 1.2, ORANGE) end
        local n = #Z.poly
        for i, p in ipairs(Z.poly) do
            AddSphere(folder, base, p, 0.8, ZCOL)
            if i < n then
                AddBar(folder, base, p, Z.poly[i + 1], ZCOL)
            elseif n >= 3 then
                AddBar(folder, base, p, Z.poly[1], ZCOL)
            end
        end
        if Z.depositCF then AddSphere(folder, base, Z.depositCF.Position, 1.2, Color3.fromRGB(150, 80, 230)) end
    end
    Z.updateVisual = UpdateVisual

    local function SetKind(kind)
        Z.kind = kind
        UpdateStatus()
        UpdateVisual()
    end

    local function FallbackKind()
        for _, k in ipairs({"parts", "box", "sphere", "poly"}) do
            if Defined(k) then return k end
        end
        return nil
    end

    -- ==================================================
    -- PART ZONA (deteksi / ketuk / path)
    -- ==================================================
    local function TogglePart(p, on)
        if on then
            if not Z.partSet[p] then
                Z.partSet[p] = true
                Z.parts[#Z.parts + 1] = p
            end
            SetKind("parts")
        else
            if Z.partSet[p] then
                Z.partSet[p] = nil
                local i = table.find(Z.parts, p)
                if i then table.remove(Z.parts, i) end
            end
            if Z.kind == "parts" and #Z.parts == 0 then
                SetKind(FallbackKind())
            else
                UpdateStatus()
                UpdateVisual()
            end
        end
        local tg = Z.candMap[p]
        if tg then tg.set(on) end
    end

    local function ClearCands()
        for _, b in ipairs(Z.candRows) do
            b:Destroy()
        end
        table.clear(Z.candRows)
        table.clear(Z.candMap)
        CandHead.Visible = false
    end

    local ZONE_WORDS = {"zone", "area", "region", "arena", "trigger", "hitbox", "safe", "bound", "spawn", "end", "finish"}
    local function ZoneScore(p)
        local s = 0
        if not p.CanCollide then s += 3 end
        if p.Transparency >= 0.9 then s += 2 end
        local n = p.Name:lower()
        for _, w in ipairs(ZONE_WORDS) do
            if n:find(w, 1, true) then
                s += 3
                break
            end
        end
        local sz = p.Size
        if math.max(sz.X, sz.Y, sz.Z) >= 20 then s += 1 end
        return s
    end

    local function ShowCands(list)
        ClearCands()
        CandHead.Visible = true
        if #list == 0 then
            CandLbl.Text = "Tidak ada Part terdeteksi. Dekati zona, atau pakai Ketuk Part / Path."
            return
        end
        CandLbl.Text = "Kandidat zona - pilih satu atau beberapa Part:"
        for i, c in ipairs(list) do
            local p = c.part
            local sz = p.Size
            local label = string.format("%s (%d×%d×%d)%s%s", p.Name,
                math.floor(sz.X + 0.5), math.floor(sz.Y + 0.5), math.floor(sz.Z + 0.5),
                c.inside and "  ✔ di dalam" or "", p.CanCollide and "" or "  · tembus")
            local tg = ESP.MakeToggle(CandHolder, label, UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 0), function(on)
                TogglePart(p, on)
            end)
            tg.btn.LayoutOrder = i
            tg.set(Z.partSet[p] ~= nil)
            table.insert(Z.candRows, tg.btn)
            Z.candMap[p] = tg
        end
    end

    local detecting = false
    local function Detect()
        if detecting then return end
        local root = GetHumanoidRootPart()
        if not root then
            Flash(DetectBtn, "⚠ Karakter tidak ada", "🔍 DETEKSI ZONA")
            return
        end
        detecting = true
        DetectBtn.Text = "🔍 mencari..."
        task.spawn(function()
            local pos = root.Position
            local params = OverlapParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {LocalPlayer.Character}
            local near = workspace:GetPartBoundsInRadius(pos, 8, params)     -- yang menyentuh / menaungi karakter
            local wide = workspace:GetPartBoundsInRadius(pos, 150, params)   -- zona lain di sekitar (nama / sifat mirip zona)
            local list, seen = {}, {}
            local function consider(p, always)
                if seen[p] or p:IsA("Terrain") then return end
                local sc = ZoneScore(p)
                local sz = p.Size
                if always or (sc >= 3 and math.max(sz.X, sz.Y, sz.Z) >= 8) then
                    seen[p] = true
                    local inside = PartContains(p, pos)
                    list[#list + 1] = {part = p, inside = inside, score = sc + (inside and 4 or 0), size = sz.X * sz.Y * sz.Z}
                end
            end
            for _, p in ipairs(near) do consider(p, true) end
            for _, p in ipairs(wide) do consider(p, false) end

            -- pencarian dalam: pemicu zona sering CanQuery=false sehingga tak terlihat oleh pencarian ruang di atas
            local char = LocalPlayer.Character
            local n = 0
            for _, d in ipairs(workspace:GetDescendants()) do
                n += 1
                if n % 3000 == 0 then
                    task.wait()
                    if hubDestroyed then
                        detecting = false
                        return
                    end
                end
                if d:IsA("BasePart") and not d.CanQuery and not seen[d] and not d:IsA("Terrain")
                    and not (char and d:IsDescendantOf(char)) then
                    local sz = d.Size
                    if math.max(sz.X, sz.Y, sz.Z) >= 8 and PartContains(d, pos) then
                        consider(d, true)
                    end
                end
            end

            table.sort(list, function(a, b)
                if a.score ~= b.score then return a.score > b.score end
                return a.size > b.size
            end)
            for i = #list, 15, -1 do list[i] = nil end
            detecting = false
            if hubDestroyed then return end
            DetectBtn.Text = "🔍 DETEKSI ZONA"
            ShowCands(list)
        end)
    end

    local function PickPartAt(pos)
        local cam = workspace.CurrentCamera
        if not cam then return end
        local ray = cam:ScreenPointToRay(pos.X, pos.Y)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        if LocalPlayer.Character then params.FilterDescendantsInstances = {LocalPlayer.Character} end
        local res = workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
        if not res or not res.Instance or res.Instance:IsA("Terrain") then
            Flash(TapBtn, "Tidak kena Part", "👆 KETUK PART: ON")
            return
        end
        local p = res.Instance
        TogglePart(p, not Z.partSet[p])
        Flash(TapBtn, (Z.partSet[p] and "＋ " or "－ ") .. p.Name, "👆 KETUK PART: ON")
    end

    local function StopTap()
        for _, c in ipairs(Z.tapConns) do c:Disconnect() end
        table.clear(Z.tapConns)
        Z.tapDown, Z.tapPos = nil, nil
        Z.tapOn = false
        TapBtn.Text = "👆 KETUK PART"
        TapBtn.BackgroundColor3 = BTN_GRAY
    end

    local function StartTap()
        if Z.tapOn then return end
        Z.tapOn = true
        TapBtn.Text = "👆 KETUK PART: ON"
        TapBtn.BackgroundColor3 = BTN_BLUE
        table.insert(Z.tapConns, UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            local t = input.UserInputType
            if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
                Z.tapDown, Z.tapPos, Z.tapTime = input, input.Position, os.clock()
            end
        end))
        table.insert(Z.tapConns, UserInputService.InputEnded:Connect(function(input)
            if Z.tapDown ~= input then return end
            Z.tapDown = nil
            if (input.Position - Z.tapPos).Magnitude > 12 or os.clock() - Z.tapTime > 0.5 then return end
            PickPartAt(input.Position)
        end))
    end

    local function AddFromPath(path)
        local added = 0
        for _, o in ipairs(ResolveAll(path)) do
            if o:IsA("BasePart") then
                if not Z.partSet[o] then
                    TogglePart(o, true)
                    added += 1
                end
            else
                local n = 0
                for _, d in ipairs(o:GetDescendants()) do
                    if d:IsA("BasePart") and not Z.partSet[d] then
                        TogglePart(d, true)
                        added += 1
                        n += 1
                        if n >= 25 then break end
                    end
                end
            end
        end
        return added
    end

    -- ==================================================
    -- SCAN ISI ZONA
    -- ==================================================
    local function GatherParts()
        local kind = Z.kind
        if not kind or not Defined(kind) then return nil end
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local ex = {}
        if LocalPlayer.Character then ex[#ex + 1] = LocalPlayer.Character end
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer and pl.Character then ex[#ex + 1] = pl.Character end
        end
        params.FilterDescendantsInstances = ex
        params.MaxParts = 4000
        local out, seen = {}, {}
        local function add(p)
            if not seen[p] and not p:IsA("Terrain") and not Z.partSet[p] then
                seen[p] = true
                out[#out + 1] = p
            end
        end
        if kind == "parts" then
            for _, zp in ipairs(Z.parts) do
                for _, p in ipairs(workspace:GetPartsInPart(zp, params)) do add(p) end   -- mengikuti bentuk asli Part
                if Z.extraH > 0 and zp.Size.Y <= 8 then      -- Part pipih: tambah kolom ruang di atasnya
                    local h = Z.extraH
                    local cf = zp.CFrame * CFrame.new(0, zp.Size.Y / 2 + h / 2, 0)
                    for _, p in ipairs(workspace:GetPartBoundsInBox(cf, Vector3.new(zp.Size.X, h, zp.Size.Z), params)) do add(p) end
                end
            end
        elseif kind == "box" then
            local cf, size = BoxGeom()
            for _, p in ipairs(workspace:GetPartBoundsInBox(cf, size, params)) do add(p) end
        elseif kind == "sphere" then
            for _, p in ipairs(workspace:GetPartBoundsInRadius(Z.center, Z.radius, params)) do add(p) end
        else
            local lo, hi = PolyBounds()
            local size = hi - lo
            size = Vector3.new(math.max(size.X, 4), math.max(size.Y, 4), math.max(size.Z, 4))
            for _, p in ipairs(workspace:GetPartBoundsInBox(CFrame.new((lo + hi) / 2), size, params)) do
                local pp = p.Position
                if InPoly(pp.X, pp.Z) then add(p) end
            end
        end
        return out
    end

    local function Base(n)
        return (n:gsub("[%s_%-]*%d+$", ""))
    end

    -- "barang" = Part itu sendiri atau Model kecil yang memuatnya; karakter/NPC (Model ber-Humanoid) dilewati
    local function ItemOf(part)
        local a = part.Parent
        while a and a ~= workspace and a ~= game do
            if a:IsA("Model") and a:FindFirstChildOfClass("Humanoid") then return nil end
            a = a.Parent
        end
        local node = part
        while true do
            local parent = node.Parent
            if not parent or parent == workspace or not parent:IsA("Model") or #parent:GetChildren() > 25 then break end
            node = parent
        end
        return node
    end

    local function ItemPos(obj)
        if obj:IsA("BasePart") then return obj.Position end
        if obj:IsA("Model") then return obj:GetPivot().Position end
        return nil
    end

    local function BuildGroups(parts)
        local groups, seen, npc = {}, {}, 0
        for _, p in ipairs(parts) do
            local item = ItemOf(p)
            if item == nil then
                npc += 1
            elseif not seen[item] then
                seen[item] = true
                local size = item:IsA("Model") and item:GetExtentsSize() or item.Size
                if math.max(size.X, size.Y, size.Z) <= Z.maxSize then
                    local key = Base(item.Name)
                    if key == "" then key = item.Name end
                    local g = groups[key]
                    if not g then
                        g = {count = 0, list = {}}
                        groups[key] = g
                    end
                    g.count += 1
                    g.list[#g.list + 1] = item
                end
            end
        end
        return groups, npc
    end

    local MAX_ROWS = 20
    local function ApplyGroups(groups, npc)
        local keys, total = {}, 0
        for k, g in pairs(groups) do
            keys[#keys + 1] = k
            total += g.count
        end
        table.sort(keys, function(a, b)
            local ca, cb = groups[a].count, groups[b].count
            if ca ~= cb then return ca > cb end
            return a < b
        end)
        local shown = {}
        for i = 1, math.min(MAX_ROWS, #keys) do shown[keys[i]] = i end
        for k, r in pairs(Z.rows) do
            if not shown[k] then
                r.tg.btn:Destroy()
                Z.rows[k] = nil
            end
        end
        for k, i in pairs(shown) do
            local r = Z.rows[k]
            if not r then
                local key = k
                local tg = ESP.MakeToggle(GroupHolder, key, UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 0), function(on)
                    Z.sel[key] = on or nil
                end)
                tg.set(Z.sel[key] == true)
                r = {tg = tg, text = ""}
                Z.rows[k] = r
            end
            r.tg.btn.LayoutOrder = i
            local text = k .. "  ×" .. groups[k].count
            if r.text ~= text then
                r.text = text
                r.tg.label.Text = text
            end
        end

        local chosen = {}
        for k, g in pairs(groups) do
            if Z.sel[k] then chosen[#chosen + 1] = k .. " ×" .. g.count end
        end
        table.sort(chosen)
        local line = "Total " .. total .. " objek • " .. #keys .. " jenis"
        if npc > 0 then line = line .. " • NPC dilewati: " .. npc end
        if #keys > MAX_ROWS then line = line .. " • " .. (#keys - MAX_ROWS) .. " jenis lain tidak ditampilkan" end
        line = line .. "\nTarget: " .. (#chosen > 0 and table.concat(chosen, ", ") or "(centang jenis di bawah)")
        SummaryLbl.Text = line
    end

    local function DoScan()
        local parts = GatherParts()
        if not parts then
            SummaryLbl.Text = "Atur zona dulu, lalu tekan SCAN."
            return nil
        end
        local groups, npc = BuildGroups(parts)
        ApplyGroups(groups, npc)
        return groups
    end

    Z.setAutoScan = function(on)
        Z.autoScan = on
        if on and not Z.scanThread then
            Z.scanThread = task.spawn(function()
                while Z.autoScan and not hubDestroyed do
                    local ok, err = pcall(DoScan)
                    if not ok and not Z.scanWarned then
                        Z.scanWarned = true
                        print("[Zone] Scan: " .. tostring(err))
                    end
                    task.wait(0.5)
                end
                Z.scanThread = nil
            end)
        end
    end

    -- ==================================================
    -- PENGAMBILAN
    -- ==================================================
    local function PartsOf(obj)
        if obj:IsA("BasePart") then return {obj} end
        local out = {}
        for _, d in ipairs(obj:GetDescendants()) do
            if d:IsA("BasePart") then
                out[#out + 1] = d
                if #out >= 6 then break end
            end
        end
        return out
    end

    local function ResolveMethod(obj)
        if Z.method ~= "auto" then return Z.method end
        if obj:FindFirstChildWhichIsA("ProximityPrompt", true) then return "prompt" end
        if obj:FindFirstChildWhichIsA("ClickDetector", true) then return "click" end
        return "touch"
    end

    -- tahan sebuah tombol sungguhan lewat VirtualInputManager (untuk prompt tanpa fireproximityprompt / tahan E)
    local function HoldKey(key, seconds)
        return pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(true, key, false, game)
            task.wait(seconds)
            vim:SendKeyEvent(false, key, false, game)
        end)
    end

    local function Pickup(obj)
        local root = GetHumanoidRootPart()
        if not root then return end
        local method = ResolveMethod(obj)
        local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
        -- tombol yang dipakai: milik prompt barang itu bila ada, kalau tidak E
        local key = prompt and prompt.KeyboardKeyCode or Enum.KeyCode.Unknown
        if key == Enum.KeyCode.Unknown then key = Enum.KeyCode.E end

        if method == "approach" then
            return                                       -- cukup didekati: barang terambil lewat jarak
        elseif method == "press" then
            HoldKey(key, 0.08)                           -- tekan sekali
        elseif method == "hold" then
            local secs = Z.holdTime
            if secs <= 0 then                            -- 0 = ikuti lama tahan milik prompt
                secs = prompt and (prompt.HoldDuration + 0.2) or 1.5
            end
            HoldKey(key, secs)
        elseif method == "prompt" then
            if not prompt or not prompt.Enabled then return end
            local ok = false
            if typeof(fireproximityprompt) == "function" then
                ok = pcall(fireproximityprompt, prompt)
            end
            if not ok then
                HoldKey(key, math.max(0.05, prompt.HoldDuration) + 0.15)   -- tekan / tahan sesuai prompt
            end
        elseif method == "click" then
            local cd = obj:FindFirstChildWhichIsA("ClickDetector", true)
            if cd and typeof(fireclickdetector) == "function" then pcall(fireclickdetector, cd) end
        else
            if typeof(firetouchinterest) == "function" then
                for _, part in ipairs(PartsOf(obj)) do
                    pcall(function()
                        firetouchinterest(root, part, 0)
                        firetouchinterest(root, part, 1)
                    end)
                end
            end
        end
    end

    -- ==================================================
    -- LOOP AUTO ZONA
    -- ==================================================
    local function SetRun(text)
        RunLbl.Text = "Status: " .. text .. "\nDiproses: " .. Z.stats.picked .. " (hilang dari game: " .. Z.stats.gone .. ")  |  Disetor: " .. Z.stats.deposits .. "x"
    end

    local function TeleportTo(pos)
        local root = GetHumanoidRootPart()
        if not root then return end
        root.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)) * root.CFrame.Rotation
        root.AssemblyLinearVelocity = Vector3.zero
    end

    local function RunLoop()
        local sinceDeposit = 0
        while Z.running and not hubDestroyed do
            local root = GetHumanoidRootPart()
            local parts = root and GatherParts() or nil
            if not root then
                SetRun("menunggu karakter...")
                task.wait(0.5)
            elseif not parts then
                SetRun("zona belum diatur")
                task.wait(0.5)
            else
                local groups, npc = BuildGroups(parts)
                ApplyGroups(groups, npc)
                local cands = {}
                for key, g in pairs(groups) do
                    if Z.sel[key] then
                        for _, it in ipairs(g.list) do
                            local pos = ItemPos(it)
                            if pos then cands[#cands + 1] = {obj = it, pos = pos, key = key} end
                        end
                    end
                end

                if #cands == 0 then
                    table.clear(Z.visited)
                    SetRun("menunggu barang muncul di zona...")
                    if not Contains(root.Position) then
                        local anchor = ZoneAnchor()          -- barang acak muncul selama pemain ada di zona
                        if anchor then TeleportTo(anchor) end
                    end
                    task.wait(0.4)
                else
                    local best, bestD = nil, math.huge
                    for _, c in ipairs(cands) do
                        if not Z.visited[c.obj] then
                            local d = (c.pos - root.Position).Magnitude
                            if d < bestD then best, bestD = c, d end
                        end
                    end
                    if not best then                          -- semua pernah dikunjungi tapi masih ada: ulangi dari awal
                        table.clear(Z.visited)
                        for _, c in ipairs(cands) do
                            local d = (c.pos - root.Position).Magnitude
                            if d < bestD then best, bestD = c, d end
                        end
                    end
                    Z.visited[best.obj] = true
                    SetRun("mengambil " .. best.key .. " (" .. #cands .. " target tersisa)")
                    TeleportTo(best.pos)
                    task.wait(0.15)
                    Pickup(best.obj)
                    task.wait(Z.pickDelay)
                    Z.stats.picked += 1
                    local char = LocalPlayer.Character
                    if not best.obj:IsDescendantOf(game) or (char and best.obj:IsDescendantOf(char)) then
                        Z.stats.gone += 1                -- benar-benar terambil (hilang atau menempel ke karakter)
                    end
                    sinceDeposit += 1

                    if Z.depositCF and sinceDeposit >= Z.depositEvery then
                        SetRun("menyetor ke titik setor...")
                        local r2 = GetHumanoidRootPart()
                        if r2 then
                            r2.CFrame = Z.depositCF
                            r2.AssemblyLinearVelocity = Vector3.zero
                        end
                        task.wait(Z.depositWait)
                        Z.stats.deposits += 1
                        sinceDeposit = 0
                    end
                end
            end
        end
    end

    local function StopZone(skipReturn)
        local was = Z.running
        Z.running = false
        if Z.thread then
            if Z.thread ~= coroutine.running() then pcall(task.cancel, Z.thread) end
            Z.thread = nil
        end
        RunBtn.Text = "▶ MULAI AUTO ZONA"
        RunBtn.BackgroundColor3 = BTN_GREEN
        if was then
            local origin = Z.origin
            Z.origin = nil
            if origin and not skipReturn and not hubDestroyed then
                local root = GetHumanoidRootPart()
                if root then
                    root.CFrame = origin + Vector3.new(0, 2, 0)      -- kembali ke posisi awal + 2 stud
                    root.AssemblyLinearVelocity = Vector3.zero
                end
            end
            if not hubDestroyed then SetRun("berhenti") end
        end
    end
    ZoneStop = StopZone

    local function StartZone()
        if Z.running then return end
        if not Z.kind or not Defined(Z.kind) then
            Flash(RunBtn, "⚠ Atur zona dulu", "▶ MULAI AUTO ZONA")
            return
        end
        if next(Z.sel) == nil then
            Flash(RunBtn, "⚠ Scan lalu centang jenis barang", "▶ MULAI AUTO ZONA")
            return
        end
        local root = GetHumanoidRootPart()
        if not root then return end
        StopCollectAll()                                   -- hindari rebutan kendali karakter
        if StopTeleport then StopTeleport(true) end
        Z.origin = root.CFrame
        Z.stats = {picked = 0, gone = 0, deposits = 0}
        table.clear(Z.visited)
        Z.running = true
        RunBtn.Text = "■ BERHENTI"
        RunBtn.BackgroundColor3 = BTN_RED
        Z.thread = task.spawn(function()
            local ok, err = xpcall(RunLoop, debug.traceback)
            if not ok then print("[Zone] Error: " .. tostring(err)) end
            Z.thread = nil
            StopZone()
        end)
    end

    -- ==================================================
    -- SAMBUNGKAN TOMBOL
    -- ==================================================
    for kind, btn in pairs(KindBtns) do
        btn.MouseButton1Click:Connect(function()
            if Defined(kind) then
                SetKind(kind)
            else
                Flash(btn, "belum diatur", btn.Text)
            end
        end)
    end

    DetectBtn.MouseButton1Click:Connect(Detect)
    TapBtn.MouseButton1Click:Connect(function()
        if Z.tapOn then StopTap() else StartTap() end
    end)
    PathAddBtn.MouseButton1Click:Connect(function()
        if PathBox.Text == "" then
            Flash(PathAddBtn, "isi path", "+ PATH")
            return
        end
        local n = AddFromPath(PathBox.Text)
        Flash(PathAddBtn, n > 0 and ("+" .. n .. " Part") or "tidak ketemu", "+ PATH")
    end)

    BtnA.MouseButton1Click:Connect(function()
        local root = GetHumanoidRootPart()
        if not root then return end
        Z.cA = root.Position
        if Z.cB then SetKind("box") else UpdateStatus() UpdateVisual() end
        Flash(BtnA, "A ✔", "Set Sudut A")
    end)
    BtnB.MouseButton1Click:Connect(function()
        local root = GetHumanoidRootPart()
        if not root then return end
        Z.cB = root.Position
        if Z.cA then SetKind("box") else UpdateStatus() UpdateVisual() end
        Flash(BtnB, "B ✔", "Set Sudut B")
    end)
    HBox.FocusLost:Connect(function()
        local v = tonumber(HBox.Text)
        if v then Z.extraH = math.max(0, v) end
        HBox.Text = Fmt(Z.extraH)
        UpdateStatus()
        UpdateVisual()
    end)
    BtnC.MouseButton1Click:Connect(function()
        local root = GetHumanoidRootPart()
        if not root then return end
        Z.center = root.Position
        SetKind("sphere")
        Flash(BtnC, "Tengah ✔", "Set Titik Tengah")
    end)
    RBox.FocusLost:Connect(function()
        local v = tonumber(RBox.Text)
        if v then Z.radius = math.max(1, v) end
        RBox.Text = Fmt(Z.radius)
        UpdateStatus()
        UpdateVisual()
    end)
    BtnPAdd.MouseButton1Click:Connect(function()
        local root = GetHumanoidRootPart()
        if not root then return end
        Z.poly[#Z.poly + 1] = root.Position
        if #Z.poly >= 3 then SetKind("poly") else UpdateStatus() UpdateVisual() end
        Flash(BtnPAdd, "Titik " .. #Z.poly .. " ✔", "+ Titik Poligon (posisi sekarang)")
    end)
    BtnPReset.MouseButton1Click:Connect(function()
        table.clear(Z.poly)
        if Z.kind == "poly" then
            SetKind(FallbackKind())
        else
            UpdateStatus()
            UpdateVisual()
        end
    end)
    BtnClear.MouseButton1Click:Connect(function()
        StopZone()
        StopTap()
        ClearCands()
        for _, p in ipairs(Z.parts) do Z.partSet[p] = nil end
        table.clear(Z.parts)
        Z.cA, Z.cB, Z.center = nil, nil, nil
        table.clear(Z.poly)
        SetKind(nil)
        SummaryLbl.Text = "Atur zona dulu, lalu tekan SCAN."
    end)

    ScanBtn.MouseButton1Click:Connect(function()
        if not DoScan() then Flash(ScanBtn, "⚠ Atur zona dulu", "🔄 SCAN") end
    end)
    MaxBox.FocusLost:Connect(function()
        local v = tonumber(MaxBox.Text)
        if v then Z.maxSize = math.max(1, v) end
        MaxBox.Text = Fmt(Z.maxSize)
    end)

    local function BindNum(box, field, minv)
        box.FocusLost:Connect(function()
            local v = tonumber(box.Text)
            if v then Z[field] = math.max(v, minv) end
            box.Text = Fmt(Z[field])
        end)
    end
    BindNum(PickBox, "pickDelay", 0)
    BindNum(HoldBox, "holdTime", 0)
    BindNum(EveryBox, "depositEvery", 1)
    BindNum(WaitBox, "depositWait", 0)

    BtnDep.MouseButton1Click:Connect(function()
        local root = GetHumanoidRootPart()
        if not root then return end
        Z.depositCF = root.CFrame
        local p = root.Position
        DepLbl.Text = string.format("Titik setor: %.0f, %.0f, %.0f", p.X, p.Y, p.Z)
        UpdateVisual()
    end)
    BtnDepClr.MouseButton1Click:Connect(function()
        Z.depositCF = nil
        DepLbl.Text = "Titik setor: belum diatur (barang tidak disetor)"
        UpdateVisual()
    end)

    RunBtn.MouseButton1Click:Connect(function()
        if Z.running then StopZone() else StartZone() end
    end)

    -- Bersih saat Shutdown: berhenti tanpa teleport, putus semua koneksi, buang visual
    table.insert(cleanups, function()
        Z.autoScan = false
        StopZone(true)
        StopTap()
        if Z.vis then
            Z.vis:Destroy()
            Z.vis = nil
        end
        ZoneStop = nil
    end)

    UpdateStatus()
end)()

-- ========== GLOBAL CONTROL REMOTE ==========
StartAllBtn.MouseButton1Click:Connect(function()
    local gDelay = tonumber(GlobalDelayBox.Text) or 0.5
    for _, sd in ipairs(slots) do
        if not sd.locked then
            sd.delayBox.Text = tostring(gDelay)
            sd.start()
        end
    end
end)

local function StopEverything()
    for _, sd in ipairs(slots) do
        sd.stop()
    end
    StopCollectAll()
    if StopTeleport then StopTeleport() end
    if ZoneStop then ZoneStop() end
end

StopAllBtn.MouseButton1Click:Connect(StopEverything)
HomeStopAllBtn.MouseButton1Click:Connect(StopEverything)

-- Anti‑AFK (cegah kick karena diam terlalu lama)
AntiAfkBtn.MouseButton1Click:Connect(function()
    if antiAfkConn then
        antiAfkConn:Disconnect()
        antiAfkConn = nil
        AntiAfkBtn.Text = "🛡 ANTI‑AFK: OFF"
        AntiAfkBtn.BackgroundColor3 = UNLOCK_COLOR
    else
        antiAfkConn = LocalPlayer.Idled:Connect(function()
            pcall(function()
                local vu = game:GetService("VirtualUser")
                vu:CaptureController()
                vu:ClickButton2(Vector2.new())
            end)
        end)
        AntiAfkBtn.Text = "🛡 ANTI‑AFK: ON"
        AntiAfkBtn.BackgroundColor3 = BTN_GREEN
    end
end)

-- ========== TAB SWITCH ==========
local function SwitchTab(tab)
    TabHomeContainer.Visible = (tab == "home")
    TabRemoteContainer.Visible = (tab == "remote")
    TabCollectContainer.Visible = (tab == "collect")
    TabTeleportContainer.Visible = (tab == "teleport")
    TabZoneContainer.Visible = (tab == "zone")
    TabHomeBtn.BackgroundColor3 = (tab == "home") and TAB_ACTIVE or TAB_IDLE
    TabRemoteBtn.BackgroundColor3 = (tab == "remote") and TAB_ACTIVE or TAB_IDLE
    TabCollectBtn.BackgroundColor3 = (tab == "collect") and TAB_ACTIVE or TAB_IDLE
    TabTeleportBtn.BackgroundColor3 = (tab == "teleport") and TAB_ACTIVE or TAB_IDLE
    TabZoneBtn.BackgroundColor3 = (tab == "zone") and TAB_ACTIVE or TAB_IDLE
end

TabHomeBtn.MouseButton1Click:Connect(function() SwitchTab("home") end)
TabRemoteBtn.MouseButton1Click:Connect(function() SwitchTab("remote") end)
TabCollectBtn.MouseButton1Click:Connect(function() SwitchTab("collect") end)
TabTeleportBtn.MouseButton1Click:Connect(function() SwitchTab("teleport") end)
TabZoneBtn.MouseButton1Click:Connect(function() SwitchTab("zone") end)
SwitchTab("home")

-- Status singkat di Tab Home
task.spawn(function()
    while ScreenGui.Parent and not hubDestroyed do
        local remoteActive = 0
        for _, sd in ipairs(slots) do
            if sd.active then remoteActive += 1 end
        end
        local collectN, collectActive, followN, followActive = 0, 0, 0, 0
        for _, s in ipairs(collectSlots) do
            if s.kind == "follow" then
                followN += 1
                if s.active then followActive += 1 end
            else
                collectN += 1
                if s.active then collectActive += 1 end
            end
        end
        HomeStatus.Text = string.format(
            "Slot Remote: %d (aktif: %d)\nSlot Collect: %d (aktif: %d) | Follow: %d (aktif: %d)\nAntrean Collect: %s\nTitik Teleport: %d | Auto Farm: %s",
            #slots, remoteActive, collectN, collectActive, followN, followActive, QueueText(),
            #TP.points, TP.farmActive and "AKTIF" or "mati"
        )
        task.wait(0.5)
    end
end)

-- ========== SIMPLE SPY + COBALT ==========
SimpleSpyBtn.MouseButton1Click:Connect(function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/bochilascript/ROBLOX/main/simplespy.lua", true))()
    end)
end)

CobaltSpyBtn.MouseButton1Click:Connect(function()
    pcall(function()
        loadstring(game:HttpGet("https://gitlab.com/upio/cobalt/-/releases/permalink/latest/downloads/Cobalt.luau"))()
    end)
end)

-- ========== HUB LOCK / MINIMIZE / DESTROY ==========
local function SetMinimized(state)
    hubMinimized = state
    MainFrame.Visible = not state
    ShrimpLogo.Visible = state
    HubMinBtn.Text = state and "+" or "-"
end

HubMinBtn.MouseButton1Click:Connect(function()
    SetMinimized(not hubMinimized)
end)

-- Shortcut keyboard: RightShift untuk sembunyikan / tampilkan hub
Track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not ScreenGui.Parent then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        SetMinimized(not hubMinimized)
    end
end))

-- Klik logo untuk membuka hub lagi (tidak terpicu saat logo di-drag)
local logoMoved = false
ShrimpLogo.MouseButton1Click:Connect(function()
    if logoMoved then return end
    SetMinimized(false)
end)

HubLockBtn.MouseButton1Click:Connect(function()
    hubLocked = not hubLocked
    if hubLocked then
        HubLockBtn.Text = "🔒"
        HubLockBtn.BackgroundColor3 = LOCK_COLOR
    else
        HubLockBtn.Text = "🔓"
        HubLockBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
    end
end)

-- Matikan semuanya: thread, tween, noclip, koneksi, lalu GUI
local function Shutdown()
    if hubDestroyed then return end
    hubDestroyed = true
    for _, sd in ipairs(slots) do
        pcall(sd.stop)
    end
    pcall(StopCollectAll)
    if StopTeleport then pcall(StopTeleport) end
    if TP.delThread then
        pcall(task.cancel, TP.delThread)
        TP.delThread = nil
    end
    pcall(NoclipReset)
    pcall(ESP.Clear)
    for _, fn in ipairs(cleanups) do pcall(fn) end
    if TP.markThread then
        pcall(task.cancel, TP.markThread)
        TP.markThread = nil
    end
    if TP.markFolder then
        pcall(function() TP.markFolder:Destroy() end)
        TP.markFolder = nil
    end
    if antiAfkConn then
        antiAfkConn:Disconnect()
        antiAfkConn = nil
    end
    for _, c in ipairs(globalConns) do
        pcall(function() c:Disconnect() end)
    end
    globalConns = {}
    pcall(function() ScreenGui:Destroy() end)
    pcall(function() LogoGui:Destroy() end)
    -- lepas referensi ke instance yang sudah dihancurkan, dan jangan biarkan getgenv menahan closure ini
    table.clear(slots)
    table.clear(collectSlots)
    table.clear(TP.points)
    table.clear(TP.seq)
    if env.ShrimpHubShutdown == Shutdown then
        env.ShrimpHubShutdown = nil
    end
end
env.ShrimpHubShutdown = Shutdown

-- Respawn: karakter lama hilang, jadi buang state yang menempel padanya
Track(LocalPlayer.CharacterAdded:Connect(function()
    if collectTween then
        pcall(function() collectTween:Cancel() end)
    end
    NoclipReset()
    Follow.engaged, Follow.origin = false, nil     -- karakter baru: posisi semula yang lama tidak berlaku lagi
    if TP.onRespawn then TP.onRespawn() end
end))

DestBtn.MouseButton1Click:Connect(Shutdown)

-- ========== DRAG (hanya lewat Header, mati saat hub dikunci) ==========
local dragging, dragStart, startPos = false, nil, nil
Header.InputBegan:Connect(function(input)
    if hubLocked then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

local logoDrag, logoDragStart, logoStartPos = false, nil, nil
ShrimpLogo.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        logoDrag = true
        logoMoved = false
        logoDragStart = input.Position
        logoStartPos = ShrimpLogo.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                logoDrag = false
                task.delay(0.05, function() logoMoved = false end)
            end
        end)
    end
end)

Track(UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    if dragging and not hubLocked then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    elseif logoDrag then
        local delta = input.Position - logoDragStart
        if delta.Magnitude > 4 then logoMoved = true end
        ShrimpLogo.Position = UDim2.new(logoStartPos.X.Scale, logoStartPos.X.Offset + delta.X, logoStartPos.Y.Scale, logoStartPos.Y.Offset + delta.Y)
    end
end))
