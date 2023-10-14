--!strict
--!native
--!optimize 2

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

---- Imports ----

---- Settings ----

local AXES: {"X" | "Y" | "Z"} = {"X", "Y", "Z"}
local HERTZ = (1 / 480) -- (1 / 240) * 0.5
local EPSILON = 1E-5

---- Constants ----

local Utility = {}

---- Variables ----

---- Private Functions ----

local function VectorSquareRoot(Vector: Vector3): Vector3
	return Vector3.new(math.sqrt(Vector.X), math.sqrt(Vector.Y), math.sqrt(Vector.Z))
end

---- Public Functions ----

function Utility.GetPosition(Origin: Vector3, Velocity: Vector3, Gravity: Vector3, Time: number): Vector3
	return Origin + Velocity * Time + 0.5 * Gravity * (Time ^ 2)
end

function Utility.GetVelocity(Velocity: Vector3, Gravity: Vector3, Time: number): Vector3
	return Velocity + Gravity * Time
end

function Utility.GetCorrection(Gravity: Vector3, Time: number): Vector3
	return HERTZ * Gravity * Time
end

function Utility.GetPositionAtTime(Origin: Vector3, Velocity: Vector3, Gravity: Vector3, Time: number): Vector3
	local Position = Utility.GetPosition(Origin, Velocity, Gravity, Time)
	return Position + Utility.GetCorrection(Gravity, Time) 
end

--> Quadratic formula actually being used in my life :shock:
function Utility.GetTimeAtPosition(Origin: Vector3, Velocity: Vector3, Gravity: Vector3, Position: Vector3, Time: number): number
	local a = (-Velocity - HERTZ * Gravity)
	local b = (Velocity + HERTZ * Gravity)
	local c = (2 * Gravity * (Origin - Position))
	
	local t1 = ((a - VectorSquareRoot(b * b - c)) / Gravity).Y
	local t2 = ((a + VectorSquareRoot(b * b - c)) / Gravity).Y
	
	local d1 = math.abs(Time - t1)
	local d2 = math.abs(Time - t2)
	
	return (d1 < d2) and t1 or t2
end

--> Assume halved size
--> Assume inverse direction (1 / direction)
--> https://tavianator.com/2015/ray_box_nan.html
--> Same performance as inlined version, I assume the compiler is inlining this under the hood
function Utility.RaycastAABB(Origin: Vector3, Direction: Vector3, Position: Vector3, Size: Vector3)
	local Minimum = -math.huge
	local Maximum = math.huge
	
	local BoundsMin = (Position - Size)
	local BoundsMax = (Position + Size)
	
	for _, Axis: "X" | "Y" | "Z" in AXES do
		--> This type checking warning is dumb :/
		local AxisMin = (BoundsMin[Axis] - Origin[Axis]) * Direction[Axis]
		local AxisMax = (BoundsMax[Axis] - Origin[Axis]) * Direction[Axis]
		
		Minimum = math.max(Minimum, math.min(AxisMin, AxisMax))
		Maximum = math.min(Maximum, math.max(AxisMin, AxisMax))
	end
	
	Minimum = math.max(Minimum, 0)
	return (Maximum > Minimum) and (Minimum < 1)
end

--> Assume halved size
--> https://www.opengl-tutorial.org/miscellaneous/clicking-on-objects/picking-with-custom-ray-obb-function/
function Utility.RaycastOBB(Length: number, Origin: Vector3, Direction: Vector3, Size: Vector3, Rotation: CFrame): number?
	local Minimum = 0
	local Maximum = 100000
	local Delta = (Rotation.Position - Origin)

	--> X plane intersection
	-- selene: allow(shadowing)
	do
		local Size = Size.X
		local Axis = Rotation.RightVector

		--> Ray direction & axis length
		local NomLength = Axis:Dot(Delta)
		local DenomLength =  Direction:Dot(Axis)

		if math.abs(DenomLength) > EPSILON then
			local PlaneMinimum = (NomLength + -Size) / DenomLength
			local PlaneMaximum = (NomLength + Size) / DenomLength

			--> PlaneMinimum needs to represent the closest intersection
			if PlaneMinimum > PlaneMaximum then
				local Temporary = PlaneMinimum
				PlaneMinimum = PlaneMaximum
				PlaneMaximum = Temporary
			end

			--> Replace with the nearest "far" intersection among the planes
			if PlaneMaximum < Maximum then
				Maximum = PlaneMaximum
			end

			--> Replace with the farthest "near" intersection among the planes
			if PlaneMinimum > Minimum then
				Minimum = PlaneMinimum
			end

			-- If "near" is farther than ray length then there is no intersection
			if Minimum > Length then
				return
			end

			--> If "far" is closer than "near" then there is no intersection
			if Maximum < Minimum then
				return
			end
			-- The ray is almost parallel to the planes, so they don't have any "intersection"
		elseif (-NomLength + Size > 0) or (-NomLength + Size < 0) then
			return
		end
	end
	
	--> Y plane intersection
	-- selene: allow(shadowing)
	do
		local Size = Size.Y
		local Axis = Rotation.UpVector

		local NomLength = Axis:Dot(Delta)
		local DenomLength =  Direction:Dot(Axis)

		if math.abs(DenomLength) > EPSILON then
			local PlaneMinimum = (NomLength + -Size) / DenomLength
			local PlaneMaximum = (NomLength + Size) / DenomLength

			if PlaneMinimum > PlaneMaximum then
				local Temporary = PlaneMinimum
				PlaneMinimum = PlaneMaximum
				PlaneMaximum = Temporary
			end

			if PlaneMaximum < Maximum then
				Maximum = PlaneMaximum
			end

			if PlaneMinimum > Minimum then
				Minimum = PlaneMinimum
			end

			if Minimum > Length then
				return
			end

			if Maximum < Minimum then
				return
			end
		elseif (-NomLength + Size > 0) or (-NomLength + Size < 0) then
			return
		end
	end

	--> Z plane intersection
	-- selene: allow(shadowing)
	do
		local Size = Size.Z
		local Axis = Rotation.LookVector

		local NomLength = Axis:Dot(Delta)
		local DenomLength =  Direction:Dot(Axis)

		if math.abs(DenomLength) > EPSILON then
			local PlaneMinimum = (NomLength + -Size) / DenomLength
			local PlaneMaximum = (NomLength + Size) / DenomLength

			if PlaneMinimum > PlaneMaximum then
				local Temporary = PlaneMinimum
				PlaneMinimum = PlaneMaximum
				PlaneMaximum = Temporary
			end

			if PlaneMaximum < Maximum then
				Maximum = PlaneMaximum
			end

			if PlaneMinimum > Minimum then
				Minimum = PlaneMinimum
			end

			if Minimum > Length then
				return
			end

			if Maximum < Minimum then
				return
			end
		elseif (-NomLength + Size > 0) or (-NomLength + Size < 0) then
			return
		end
	end

	return Minimum
end

---- Initialization ----

---- Connections ----

return Utility