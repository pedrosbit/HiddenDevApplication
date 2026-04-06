--!native
--!strict
-- By @pedroGD2007 made with much love <3
--[[
	Description: 
	Im from Brazil, so sorry if my english looks little bit weird. <3
	I tried to explain a lot of code here and thats all thanks.
	
	This is a command bar code, that auto complete.
	
	I struct code like this:
		- Contants/Variables
		- Utils Functions
		- Main Functions
		- Event Functions
		- Inital Code
		- Connections
	
	Base logic, server registers all commands in "_COMMANDS"
	All commands is stringValues thats JSON encoded, I made it to not leak server commands.
	
	Variable "AllCommands" is a table with all commands, permissions and args.
	Thats loads when you calls "LoadCommand(JSON)"
	
	The JSON decode returns:

		The permission level, command name and args
		
		ServerBaseProperties = {
				Nome:string;
				
				PermissonLevel:number;
				
				StringParam1:boolean;
				
				StringParam2:boolean;
				
				IntParam:boolean; -> USER ID in major cases
				
				ShowInCommands:boolean; -> Will show in commands
		}
	
	DoCommand(CommandString:string, StringParam1:string, StringParam2:string, IntParam:number) -> Execute a command
	
	OnFocusedLost(Enter) -> Checks if enter and execute command.
	
	OnWrite() -> Main code is there thats checks for users permissions
	auto completes if it have args and execute it.
		
		This function have 2 sub functions:
			clear() -> That clear all suggestions
			createSuggestion() -> that create a suggestion
			
		if you uses "/" you can see all commands suggestions
		
		or if you simple texts it shows next suggestions.
		
		Resume: It make a list when player write, if player uses space 
			it shows a parameter, if it have int param it shows players suggestions.
			Simple its it.
			
			It should look like this:
				/kill @player
				/ban @player <Parametro1> <Parametro2>
				
	To send a command to server you need to use SERA to buffer it and send it to server
	
	-> Use command template:

		local Sera = require("../Sera")

		local Schema = Sera.Schema({
			Command = Sera.String8;
			
			StringParam1 = Sera.String16;
			
			StringParam2 = Sera.String16;
			
			IntParam = Sera.UInt32;
		})

		return Schema
		
		
		
	Why I used JSON:
		- To not leak server commands
		- And to make it harder to exploiters to get server commands
		
	Why I made it with sera? 

		- To prevent exploiters to send random data to server, simple exploiters
		cant use it
		- Its use less data to sent to server
		- Its cool lol
		
	Also why I put "native":
		--!native
		@native
		
		Native -> Makes the code run faster for LUAU calculation, so it makes some sense
		here because its use a lot of strings concats and table indexs.
		
	--!strict -> its just to Luau Type coding.	
]]

--// CONSTANTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local ReplicaClient = require(ReplicatedStorage.Modules.ReplicaClient)

local R_UseCommands = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UseCommand")

local _COMMANDS = ReplicatedStorage:WaitForChild("Comandos")

local CommandTemplate = require(ReplicatedStorage.Modules.Types.CommandTemplate)

--// Sera infos

local Sera = require(ReplicatedStorage.Modules.Sera)
local UseCommand = require(ReplicatedStorage.Modules.Schemas.UseCommand)

--// Commands Info

local CommandCount = (ReplicatedStorage:WaitForChild("CommandsCount", 9e9) :: NumberValue).Value

local CommandLine = script.Parent:WaitForChild("CommandLine")

local BaseCommand = CommandLine:WaitForChild("BaseCommand")

--// Anims infos

local OpenTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CloseTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local SuggestionTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--// VARIABLES

local AllCommands:{[string]:typeof(CommandTemplate.Propriedades)} = {}

local CanToggle = true

--// FUNCTIONS

local function DoCommand(CommandString:string, StringParam1:string, StringParam2:string, IntParam:number)
	local Params, err = Sera.Serialize(UseCommand, {
		Command = CommandString:gsub("/", "");

		StringParam1 = StringParam1;

		StringParam2 = StringParam2;

		IntParam = IntParam;
	})
	if err ~= nil then
		return print("[LOCAL] Erro estranho, nos comandos /n", err)
	end
	R_UseCommands:FireServer(Params)
end

local function LoadCommand(Properties:string)
	local Properties = HttpService:JSONDecode(Properties)
	AllCommands[Properties.Nome] = Properties
end

local function ToggleEnabled(Enabled:boolean)	
	CanToggle = false
	if Enabled then
		CommandLine.Text = ""
		CommandLine.Visible = true
		local t = TweenService:Create(CommandLine, 
			OpenTweenInfo, 
			{Size = UDim2.fromScale(1,0.072)})
		t:Play()
		t.Completed:Wait()
	else
		local t = TweenService:Create(CommandLine, 
			OpenTweenInfo, 
			{Size = UDim2.fromScale(0,0.072)})
		t:Play()
		t.Completed:Wait()
		CommandLine.Text = ""
		CommandLine.Visible = false
	end
	CanToggle = true
end

local function clear()
	for _, child in CommandLine:GetChildren() do
		if child:IsA("TextButton") and child.Name ~= "BaseCommand" and child.Name ~= "empty" then
			if child:GetAttribute("Deletando") then continue end
			child:SetAttribute("Deletando", true)

			local t = TweenService:Create(child, SuggestionTweenInfo, {
				BackgroundTransparency = 1, 
				TextTransparency = 1,
				Size = UDim2.new(child.Size.X.Scale, child.Size.X.Offset, 0, 0)
			})
			t:Play()
			task.delay(0.15, function() child:Destroy() end)
		end
	end
end

