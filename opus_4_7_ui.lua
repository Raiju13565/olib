local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local HttpService = game:GetService("HttpService")

local MyLib = {
	Elements = {},
	ThemeObjects = {},
	Connections = {},
	Flags = {},
	Themes = {
		Default = {
			Main = Color3.fromRGB(20, 20, 20),
			Second = Color3.fromRGB(28, 28, 28),
			Stroke = Color3.fromRGB(55, 55, 55),
			Divider = Color3.fromRGB(55, 55, 55),
			Text = Color3.fromRGB(235, 235, 235),
			TextDark = Color3.fromRGB(140, 140, 140)
		}
	},
	SelectedTheme = "Default",
	Folder = nil,
	SaveCfg = false
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MyUI"
ScreenGui.ResetOnSpawn = false

if syn and syn.protect_gui then
	syn.protect_gui(ScreenGui)
	ScreenGui.Parent = game.CoreGui
else
	ScreenGui.Parent = gethui and gethui() or game.CoreGui
end

local function CleanOldInstances()
	local parent = gethui and gethui() or game.CoreGui
	for _, v in ipairs(parent:GetChildren()) do
		if v.Name == ScreenGui.Name and v ~= ScreenGui then
			v:Destroy()
		end
	end
end
CleanOldInstances()

function MyLib:IsAlive()
	if gethui then
		return ScreenGui.Parent == gethui()
	end
	return ScreenGui.Parent == game:GetService("CoreGui")
end

local function Bind(Signal, Func)
	if not MyLib:IsAlive() then return end
	local conn = Signal:Connect(Func)
	table.insert(MyLib.Connections, conn)
	return conn
end

task.spawn(function()
	while MyLib:IsAlive() do
		task.wait()
	end
	for _, c in next, MyLib.Connections do
		c:Disconnect()
	end
end)

local function MakeDraggable(dragPoint, frame)
	pcall(function()
		local dragging, dragInput, mousePos, framePos
		dragPoint.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				mousePos = input.Position
				framePos = frame.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)
		dragPoint.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				dragInput = input
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if input == dragInput and dragging then
				local delta = input.Position - mousePos
				TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
					Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
				}):Play()
			end
		end)
	end)
end

-- Utility functions
local function New(class, props, children)
	local obj = Instance.new(class)
	for k, v in next, props or {} do
		obj[k] = v
	end
	for _, child in next, children or {} do
		child.Parent = obj
	end
	return obj
end

local function RegElement(name, func)
	MyLib.Elements[name] = func
end

local function Elem(name, ...)
	return MyLib.Elements[name](...)
end

local function Props(obj, tbl)
	for k, v in next, tbl do
		obj[k] = v
	end
	return obj
end

local function Children(obj, tbl)
	for _, v in next, tbl do
		v.Parent = obj
	end
	return obj
end

local function RoundNum(num, factor)
	local r = math.floor(num / factor + 0.5) * factor
	if r < 0 then r = r + factor end
	return r
end

local function GetPropType(obj)
	if obj:IsA("Frame") or obj:IsA("TextButton") then return "BackgroundColor3" end
	if obj:IsA("ScrollingFrame") then return "ScrollBarImageColor3" end
	if obj:IsA("UIStroke") then return "Color" end
	if obj:IsA("TextLabel") or obj:IsA("TextBox") then return "TextColor3" end
	if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then return "ImageColor3" end
end

local function AddThemeObj(obj, themeType)
	if not MyLib.ThemeObjects[themeType] then
		MyLib.ThemeObjects[themeType] = {}
	end
	table.insert(MyLib.ThemeObjects[themeType], obj)
	local prop = GetPropType(obj)
	if prop then
		obj[prop] = MyLib.Themes[MyLib.SelectedTheme][themeType]
	end
	return obj
end

local function ApplyTheme()
	for themeType, objs in pairs(MyLib.ThemeObjects) do
		for _, obj in pairs(objs) do
			local prop = GetPropType(obj)
			if prop then
				obj[prop] = MyLib.Themes[MyLib.SelectedTheme][themeType]
			end
		end
	end
end

local function PackC(c)
	return {R = c.R * 255, G = c.G * 255, B = c.B * 255}
end

local function UnpackC(c)
	return Color3.fromRGB(c.R, c.G, c.B)
end

local function LoadConfig(data)
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, data)
	if not ok then return end
	for name, val in next, decoded do
		if MyLib.Flags[name] then
			task.spawn(function()
				if MyLib.Flags[name].Type == "Colorpicker" then
					MyLib.Flags[name]:Set(UnpackC(val))
				else
					MyLib.Flags[name]:Set(val)
				end
			end)
		end
	end
end

local function SaveConfig(gameId)
	local data = {}
	for name, flag in pairs(MyLib.Flags) do
		if flag.Save then
			if flag.Type == "Colorpicker" then
				data[name] = PackC(flag.Value)
			else
				data[name] = flag.Value
			end
		end
	end
	local ok, json = pcall(HttpService.JSONEncode, HttpService, data)
	if ok then
		writefile(MyLib.Folder .. "/" .. gameId .. ".txt", json)
	end
end

local WhitelistedInputs = {
	Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2,
	Enum.UserInputType.MouseButton3, Enum.UserInputType.Touch
}

local BlacklistedKeys = {
	Enum.KeyCode.Unknown, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S,
	Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Left, Enum.KeyCode.Down,
	Enum.KeyCode.Right, Enum.KeyCode.Slash, Enum.KeyCode.Tab,
	Enum.KeyCode.Backspace, Enum.KeyCode.Escape
}

