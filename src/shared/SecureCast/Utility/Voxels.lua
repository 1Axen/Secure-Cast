--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local ReplicatedStorage = game:GetService("ReplicatedStorage")

---- Imports ----

local SecureCast = script.Parent.Parent
local Utility = SecureCast.Utility

local DrawUtility = require(Utility.Draw)

---- Settings ----

local VOXEL_SIZE = 32
local VOXEL_CENTER = (Vector3.one * (VOXEL_SIZE / 2))

local GRID_SIZE = Vector3.new(4096, 512, 4096)
local GRID_CFRAME = CFrame.new(-GRID_SIZE)
local GRID_VOXELS = Vector3.new(
	math.floor(GRID_SIZE.X / VOXEL_SIZE),
	math.floor(GRID_SIZE.Y / VOXEL_SIZE),
	math.floor(GRID_SIZE.Z / VOXEL_SIZE)
) * 2 - Vector3.one

export type Grid<T> = typeof(setmetatable({}, {})) & {
	Size: number,
	Voxels: {[Vector3]: {T}},
	TraverseVoxels: (Grid<T>, Origin: Vector3, Direction: Vector3) -> {T},
	Destroy: (Grid<T>) -> (),
}

---- Constants ----

local Grid = {}
Grid.__index = Grid

---- Variables ----

---- Private Functions ----

local function ClearTable(Table: {[any]: any}, Deep: boolean?)
	for Index, Value in pairs(Table) do
		if Deep and type(Value) == "table" then
			ClearTable(Value, true)
		end

		Table[Index] = nil
	end
end

local function DrawVoxel(Position: Vector3)
	DrawUtility.box(GRID_CFRAME:PointToWorldSpace(Position * VOXEL_SIZE) + VOXEL_CENTER, Vector3.one * VOXEL_SIZE)
end

---- Public Functions ----

function Grid.new<T>(Data: {[Vector3]: T}): Grid<T>
	--> Populate Voxels
	local Size = 0
	local Voxels = {}

	for Position, Value in Data do
		Position = GRID_CFRAME:PointToObjectSpace(Position)
		
		local Key = Vector3.new(
			math.floor(Position.X / VOXEL_SIZE),
			math.floor(Position.Y / VOXEL_SIZE),
			math.floor(Position.Z / VOXEL_SIZE)
		)
		
		local Voxel = Voxels[Key]
		if not Voxel then
			Size += 1			
			Voxels[Key] = {Value}
			continue
		end
		
		table.insert(Voxel, Value)
	end
	
	return setmetatable({
		Size = Size,
		Voxels = Voxels,
	} :: any, Grid)
end

function Grid:TraverseVoxels(Origin: Vector3, Direction: Vector3)
	local Voxels = self.Voxels
	
	--> Initialize Positions
	local RayStart = GRID_CFRAME:PointToObjectSpace(Origin) / VOXEL_SIZE
	local RayDestination = GRID_CFRAME:PointToObjectSpace(Origin + Direction) / VOXEL_SIZE
	local RayDirection = (RayDestination - RayStart)
	
	--> Initialise Values
	local X = math.floor(RayStart.X)
	local Y = math.floor(RayStart.Y)
	local Z = math.floor(RayStart.Z)
	
	--> Skip over rays that don't exit the voxel they start in
	if (X == math.floor(RayDestination.X))
		and (Y == math.floor(RayDestination.Y))
		and (Z == math.floor(RayDestination.Z)) then
		return Voxels[Vector3.new(X, Y, Z)] or {}
	end
	
	local StepX = math.sign(RayDirection.X)
	local StepY = math.sign(RayDirection.Y)
	local StepZ = math.sign(RayDirection.Z)
	
	local RayX, DeltaX = math.huge, math.huge
	if StepX ~= 0 then
		DeltaX = (StepX / RayDirection.X)
		RayX = StepX > 0 and DeltaX * (1 - RayStart.X + X) or DeltaX * (RayStart.X - X)
	end
	
	local RayY, DeltaY = math.huge, math.huge
	if StepY ~= 0 then
		DeltaY = (StepY / RayDirection.Y)
		RayY = StepY > 0 and DeltaY * (1 - RayStart.Y + Y) or DeltaY * (RayStart.Y - Y)
	end
	
	local RayZ, DeltaZ = math.huge, math.huge
	if StepZ ~= 0 then
		DeltaZ = (StepZ / RayDirection.Z)
		RayZ = StepZ > 0 and DeltaZ * (1 - RayStart.Z + Z) or DeltaZ * (RayStart.Z - Z)
	end
	
	--> Traverse
	local PopulatedVoxels: {{any}} = {}
	while true do
		--> Insert current voxel
		local Voxel = Voxels[Vector3.new(X, Y, Z)]
		if Voxel then
			table.insert(PopulatedVoxels, Voxel)
		end		
		
		--> Break if we reached the end of the ray
		if (RayX > 1) 
			and (RayY > 1) 
			and (RayZ > 1) then
			break
		end

		--> Go forwards
		if RayZ < RayX and RayZ < RayY then
			Z += StepZ
			RayZ += DeltaZ
		elseif RayX < RayY then
			X += StepX
			RayX += DeltaX
		else
			Y += StepY
			RayY += DeltaY
		end
	end
	
	--> Extract items from voxels
	local Items = {}
	for Index, Voxel in PopulatedVoxels do
		for Index, Item in Voxel do
			table.insert(Items, Item)
		end
	end
	
	return Items
end

function Grid:Destroy()
	ClearTable(self, true)
	setmetatable(self, nil)
end

---- Initialization ----

---- Connections ----

return Grid