local function createSuggestion(text:string, name:string, color:Color3?, attributes:{[string]:number}?): typeof(BaseCommand)
	local new = BaseCommand:Clone()
	new.Text = text
	new.Name = name
	new.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	if attributes then
		for k, v in attributes do new:SetAttribute(k, v) end
	end

	new.BackgroundTransparency = 1
	new.TextTransparency = 1
	local originalSize = BaseCommand.Size -- Usa o tamanho do template
	new.Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 0)

	new.Visible = true
	new.Parent = CommandLine

	TweenService:Create(new, SuggestionTweenInfo, {
		BackgroundTransparency = 0,
		TextTransparency = 0,
		Size = originalSize
	}):Play()

	return new
end

@native
local function OnWrite()
	local fullText = CommandLine.Text
	local args = fullText:split(" ")
	local commandName = args[1] and args[1]:gsub("/", ""):lower() or ""

	if #fullText == 0 then return clear() end

	if fullText:match("\t") then
		local target = CommandLine:FindFirstChild("Suggestion_Player_1") or CommandLine:FindFirstChild("Suggestion_Cmd_1")
		if target then
			CommandLine:CaptureFocus()
			if target.Name:match("Player") then
				CommandLine.Text = "/" .. commandName .. " @" .. target:GetAttribute("plr") .. " "
			else
				CommandLine.Text = "/" .. target:GetAttribute("cmd") .. " "
			end
			CommandLine.CursorPosition = #CommandLine.Text + 1
		end
		return
	end

	clear()

	if #args <= 1 then
		local c = 0
		for nome, info in AllCommands do
			if info.ShowInCommands and nome:lower():sub(1, #commandName) == commandName then
				c += 1
				local displayHint = "/" .. nome
				if info.IntParam then displayHint ..= " @jogador" end
				if info.StringParam1 then displayHint ..= " <param1>" end
				if info.StringParam2 then displayHint ..= " <param2>" end

				local btn = createSuggestion(displayHint, "Suggestion_Cmd_"..c, nil, {cmd = nome})
				btn.MouseButton1Click:Connect(function()
					CommandLine:CaptureFocus()
					CommandLine.Text = "/" .. nome .. " "
					CommandLine.CursorPosition = #CommandLine.Text + 1
					OnWrite()
				end)
			end
		end
	elseif #args == 2 and AllCommands[commandName] and AllCommands[commandName].IntParam then
		local info = AllCommands[commandName]
		local playerSearch = args[2]:gsub("@", ""):lower()
		local c = 0
		for _, player in Players:GetPlayers() do
			if player.Name:lower():sub(1, #playerSearch) == playerSearch or player.DisplayName:lower():sub(1, #playerSearch) == playerSearch then
				c += 1
				local btn = createSuggestion(`{player.DisplayName}(@{player.Name})`, "Suggestion_Player_"..c, Color3.fromRGB(85, 255, 127), {plr = player.Name})
				btn.MouseButton1Click:Connect(function()
					CommandLine:CaptureFocus()
					CommandLine.Text = "/" .. commandName .. " @" .. player.Name .. " "
					CommandLine.CursorPosition = #CommandLine.Text + 1
					OnWrite()
				end)
			end
		end
	else
		local info = AllCommands[commandName]
		if info then
			local fixedArgs = info.IntParam and 2 or 1

			local currentTextIndex = #args - fixedArgs

			if info.StringParam1 then
				local isAtParam1 = (currentTextIndex == 1)
				local isOverflowing = (currentTextIndex > 1 and not info.StringParam2)

				if isAtParam1 or isOverflowing then
					createSuggestion(`<Parametro 1>`, "Suggestion_Parametro", Color3.fromRGB(85, 255, 127))
					return 
				end
			end

			if info.StringParam2 and currentTextIndex >= 2 then
				createSuggestion(`<Parametro 2>`, "Suggestion_Parametro", Color3.fromRGB(85, 255, 127))
			end
		end
	end
end

local function OnEndInput(key:InputObject, bool)
	if bool then return end
	if key.KeyCode == Enum.KeyCode.Z then
		ToggleEnabled(not CommandLine.Visible)
	end
end

local function OnFocusedLost(enterPressed)
	if enterPressed then
		local fullText = CommandLine.Text
		local args = fullText:split(" ")
		local commandName = args[1] and args[1]:gsub("/", ""):lower() or ""
		local info = AllCommands[commandName]

		CommandLine.Text = ""

		if #fullText == 0 or not info then return end

		local targetId = 0
		local textStartIndex = 2

		if info.IntParam then
			local nm = (args[2] or ""):gsub("@", "")
			local plr = Players:FindFirstChild(nm or "") :: Player
			targetId = if plr then plr.UserId else 0

			if tonumber(args[2]) then
				targetId = tonumber(args[2]) or 0
			end

			textStartIndex = 3
		end

		local param1 = ""
		local param2 = ""

		if info.StringParam1 then
			if info.StringParam2 then
				param1 = args[textStartIndex] or ""
				param2 = table.concat(args, " ", textStartIndex + 1)
			else
				param1 = table.concat(args, " ", textStartIndex)
			end
		end

		DoCommand(args[1], param1, param2, targetId)
	end
end

--// INIT CODE

BaseCommand.Visible = false

repeat task.wait(0.1) until #_COMMANDS:GetChildren() == CommandCount

for _, v in _COMMANDS:GetChildren() do
	LoadCommand((v :: StringValue).Value)
end

ToggleEnabled(false)

--// CONNECTIONS

UserInputService.InputEnded:Connect(OnEndInput)

CommandLine.FocusLost:Connect(OnFocusedLost)

local OldText = CommandLine.Text
CommandLine.Changed:Connect(function()
	if CommandLine.Text ~= OldText then
		OldText = CommandLine.Text 
		OnWrite()
	end
end)