local function IsInputAllowed(input, list)
	for _, v in next, list do
		if v == input then return true end
	end
	return false
end

-- ===================== BASE ELEMENTS =====================

RegElement("Corner", function(s, o)
	return New("UICorner", { CornerRadius = UDim.new(s or 0, o or 10) })
end)

RegElement("Stroke", function(c, t)
	return New("UIStroke", { Color = c or Color3.fromRGB(255,255,255), Thickness = t or 1 })
end)

RegElement("List", function(s, o)
	return New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(s or 0, o or 0) })
end)

RegElement("Padding", function(b, l, r, t)
	return New("UIPadding", {
		PaddingBottom = UDim.new(0, b or 4), PaddingLeft = UDim.new(0, l or 4),
		PaddingRight = UDim.new(0, r or 4), PaddingTop = UDim.new(0, t or 4)
	})
end)

RegElement("ClearFrame", function()
	return New("Frame", { BackgroundTransparency = 1 })
end)

RegElement("ColorFrame", function(c)
	return New("Frame", { BackgroundColor3 = c or Color3.fromRGB(255,255,255), BorderSizePixel = 0 })
end)

RegElement("RoundedFrame", function(c, s, o)
	return New("Frame", { BackgroundColor3 = c or Color3.fromRGB(255,255,255), BorderSizePixel = 0 }, {
		New("UICorner", { CornerRadius = UDim.new(s, o) })
	})
end)

RegElement("Clickable", function()
	return New("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0 })
end)

RegElement("Scroll", function(c, w)
	return New("ScrollingFrame", {
		BackgroundTransparency = 1,
		MidImage = "rbxassetid://7445543667",
		BottomImage = "rbxassetid://7445543667",
		TopImage = "rbxassetid://7445543667",
		ScrollBarImageColor3 = c,
		BorderSizePixel = 0,
		ScrollBarThickness = w,
		CanvasSize = UDim2.new(0, 0, 0, 0)
	})
end)

local Icons = {}
local Success, IconResponse = pcall(function()
	Icons = HttpService:JSONDecode(game:HttpGetAsync("https://raw.githubusercontent.com/evoincorp/lucideblox/master/src/modules/util/icons.json")).icons
end)

RegElement("Pic", function(id)
	local img = New("ImageLabel", { Image = id, BackgroundTransparency = 1 })
	if Icons[id] ~= nil then
		img.Image = Icons[id]
	end
	return img
end)

RegElement("Text", function(text, size, transparency)
	return New("TextLabel", {
		Text = text or "", TextColor3 = Color3.fromRGB(235, 235, 235),
		TextTransparency = transparency or 0, TextSize = size or 15,
		Font = Enum.Font.Gotham, RichText = true, BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left
	})
end)

-- ===================== NOTIFICATIONS =====================

local NotificationContainer = Children(Props(Elem("ClearFrame"), {
	Position = UDim2.new(1, -25, 1, -25),
	Size = UDim2.new(0, 300, 1, -25),
	AnchorPoint = Vector2.new(1, 1),
	Parent = ScreenGui
}), {
	Props(Elem("List"), { HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 5) })
})

function MyLib:Notify(config)
	config = config or {}
	config.Title = config.Title or "Notification"
	config.Content = config.Content or "Content"
	config.Icon = config.Icon or "rbxassetid://4384403532"
	config.Duration = config.Duration or 15

	task.spawn(function()
		local holder = Props(Elem("ClearFrame"), { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = NotificationContainer })

		local frame = Children(Props(Elem("RoundedFrame", Color3.fromRGB(25, 25, 25), 0, 10), {
			Parent = holder, Size = UDim2.new(1, 0, 0, 0),
			Position = UDim2.new(1, -55, 0, 0), BackgroundTransparency = 0,
			AutomaticSize = Enum.AutomaticSize.Y
		}), {
			Elem("Stroke", Color3.fromRGB(93, 93, 93), 1.2),
			Elem("Padding", 12, 12, 12, 12),
			Props(Elem("Pic", config.Icon), { Size = UDim2.new(0, 20, 0, 20), ImageColor3 = Color3.fromRGB(235, 235, 235), Name = "Icon" }),
			Props(Elem("Text", config.Title, 15), { Size = UDim2.new(1, -30, 0, 20), Position = UDim2.new(0, 30, 0, 0), Font = Enum.Font.GothamBold, Name = "Title" }),
			Props(Elem("Text", config.Content, 14), { Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 0, 25), Font = Enum.Font.GothamSemibold, Name = "Content", AutomaticSize = Enum.AutomaticSize.Y, TextColor3 = Color3.fromRGB(200, 200, 200), TextWrapped = true })
		})

		TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { Position = UDim2.new(0, 0, 0, 0) }):Play()

		task.wait(config.Duration - 0.88)
		TweenService:Create(frame.Icon, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { ImageTransparency = 1 }):Play()
		TweenService:Create(frame, TweenInfo.new(0.8, Enum.EasingStyle.Quint), { BackgroundTransparency = 0.6 }):Play()
		task.wait(0.3)
		TweenService:Create(frame.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), { Transparency = 0.9 }):Play()
		TweenService:Create(frame.Title, TweenInfo.new(0.6, Enum.EasingStyle.Quint), { TextTransparency = 0.4 }):Play()
		TweenService:Create(frame.Content, TweenInfo.new(0.6, Enum.EasingStyle.Quint), { TextTransparency = 0.5 }):Play()
		task.wait(0.05)
		frame:TweenPosition(UDim2.new(1, 20, 0, 0), "In", "Quint", 0.8, true)
		task.wait(1.35)
		frame:Destroy()
	end)
