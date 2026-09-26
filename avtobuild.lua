-- ============================================================
-- AVTO BUILD for Build a Boat for Treasure
-- Загружает .build файлы из папки workspace и строит по ним
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- === ПРОВЕРКА НАЛИЧИЯ ФУНКЦИЙ ФАЙЛОВОЙ СИСТЕМЫ ===
local hasFileSystem = (readfile and writefile and listfiles and isfile and isfolder)

if not hasFileSystem then
    warn("[AVTO BUILD] Файловые функции недоступны. Убедись, что используешь Xeno или другой исполнитель с поддержкой файлов.")
    return
end

-- === НАСТРОЙКИ ===
local BUILD_FOLDER = "workspace"  -- Папка, где лежат .build файлы
local PLACE_DELAY = 0.05          -- Задержка между блоками (сек)

-- === ПОИСК REMOTE-ФУНКЦИИ ДЛЯ РАЗМЕЩЕНИЯ БЛОКОВ ===
local function findPlaceBlockRemote()
    -- Пытаемся найти RemoteFunction по типичным именам
    local possibleNames = {"PlaceBlock", "Place", "BuildBlock", "RemoteFunction"}
    for _, name in ipairs(possibleNames) do
        local remote = ReplicatedStorage:FindFirstChild(name, true)
        if remote and remote:IsA("RemoteFunction") then
            return remote
        end
    end
    -- Если не нашли — возвращаем nil
    return nil
end

local placeBlockRemote = findPlaceBlockRemote()

if not placeBlockRemote then
    warn("[AVTO BUILD] RemoteFunction для размещения блоков не найдена. Строительство может не работать.")
end

-- === ФУНКЦИЯ РАЗМЕЩЕНИЯ ОДНОГО БЛОКА ===
local function placeBlock(blockType, cframe)
    if not placeBlockRemote then return end

    local args = {
        [1] = "PlaceBlock",
        [2] = {
            blockType = blockType,
            cframe = cframe
        }
    }

    local success, err = pcall(function()
        placeBlockRemote:InvokeServer(unpack(args))
    end)

    if not success then
        warn("[AVTO BUILD] Ошибка размещения блока:", err)
    end
end

-- === ЗАГРУЗКА И ПАРСИНГ .BUILD ФАЙЛА ===
local function loadBuildFile(fileName)
    local path = BUILD_FOLDER .. "/" .. fileName

    if not isfile(path) then
        return nil, "Файл не найден: " .. path
    end

    local content = readfile(path)
    if not content or content == "" then
        return nil, "Файл пуст или не читается"
    end

    -- Пытаемся распарсить JSON
    local success, data = pcall(function()
        return HttpService:JSONDecode(content)
    end)

    if not success then
        return nil, "Ошибка парсинга JSON: " .. tostring(data)
    end

    -- Ожидаем, что data — массив блоков
    if type(data) ~= "table" then
        return nil, "Неверный формат .build: ожидался массив блоков"
    end

    return data, nil
end

-- === ФУНКЦИЯ СТРОИТЕЛЬСТВА ПОСТРОЙКИ ===
local function buildFromData(blocks, originCFrame)
    if not blocks or #blocks == 0 then
        warn("[AVTO BUILD] Нет блоков для строительства")
        return
    end

    -- Определяем базовую позицию (перед игроком)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        warn("[AVTO BUILD] Персонаж не найден")
        return
    end

    local baseCFrame = originCFrame or (hrp.CFrame * CFrame.new(0, 0, -10))

    print("[AVTO BUILD] Начинаю строительство. Блоков:", #blocks)

    local builtCount = 0
    for i, blockData in ipairs(blocks) do
        -- Поддерживаем разные варианты полей
        local blockType = blockData.blockType or blockData.type or blockData.BlockType
        local pos = blockData.position or blockData.pos or blockData.Position
        local rot = blockData.rotation or blockData.rot or blockData.Rotation

        if blockType and pos then
            -- Преобразуем позицию в CFrame относительно базовой точки
            local offset = Vector3.new(pos.x or pos[1] or 0, pos.y or pos[2] or 0, pos.z or pos[3] or 0)
            local blockCFrame = baseCFrame * CFrame.new(offset)

            -- Применяем поворот, если есть
            if rot then
                local rx = math.rad(rot.x or rot[1] or 0)
                local ry = math.rad(rot.y or rot[2] or 0)
                local rz = math.rad(rot.z or rot[3] or 0)
                blockCFrame = blockCFrame * CFrame.Angles(rx, ry, rz)
            end

            placeBlock(blockType, blockCFrame)
            builtCount = builtCount + 1

            -- Задержка, чтобы не забанили за спам
            task.wait(PLACE_DELAY)
        end
    end

    print("[AVTO BUILD] Готово! Построено блоков:", builtCount)
end

-- === GUI ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AVTO_BUILD_Gui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 300, 0, 400)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = mainFrame

