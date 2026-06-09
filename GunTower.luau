--!strict
--!native
-- By @pedroGD2007
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const TweenService = game:GetService("TweenService")

const GunTower = workspace:WaitForChild("GunTower")
const Base = workspace:WaitForChild("Base")
const Barrel = GunTower:WaitForChild("Barrel")

const FastButton = workspace:WaitForChild("FastButton")
const NormalButton = workspace:WaitForChild("NormalButton")
const LaserButton = workspace:WaitForChild("LaserButton")

local RangeTemplate = ReplicatedStorage:WaitForChild("Range")

-- BULLET TEMPLATE
const Bullet = ReplicatedStorage:WaitForChild("Bullet")
const BulletPosition = Barrel:GetPivot().Position
Bullet.Position = BulletPosition

-- Configs
const GunTowerPosition = Base.Position
const MaxRadiusDistance = 35 -- RADIUS
const Smoothness = 15 -- Animation Smoothness
const BulletVelocity = 50 -- Studs per second
local ShootDelay = .5 -- Shoot delay
const StandByRotationSpeed = 5 -- Stand by rotation speed

-- All players characters
const AllCharacters = {}
const Overlap = OverlapParams.new()
Overlap.FilterType = Enum.RaycastFilterType.Include
Overlap.FilterDescendantsInstances = AllCharacters

-- Bullet Chached
const CachedBullets:{BasePart} = {}
const CacheSize = 25

const ActiveBullets:{[BasePart]:boolean} = {}

-- Last Shoot time
local LastShoot = os.clock()

-- Change shot delay
const function ChangeDelay(NewDelay:number)
	ShootDelay =NewDelay
end

-- Setup a speed button
const function SetupButton(Button:BasePart)
	local debouce = false
	Button.Color = Color3.fromRGB(255, 0, 200)
	
	Button.Touched:Connect(function()
		if debouce then return end
		debouce = true
		Button.Color = Color3.fromRGB(255, 255, 0)
		
		ChangeDelay(Button:GetAttribute("Delay") or 0.05)
		
		task.wait(1)
		Button.Color = Color3.fromRGB(255, 0, 200)
		debouce = false
	end)
end

-- Create the range
const function CreateRange()
	local Range = RangeTemplate:Clone()
	
	Range.Size = Vector3.new(0.05, MaxRadiusDistance, MaxRadiusDistance)*2
	Range.Position = Base.Position-(Vector3.yAxis*(Base.Size.Y/2))
	Range.Parent = GunTower	
end

-- Add a new bullet to CachedBullets
const function AddBulletToCache():BasePart
	const BulletClone = Bullet:Clone()
	table.insert(CachedBullets, BulletClone)
	return BulletClone
end

-- Removes a bullet from CachedBullets or create a new one if none is available
const function GetCachedBullet():BasePart
	if #CachedBullets == 0 then
		return AddBulletToCache()
	end
	return table.remove(CachedBullets) or AddBulletToCache()
end

-- Return a bullet to the cache
const function DeleteBullet(Bullet:BasePart)
	ActiveBullets[Bullet] = nil

	table.insert(CachedBullets, Bullet)
	Bullet.Position = Barrel:GetPivot().Position
	Bullet.Parent = nil
end

-- Update the OverlapParams filter
const function UpdateOverlapParams()
	Overlap.FilterDescendantsInstances = AllCharacters
end

-- Rotate the gun to look at some position
const function LookTo(Position:Vector3, delta:number)
	const BarrelCFrame = Barrel:GetPivot()
	Barrel:PivotTo(BarrelCFrame:Lerp(CFrame.lookAt(BarrelCFrame.Position, Position), Smoothness*delta))
end

-- Find the nearest player to the gun
const function FindNearPlayer():(Humanoid?, Player?)
	const Parts = workspace:GetPartBoundsInRadius(GunTowerPosition, MaxRadiusDistance, Overlap)
	
	local NearPlayer:Player? = nil
	local NearCharacter:Model? = nil
	local NearDistance = MaxRadiusDistance
	local Humanoid:Humanoid? = nil
	
	const BlacklistedModels:{[Model]:boolean} = {} -- Already verified models
	
	-- Loop through all the parts found in the radius
	-- this finds a player and save it if it's the closest to the gun
	for _, Part:BasePart in Parts do
		const Model = Part:FindFirstAncestorOfClass("Model")
		if not Model then continue end
		if Model == NearCharacter then continue end
		if BlacklistedModels[Model] then continue end		
		BlacklistedModels[Model] = true
		const Player = Players:GetPlayerFromCharacter(Model)
		if not Player then continue end
		
		Humanoid = Model:FindFirstChildOfClass("Humanoid")
		if not Humanoid or Humanoid.Health <= 0 then continue end
		
		const Distance = Player:DistanceFromCharacter(GunTowerPosition)
		
		if Distance < NearDistance then
			NearPlayer = Player
			NearCharacter = Model
			NearDistance = Distance
		end
	end
	
	return Humanoid, NearPlayer
