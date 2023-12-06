--!strict
--!optimize 2
--!nolint LocalShadow

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

---- Imports ----

---- Settings ----

--> Times - How much time a tag took to run
--> Invocations - How many times a tag appears per sample

type Tag = {
	Samples: number,
	Timestamp: number,

	Times: {number},
	Invocations: {number},
}

---- Constants ----

local Utility = {}

---- Variables ----

---- Private Functions ----

local function Format(Time: number): string
	if Time < 1E-6 then
		return `{Time * 1E+9} ns`
	elseif Time < 0.001 then
		return `{Time * 1E+6} μs`
	elseif Time < 1 then
		return `{Time * 1000} ms`
	else
		return `{Time} s`
	end
end

---- Public Functions ----

function Utility.Benchmark(Label: string, Samples: number, Closure: (Begin: (Name: string) -> (), End: (Name: string) -> (), ...any) -> (...any), ...: any)
	local Elapsed = 0
	local Results = table.create(Samples)
	
	--> Prevent 'Script timeout: exhausted allowed execution time'
	local Tick = os.clock()
	local function Rest()
		if (os.clock() - Tick) > 5 then
			Tick = os.clock()
			task.wait()
		end
	end
	
	--> Tag system	
	local Tags: {[string]: Tag} = {}
	local function Begin(Name: string)
		local Tag = Tags[Name]
		if not Tag then
			Tags[Name] = {
				Samples = 1,
				Timestamp = os.clock(),

				Times = {},
				Invocations = {}
			}

			return
		end

		Tag.Samples += 1
		Tag.Timestamp = os.clock()
	end
	
	local function End(Name: string)
		local Tag = Tags[Name]
		table.insert(Tag.Times, os.clock() - Tag.Timestamp)
	end
	
	for _ = 1, Samples do
		--> Execute closure
		local Start = os.clock()
		Closure(Begin, End, ...)
		local Time = (os.clock() - Start)
		
		--> Accumulate
		Elapsed += Time
		table.insert(Results, Time)
		
		--> Record calls
		for _, Tag in Tags do
			table.insert(Tag.Invocations, Tag.Samples)
			Tag.Samples = 0
		end
		
		Rest()
	end
	
	task.wait()
	
	--> Main benchmark results
	do
		table.sort(Results)

		local Index50th = math.max(math.floor(Samples / 2), 1)	
		local Index95th = math.max(math.floor(Samples * 0.95), 1)
		local Index99th = math.max(math.floor(Samples * 0.99), 1)
		
		warn(`BENCHMARK: {Label} -- {debug.info(2, "s")}`)
		print(`Fastest Time: {Format(Results[1])}`)
		print(`Average Time: {Format(Elapsed / Samples)}`)
		print(`50th Percentile: {Format(Results[Index50th])}`)
		print(`95th Percentile: {Format(Results[Index95th])}`)
		print(`99th Percentile: {Format(Results[Index99th])}`)
	end
	
	--selene: allow(shadowing)
	for Name, Tag in Tags do
		local Times = Tag.Times
		local Invocations = Tag.Invocations

		local Elapsed = 0
		local Samples = 0
		
		for _, Time in Times do
			Elapsed += Time
			Rest()
		end
		
		task.wait()
		
		for _, Amount in Invocations do
			Samples += Amount
			Rest()
		end
		
		task.wait()
		table.sort(Invocations)
		task.wait()
		table.sort(Times)
		
		local Index50th = math.max(math.floor(#Times / 2), 1)	
		local Index95th = math.max(math.floor(#Times * 0.95), 1)
		local Index99th = math.max(math.floor(#Times * 0.99), 1)
		local InvocationsIndex50th = math.max(math.floor(#Invocations / 2), 1)	
		
		warn(`TAG: {Name}`)
		print(`	Sample Time: {Format(Times[Index50th] * Invocations[InvocationsIndex50th])}`)
		print(`	Fastest Time: {Format(Times[1])}`)
		print(`	Average Time: {Format(Elapsed / #Times)}`)
		print(`	Average Invocations: {Samples / #Invocations}`)
		print(`	50th Percentile: {Format(Times[Index50th])}`)
		print(`	95th Percentile: {Format(Times[Index95th])}`)
		print(`	99th Percentile: {Format(Times[Index99th])}`)
		
		Rest()
	end
end

---- Initialization ----

---- Connections ----

return Utility