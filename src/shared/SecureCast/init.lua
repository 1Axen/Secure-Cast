--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

---- Imports ----

local Dispatcher = require(script.Dispatcher)
local Simulation = require(script.Simulation)

---- Settings ----

local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

local DEFAULT_THREADS = 9

---- Constants ----

local SecureCast = {}

---- Variables ----

local SimulationDispatcher;

---- Private Functions ----

---- Public Functions ----

function SecureCast.Initialize(Threads: number?)
    assert(SimulationDispatcher == nil, "SecureCast.Initialize can only be called once per execution context!")

    Simulation.ImportDefentions()
    SimulationDispatcher = Dispatcher.new(Threads or DEFAULT_THREADS, script.Simulation, Simulation.Process)
end

function SecureCast.Cast(Caster: Player, Type: string, Origin: Vector3, Direction: Vector3, Timestamp: number, PVInstance: PVInstance?, Modifier: Simulation.Modifier?)
    assert(SimulationDispatcher, "You must call SecureCast.Initialize before calling SecureCast.Cast!")
    SimulationDispatcher:Dispatch(Caster, Type, Origin, Direction, Timestamp, PVInstance, Modifier)
end

---- Initialization ----

---- Connections ----

return SecureCast