-- Заголовок
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -60, 1, 0)
titleLabel.Position = UDim2.new(0, 15, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "AVTO BUILD | .build Loader"
titleLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

-- Кнопка закрытия
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -34, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

-- Кнопка "Сканировать"
local scanBtn = Instance.new("TextButton")
scanBtn.Size = UDim2.new(1, -30, 0, 35)
scanBtn.Position = UDim2.new(0, 15, 0, 55)
scanBtn.BackgroundColor3 = Color3.fromRGB(50, 80, 150)
scanBtn.Text = "🔍 Сканировать папку workspace"
scanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
scanBtn.Font = Enum.Font.Gotham
scanBtn.TextSize = 13
scanBtn.BorderSizePixel = 0
scanBtn.Parent = mainFrame

local scanCorner = Instance.new("UICorner")
scanCorner.CornerRadius = UDim.new(0, 6)
scanCorner.Parent = scanBtn

-- Скролл-фрейм для списка файлов
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -30, 0, 220)
scrollFrame.Position = UDim2.new(0, 15, 0, 100)
scrollFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.Parent = mainFrame

local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 6)
scrollCorner.Parent = scrollFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

-- Переменная для хранения выбранного файла
local selectedFile = nil

-- Функция обновления списка файлов
local function refreshFileList()
    -- Очищаем старые кнопки
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    -- Получаем список файлов в папке
    local success, files = pcall(function()
        return listfiles(BUILD_FOLDER)
    end)

    if not success or not files then
        local errorLabel = Instance.new("TextLabel")
        errorLabel.Size = UDim2.new(1, 0, 0, 30)
        errorLabel.BackgroundTransparency = 1
        errorLabel.Text = "❌ Не удалось прочитать папку workspace"
        errorLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        errorLabel.Font = Enum.Font.Gotham
        errorLabel.TextSize = 12
        errorLabel.Parent = scrollFrame
        return
    end

    local buildFiles = {}
    for _, file in ipairs(files) do
        if file:match("%.build$") then
            table.insert(buildFiles, file)
        end
    end

    if #buildFiles == 0 then
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Size = UDim2.new(1, 0, 0, 30)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Text = "📂 Нет .build файлов в workspace"
        emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        emptyLabel.Font = Enum.Font.Gotham
        emptyLabel.TextSize = 12
        emptyLabel.Parent = scrollFrame
        return
    end

    -- Создаём кнопки для каждого файла
    local yPos = 0
    for i, fileName in ipairs(buildFiles) do
        local fileBtn = Instance.new("TextButton")
        fileBtn.Size = UDim2.new(1, -8, 0, 32)
        fileBtn.Position = UDim2.new(0, 4, 0, yPos)
        fileBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        fileBtn.Text = "📄 " .. fileName
        fileBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
        fileBtn.Font = Enum.Font.Gotham
        fileBtn.TextSize = 12
        fileBtn.BorderSizePixel = 0
        fileBtn.TextXAlignment = Enum.TextXAlignment.Left
        fileBtn.Parent = scrollFrame

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = fileBtn

        fileBtn.MouseButton1Click:Connect(function()
            selectedFile = fileName
            -- Подсвечиваем выбранный
            for _, other in ipairs(scrollFrame:GetChildren()) do
                if other:IsA("TextButton") then
                    other.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
                end
            end
            fileBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 180)
            print("[AVTO BUILD] Выбран файл:", fileName)
        end)

        yPos = yPos + 36
    end

    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yPos)
end

-- Кнопка "Строить"
local buildBtn = Instance.new("TextButton")
buildBtn.Size = UDim2.new(1, -30, 0, 40)
buildBtn.Position = UDim2.new(0, 15, 0, 335)
buildBtn.BackgroundColor3 = Color3.fromRGB(50, 140, 60)
buildBtn.Text = "🏗️ Построить выбранный .build"
buildBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
buildBtn.Font = Enum.Font.GothamBold
buildBtn.TextSize = 14
buildBtn.BorderSizePixel = 0
buildBtn.Parent = mainFrame

local buildCorner = Instance.new("UICorner")
buildCorner.CornerRadius = UDim.new(0, 6)
buildCorner.Parent = buildBtn

-- Обработчик сканирования
scanBtn.MouseButton1Click:Connect(function()
    refreshFileList()
    print("[AVTO BUILD] Список файлов обновлён")
end)

-- Обработчик строительства
buildBtn.MouseButton1Click:Connect(function()
    if not selectedFile then
        warn("[AVTO BUILD] Сначала выбери .build файл")
        return
    end

    local blocks, err = loadBuildFile(selectedFile)
    if not blocks then
        warn("[AVTO BUILD] Ошибка загрузки:", err)
        return
    end

    -- Запускаем строительство
    buildFromData(blocks)
end)

-- Автоматическое сканирование при запуске
task.spawn(function()
    task.wait(1)
    refreshFileList()
end)

print("[AVTO BUILD] Скрипт загружен. Папка для .build файлов: " .. BUILD_FOLDER)
print("[AVTO BUILD] Нажми 'Сканировать', чтобы найти файлы.")