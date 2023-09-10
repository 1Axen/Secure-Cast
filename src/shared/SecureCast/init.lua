--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local RunService = game:GetService("RunService")

---- Imports ----

local Utility = script.Utility

local Settings = require(script.Settings)
local Dispatcher = require(script.Dispatcher)
local Simulation = require(script.Simulation)

local SnapshotsUtility = require(Utility.Snapshots)

---- Settings ----

local IS_SERVER = RunService:IsServer()
local DEFAULT_THREADS = Settings.Threads

---- Constants ----

local SecureCast = {
    Snapshots = SnapshotsUtility
}

---- Variables ----

local SimulationDispatcher;

---- Private Functions ----

---- Public Functions ----

function SecureCast.Initialize(Threads: number?)
    assert(SimulationDispatcher == nil, "SecureCast.Initialize can only be called once per execution context!")

    Simulation.ImportDefentions()
    SimulationDispatcher = Dispatcher.new(Threads or DEFAULT_THREADS, script.Simulation, Simulation.Process)

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