end

-- Shot a bullet foward the barrel
const function Shoot()
	const BulletClone = GetCachedBullet()

	BulletClone.Position = BulletPosition -- Put back the bullet to the gun

	const LookPosition = Barrel.CFrame.LookVector

	const BulletTweenInfo = TweenInfo.new(
		MaxRadiusDistance/BulletVelocity,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.In
	)

	const Tween = TweenService:Create(
		BulletClone,
		BulletTweenInfo,
		{
			--[[
			I get bulletPosition and sum with the look vector of the barrel 
			to get the final position of bullet
			]] 
			Position = BulletPosition + (LookPosition * (MaxRadiusDistance + 1))
		}
	)

	Tween:Play()

	ActiveBullets[BulletClone] = true -- set bullet as active

	local connection 
	
	-- this connections prevent the bullet to be deleted twice
	const TC = Tween.Completed:Once(function()
		if connection then
			connection:Disconnect()
		end

		DeleteBullet(BulletClone)
	end)

	BulletClone.Parent = workspace

	connection = BulletClone:GetPropertyChangedSignal("Parent"):Once(function()
		if TC then
			TC:Disconnect()
		end
	end)
end

-- Rotate the gun until find a player
const function StandBy(dt:number)
	const CurrentBarrelCFrame = Barrel:GetPivot()
	const _, Y, _ = CurrentBarrelCFrame:ToOrientation()
	const TargetCFrame = CFrame.Angles(0, Y+StandByRotationSpeed*dt, 0) + CurrentBarrelCFrame.Position
	
	Barrel:PivotTo(CurrentBarrelCFrame:Lerp(TargetCFrame, Smoothness*dt))
end

-- Processes the collision checks for every active bullet
const function OnUpdateBullets()
	const ToDelete = {}
	
	for Bullet in ActiveBullets do
		local Parts = workspace:GetPartsInPart(Bullet)
		
		for _, Part:BasePart in Parts do
			const Model = Part:FindFirstAncestorOfClass("Model")
			if not Model then continue end

			const Hum = Model:FindFirstChildOfClass("Humanoid")
			if not Hum then continue end
			if Part == Hum.RootPart then return end
			Hum:TakeDamage(5)
			table.insert(ToDelete, Bullet)
			
			if Part.Name == "Head" then break end
			if Part.Name == "Torso" then break end
			Part:Destroy()
			break
		end
	end
	
	for _, Bullet in ToDelete do
		DeleteBullet(Bullet)
	end
end

-- Main update loop
-- Finding the near valid target
-- Rotating the turret towards that target
-- Handling the firing cooldown
const function OnUpdate(dt:number)
	local Hum, Player = FindNearPlayer()
	
	if not Hum or not Player then return StandBy(dt) end
	
	const RootPart = Hum.RootPart
	if not RootPart then return end
	
	const TargetPosition = RootPart.Position
	LookTo(TargetPosition, dt)
	
	if os.clock()-LastShoot < ShootDelay then return end
	LastShoot = os.clock()
	
	Shoot()
end

-- Remove character from filter
const function RemoveChar(Char:Model)
	local Index = table.find(AllCharacters, Char)
	if not Index then return end

	table.remove(AllCharacters, Index)
	UpdateOverlapParams()
end

-- Add character to filter
const function AddChar(Char:Model)
	local Index = table.find(AllCharacters, Char)
	if Index then return end
	table.insert(AllCharacters, Char) 
	UpdateOverlapParams()
	
	Char.Destroying:Connect(function()
		RemoveChar(Char)
	end)
end

-- Fires when a player joins
const function OnPlayerAdded(Player:Player)
	if Player.Character then
		AddChar(Player.Character)
	end
	Player.CharacterAdded:Connect(AddChar)
	Player.CharacterRemoving:Connect(RemoveChar)
end

-- Fires when a player removing
const function OnPlayerRemoving(Player:Player)
	const Char = Player.Character
	if not Char then return end	
	RemoveChar(Char)
end

-- Cache init
for i=1, CacheSize do
	AddBulletToCache()
end

-- If player joins earlier than the script
for _, Player in Players:GetPlayers() do
	OnPlayerAdded(Player)
end

CreateRange()

SetupButton(workspace.LaserButton)
SetupButton(workspace.NormalButton)
SetupButton(workspace.FastButton)

-- Connections

RunService.Heartbeat:Connect(OnUpdate)

RunService.Heartbeat:Connect(OnUpdateBullets)

Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)
