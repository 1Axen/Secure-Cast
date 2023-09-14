--!strict
--!native
--!optimize 2

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

---- Imports ----

local SecureCast = script.Parent
local Utility = SecureCast.Utility

local Settings = require(SecureCast.Settings)

local DrawUtility = require(Utility.Draw)
local VoxelsUtility = require(Utility.Voxels)
local PhysicsUtility = require(Utility.Physics)
local SnapshotsUtility = require(Utility.Snapshots)
local BenchmarkUtility = require(Utility.Benchmark)

---- Settings ----

local IS_CLIENT = RunService:IsClient()
local IS_SERVER = RunService:IsServer()

local PARTS = Settings.Parts
local SIZES = Settings.PartsSizes
local HITBOX_SIZE = Settings.HitboxSize

local FULL_CIRCLE = math.pi * 2
local SURFACE_HARDNESS = Settings.SurfaceHardness
local RICOCHET_HARDNESS = Settings.RicochetHardness

local SERVER_FRAME_RATE = Settings.ServerFrameRate
local REMAINING_FRAME_TIME_RATIO = Settings.RemianingFrameTimeRatio

local RAYCAST_PARAMS = RaycastParams.new()
RAYCAST_PARAMS.FilterType = Enum.RaycastFilterType.Include
RAYCAST_PARAMS.FilterDescendantsInstances = {workspace.Map, workspace.Terrain, workspace.Characters}

export type Intersection = {
	Part: string,
	Player: Player,
	Position: Vector3,
}

export type Modifier = {
	Loss: number?,
	Power: number?,
	Angle: number?,
	Collaterals: boolean?,
	
	Gravity: number?,
	Velocity: number?,
	Lifetime: number?,

	Output: BindableEvent?,
	OnImpact: BindableEvent?,
	OnDestroyed: BindableEvent?,
	OnIntersection: BindableEvent?,
	RaycastFilter: RaycastParams?,

	[string]: any,
}

export type Projectile = {
	--> Information
	Type: string,
	Caster: Player,

	--> Simulation
	Origin: Vector3,
	Gravity: Vector3,
	Velocity: Vector3,
	Position: Vector3,
	
	Loss: number,
	Power: number,
	Speed: number,
	Angle: number,
	
	Tick: number,
	Step: number,
	Time: number,
	Lifetime: number,
	Timestamp: number,
	
	Output: BindableEvent?,
	OnImpact: BindableEvent?,
	OnDestroyed: BindableEvent?,
	OnIntersection: BindableEvent?,
	RaycastFilter: RaycastParams,
	IncludeFilter: RaycastParams,
	
	Collaterals: boolean,
	PlayerCollisions: boolean, --> Used to determine wether the server will run collision checks for players
	
	Instance: PVInstance,
	Orientation: Vector3,
}

export type Definition = {
	Loss: number, --> Speed loss when ricocheting or bouncing
	Power: number, --> Penetrative power of the projectile :sus:
	Angle: number, --> Ricochet angle of the projectile in degrees (set to 360 for grenades),
	Collaterals: boolean,
	
	Gravity: number,
	Velocity: number,
	Lifetime: number,

	Output: BindableEvent?,
	RaycastFilter: RaycastParams?,
	
	--> Called when the projectile hits something in the world
	OnImpact: (Player: Player, Direction: Vector3, Instance: Instance, Normal: Vector3, Position: Vector3, Material: Enum.Material) -> (), 
	--> Called when the projectile is destroyed
	OnDestroyed: (Player: Player, Position: Vector3) -> (),
	--> Called whenever a player hitbox is intersected [SERVER SIDE ONLY]
	OnIntersection: (Player: Player, Direction: Vector3, Part: string, Victim: Player, Position: Vector3) -> (), 
}

---- Constants ----

local Terrain = workspace.Terrain
local Visuals = workspace.Visuals
local Characters = workspace.Characters
local ProjectileInstances = SecureCast.Projectiles

