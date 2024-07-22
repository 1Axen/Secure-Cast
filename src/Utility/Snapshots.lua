--!strict
--!optimize 2

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

---- Imports ----

local SecureCast = script.Parent.Parent
local Utility = SecureCast.Utility

local Settings = require(SecureCast.Settings)
local VoxelsUtility = require(Utility.Voxels)

---- Settings ----

local PARTS = Settings.Parts
local HITBOX_SIZE = Settings.HitboxSize

local SNAPSHOT_LIFETIME = Settings.SnapshotLifetime

local IS_SERVER = RunService:IsServer()

type Character = Model

export type Record = {
	Player: Player?,
	RigType: Enum.HumanoidRigType,
	Parts: {CFrame},
	Position: Vector3,
}

export type Snapshot = {
	Time: number,
	Grid: VoxelsUtility.Grid<Character>,
	Records: {[Character]: Record},
}

export type Orientations = {
    [Character]: {
        [string]: CFrame
    }
}

---- Constants ----

local Module = {}
local Snapshots: {Snapshot} = table.create(60)
local Characters: Folder = workspace[Settings.CharacterFolder]

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

local function GetSnapshotsAtTime(Time: number): (Snapshot?, Snapshot?, number?)
	assert(IS_SERVER, "Snapshots.GetSnapshotsAtTime should only be called on the server!")

    local Next: Snapshot?, Previous: Snapshot?;
    for Index = #Snapshots - 1, 1, -1 do
		local Snapshot = Snapshots[Index]
		if Snapshot and Snapshot.Time < Time then
			Next = Snapshots[Index + 1]
			Previous = Snapshots[Index]
			break
		end
	end

    if not Next or not Previous then
        return
    end

    local Fraction = (Time - Previous.Time) / (Next.Time - Previous.Time)
    return Next, Previous, Fraction
end

---- Public Functions ----

function Module.GetPlayerAtTime(Player: Player, Time: number): {[string]: CFrame}?
	assert(IS_SERVER, "Snapshots.GetPlayerAtTime should only be called on the server!")

	local Character = Player.Character
	if not Character then
		return
	end

    local Next, Previous, Fraction = GetSnapshotsAtTime(Time)
    if not Next or not Previous or not Fraction then
        return
    end

    local NextRecord = Next.Records[Character]
    local PreviousRecord = Previous.Records[Character]
    if not NextRecord or not PreviousRecord then
        return
    end

	local PartNames = PARTS[NextRecord.RigType].Names

    local Orientations: {[string]: CFrame} = {}
    for Index, Orientation in PreviousRecord.Parts do
        Orientations[PartNames[Index]] = Orientation:Lerp(NextRecord.Parts[Index], Fraction)
    end
    
    return Orientations
end

function Module.GetRecordsAtTime(Time: number): Orientations?
	assert(IS_SERVER, "Snapshots.GetPlayersAtTime should only be called on the server!")

    local Next, Previous, Fraction = GetSnapshotsAtTime(Time)
    if not Next or not Previous or not Fraction then
        return
    end

    local Orientations: Orientations = {}
    for Character, Record in Previous.Records do
        local NextRecord = Next.Records[Character]
        if not NextRecord then
            continue
        end

        local Parts = {}
		local PartNames = PARTS[NextRecord.RigType].Names
        
		Orientations[Character] = Parts

        for Index, Orientation in Record.Parts do
            Parts[PartNames[Index]] = Orientation:Lerp(NextRecord.Parts[Index], Fraction)
        end
    end

    return Orientations
end

function Module.CreatePlayersSnapshot(Time: number)
    --> Create new snapshot
	local Voxels: {[Character]: Vector3} = {}
	local Records: {[Character]: Record} = {}

	for _, Character: Character in Characters:GetChildren() :: {any} do
		local Player = Players:FindFirstChild(Character.Name)
		local Humanoid = Character:FindFirstChildWhichIsA("Humanoid") :: Humanoid
		if not Humanoid or Humanoid.Health <= 0 then
			continue
		end

		local RigType = Humanoid.RigType
		local PartNames = PARTS[RigType].Names

		local Root: BasePart? = Character.PrimaryPart or Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not Root then
			warn(`Cannot build snapshot record for {Character.Name}, it has no root.`)
			continue
		end

		local Parts = {}
		local Record: Record = {
			Parts = Parts,
			Player = Player,
			RigType = RigType,
			Position = Root.Position,
		}
		
		for Index, Name in PartNames do
			local Part: BasePart? = Character:FindFirstChild(Name) :: BasePart?
			if Part then
				Parts[Index] = Part.CFrame
				continue
			end
		end

		if #Parts == #PartNames then
			Voxels[Character] = Record.Position
			Records[Character] = Record
		end
	end

	table.insert(Snapshots, {
		Time = Time,
		Grid = VoxelsUtility.BuildVoxelGrid(Voxels, HITBOX_SIZE),
		Records = Records,
	})

	--> Remove expired snapshots (might be more than one!)
	--> We must use a reverse loop here to avoid skipping over entries when removing
	for Index = #Snapshots, 1, -1 do
		local Snapshot = Snapshots[Index]
		if (Time - Snapshot.Time) > SNAPSHOT_LIFETIME then
			table.remove(Snapshots, Index)
		end
	end
end

Module.GetPlayersAtTime = Module.GetRecordsAtTime
Module.GetSnapshotsAtTime = GetSnapshotsAtTime

---- Initialization ----

---- Connections ----

return Module