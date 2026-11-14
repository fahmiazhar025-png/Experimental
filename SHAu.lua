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
    if gui.Name == "Shrimp_Hub_Auto" or gui.Name == "Shrimp_Hub_Logo" then
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
local antiAfkConn = nil

-- Auto-Teleport (state)
local TP = {
    points = {}, seq = {}, counter = 0,
    useTween = false, pickMode = false, busy = false,
    farmActive = false, farmThread = nil, manualThread = nil,
    tween = nil, delThread = nil, onRespawn = nil,
}
local TabTeleportContainer = nil
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

local function ResolveSafePath(pathStr)
    if not pathStr or pathStr == "" then return nil end
    local parts = string.split(pathStr, ".")
    local current = game
    for _, seg in ipairs(parts) do
        if not current then return nil end
        current = current:FindFirstChild(seg)
    end
    if not current or not current:IsDescendantOf(game) then
        return nil
    end
    return current
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

local TAB_H = 42
local TAB_GAP = 50
local function CreateTabButton(text, order)
    local y = 10 + (order - 1) * TAB_GAP

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
StartAllBtn.Size = UDim2.new(0.23, 0, 1, 0)
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
StopAllBtn.Size = UDim2.new(0.23, 0, 1, 0)
StopAllBtn.Position = UDim2.new(0.52, 0, 0, 0)
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
CollectScrollFrame.Size = UDim2.new(1, 0, 1, -40)
CollectScrollFrame.Position = UDim2.new(0, 0, 0, 38)
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

local function BuildQueue()
    local pri, normal = {}, {}
    for _, s in ipairs(collectSlots) do
        if s.active then
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
        if s.active then anyActive = true break end
    end
    if not anyActive then
        StopCollectScheduler()
    end
end

local function StopCollectAll()
    for _, s in ipairs(collectSlots) do
        if s.active then
            s.active = false
            SetSlotButton(s, false)
        end
    end
    StopCollectScheduler()
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

    local targetObj = ResolveSafePath(path)
    if not targetObj then
        print("[Collect Slot " .. slotData.id .. "] Target path tidak ditemukan")
        return
    end

    local targetPos = GetTargetPosition(targetObj)
    if not targetPos then
        print("[Collect Slot " .. slotData.id .. "] Tidak bisa baca posisi target")
        return
    end

    local yLimit = tonumber(slotData.yLimitBox.Text)
    if yLimit ~= nil and targetPos.Y < yLimit then
        print(string.format("[Collect Slot %d] Target Y(%.2f) < batas %.2f → dilewati", slotData.id, targetPos.Y, yLimit))
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
        end, debug.traceback)
        if not ok then
            print("[Collect] Error Runtime: " .. tostring(err))
        end
        StopCollectAll()
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
    collectStartCounter += 1
    slotData.startOrder = collectStartCounter
    slotData.active = true
    SetSlotButton(slotData, true)
    EnsureCollectScheduler()
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