local Simulation = {}

---- Variables ----

local FrameStartTick;

local Actor: Actor;
local Bindable: BindableEvent;

local Projectiles: {[string]: Projectile} = {}
local Definitions: {[string]: Definition} = {}

---- Private Functions ----

local function CloneRaycastFilter(RaycastFilter: RaycastParams): RaycastParams
	local Clone = RaycastParams.new()
	Clone.FilterType = RaycastFilter.FilterType
	Clone.IgnoreWater = RaycastFilter.IgnoreWater
	Clone.CollisionGroup = RaycastFilter.CollisionGroup
	Clone.FilterDescendantsInstances = RaycastFilter.FilterDescendantsInstances
	return Clone
end

local function IncrementTasks(Amount: number)
	Actor:SetAttribute("Tasks", Actor:GetAttribute("Tasks") + Amount)
end

local function IsPlayerFriendly(Caster: Player, Player: Player): boolean
	return Caster.Team == Player.Team
end

local function RaycastPlayers(Caster: Player, Origin: Vector3, Direction: Vector3, Time: number): Intersection?
	--> Retrieve previous & next snapshot
	local NextSnapshot, PreviousSnapshot, Fraction = SnapshotsUtility.GetSnapshotsAtTime(Time)
    if not NextSnapshot or not PreviousSnapshot or not Fraction then
        return
    end
	
	local NextRecords = NextSnapshot.Records
	local PreviousRecords = PreviousSnapshot.Records
	
	--> Pre-compute commons
	local Inverse = (1 / Direction)
	local Normalized = Direction.Unit
	local Length = Direction.Magnitude

	--> Broadphase: Voxels Grid Traversal
	local Results: {[Player]: boolean} = VoxelsUtility.TraverseVoxelGrid(Origin, Direction, PreviousSnapshot.Grid)
	for Player in Results do
		local NextRecord: SnapshotsUtility.Record = NextRecords[Player]
		local PreviousRecord: SnapshotsUtility.Record = PreviousRecords[Player]
		
		--> Avoid checking teammates
		if IsPlayerFriendly(Caster, Player) then
			continue
		end
		
		--> Previous record is guaranteed to exist due to it being in the grid
		if not NextRecord then
			continue
		end

		--> Broadphase: Axis-Aligned Bounding Box
		local Position = PreviousRecord.Position:Lerp(NextRecord.Position, Fraction)
		if not PhysicsUtility.RaycastAABB(Origin, Inverse, Position, HITBOX_SIZE) then
			continue
		end

		local NextParts = NextRecord.Parts
		for Index, Rotation in PreviousRecord.Parts do
			local Size = SIZES[Index]
			local Next = NextParts[Index]

			--> Narrowphase: Oriented Bounding Box
			local Intersection = PhysicsUtility.RaycastOBB(
				Length,
				Origin, 
				Normalized, 
				Size, 
				Rotation:Lerp(Next, Fraction)
			)

			if Intersection then
				return {
					Part = PARTS[Index],
					Player = Player,
					Position = (Normalized * Intersection)
				}
			end
		end
	end
	
	return
end

---- Public Functions ----

local function OnPreRender()
	local Tick = os.clock()
	local Parts: {BasePart} = {}
	local CFrames: {CFrame} = {}

	--> Calculate cframes
	for _, Projectile in Projectiles do
		--> Type casting for client projectiles
		local PVInstance = Projectile.Instance
		
		local Time = (Projectile.Step + (Tick - Projectile.Tick))
		local Position = PhysicsUtility.GetPositionAtTime(Projectile.Origin, Projectile.Velocity, Projectile.Gravity, Time)
		local Orientation = CFrame.lookAt(Position, Position + PhysicsUtility.GetVelocity(Projectile.Velocity, Projectile.Gravity, Time))

		if PVInstance:IsA("BasePart") then
			table.insert(Parts, PVInstance)
			table.insert(CFrames, Orientation)
		else
			PVInstance:PivotTo(Orientation)
		end
	end

	--> Apply
	task.synchronize()
	workspace:BulkMoveTo(Parts, CFrames, Enum.BulkMoveMode.FireCFrameChanged)
