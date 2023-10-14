--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

---- Imports ----

---- Settings ----

local IS_SERVER = RunService:IsServer()

export type Dispatcher = typeof(setmetatable({}, {})) & {
	Module: ModuleScript,
	Threads: {Actor},
	Callback: (...any) -> (...any),
	
	Dispatch: (Dispatcher, ...any) -> (),
	Allocate: (Dispatcher, Threads: number) -> (),
}

---- Constants ----

local Dispatcher = {}
Dispatcher.__index = Dispatcher

local Template;
local Container: Folder;

---- Variables ----

---- Private Functions ----

---- Public Functions ----

function Dispatcher.new(Threads: number, Module: ModuleScript, Callback: (...any) -> (...any)): Dispatcher
	assert(typeof(Module) == "Instance" and Module:IsA("ModuleScript"), "Invalid argument #1 to 'Dispatcher.new', module must be a module script.")
	assert(type(Threads) == "number" and Threads > 0, "Invalid argument #2 to 'Dispatcher.new', threads must be a positive integer.")
	
	local self: Dispatcher = setmetatable({
		Module = Module,
		Threads = {},
		Callback = Callback,
	} :: any, Dispatcher)
	
	--> Allocate initial threads
	self:Allocate(Threads)
	
	return self
end

function Dispatcher:Allocate(Threads: number)
	assert(type(Threads) == "number" and Threads > 0, "Invalid argument #2 to 'Dispatcher.new', threads must be a positive integer.")
	
	local Actors = {}
	
	--> Create actors
	for Index = 1, Threads do
		local Actor = Template:Clone()
		Actor.Parent = Container
		Actor.Controller.Enabled = true
		Actor.Output.Event:Connect(self.Callback)
		table.insert(Actors, Actor)
	end
	
	--> Allow actors to start
	RunService.PostSimulation:Wait()
	
	--> Initialize actors
	for Index, Actor in Actors do
		Actor:SendMessage("Initialize", self.Module)
	end
	
	--> Merge actors into threads
	table.move(Actors, 1, #Actors, #self.Threads + 1, self.Threads)
end

function Dispatcher:Dispatch(...)
	local Threads: {Actor} = table.clone(self.Threads)
	table.sort(Threads, function(a: Actor, b: Actor)
		return (a:GetAttribute("Tasks") < b:GetAttribute("Tasks"))
	end)
	
	Threads[1]:SendMessage("Dispatch", ...)
end

---- Initialization ----

do
	local Actor = Instance.new("Actor")
	Actor:SetAttribute("Tasks", 0)
	
	local Output = Instance.new("BindableEvent")
	Output.Name = "Output"
	Output.Parent = Actor
	
	local Controller = (IS_SERVER and script.ServerController or script.ClientController):Clone()
	Controller.Name = "Controller"
	Controller.Parent = Actor
	Actor.Parent = script
	
	Template = Actor :: any
end

do
	Container = Instance.new("Folder")
	Container.Name = "DISPATCHER_THREADS"
	Container.Parent = IS_SERVER and ServerScriptService or ReplicatedFirst 
end

---- Connections ----

return Dispatcher