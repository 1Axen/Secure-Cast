--!strict
--!optimize 2

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

---- Imports ----

local SecureCast = script.Parent
local Utility = SecureCast.Utility

local DrawUtility = require(Utility.Draw)
local VoxelsUtility = require(Utility.Voxels)
local PhysicsUtility = require(Utility.Physics)
local BenchmarkUtility = require(Utility.Benchmark)

---- Settings ----

local IS_CLIENT = RunService:IsClient()
local IS_SERVER = RunService:IsServer()

local PARTS = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot"
}

--> OBB intersection requires hitbox size to be halved!
local SIZES = {
	Vector3.new(1.161, 1.181, 1.161) / 2, --> Head
	Vector3.new(1.943, 1.698, 1.004) / 2, -- UpperTorso
	Vector3.new(1.991, 0.401, 1.004) / 2, -- LowerTorso
	Vector3.new(1.001, 1.242, 1.002) / 2, -- LeftUpperArm
	Vector3.new(1.001, 1.118, 1.002) / 2, -- LeftLowerArm
	Vector3.new(0.984, 0.316, 1.028) / 2, -- LeftHand
	Vector3.new(1.001, 1.242, 1.002) / 2, -- RightUpperArm
	Vector3.new(1.001, 1.118, 1.002) / 2, -- RightLowerArm
	Vector3.new(0.984, 0.316, 1.028) / 2, -- RightHand
	Vector3.new(0.993, 1.363, 0.973) / 2, -- LeftUpperLeg
	Vector3.new(0.993, 1.301, 0.973) / 2, -- LeftLowerLeg
	Vector3.new(1.009, 0.312, 1.001) / 2, -- LeftFoot
	Vector3.new(0.993, 1.363, 0.973) / 2, -- RightUpperLeg
	Vector3.new(0.993, 1.301, 0.973) / 2, -- RightLowerLeg
	Vector3.new(1.009, 0.312, 1.001) / 2, -- RightFoot
}