end

-- ===================== WINDOW =====================

function MyLib:Init()
	if MyLib.SaveCfg then
		pcall(function()
			local path = MyLib.Folder .. "/" .. game.GameId .. ".txt"
			if isfile(path) then
				LoadConfig(readfile(path))
				MyLib:Notify({ Title = "Configuration", Content = "Auto-loaded config for " .. game.GameId, Duration = 5 })
			end
		end)
	end
end

function MyLib:MakeWindow(cfg)
	cfg = cfg or {}
	cfg.Name = cfg.Name or "My Library"
	cfg.ConfigFolder = cfg.ConfigFolder or cfg.Name
	cfg.SaveConfig = cfg.SaveConfig or false
	cfg.IntroEnabled = cfg.IntroEnabled == nil and false or cfg.IntroEnabled
	cfg.IntroText = cfg.IntroText or "My Library"
	cfg.CloseCallback = cfg.CloseCallback or function() end
	cfg.ShowIcon = cfg.ShowIcon or false
	cfg.Icon = cfg.Icon or "rbxassetid://8834748103"
	cfg.IntroIcon = cfg.IntroIcon or "rbxassetid://8834748103"

	MyLib.Folder = cfg.ConfigFolder
	MyLib.SaveCfg = cfg.SaveConfig

	if cfg.SaveConfig and not isfolder(cfg.ConfigFolder) then
		makefolder(cfg.ConfigFolder)
	end

	local firstTab = true
	local minimized = false
	local hidden = false

	-- Tab sidebar
	local tabHolder = AddThemeObj(Children(Props(Elem("Scroll", Color3.fromRGB(255, 255, 255), 4), {
		Size = UDim2.new(1, 0, 1, -50)
	}), {
		Elem("List"),
		Elem("Padding", 8, 0, 0, 8)
	}), "Divider")

	Bind(tabHolder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		tabHolder.CanvasSize = UDim2.new(0, 0, 0, tabHolder.UIListLayout.AbsoluteContentSize.Y + 16)
	end)

	-- Window title
	local windowTitle = AddThemeObj(Props(Elem("Text", cfg.Name, 14), {
		Size = UDim2.new(1, -30, 2, 0),
		Position = UDim2.new(0, 25, 0, -24),
		Font = Enum.Font.GothamBlack, TextSize = 20
	}), "Text")

	local topBarLine = AddThemeObj(Props(Elem("ColorFrame"), {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1)
	}), "Stroke")

	-- Close button
	local closeBtn = Children(Props(Elem("Clickable"), {
		Size = UDim2.new(0.5, 0, 1, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		BackgroundTransparency = 1
	}), {
		AddThemeObj(Props(Elem("Pic", "rbxassetid://7072725342"), {
			Position = UDim2.new(0, 9, 0, 6), Size = UDim2.new(0, 18, 0, 18)
		}), "Text")
	})

	-- Minimize button
	local minimizeBtn = Children(Props(Elem("Clickable"), {
		Size = UDim2.new(0.5, 0, 1, 0),
		BackgroundTransparency = 1
	}), {
		AddThemeObj(Props(Elem("Pic", "rbxassetid://7072719338"), {
			Position = UDim2.new(0, 9, 0, 6), Size = UDim2.new(0, 18, 0, 18), Name = "Ico"
		}), "Text")
	})

	local dragPoint = Props(Elem("ClearFrame"), { Size = UDim2.new(1, 0, 0, 50) })

	-- Side panel
	local sidePanel = AddThemeObj(Children(Props(Elem("RoundedFrame", Color3.fromRGB(255, 255, 255), 0, 10), {
		Size = UDim2.new(0, 150, 1, -50),
		Position = UDim2.new(0, 0, 0, 50)
	}), {
		AddThemeObj(Props(Elem("ColorFrame"), { Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 0, 0) }), "Second"),
		AddThemeObj(Props(Elem("ColorFrame"), { Size = UDim2.new(0, 10, 1, 0), Position = UDim2.new(1, -10, 0, 0) }), "Second"),
		AddThemeObj(Props(Elem("ColorFrame"), { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0) }), "Stroke"),
		tabHolder,
		Children(Props(Elem("ClearFrame"), { Size = UDim2.new(1, 0, 0, 50), Position = UDim2.new(0, 0, 1, -50) }), {
			AddThemeObj(Props(Elem("ColorFrame"), { Size = UDim2.new(1, 0, 0, 1) }), "Stroke"),
			AddThemeObj(Children(Props(Elem("ColorFrame"), { AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(0, 32, 0, 32), Position = UDim2.new(0, 10, 0.5, 0) }), {
				Props(Elem("Pic", "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=420&height=420&format=png"), { Size = UDim2.new(1, 0, 1, 0) }),
				AddThemeObj(Props(Elem("Pic", "rbxassetid://4031889928"), { Size = UDim2.new(1, 0, 1, 0) }), "Second"),
				Elem("Corner", 1)
			}), "Divider"),
			Children(Props(Elem("ClearFrame"), { AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(0, 32, 0, 32), Position = UDim2.new(0, 10, 0.5, 0) }), {
				AddThemeObj(Elem("Stroke"), "Stroke"),
				Elem("Corner", 1)
			}),
			AddThemeObj(Props(Elem("Text", LocalPlayer.DisplayName, 14), {
				Size = UDim2.new(1, -60, 0, 13),
				Position = UDim2.new(0, 50, 0, 19),
				Font = Enum.Font.GothamBold, ClipsDescendants = true
			}), "Text")
		})
	}), "Second")

	-- Main window frame
	local mainWindow = AddThemeObj(Children(Props(Elem("RoundedFrame", Color3.fromRGB(255, 255, 255), 0, 10), {
		Parent = ScreenGui,
		Position = UDim2.new(0.5, -307, 0.5, -172),
		Size = UDim2.new(0, 615, 0, 344),
		ClipsDescendants = true
	}), {
		Children(Props(Elem("ClearFrame"), { Size = UDim2.new(1, 0, 0, 50), Name = "TopBar" }), {
			windowTitle,
			topBarLine,
			AddThemeObj(Children(Props(Elem("RoundedFrame", Color3.fromRGB(255, 255, 255), 0, 7), {
				Size = UDim2.new(0, 70, 0, 30),
				Position = UDim2.new(1, -90, 0, 10)
			}), {
				AddThemeObj(Elem("Stroke"), "Stroke"),
				AddThemeObj(Props(Elem("ColorFrame"), { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(0.5, 0, 0, 0) }), "Stroke"),
				closeBtn,
				minimizeBtn
			}), "Second")
		}),
		dragPoint,
		sidePanel
	}), "Main")

	if cfg.ShowIcon then
		windowTitle.Position = UDim2.new(0, 50, 0, -24)
		Props(Elem("Pic", cfg.Icon), { Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(0, 25, 0, 15), Parent = mainWindow.TopBar })
	end

	MakeDraggable(dragPoint, mainWindow)

	Bind(closeBtn.MouseButton1Up, function()
		mainWindow.Visible = false
		hidden = true
		MyLib:Notify({ Title = "Interface Hidden", Content = "Tap RightShift to reopen", Duration = 5 })
		cfg.CloseCallback()
	end)

	Bind(UserInputService.InputBegan, function(input)
		if input.KeyCode == Enum.KeyCode.RightShift and hidden then
			mainWindow.Visible = true
		end
	end)

	Bind(minimizeBtn.MouseButton1Up, function()
		if minimized then
			TweenService:Create(mainWindow, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(0, 615, 0, 344) }):Play()
			minimizeBtn.Ico.Image = "rbxassetid://7072719338"
			task.wait(0.02)
			mainWindow.ClipsDescendants = false
			sidePanel.Visible = true
			topBarLine.Visible = true
		else
			mainWindow.ClipsDescendants = true
			topBarLine.Visible = false
			minimizeBtn.Ico.Image = "rbxassetid://7072720870"
			TweenService:Create(mainWindow, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(0, windowTitle.TextBounds.X + 140, 0, 50) }):Play()
			task.wait(0.1)
			sidePanel.Visible = false
		end
		minimized = not minimized
	end)

	-- Intro animation
	if cfg.IntroEnabled then
		mainWindow.Visible = false
		local logo = Props(Elem("Pic", cfg.IntroIcon), {
			Parent = ScreenGui,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.4, 0),
			Size = UDim2.new(0, 28, 0, 28),
			ImageColor3 = Color3.fromRGB(255, 255, 255),
			ImageTransparency = 1
		})
		local text = Props(Elem("Text", cfg.IntroText, 14), {
			Parent = ScreenGui,
			Size = UDim2.new(1, 0, 1, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 19, 0.5, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Enum.Font.GothamBold,
			TextTransparency = 1
		})
		TweenService:Create(logo, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { ImageTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()
		task.wait(0.8)
		TweenService:Create(logo, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, -(text.TextBounds.X / 2), 0.5, 0) }):Play()
		task.wait(0.3)
		TweenService:Create(text, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
		task.wait(2)
		TweenService:Create(text, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 1 }):Play()
		mainWindow.Visible = true
		logo:Destroy()
		text:Destroy()
	end

	-- Tab creation
	local tabApi = {}

	function tabApi:MakeTab(tabCfg)
		tabCfg = tabCfg or {}
		tabCfg.Name = tabCfg.Name or "Tab"
		tabCfg.Icon = tabCfg.Icon or ""

		local tabBtn = Children(Props(Elem("Clickable"), {
			Size = UDim2.new(1, 0, 0, 30),
			Parent = tabHolder
		}), {
			AddThemeObj(Props(Elem("Pic", tabCfg.Icon), {
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.new(0, 18, 0, 18),
				Position = UDim2.new(0, 10, 0.5, 0),
				ImageTransparency = 0.4,
				Name = "Ico"
			}), "Text"),
			AddThemeObj(Props(Elem("Text", tabCfg.Name, 14), {
				Size = UDim2.new(1, -35, 1, 0),
				Position = UDim2.new(0, 35, 0, 0),
				Font = Enum.Font.GothamSemibold,
				TextTransparency = 0.4,
				Name = "Title"
			}), "Text")
		})

		local container = AddThemeObj(Children(Props(Elem("Scroll", Color3.fromRGB(255, 255, 255), 5), {
			Size = UDim2.new(1, -150, 1, -50),
			Position = UDim2.new(0, 150, 0, 50),
			Parent = mainWindow,
			Visible = false,
			Name = "ItemContainer"
		}), {
			Elem("List", 0, 6),
			Elem("Padding", 15, 10, 10, 15)
		}), "Divider")

		Bind(container.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
			container.CanvasSize = UDim2.new(0, 0, 0, container.UIListLayout.AbsoluteContentSize.Y + 30)
		end)

		if firstTab then
			firstTab = false
			tabBtn.Ico.ImageTransparency = 0
			tabBtn.Title.TextTransparency = 0
			tabBtn.Title.Font = Enum.Font.GothamBlack
			container.Visible = true
		end

		Bind(tabBtn.MouseButton1Click, function()
			for _, btn in next, tabHolder:GetChildren() do
				if btn:IsA("TextButton") then
					btn.Title.Font = Enum.Font.GothamSemibold
					TweenService:Create(btn.Ico, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { ImageTransparency = 0.4 }):Play()
					TweenService:Create(btn.Title, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { TextTransparency = 0.4 }):Play()
				end
			end
			for _, c in next, mainWindow:GetChildren() do
				if c.Name == "ItemContainer" then
					c.Visible = false
				end
			end
			TweenService:Create(tabBtn.Ico, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { ImageTransparency = 0 }):Play()
			TweenService:Create(tabBtn.Title, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
			tabBtn.Title.Font = Enum.Font.GothamBlack
			container.Visible = true
		end)

		-- Element creation
		local function GetElements(parent)
			local el = {}

			function el:AddLabel(text)
				local frame = AddThemeObj(Children(Props(Elem("RoundedFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 30),
					BackgroundTransparency = 0.7,
					Parent = parent
				}), {
					AddThemeObj(Props(Elem("Text", text, 15), { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 12, 0, 0), Font = Enum.Font.GothamBold, Name = "Content" }), "Text"),
					AddThemeObj(Elem("Stroke"), "Stroke")
				}), "Second")
				local api = {}
				function api:Set(t)
					frame.Content.Text = t
				end
				return api
			end

			function el:AddParagraph(title, content)
				title = title or "Title"
				content = content or "Content"
				local frame = AddThemeObj(Children(Props(Elem("RoundedFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 30),
					BackgroundTransparency = 0.7,
					Parent = parent
				}), {
					AddThemeObj(Props(Elem("Text", title, 15), { Size = UDim2.new(1, -12, 0, 14), Position = UDim2.new(0, 12, 0, 10), Font = Enum.Font.GothamBold, Name = "Title" }), "Text"),
					AddThemeObj(Props(Elem("Text", "", 13), { Size = UDim2.new(1, -24, 0, 0), Position = UDim2.new(0, 12, 0, 26), Font = Enum.Font.GothamSemibold, Name = "Content", TextWrapped = true }), "TextDark"),
					AddThemeObj(Elem("Stroke"), "Stroke")
				}), "Second")
				Bind(frame.Content:GetPropertyChangedSignal("Text"), function()
					frame.Content.Size = UDim2.new(1, -24, 0, frame.Content.TextBounds.Y)
					frame.Size = UDim2.new(1, 0, 0, frame.Content.TextBounds.Y + 35)
				end)
				frame.Content.Text = content
				local api = {}
				function api:Set(t)
					frame.Content.Text = t
				end
				return api
			end

			function el:AddButton(btnCfg)
				btnCfg = btnCfg or {}
				btnCfg.Name = btnCfg.Name or "Button"
				btnCfg.Callback = btnCfg.Callback or function() end

				local click = Props(Elem("Clickable"), { Size = UDim2.new(1, 0, 1, 0) })
				local frame = AddThemeObj(Children(Props(Elem("RoundedFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 33),
					Parent = parent
				}), {
					AddThemeObj(Props(Elem("Text", btnCfg.Name, 15), { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 12, 0, 0), Font = Enum.Font.GothamBold, Name = "Content" }), "Text"),
					AddThemeObj(Elem("Stroke"), "Stroke"),
					click
				}), "Second")

				local theme = MyLib.Themes[MyLib.SelectedTheme]
				Bind(click.MouseEnter, function()
					TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { BackgroundColor3 = Color3.fromRGB(theme.Second.R * 255 + 3, theme.Second.G * 255 + 3, theme.Second.B * 255 + 3) }):Play()
				end)
				Bind(click.MouseLeave, function()
					TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { BackgroundColor3 = theme.Second }):Play()
				end)
				Bind(click.MouseButton1Up, function()
					TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { BackgroundColor3 = Color3.fromRGB(theme.Second.R * 255 + 3, theme.Second.G * 255 + 3, theme.Second.B * 255 + 3) }):Play()
					task.spawn(btnCfg.Callback)
				end)
				Bind(click.MouseButton1Down, function()
					TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { BackgroundColor3 = Color3.fromRGB(theme.Second.R * 255 + 6, theme.Second.G * 255 + 6, theme.Second.B * 255 + 6) }):Play()
				end)

				local api = {}
				function api:Set(t)
					frame.Content.Text = t
				end
				return api
			end

			function el:AddToggle(togCfg)
				togCfg = togCfg or {}
				togCfg.Name = togCfg.Name or "Toggle"
				togCfg.Default = togCfg.Default or false
				togCfg.Callback = togCfg.Callback or function() end
				togCfg.Color = togCfg.Color or Color3.fromRGB(9, 99, 195)
				togCfg.Flag = togCfg.Flag or nil
				togCfg.Save = togCfg.Save or false

				local toggle = { Value = togCfg.Default, Save = togCfg.Save }
				local click = Props(Elem("Clickable"), { Size = UDim2.new(1, 0, 1, 0) })

				local box = Children(Props(Elem("RoundedFrame", togCfg.Color, 0, 4), {
					Size = UDim2.new(0, 24, 0, 24),
					Position = UDim2.new(1, -24, 0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5)
				}), {
					Props(Elem("Stroke"), { Color = togCfg.Color, Name = "Stroke", Transparency = 0.5 }),
					Props(Elem("Pic", "rbxassetid://3944680095"), {
						Size = UDim2.new(0, 20, 0, 20),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(0.5, 0, 0.5, 0),
						ImageColor3 = Color3.fromRGB(255, 255, 255),
						Name = "Ico"
					})
				})

				local frame = AddThemeObj(Children(Props(Elem("RoundedFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 38),
					Parent = parent
				}), {
					AddThemeObj(Props(Elem("Text", togCfg.Name, 15), { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 12, 0, 0), Font = Enum.Font.GothamBold, Name = "Content" }), "Text"),
					AddThemeObj(Elem("Stroke"), "Stroke"),
					box, click
				}), "Second")

				local defaultTheme = MyLib.Themes.Default
				function toggle:Set(val)
					toggle.Value = val
					TweenService:Create(box, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { BackgroundColor3 = val and togCfg.Color or defaultTheme.Divider }):Play()
					TweenService:Create(box.Stroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Color = val and togCfg.Color or defaultTheme.Stroke }):Play()
					TweenService:Create(box.Ico, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { ImageTransparency = val and 0 or 1, Size = val and UDim2.new(0, 20, 0, 20) or UDim2.new(0, 8, 0, 8) }):Play()
					togCfg.Callback(val)
				end

				toggle:Set(toggle.Value)

				local theme = MyLib.Themes[MyLib.SelectedTheme]
				Bind(click.MouseEnter, function()
					TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { BackgroundColor3 = Color3.fromRGB(theme.Second.R * 255 + 3, theme.Second.G * 255 + 3, theme.Second.B * 255 + 3) }):Play()
				end)
				Bind(click.MouseLeave, function()
					TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { BackgroundColor3 = theme.Second }):Play()
				end)
				Bind(click.MouseButton1Up, function()
					TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { BackgroundColor3 = Color3.fromRGB(theme.Second.R * 255 + 3, theme.Second.G * 255 + 3, theme.Second.B * 255 + 3) }):Play()
					if MyLib.SaveCfg then SaveConfig(game.GameId) end
					toggle:Set(not toggle.Value)
				end)
				Bind(click.MouseButton1Down, function()
					TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { BackgroundColor3 = Color3.fromRGB(theme.Second.R * 255 + 6, theme.Second.G * 255 + 6, theme.Second.B * 255 + 6) }):Play()
				end)

				if togCfg.Flag then MyLib.Flags[togCfg.Flag] = toggle end
				return toggle
			end

			function el:AddSlider(slCfg)
				slCfg = slCfg or {}
				slCfg.Name = slCfg.Name or "Slider"
				slCfg.Min = slCfg.Min or 0
				slCfg.Max = slCfg.Max or 100
				slCfg.Increment = slCfg.Increment or 1
				slCfg.Default = slCfg.Default or 50
				slCfg.Callback = slCfg.Callback or function() end
				slCfg.ValueName = slCfg.ValueName or ""
				slCfg.Color = slCfg.Color or Color3.fromRGB(9, 149, 98)
				slCfg.Flag = slCfg.Flag or nil
				slCfg.Save = slCfg.Save or false

				local slider = { Value = slCfg.Default, Save = slCfg.Save }
				local dragging = false

				local dragBar = Children(Props(Elem("RoundedFrame", slCfg.Color, 0, 5), {
					Size = UDim2.new(0, 0, 1, 0),
					BackgroundTransparency = 0.3,
					ClipsDescendants = true
				}), {
					AddThemeObj(Props(Elem("Text", "value", 13), { Size = UDim2.new(1, -12, 0, 14), Position = UDim2.new(0, 12, 0, 6), Font = Enum.Font.GothamBold, Name = "Value", TextTransparency = 0 }), "Text")
				})

				local sliderBar = Children(Props(Elem("RoundedFrame", slCfg.Color, 0, 5), {
					Size = UDim2.new(1, -24, 0, 26),
					Position = UDim2.new(0, 12, 0, 30),
					BackgroundTransparency = 0.9
				}), {
					Props(Elem("Stroke"), { Color = slCfg.Color }),
					AddThemeObj(Props(Elem("Text", "value", 13), { Size = UDim2.new(1, -12, 0, 14), Position = UDim2.new(0, 12, 0, 6), Font = Enum.Font.GothamBold, Name = "Value", TextTransparency = 0.8 }), "Text"),
					dragBar
				})

				local frame = AddThemeObj(Children(Props(Elem("RoundedFrame", Color3.fromRGB(255, 255, 255), 0, 4), {
					Size = UDim2.new(1, 0, 0, 65),
					Parent = parent
				}), {
					AddThemeObj(Props(Elem("Text", slCfg.Name, 15), { Size = UDim2.new(1, -12, 0, 14), Position = UDim2.new(0, 12, 0, 10), Font = Enum.Font.GothamBold, Name = "Content" }), "Text"),
					AddThemeObj(Elem("Stroke"), "Stroke"),
					sliderBar
				}), "Second")

				sliderBar.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						dragging = true
					end
				end)
				sliderBar.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						dragging = false
					end
				end)
				UserInputService.InputChanged:Connect(function(input)
					if dragging then
						local scale = math.clamp((input.Position.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
						slider:Set(slCfg.Min + ((slCfg.Max - slCfg.Min) * scale))
						if MyLib.SaveCfg then SaveConfig(game.GameId) end
					end
				end)

				function slider:Set(val)
					self.Value = math.clamp(RoundNum(val, slCfg.Increment), slCfg.Min, slCfg.Max)
					TweenService:Create(dragBar, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale((self.Value - slCfg.Min) / (slCfg.Max - slCfg.Min), 1) }):Play()
					sliderBar.Value.Text = tostring(self.Value) .. " " .. slCfg.ValueName
					dragBar.Value.Text = tostring(self.Value) .. " " .. slCfg.ValueName
					slCfg.Callback(self.Value)
				end

				slider:Set(slider.Value)
				if slCfg.Flag then MyLib.Flags[slCfg.Flag] = slider end
				return slider
			end

			function el:AddDropdown(ddCfg)
				ddCfg = ddCfg or {}
				ddCfg.Name = ddCfg.Name or "Dropdown"
				ddCfg.Options = ddCfg.Options or {}
				ddCfg.Default = ddCfg.Default or ""
				ddCfg.Callback = ddCfg.Callback or function() end
				ddCfg.Flag = ddCfg.Flag or nil
				ddCfg.Save = ddCfg.Save or false

				local dropdown = { Value = ddCfg.Default, Options = ddCfg.Options, Buttons = {}, Toggled = false, Type = "Dropdown", Save = ddCfg.Save }
				local maxShown = 5

				if not table.find(dropdown.Options, dropdown.Value) then
					dropdown.Value = "..."
				end

				local ddList = Elem("List")
				local ddContainer = AddThemeObj(Props(Children(Elem("Scroll", Color3.fromRGB(40, 40, 40), 4), { ddList }), {
					Parent = parent,
					Position = UDim2.new(0, 0, 0, 38),
					Size = UDim2.new(1, 0, 1, -38),
					ClipsDescendants = true
				}), "Divider")

				local click = Props(Elem("Clickable"), { Size = UDim2.new(1, 0, 1, 0) })

				local ddFrame = AddThemeObj(Children(Props(Elem("RoundedFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 38),
					Parent = parent,
					ClipsDescendants = true
				}), {
					ddContainer,
					Props(Children(Elem("ClearFrame"), {
						AddThemeObj(Props(Elem("Text", ddCfg.Name, 15), { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 12, 0, 0), Font = Enum.Font.GothamBold, Name = "Content" }), "Text"),
						AddThemeObj(Props(Elem("Pic", "rbxassetid://7072706796"), { Size = UDim2.new(0, 20, 0, 20), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -30, 0.5, 0), Name = "Ico" }), "TextDark"),
						AddThemeObj(Props(Elem("Text", "Selected", 13), { Size = UDim2.new(1, -40, 1, 0), Font = Enum.Font.Gotham, Name = "Selected", TextXAlignment = Enum.TextXAlignment.Right }), "TextDark"),
						AddThemeObj(Props(Elem("ColorFrame"), { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), Name = "Line", Visible = false }), "Stroke"),
						click
					}), { Size = UDim2.new(1, 0, 0, 38), ClipsDescendants = true, Name = "F" }),
					AddThemeObj(Elem("Stroke"), "Stroke"),
					Elem("Corner")
				}), "Second")

				Bind(ddList:GetPropertyChangedSignal("AbsoluteContentSize"), function()
					ddContainer.CanvasSize = UDim2.new(0, 0, 0, ddList.AbsoluteContentSize.Y)
				end)

				local function AddOptions(opts)
					for _, opt in pairs(opts) do
						local btn = AddThemeObj(Props(Children(Elem("Clickable"), {
							Elem("Corner", 0, 6),
							AddThemeObj(Props(Elem("Text", opt, 13, 0.4), { Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(1, -8, 1, 0), Name = "Title" }), "Text")
						}), {
							Parent = ddContainer,
							Size = UDim2.new(1, 0, 0, 28),
							BackgroundTransparency = 1,
							ClipsDescendants = true
						}), "Divider")
						Bind(btn.MouseButton1Click, function()
							dropdown:Set(opt)
							if MyLib.SaveCfg then SaveConfig(game.GameId) end
						end)
						dropdown.Buttons[opt] = btn
					end
				end

				function dropdown:Refresh(opts, delete)
					if delete then
						for _, btn in pairs(dropdown.Buttons) do btn:Destroy() end
						table.clear(dropdown.Options)
						table.clear(dropdown.Buttons)
					end
					dropdown.Options = opts
					AddOptions(dropdown.Options)
				end

				function dropdown:Set(val)
					if not table.find(dropdown.Options, val) then
						dropdown.Value = "..."
						ddFrame.F.Selected.Text = dropdown.Value
						for _, btn in pairs(dropdown.Buttons) do
							TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
							TweenService:Create(btn.Title, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0.4 }):Play()
						end
						return
					end
					dropdown.Value = val
					ddFrame.F.Selected.Text = dropdown.Value
					for _, btn in pairs(dropdown.Buttons) do
						TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
						TweenService:Create(btn.Title, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0.4 }):Play()
					end
					if dropdown.Buttons[val] then
						TweenService:Create(dropdown.Buttons[val], TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0 }):Play()
						TweenService:Create(dropdown.Buttons[val].Title, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
					end
					return ddCfg.Callback(dropdown.Value)
				end

				Bind(click.MouseButton1Click, function()
					dropdown.Toggled = not dropdown.Toggled
					ddFrame.F.Line.Visible = dropdown.Toggled
					TweenService:Create(ddFrame.F.Ico, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = dropdown.Toggled and 180 or 0 }):Play()
					if #dropdown.Options > maxShown then
						TweenService:Create(ddFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = dropdown.Toggled and UDim2.new(1, 0, 0, 38 + (maxShown * 28)) or UDim2.new(1, 0, 0, 38) }):Play()
					else
						TweenService:Create(ddFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = dropdown.Toggled and UDim2.new(1, 0, 0, ddList.AbsoluteContentSize.Y + 38) or UDim2.new(1, 0, 0, 38) }):Play()
					end
				end)

				dropdown:Refresh(dropdown.Options, false)
				dropdown:Set(dropdown.Value)
				if ddCfg.Flag then MyLib.Flags[ddCfg.Flag] = dropdown end
				return dropdown
			end

			function el:AddBind(bindCfg)
				bindCfg = bindCfg or {}
				bindCfg.Name = bindCfg.Name or "Bind"
				bindCfg.Default = bindCfg.Default or Enum.KeyCode.Unknown
				bindCfg.Hold = bindCfg.Hold or false
				bindCfg.Callback = bindCfg.Callback or function() end
				bindCfg.Flag = bindCfg.Flag or nil
				bindCfg.Save = bindCfg.Save or false

				local bind = { Value = bindCfg.Default, Binding = false, Type = "Bind", Save = bindCfg.Save }
				local holding = false
				local click = Props(Elem("Clickable"), { Size = UDim2.new(1, 0, 1, 0) })

				local bindBox = AddThemeObj(Children(Props(Elem("RoundedFrame", Color3.fromRGB(255, 255, 255), 0, 4), {
					Size = UDim2.new(0, 24, 0, 24),
					Position = UDim2.new(1, -12, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5)
				}), {
					AddThemeObj(Elem("Stroke"), "Stroke"),
					AddThemeObj(Props(Elem("Text", "?", 14), { Size = UDim2.new(1, 0, 1, 0), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, Name = "Value" }), "Text")
				}), "Main")

				-- Show current key name
				local function KeyToName(key)
					if type(key) == "EnumItem" then
						return key.Name
					end
					return tostring(key)
				end
				bindBox.Value.Text = KeyToName(bind.Value)

				local bindFrame = AddThemeObj(Children(Props(Elem("RoundedFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 38),
					Parent = parent
				}), {
					AddThemeObj(Props(Elem("Text", bindCfg.Name, 15), { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 12, 0, 0), Font = Enum.Font.GothamBold, Name = "Content" }), "Text"),
					AddThemeObj(Elem("Stroke"), "Stroke"),
					bindBox, click
				}), "Second")

				Bind(bindBox.Value:GetPropertyChangedSignal("Text"), function()
					TweenService:Create(bindBox, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(0, bindBox.Value.TextBounds.X + 16, 0, 24) }):Play()
				end)

				Bind(click.InputEnded, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						if bind.Binding then return end
						bind.Binding = true
						bindBox.Value.Text = "..."
					end
				end)

				Bind(UserInputService.InputBegan, function(input)
					if UserInputService:GetFocusedTextBox() then return end
					if (input.KeyCode == bind.Value or input.UserInputType == bind.Value) and not bind.Binding then
						if bindCfg.Hold then
							holding = true
							bindCfg.Callback(holding)
						else
							bindCfg.Callback()
						end
					elseif bind.Binding then
						local key
						pcall(function()
							if not IsInputAllowed(input.KeyCode, BlacklistedKeys) then
								key = input.KeyCode
							end
						end)
						pcall(function()
							if IsInputAllowed(input.UserInputType, WhitelistedInputs) and not key then
								key = input.UserInputType
							end
						end)
						if key then
							bind.Value = key
							bindBox.Value.Text = KeyToName(key)
							bind.Binding = false
							if bindCfg.Flag then MyLib.Flags[bindCfg.Flag] = bind end
							if MyLib.SaveCfg then SaveConfig(game.GameId) end
						end
					end
				end)

				Bind(UserInputService.InputEnded, function(input)
					if (input.KeyCode == bind.Value or input.UserInputType == bind.Value) and bindCfg.Hold then
						holding = false
						bindCfg.Callback(holding)
					end
				end)

				if bindCfg.Flag then MyLib.Flags[bindCfg.Flag] = bind end
				return bind
			end

			function el:AddSection(sectionCfg)
				sectionCfg = sectionCfg or {}
				sectionCfg.Name = sectionCfg.Name or "Section"

				local sectionFrame = Children(Props(Elem("ClearFrame"), {
					Size = UDim2.new(1, 0, 0, 26),
					Parent = parent
				}), {
					AddThemeObj(Props(Elem("Text", sectionCfg.Name, 14), { Size = UDim2.new(1, -12, 0, 16), Position = UDim2.new(0, 0, 0, 3), Font = Enum.Font.GothamSemibold }), "TextDark"),
					Children(Props(Elem("ClearFrame"), { AnchorPoint = Vector2.new(0, 0), Size = UDim2.new(1, 0, 1, -24), Position = UDim2.new(0, 0, 0, 23), Name = "Holder" }), {
						Elem("List", 0, 6)
					})
				})

				Bind(sectionFrame.Holder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
					sectionFrame.Size = UDim2.new(1, 0, 0, sectionFrame.Holder.UIListLayout.AbsoluteContentSize.Y + 31)
					sectionFrame.Holder.Size = UDim2.new(1, 0, 0, sectionFrame.Holder.UIListLayout.AbsoluteContentSize.Y)
				end)

				local sectionApi = {}
				for k, v in next, GetElements(sectionFrame.Holder) do
					sectionApi[k] = v
				end
				return sectionApi
			end

			return el
		end

		local tabElements = {}
		for k, v in next, GetElements(container) do
			tabElements[k] = v
		end

		return tabElements
	end

	return tabApi
end

function MyLib:Destroy()
	ScreenGui:Destroy()
end

function MyLib:Toggle()
	ScreenGui.Enabled = not ScreenGui.Enabled
end

return MyLib