-- ========== FUNGSI BUAT SLOT COLLECT ==========
local function CreateCollectSlot()
    collectSlotCount += 1
    local slotId = collectSlotCount

    local SlotWrapper = Instance.new("Frame")
    SlotWrapper.Parent = CollectScrollFrame
    SlotWrapper.Size = UDim2.new(1, -12, 0, 112)
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

    -- ★ Bintang prioritas (kiri atas slot)
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

    local SlotNameBox = Instance.new("TextBox")
    SlotNameBox.Parent = SlotHeader
    SlotNameBox.Size = UDim2.new(1, -116, 1, -4)
    SlotNameBox.Position = UDim2.new(0, 30, 0, 2)
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
    SlotContent.Size = UDim2.new(1, -6, 1, -34)
    SlotContent.Position = UDim2.new(0, 3, 0, 32)
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

    local DLabel = Instance.new("TextLabel")
    DLabel.Parent = SlotContent
    DLabel.Size = UDim2.new(0.05, 0, 0, 18)
    DLabel.Position = UDim2.new(0, 0, 0, 52)
    DLabel.BackgroundTransparency = 1
    DLabel.Text = "D:"
    DLabel.TextColor3 = TEXT_DARK
    DLabel.Font = Enum.Font.GothamBold
    DLabel.TextSize = 9

    local DelayBox = Instance.new("TextBox")
    DelayBox.Parent = SlotContent
    DelayBox.Size = UDim2.new(0.10, 0, 0, 18)
    DelayBox.Position = UDim2.new(0.06, 0, 0, 52)
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
    YLabel.Position = UDim2.new(0.18, 0, 0, 52)
    YLabel.BackgroundTransparency = 1
    YLabel.Text = "<Y:"
    YLabel.TextColor3 = TEXT_DARK
    YLabel.Font = Enum.Font.GothamBold
    YLabel.TextSize = 9

    local YLimitBox = Instance.new("TextBox")
    YLimitBox.Parent = SlotContent
    YLimitBox.Size = UDim2.new(0.14, 0, 0, 18)
    YLimitBox.Position = UDim2.new(0.26, 0, 0, 52)
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
    ResetBtn.Position = UDim2.new(0.42, 0, 0, 52)
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
    StartStopBtn.Position = UDim2.new(0.60, 0, 0, 52)
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

    local slotData = {
        id = slotId,
        wrapper = SlotWrapper,
        content = SlotContent,
        nameBox = SlotNameBox,
        dexPath = DexPathBox,
        delayBox = DelayBox,
        yLimitBox = YLimitBox,
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
    }
    table.insert(collectSlots, slotData)

    local function UpdateStar()
        if slotData.priority then
            StarBtn.Text = "★"
            StarBtn.BackgroundColor3 = STAR_ON
        else
            StarBtn.Text = "☆"
            StarBtn.BackgroundColor3 = UNLOCK_COLOR
        end
    end

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

    -- RESET: hentikan slot lalu kembalikan semua isian ke bawaan (termasuk bintang)
    ResetBtn.MouseButton1Click:Connect(function()
        if slotData.locked then return end
        StopCollectSlot(slotData)
        DexPathBox.Text = ""
        DelayBox.Text = "0.5"
        YLimitBox.Text = ""
        slotData.mode = "teleport"
        ModeBtn.Text = "MODE: TELEPORT"
        slotData.priority = false
        UpdateStar()
    end)

    StartStopBtn.MouseButton1Click:Connect(function()
        if slotData.active then
            StopCollectSlot(slotData)
        else
            StartCollectSlot(slotData)
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
    end)

    SlotMinBtn.MouseButton1Click:Connect(function()
        slotData.minimized = not slotData.minimized
        if slotData.minimized then
            SlotMinBtn.Text = "+"
            SlotContent.Visible = false
            SlotWrapper.Size = UDim2.new(1, -12, 0, 36)
        else
            SlotMinBtn.Text = "−"
            SlotContent.Visible = true
            SlotWrapper.Size = UDim2.new(1, -12, 0, 112)
        end
    end)

    SlotDestroyBtn.MouseButton1Click:Connect(function()
        StopCollectSlot(slotData)
        for i, v in ipairs(collectSlots) do
            if v.id == slotData.id then
                table.remove(collectSlots, i)
                break
            end
        end
        SlotWrapper:Destroy()
    end)

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
do
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

    local function NewRow(card, order, height)
        local row = Instance.new("Frame")
        row.Parent = card
        row.Size = UDim2.new(1, 0, 0, height)
        row.BackgroundTransparency = 1
        row.LayoutOrder = order
        return row
    end

    -- ===== Kartu 1: Posisi & Teleport =====
    local CardPos = NewCard(1, "📍 POSISI & TELEPORT")
    local RowCopy = NewRow(CardPos, 1, 24)
    local CopyPosBtn = MakeButton(RowCopy, "📋 SALIN POSISI SEKARANG", BTN_TEAL, UDim2.new(1, 0, 1, 0))
    local RowPos = NewRow(CardPos, 2, 24)
    local PosBox = MakeBox(RowPos, "X, Y, Z (pisah koma)", "", UDim2.new(0.62, 0, 1, 0))
    local GoPosBtn = MakeButton(RowPos, "TELEPORT", BTN_ORANGE, UDim2.new(0.36, 0, 1, 0), UDim2.new(0.64, 0, 0, 0))

    -- ===== Kartu 2: Cara Perpindahan =====
    local CardMove = NewCard(2, "🚶 CARA PERPINDAHAN")
    local RowMode = NewRow(CardMove, 1, 26)
    local ModeBtn = MakeButton(RowMode, "⚡ TELEPORT LANGSUNG", BTN_ORANGE, UDim2.new(0.62, 0, 1, 0))
    local StopMoveBtn = MakeButton(RowMode, "⏹ BERHENTI", BTN_GRAY, UDim2.new(0.36, 0, 1, 0), UDim2.new(0.64, 0, 0, 0))
    local RowSpeed = NewRow(CardMove, 2, 22)
    MakeLabel(RowSpeed, "Kec:", UDim2.new(0.12, 0, 1, 0))
    local SpeedBox = MakeBox(RowSpeed, "30", "30", UDim2.new(0.30, 0, 1, 0), UDim2.new(0.13, 0, 0, 0))
    MakeLabel(RowSpeed, "Tinggi:", UDim2.new(0.16, 0, 1, 0), UDim2.new(0.50, 0, 0, 0))
    local HeightBox = MakeBox(RowSpeed, "12", "12", UDim2.new(0.30, 0, 1, 0), UDim2.new(0.68, 0, 0, 0))

    -- ===== Kartu 3: Titik Tersimpan =====
    local CardPoints = NewCard(3, "📋 TITIK TERSIMPAN")
    local RowAdd = NewRow(CardPoints, 1, 24)
    local AddPointBtn = MakeButton(RowAdd, "➕ SIMPAN POSISI SEKARANG", BTN_GREEN, UDim2.new(1, 0, 1, 0))
    local RowDel = NewRow(CardPoints, 9999, 24)
    local DelAllBtn = MakeButton(RowDel, "🗑 HAPUS SEMUA TITIK", BTN_RED, UDim2.new(1, 0, 1, 0))

    -- ===== Kartu 4: Auto Farm Berantai =====
    local CardFarm = NewCard(4, "🔁 AUTO FARM BERANTAI")
    local RowPick = NewRow(CardFarm, 1, 24)
    local PickBtn = MakeButton(RowPick, "📝 PILIH URUTAN TITIK", BTN_BLUE, UDim2.new(1, 0, 1, 0))
    local RowJeda = NewRow(CardFarm, 2, 22)
    MakeLabel(RowJeda, "Jeda (detik):", UDim2.new(0.40, 0, 1, 0))
    local JedaBox = MakeBox(RowJeda, "3", "3", UDim2.new(0.30, 0, 1, 0), UDim2.new(0.42, 0, 0, 0))
    local RowFarm = NewRow(CardFarm, 3, 26)
    local FarmBtn = MakeButton(RowFarm, "▶ MULAI AUTO FARM", BTN_GREEN, UDim2.new(1, 0, 1, 0), nil, 10)

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
    local function MoveTo(targetCF)
        local root = GetHumanoidRootPart()
        if not root then return false end
        SetBusy(true)

        if not TP.useTween then
            SetNoclip(false)
            root.CFrame = targetCF
            root.AssemblyLinearVelocity = Vector3.zero
            SetBusy(false)
            return true
        end

        local speed = math.max(1, tonumber(SpeedBox.Text) or 30)
        local lift = tonumber(HeightBox.Text) or 12
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

    -- Hentikan semua perpindahan + Auto Farm, diam di posisi sekarang
    StopTeleport = function()
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
    end

    local function RunManual(cf)
        StopTeleport()   -- perintah manual menggantikan gerakan sebelumnya
        TP.manualThread = task.spawn(function()
            MoveTo(cf)
            TP.manualThread = nil
        end)
    end

    -- Tanda urutan (+ / 1 / 2 / 3 ...) di tiap titik
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
        end
    end

    local function AddPoint(cf)
        TP.counter += 1
        local pt = {id = TP.counter, name = "Titik " .. TP.counter, cframe = cf}
        table.insert(TP.points, pt)

        local row = Instance.new("Frame")
        row.Name = "Point_" .. pt.id
        row.Parent = CardPoints
        row.Size = UDim2.new(1, 0, 0, 28)
        row.BackgroundColor3 = SLOT_HEADER
        row.LayoutOrder = 10 + pt.id
        Corner(row, 5)
        pt.row = row

        local seqBtn = MakeButton(row, "+", BTN_ORANGE, UDim2.new(0, 22, 0, 22), UDim2.new(0, 4, 0.5, -11), 11)
        seqBtn.Visible = false
        pt.seqBtn = seqBtn

        local nameBox = MakeBox(row, "Nama titik", pt.name, UDim2.new(1, -100, 0, 22), UDim2.new(0, 30, 0.5, -11))
        local goBtn = MakeButton(row, "GO", BTN_TEAL, UDim2.new(0, 34, 0, 22), UDim2.new(1, -66, 0.5, -11), 10)
        local delBtn = MakeButton(row, "X", Color3.fromRGB(214, 70, 70), UDim2.new(0, 22, 0, 22), UDim2.new(1, -26, 0.5, -11), 10)

        nameBox.FocusLost:Connect(function()
            pt.name = nameBox.Text
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
            RunManual(pt.cframe)
        end)

        delBtn.MouseButton1Click:Connect(function()
            local i = table.find(TP.points, pt)
            if i then table.remove(TP.points, i) end
            local j = table.find(TP.seq, pt)
            if j then table.remove(TP.seq, j) end
            row:Destroy()
            RefreshSeq()
        end)

        RefreshSeq()
    end

    local function ClearAllPoints()
        for _, pt in ipairs(TP.points) do
            if pt.row then pt.row:Destroy() end
        end
        table.clear(TP.points)
        table.clear(TP.seq)
        RefreshSeq()
    end

    -- Auto Farm berantai: titik-titik urutan dikunjungi berulang
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
        if not GetHumanoidRootPart() then return end

        TP.farmActive = true
        UpdateFarmBtn()
        TP.farmThread = task.spawn(function()
            while TP.farmActive and not hubDestroyed do
                local seq = table.clone(TP.seq)   -- perubahan urutan berlaku di putaran berikutnya
                if #seq == 0 then break end
                for _, pt in ipairs(seq) do
                    if not TP.farmActive or hubDestroyed then break end
                    MoveTo(pt.cframe)
                    local jeda = math.max(0.5, tonumber(JedaBox.Text) or 3)
                    task.wait(jeda)
                end
            end
            TP.farmActive = false
            TP.farmThread = nil
            UpdateFarmBtn()
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
            task.delay(1.2, function() GoPosBtn.Text = "TELEPORT" end)
            return
        end
        RunManual(CFrame.new(nums[1], nums[2], nums[3]))
    end)

    ModeBtn.MouseButton1Click:Connect(function()
        TP.useTween = not TP.useTween
        if TP.useTween then
            ModeBtn.Text = "🚶 JALAN + NOCLIP"
            ModeBtn.BackgroundColor3 = BTN_BLUE
        else
            SetNoclip(false)
            ModeBtn.Text = "⚡ TELEPORT LANGSUNG"
            ModeBtn.BackgroundColor3 = BTN_ORANGE
        end
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
end

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
    TabHomeBtn.BackgroundColor3 = (tab == "home") and TAB_ACTIVE or TAB_IDLE
    TabRemoteBtn.BackgroundColor3 = (tab == "remote") and TAB_ACTIVE or TAB_IDLE
    TabCollectBtn.BackgroundColor3 = (tab == "collect") and TAB_ACTIVE or TAB_IDLE
    TabTeleportBtn.BackgroundColor3 = (tab == "teleport") and TAB_ACTIVE or TAB_IDLE
end

TabHomeBtn.MouseButton1Click:Connect(function() SwitchTab("home") end)
TabRemoteBtn.MouseButton1Click:Connect(function() SwitchTab("remote") end)
TabCollectBtn.MouseButton1Click:Connect(function() SwitchTab("collect") end)
TabTeleportBtn.MouseButton1Click:Connect(function() SwitchTab("teleport") end)
SwitchTab("home")

-- Status singkat di Tab Home
task.spawn(function()
    while ScreenGui.Parent and not hubDestroyed do
        local remoteActive = 0
        for _, sd in ipairs(slots) do
            if sd.active then remoteActive += 1 end
        end
        local collectActive = 0
        for _, s in ipairs(collectSlots) do
            if s.active then collectActive += 1 end
        end
        HomeStatus.Text = string.format(
            "Slot Remote: %d (aktif: %d)\nSlot Collect: %d (aktif: %d)\nAntrean Collect: %s\nTitik Teleport: %d | Auto Farm: %s",
            #slots, remoteActive, #collectSlots, collectActive, QueueText(),
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
