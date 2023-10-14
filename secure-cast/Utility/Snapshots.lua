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
local PARTS_SIZE = #PARTS
local HITBOX_SIZE = Settings.HitboxSize

local SNAPSHOT_LIFETIME = Settings.SnapshotLifetime

local IS_SERVER = RunService:IsServer()

export type Record = {
	Parts: {CFrame},
	Position: Vector3,
}

export type Snapshot = {
	Time: number,
	Grid: VoxelsUtility.Grid<Player>,
	Records: {[Player]: Record},
}

export type Orientations = {
    [Player]: {
        [string]: CFrame
    }
}

---- Constants ----

local Utility = {}
local Snapshots: {Snapshot} = table.create(60)

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

function Utility.GetPlayerAtTime(Player: Player, Time: number): {[string]: CFrame}?
	assert(IS_SERVER, "Snapshots.GetPlayerAtTime should only be called on the server!")

    local Next, Previous, Fraction = GetSnapshotsAtTime(Time)
    if not Next or not Previous or not Fraction then
        return
    end

    local NextRecord = Next.Records[Player]
    local PreviousRecord = Previous.Records[Player]
    if not NextRecord or not PreviousRecord then
        return
    end

    local Orientations: {[string]: CFrame} = {}
    for Index, Orientation in PreviousRecord.Parts do
        Orientations[PARTS[Index]] = Orientation:Lerp(NextRecord.Parts[Index], Fraction)
    end
    
    return Orientations
end

function Utility.GetPlayersAtTime(Time: number): Orientations?
	assert(IS_SERVER, "Snapshots.GetPlayersAtTime should only be called on the server!")

    local Next, Previous, Fraction = GetSnapshotsAtTime(Time)
    if not Next or not Previous or not Fraction then
        return
    end

    local Orientations: Orientations = {}
    for Player, Record in Previous.Records do
        local NextRecord = Next.Records[Player]
        if not NextRecord then
            continue
        end

        local Parts = {}
        Orientations[Player] = Parts

        for Index, Orientation in Record.Parts do
            Parts[PARTS[Index]] = Orientation:Lerp(NextRecord.Parts[Index], Fraction)
        end
    end

    return Orientations
end

function Utility.CreatePlayersSnapshot(Time: number)
    --> Create new snapshot
	local Voxels: {[Player]: Vector3} = {}
	local Records: {[Player]: Record} = {}

	for _, Player in Players:GetPlayers() do
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
			if Part then
				Parts[Index] = Part.CFrame
				continue
			end
		end

		if #Parts == PARTS_SIZE then
			Records[Player] = Record
			Voxels[Player] = Record.Position
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
			ClearTable(Snapshot, true)
		end
	end
end

Utility.GetSnapshotsAtTime = GetSnapshotsAtTime

---- Initialization ----

---- Connections ----

return Utility