--> Discard phase requires maximum hitbox bounds
local BOUNDS = table.create(#SIZES)
for Index, Vector in SIZES do
	table.insert(BOUNDS, Vector * 1.67)
end

--> Per stud
local HARDNESS = {
	[Enum.Material.Wood] = 2,
	[Enum.Material.Concrete] = 10,
	Default = 10,
}

local FULL_CIRCLE = math.pi * 2

--> Minimum surface hardness needed for a projectile to ricochet
local RICOCHET_HARDNESS = 10

local PARTS_SIZE = #PARTS
local HITBOX_SIZE = (Vector3.new(6, 6, 6) / 2)
local SNAPSHOT_LIFETIME = 1

local MAXIMUM_SIMULATION_TIME = 0.003 --> The maximum amount of time in seconds a thread/worker is allowed to run the simulation for

local RAYCAST_PARAMS = RaycastParams.new()
RAYCAST_PARAMS.FilterType = Enum.RaycastFilterType.Include
RAYCAST_PARAMS.FilterDescendantsInstances = {workspace.Map, workspace.Terrain, workspace.Characters}

export type Record = {
	Parts: {CFrame},
	Position: Vector3,
}

export type Snapshot = {
	Time: number,
	Grid: VoxelsUtility.Grid<Player>,
	Records: {[Player]: Record},
}

export type Intersection = {
	Part: string,
	Player: Player,
	Position: Vector3,
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
	
	RaycastFilter: RaycastParams,
	IncludeFilter: RaycastParams,
	
	PlayerCollisions: boolean, --> Used to determine wether the server will run collision checks for players
	
	Instance: PVInstance,
	Orientation: Vector3,
}

export type Definition = {
	Loss: number, --> Speed loss when ricocheting or bouncing
	Power: number, --> Penetrative power of the projectile :sus:
	Angle: number, --> Ricochet angle of the projectile in degrees (set to 360 for grenades)
	
	Gravity: number,
	Velocity: number,
	
	Lifetime: number,
	RaycastFilter: RaycastParams?,
	
	OnImpact: (Player: Player, Direction: Vector3, Instance: Instance, Normal: Vector3, Position: Vector3, Material: Enum.Material) -> (), --> Called when the projectile hits something in the world
	OnDestroyed: (Player: Player, Position: Vector3) -> (), --> Called when the projectile is destroyed
	OnIntersection: (Player: Player, Direction: Vector3, Part: string, Victim: Player, Position: Vector3) -> (), --> Called whenever a player hitbox is intersected [SERVER SIDE ONLY]
}

---- Constants ----

local Terrain = workspace.Terrain
local Visuals = workspace.Visuals
local Characters = workspace.Characters
local LocalPlayer = Players.LocalPlayer
local ProjectileInstances = ReplicatedStorage.Projectiles

local Simulation = {}

---- Variables ----

local LastTick;

local Actor: Actor;
local Bindable: BindableEvent;

local Snapshots: {Snapshot} = table.create(60)
local Projectiles: {[string]: Projectile} = {}
local Definitions: {[string]: Definition} = {}

---- Private Functions ----

local function ClearTable(Table: {[any]: any}, Deep: boolean?)
	for Index, Value in pairs(Table) do
		if Deep and type(Value) == "table" then
			ClearTable(Value, true)
		end

		Table[Index] = nil
	end
end

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

local function RaycastPlayers(Caster: Player, Origin: Vector3, Direction: Vector3, Time: number): Intersection?
	--> Retrieve previous & next snapshot
	local NextSnapshot: Snapshot?;
	local PreviousSnapshot: Snapshot?;
	
	for Index = #Snapshots - 1, 1, -1 do
		local Snapshot = Snapshots[Index]
		if Snapshot.Time < Time then
			NextSnapshot = Snapshots[Index + 1]
			PreviousSnapshot = Snapshots[Index]
			break
		end
	end
	
	if not NextSnapshot or not PreviousSnapshot then
		return
	end
	
	local NextRecords = NextSnapshot.Records
	local PreviousRecords = PreviousSnapshot.Records
	local Fraction = (Time - PreviousSnapshot.Time) / (NextSnapshot.Time - PreviousSnapshot.Time)
	
	--> Pre-compute commons
	local Inverse = (1 / Direction)
	local Normalized = Direction.Unit
	local Length = Direction.Magnitude

	--> Broadphase: Voxels Grid Traversal
	local Results: {Player} = PreviousSnapshot.Grid:TraverseVoxels(Origin, Direction)
	for Index, Player in Results do
		local NextRecord: Record = NextRecords[Player]
		local PreviousRecord: Record = PreviousRecords[Player]
		
		--> Avoid checking teammates
		if Player.Team == Caster.Team then
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
			
			--> We don't interpolate the matrix here because it's sloooooooooow
			--> From my benchmarking interpolating full matrix here
			--> slows down the raycast by ~300 microseconds at 100 players
			--> this is what no native cframe type does to a mf
			local Position = Rotation.Position:Lerp(Next.Position, Fraction)

			--> Discard phase: Axis-Aligned Bounding Box of complete hitbox bounds	
			local Vector = (Position - Origin)
			local Dot = Vector:Dot(Normalized)
			local Point = (Origin + Normalized * Dot)
			
			local Bounds = BOUNDS[Index]
			local Offset = (Position - Point)

			if math.abs(Offset.X) > Bounds.X
				or math.abs(Offset.Y) > Bounds.Y
				or math.abs(Offset.Z) > Bounds.Z then
				continue
			end
			
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

local function OnPreRender(deltaTime: number)
	local Parts: {BasePart} = {}
	local CFrames: {CFrame} = {}

	--> Calculate cframes
	for Identifier, Projectile in Projectiles do
		--> Type casting for client projectiles
		local PVInstance = Projectile.Instance
		
		local Step = (Projectile.Step + (os.clock() - Projectile.Tick))
		local Position = PhysicsUtility.GetPositionAtTime(Projectile.Origin, Projectile.Velocity, Projectile.Gravity, Step)
		local Orientation = CFrame.lookAt(Position, Position + PhysicsUtility.GetVelocity(Projectile.Velocity, Projectile.Gravity, Step))

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

local function OnPostSimulation()
	local Tick = os.clock()
	local Delta = (Tick - LastTick)
	
	--> Take a snapshot of the latest player positions
	if IS_SERVER then
		--> Create new snapshot
		local Voxels: {[Vector3]: Player} = {}
		local Records: {[Player]: Record} = {}
		
		for Index, Player in Players:GetPlayers() do
			local Character = Player.Character
			if not Character then
				continue
			end
			
			local Parts = {}
			local Record: Record = {
				Parts = Parts,
				Player = Player,
				Position = Character:GetPivot().Position,
			}
			
			for Index, Name in PARTS do
				local Part: BasePart = Character:FindFirstChild(Name)
				if not Part then
					break
				end

				Parts[Index] = Part.CFrame
			end

			if #Parts == PARTS_SIZE then
				Records[Player] = Record
				Voxels[Record.Position] = Player
			end
		end
		
		table.insert(Snapshots, {
			Time = Tick,
			Grid = VoxelsUtility.new(Voxels),
			Records = Records,
		})
		
		--> Remove expired snapshots (might be more than one!)
		--> We must use a reverse loop here to avoid skipping over entries when removing
		for Index = #Snapshots, 1, -1 do
			local Snapshot = Snapshots[Index]
			if (Tick - Snapshot.Time) > SNAPSHOT_LIFETIME then
				table.remove(Snapshots, Index)
				Snapshot.Grid:Destroy()
				ClearTable(Snapshot, true)
			end
		end
	end
	
	--> Projectile callbacks need to be processed in serial execution in the main thread
	--> This is to avoid any sort of issues with thread safety and seperate VMs
	local Impacted: {[Projectile]: RaycastResult} = {}
	local Destroyed: {Projectile} = {}
	local Intersected: {[Projectile]: Intersection} = {}
	
	--> Simulate Projectiles
	for Identifier, Projectile in Projectiles do
		if (os.clock() - Tick) > MAXIMUM_SIMULATION_TIME then
			warn("Thread has elapsed all of it's allocated simulation time.")
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
		local Time = math.min(Projectile.Time + Delta, Projectile.Lifetime)
		local Step = math.min(Projectile.Step + Delta, Time)
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
					Destroy = true
					Intersected[Projectile] = Intersection
				end
			end
			
			if RaycastResult and not Intersection then
				local Impact = RaycastResult.Instance
				local Normal = RaycastResult.Normal
				local UnitDirection = Direction.Unit
				local SurfaceAngle = math.acos(UnitDirection:Dot(Normal.Unit))
				local SurfaceHardness = HARDNESS[RaycastResult.Material] or HARDNESS.Default
				
				--> Filter ally characters
				if IS_CLIENT and Impact:IsDescendantOf(Characters) then
					local Humanoid = Impact.Parent:FindFirstChild("Humanoid") or Impact.Parent.Parent:FindFirstChild("Humanoid")
					local Character = Humanoid and Humanoid.Parent
					local Victim = Character and Players:FindFirstChild(Character.Name)
					if Victim then
						if Victim.Team ~= Caster.Team then
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
					Projectile.IncludeFilter:AddToFilter({Impact})

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
						Time = math.min(Time + (Step - Temporary), Projectile.Lifetime)
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
	
	LastTick = Tick
	
	task.synchronize()
	
	--> Process impacts:
	for Projectile, RaycastResult in Impacted do
		local Direction = PhysicsUtility.GetVelocity(Projectile.Velocity, Projectile.Gravity, Projectile.Step)
		Bindable:Fire(Projectile.Type, "OnImpact", Projectile.Caster, Direction, RaycastResult.Instance, RaycastResult.Normal, RaycastResult.Position, RaycastResult.Material)
	end
	
	--> Process intersected:
	for Projectile, Interesction in Intersected do
		local Direction = PhysicsUtility.GetVelocity(Projectile.Velocity, Projectile.Gravity, Projectile.Step)
		Bindable:Fire(Projectile.Type, "OnIntersection", Projectile.Caster, Direction, Interesction.Part, Interesction.Player, Interesction.Position)
	end
	
	--> Process destroyed:
	--> This is done last to allow for processing
	--> of multiple events per single projectile
	for Index, Projectile in Destroyed do
		--> Only send events for owned projectiles
		if Projectile.Caster.Parent == Players then
			Bindable:Fire(Projectile.Type, "OnDestroyed", Projectile.Caster, Projectile.Position)
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
	LastTick = os.clock()
	Actor = ActorInstance
	Bindable = ActorInstance:FindFirstChild("Result") :: BindableEvent
	Simulation.ImportDefentions()
	
	--> Connections
	Actor:BindToMessage("Dispatch", Simulation.Simulate)
	RunService.PostSimulation:ConnectParallel(OnPostSimulation)
	
	if IS_CLIENT then 
		RunService.PreRender:ConnectParallel(OnPreRender) 
	end
end

function Simulation.Process(Type: string, Action: "OnImpact" | "OnDestroyed" | "OnIntersection", Caster: Player, ...)
	Definitions[Type][Action](Caster, ...)
end

function Simulation.Simulate(Player: Player, Type: string, Origin: Vector3, Direction: Vector3, Timestamp: number, PVInstance: PVInstance?)
	if Direction.Magnitude > 1 then
		Direction = Direction.Unit
		--warn(`Direction must be normalized before passing to Simulate!`)
	end
	
	local Definition = Definitions[Type]
	if not Definition then
		error(`Unknown projectile type '{Type}'`)
		return
	end
	
	local IncludeFilter = RaycastParams.new()
	IncludeFilter.FilterType = Enum.RaycastFilterType.Include
	
	local RaycastFilter = CloneRaycastFilter(Definition.RaycastFilter or RAYCAST_PARAMS)
	local InstancesFilter = RaycastFilter.FilterDescendantsInstances
	local PlayerCollisions = false
	
	--> Remove character collisions from server filter
	if IS_SERVER and (RaycastFilter.FilterType == Enum.RaycastFilterType.Include) then
		local Index = table.find(InstancesFilter, Characters)
		if Index then
			--> Assume we want player collisions
			PlayerCollisions = true
			table.remove(InstancesFilter, Index)
			
			--> Update filter array
			RaycastFilter.FilterDescendantsInstances = InstancesFilter
		end
	end 
	
	local PVInstance = IS_CLIENT and (PVInstance or ProjectileInstances:FindFirstChild(Type)) or nil
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
		Velocity = Direction * Definition.Velocity,
		Position = Origin,

		Loss = Definition.Loss,
		Power = Definition.Power,
		Angle = math.rad(Definition.Angle),
		Speed = Definition.Velocity,

		Tick = os.clock(),
		Step = 0,
		Time = 0,
		Lifetime = Definition.Lifetime,
		Timestamp = Timestamp,

		RaycastFilter = RaycastFilter,
		IncludeFilter = IncludeFilter,

		PlayerCollisions = PlayerCollisions,

		--> Client rendering
		Instance = PVInstance :: any,
		Orientation = Vector3.new(),
	}
end

function Simulation.ImportDefentions()
	for Index, Module in script:GetChildren() do
		if Module:IsA("ModuleScript") then
			--> Unknown path waaaaaaaaaaaaaaaa
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