end

local function OnPreSimulation()
	FrameStartTick = os.clock()
end

local function OnPostSimulation(deltaTime: number)
	local Tick = os.clock()
	local MaximumSimulationTime = (SERVER_FRAME_RATE - (Tick - FrameStartTick)) * REMAINING_FRAME_TIME_RATIO

	--> Take a snapshot of the latest player positions
	if IS_SERVER then
		SnapshotsUtility.CreatePlayersSnapshot(os.clock())
	end
	
	--> Projectile callbacks need to be processed in serial execution in the main thread
	--> This is to avoid any sort of issues with thread safety and seperate VMs
	local Impacted: {[Projectile]: RaycastResult} = {}
	local Destroyed: {Projectile} = {}
	local Intersected: {[Projectile]: Intersection} = {}

	--> Simulate Projectiles
	for Identifier, Projectile in Projectiles do
		if (os.clock() - Tick) > MaximumSimulationTime then
			--warn("Thread has used all of it's allocated simulation time.")
			break
		end
		
		local Destroy = false

		--> Don't simulate projectiles without owners
		local Caster = Projectile.Caster
		if Caster.Parent ~= Players then
			Projectiles[Identifier] = nil
			table.insert(Destroyed, Projectile)
			continue
		end
		
		--> Increment timers
		local Time = math.min(Projectile.Time + deltaTime, Projectile.Lifetime)
		local Step = math.min(Projectile.Step + deltaTime, Time)
		local Position = Projectile.Position
		
		--> Only simulate moving projectiles
		if Projectile.Speed > 0 then
			Position = PhysicsUtility.GetPositionAtTime(Projectile.Origin, Projectile.Velocity, Projectile.Gravity, Step)
			
			--> Raycast against world
			local Origin = Projectile.Position
			local Direction = (Position - Origin)
			local RaycastResult = workspace:Raycast(Origin, Direction, Projectile.RaycastFilter)
			local RaycastPosition = RaycastResult and RaycastResult.Position or (Origin + Direction)

			--> Perform server-sided player hit detection
			local Intersection: Intersection?;
			if Projectile.PlayerCollisions then
				--> We only need to check up to the raycast intersection
				Intersection = RaycastPlayers(Caster, Origin, (RaycastPosition - Origin), Projectile.Timestamp + Time)
				
				if Intersection then
					if not Projectile.Collaterals then
						Destroy = true
					end

					Intersected[Projectile] = Intersection
				end
			end
			
			if RaycastResult and not Intersection then
				local Impact = RaycastResult.Instance
				local Normal = RaycastResult.Normal
				local UnitDirection = Direction.Unit
				local SurfaceAngle = math.acos(UnitDirection:Dot(Normal.Unit))
				local SurfaceHardness = SURFACE_HARDNESS[RaycastResult.Material] or SURFACE_HARDNESS.Default
				
				--> Filter ally characters
				if IS_CLIENT and Impact:IsDescendantOf(Characters) then
					local Humanoid = Impact.Parent:FindFirstChild("Humanoid") or Impact.Parent.Parent:FindFirstChild("Humanoid")
					local Character = Humanoid and Humanoid.Parent
					local Victim = Character and Players:FindFirstChild(Character.Name)
					if Victim then
						if Victim.Team ~= Caster.Team and not Projectile.Collaterals then
							Destroy = true
						else
							RaycastResult = nil --> Prevent OnImpact event
							Projectile.RaycastFilter:AddToFilter(Character)
						end
					end
				--> Ricochet & Grenade bounce:
				elseif (Projectile.Angle == FULL_CIRCLE) or (Projectile.Angle >= SurfaceAngle and SurfaceHardness >= RICOCHET_HARDNESS) then
					Step = 0
					Position = RaycastPosition
					Projectile.Origin = RaycastPosition
					Projectile.Speed = math.max(0, Projectile.Speed - Projectile.Loss)
					Projectile.Velocity = (UnitDirection - (2 * UnitDirection:Dot(Normal) * Normal)).Unit * Projectile.Speed
				--> Wall penetration:
				elseif Impact ~= Terrain then
					Projectile.IncludeFilter:AddToFilter(Impact)

					local ReverseDirection = -UnitDirection *  Impact.Size.Magnitude
					local ReverseOrigin = RaycastPosition - ReverseDirection
					local ReverseResult = workspace:Raycast(ReverseOrigin, ReverseDirection, Projectile.IncludeFilter)
					local ReversePosition = ReverseResult and ReverseResult.Position or (ReverseOrigin + ReverseDirection)

					local Depth = (ReversePosition - RaycastPosition).Magnitude
					local Power = (Depth * SurfaceHardness)

					if Projectile.Power >= Power then
						local Temporary = Step
						Projectile.Power -= Power
						Step = PhysicsUtility.GetTimeAtPosition(Projectile.Origin, Projectile.Velocity, Projectile.Gravity, ReversePosition, Step)
						Position = PhysicsUtility.GetPositionAtTime(Projectile.Origin, Projectile.Velocity, Projectile.Gravity, Step)

						--> Update simulation values
						local Difference = (Step - Temporary)
						Time = math.min(Time + Difference, Projectile.Lifetime)
					else
						Destroy = true
					end
				else
					Destroy = true
				end
				
				Impacted[Projectile] = RaycastResult
			end
		end
		
		--> Update state
		Projectile.Tick = Tick
		Projectile.Time = Time
		Projectile.Step = Step
		Projectile.Position = Position
		
		if Destroy or Time == Projectile.Lifetime then
			Projectiles[Identifier] = nil
			table.insert(Destroyed, Projectile)
		end
	end
	
	task.synchronize()
	
	--> Process impacts:
	for Projectile, RaycastResult in Impacted do
		local Output = Projectile.OnImpact or Projectile.Output or Bindable
		local Direction = PhysicsUtility.GetVelocity(Projectile.Velocity, Projectile.Gravity, Projectile.Step)
		Output:Fire(Projectile.Type, "OnImpact", Projectile.Caster, Direction, RaycastResult.Instance, RaycastResult.Normal, RaycastResult.Position, RaycastResult.Material)
	end
	
	--> Process intersected:
	for Projectile, Interesction in Intersected do
		local Output = Projectile.OnIntersection or Projectile.Output or Bindable
		local Direction = PhysicsUtility.GetVelocity(Projectile.Velocity, Projectile.Gravity, Projectile.Step)
		Output:Fire(Projectile.Type, "OnIntersection", Projectile.Caster, Direction, Interesction.Part, Interesction.Player, Interesction.Position)
	end
	
	--> Process destroyed:
	--> This is done last to allow for processing
	--> of multiple events per single projectile
	for _, Projectile in Destroyed do
		--> Only send events for owned projectiles
		if Projectile.Caster.Parent == Players then
			local Output = Projectile.OnDestroyed or Projectile.Output or Bindable
			Output:Fire(Projectile.Type, "OnDestroyed", Projectile.Caster, Projectile.Position)
		end
		
		if IS_CLIENT then
			Projectile.Instance:Destroy()
		end
		
		IncrementTasks(-1)
		table.clear(Projectile)
	end
