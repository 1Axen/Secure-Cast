--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local RunService = game:GetService("RunService")

---- Imports ----

local Utility = script.Utility

local Settings = require(script.Settings)

--> Ensure that a visuals folder exists
do
    local Visuals = workspace:FindFirstChild(Settings.VisualsFolder)
    if not Visuals then
        local Folder = Instance.new("Folder")
        Folder.Name = Settings.VisualsFolder
        Folder.Parent = workspace
    end
end

local Dispatcher = require(script.Dispatcher)
local Simulation = require(script.Simulation)
local SnapshotsUtility = require(Utility.Snapshots)

---- Settings ----

local IS_SERVER = RunService:IsServer()

export type Settings = typeof(Settings)

---- Constants ----

local SecureCast = {
    Settings = Settings,
    Snapshots = SnapshotsUtility
}

---- Variables ----

local SimulationDispatcher;

---- Private Functions ----

---- Public Functions ----

function SecureCast.Initialize()
    assert(SimulationDispatcher == nil, "SecureCast.Initialize can only be called once per execution context!")
    assert(workspace:WaitForChild(Settings.CharacterFolder, 15), `SecureCast requires a "{Settings.CharacterFolder}" folder in workspace to function properly!`)

    Simulation.ImportDefentions()
    SimulationDispatcher = Dispatcher.new(Settings.Threads, script.Simulation, Simulation.Process)

    if IS_SERVER then
        RunService.PostSimulation:Connect(function()
            SnapshotsUtility.CreatePlayersSnapshot(os.clock())
        end)
    end
end

function SecureCast.Cast(Caster: Player, Type: string, Origin: Vector3, Direction: Vector3, Timestamp: number, PVInstance: PVInstance?, Modifier: Simulation.Modifier?)
    assert(SimulationDispatcher, "You must call SecureCast.Initialize before calling SecureCast.Cast!")
    SimulationDispatcher:Dispatch(Caster, Type, Origin, Direction, Timestamp, PVInstance, Modifier)
end

---- Initialization ----

---- Connections ----

return SecureCast