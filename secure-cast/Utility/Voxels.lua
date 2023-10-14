--!strict
--!native

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

---- Imports ----

local SecureCast = script.Parent.Parent
local Settings = require(SecureCast.Settings)

---- Settings ----

local VOXEL_SIZE = Settings.VoxelSize
local GRID_CFRAME = Settings.VoxelGridCorner

export type Grid<T> = {
	[Vector3]: {[T]: boolean}
}
---- Constants ----

local Utility = {}

---- Variables ----

---- Private Functions ----

local function FloorVector3(Vector: Vector3): Vector3
	return Vector3.new(
		math.floor(Vector.X),
		math.floor(Vector.Y),
		math.floor(Vector.Z)
	)
end

---- Public Functions ----

--> Bounds is a Vector3 which specifies the bounds/size of each input
--> Example: Player hitboxes which occupy multiple voxels need to be put every voxel they occupy
function Utility.BuildVoxelGrid<T>(Input: {[T]: Vector3}, Bounds: Vector3): Grid<T>
	local Voxels: Grid<T> = {}
	Bounds = Bounds and (Bounds / VOXEL_SIZE) or Vector3.zero

	local function Insert(Key: Vector3, Value: T)
		local Voxel = Voxels[Key]
		if not Voxel then	
			Voxel = {}
			Voxels[Key] = Voxel
		end

		Voxel[Value] = true
	end

	for Value, Position in Input do
		Position = GRID_CFRAME:PointToObjectSpace(Position) / VOXEL_SIZE
	
		--> Insert at each axes
		if Bounds ~= Vector3.zero then
			local Maximum = FloorVector3(Position + Bounds)
			local Minimum = FloorVector3(Position - Bounds) 

			--> X Axis
			Insert(Vector3.new(Maximum.X, Position.Y, Position.Z), Value)
			Insert(Vector3.new(Minimum.X, Position.Y, Position.Z), Value)

			--> Y Axis
			Insert(Vector3.new(Position.X, Maximum.Y, Position.Z), Value)
			Insert(Vector3.new(Position.X, Minimum.Y, Position.Z), Value)

			--> Z Axis
			Insert(Vector3.new(Position.X, Position.Y, Maximum.Z), Value)
			Insert(Vector3.new(Position.X, Position.Y, Minimum.Z), Value)
		end

		--> Insert at centre
		Insert(FloorVector3(Position), Value)
	end

	return Voxels
end

function Utility.TraverseVoxelGrid<T>(Origin: Vector3, Direction: Vector3, Voxels: Grid<T>): {[T]: boolean}
	--> Initialize ray variables
	local RayStart = GRID_CFRAME:PointToObjectSpace(Origin) / VOXEL_SIZE
	local RayDestination = GRID_CFRAME:PointToObjectSpace(Origin + Direction) / VOXEL_SIZE
	local RayDirection = (RayDestination - RayStart)

	--> Initialize voxel variables
	local X = math.floor(RayStart.X)
	local Y = math.floor(RayStart.Y)
	local Z = math.floor(RayStart.Z)

	--> Skip over rays that don't exit the voxel they start in
	if (X == math.floor(RayDestination.X))
		and (Y == math.floor(RayDestination.Y))
		and (Z == math.floor(RayDestination.Z)) then
		return Voxels[Vector3.new(X, Y, Z)] or {}
	end

	--> Initialize traversal variables
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
	local Occupied: {{[T]: boolean}} = {}
	while true do
		--> Insert current voxel
		local Voxel = Voxels[Vector3.new(X, Y, Z)]
		if Voxel then
			table.insert(Occupied, Voxel)
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
	local Result: {[T]: boolean} = {}
	for _, Voxel in Occupied do
		for Item in Voxel do
			Result[Item] = true
		end
	end
	
	return Result
end

---- Initialization ----

---- Connections ----

return Utility