end

---- Initialization ----

function Simulation.Initialize(ActorInstance: Actor)
	assert(typeof(ActorInstance) == "Instance" and ActorInstance:IsA("Actor"), "Simulation can only be used with an actor!")
	
	--> Initialize
	Actor = ActorInstance
	Bindable = ActorInstance:FindFirstChild("Output") :: BindableEvent
	Simulation.ImportDefentions()
	
	--> Connections
	Actor:BindToMessage("Dispatch", Simulation.Simulate)
	RunService.PreSimulation:Connect(OnPreSimulation)
	RunService.PostSimulation:ConnectParallel(OnPostSimulation)
	
	if IS_CLIENT then 
		RunService.PreRender:ConnectParallel(OnPreRender) 
	end
end

function Simulation.Process(Type: string, Action: "OnImpact" | "OnDestroyed" | "OnIntersection", Caster: Player, ...)
	Definitions[Type][Action](Caster, ...)
end

function Simulation.Simulate(Player: Player, Type: string, Origin: Vector3, Direction: Vector3, Timestamp: number, PVInstance: PVInstance?, Modifier: Modifier?)
	if Direction.Magnitude > 1 then
		Direction = Direction.Unit
		--warn(`Direction must be normalized before passing to Simulate!`)
	end
	
	local Definition = Definitions[Type]
	if not Definition then
		error(`Unknown projectile type '{Type}'`)
		return
	end

	--> Overwrite definition values with modifier values
	if Modifier then
		Definition = table.clone(Definition)
		for Key, Value in Modifier do
			Definition[Key] = Value
		end
	end
	
	--> Create raycast filters
	local IncludeFilter = RaycastParams.new()
	IncludeFilter.FilterType = Enum.RaycastFilterType.Include
	
	local RaycastFilter = CloneRaycastFilter(Definition.RaycastFilter or RAYCAST_PARAMS)
	local PlayerCollisions = false
	
	--> Remove character collisions from server filter
	if IS_SERVER then
		local List = RaycastFilter.FilterDescendantsInstances
		local Index = table.find(List, Characters)
		if RaycastFilter.FilterType == Enum.RaycastFilterType.Include then
			if Index then
				--> Assume we want player collisions
				PlayerCollisions = true
				table.remove(List, Index)
				
				--> Update filter array
				RaycastFilter.FilterDescendantsInstances = List
			end
		--> Assume we want player collisions if we aren't filtering them out
		elseif not Index then
			PlayerCollisions = true
			table.insert(List, Characters)
			RaycastFilter.FilterDescendantsInstances = List
		end
	end 
	
	--> Create projectile visual
	PVInstance = IS_CLIENT and (PVInstance or ProjectileInstances:FindFirstChild(Type)) or nil
	if PVInstance then
		PVInstance = PVInstance:Clone()
		PVInstance.Parent = Visuals
	end
	
	IncrementTasks(1)
	Projectiles[HttpService:GenerateGUID(false)] = {
		Type = Type,
		Caster = Player,

		Origin = Origin,
		Gravity = Vector3.new(0, Definition.Gravity, 0),
		Velocity = Direction * (Definition.Velocity),
		Position = Origin,

		Loss = Definition.Loss,
		Power = Definition.Power,
		Angle = math.rad(Definition.Angle),
		Speed = Definition.Velocity,

		Step = 0,
		Time = 0,
		Tick = os.clock(),
		Lifetime = Definition.Lifetime,
		Timestamp = Timestamp,

		Output = Definition.Output,
		OnImpact = Modifier and Modifier.OnImpact,
		OnDestroyed = Modifier and Modifier.OnDestroyed,
		OnIntersection = Modifier and Modifier.OnIntersection,
		RaycastFilter = RaycastFilter,
		IncludeFilter = IncludeFilter,

		Collaterals = Definition.Collaterals,
		PlayerCollisions = PlayerCollisions,

		--> Client rendering
		Instance = PVInstance :: any,
		Orientation = Vector3.new(),
	}
end

function Simulation.ImportDefentions()
	for _, Module in Settings.Definitions:GetChildren() do
		if Module:IsA("ModuleScript") then
			Definitions[Module.Name] = require(Module) :: any
		end
	end
end

function Simulation.GetRaycastParams()
	return RAYCAST_PARAMS
end

function Simulation.SetRaycastParams(Parameters: RaycastParams)
	RAYCAST_PARAMS = Parameters
end

---- Connections ----

return Simulation
