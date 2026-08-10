-- bench_penlight_class.lua
-- Benchmark suite for Penlight's pl.class module (class-based OOP via metatables)
-- https://github.com/lunarmodules/Penlight
--
-- Exercises 6 distinct operations to probe metatable/inheritance-related cost centers,
-- which differ significantly across Lua implementations (LuaJIT specializes
-- __index dispatch heavily; PUC-Lua's cost is more uniform per lookup):
--   1. Instantiation                 -> constructor call + metatable setup overhead
--   2. Method dispatch (single class) -> one-hop __index lookup on every call
--   3. Deep inheritance chain dispatch -> multi-hop __index traversal up the chain
--   4. Polymorphic dispatch (mixed)   -> megamorphic call site across subclasses
--   5. Operator overloading           -> __add/__eq metamethod dispatch
--   6. Multiple inheritance (mixins)  -> Penlight's multi-base class resolution

local class = require "pl.class"

local N     = tonumber(arg and arg[1]) or 5000  -- objects / calls per iteration
local ITERS = tonumber(arg and arg[2]) or 50     -- repetitions per benchmark

-- ---------- helpers ----------

local function bench(name, fn, iters)
  collectgarbage("collect")
  local start_mem = collectgarbage("count")
  local t0 = os.clock()
  for _ = 1, iters do
    fn()
  end
  local elapsed = os.clock() - t0
  local end_mem = collectgarbage("count")
  print(string.format(
    "%-32s  total: %8.4fs   avg/iter: %8.6fs   mem_delta: %8.1f KB",
    name, elapsed, elapsed / iters, end_mem - start_mem
  ))
  return elapsed
end

-- ---------- class hierarchy ----------

-- flat class, no inheritance (baseline for #1, #2)
local Point = class()
function Point:_init(x, y)
  self.x, self.y = x, y
end
function Point:magnitude()
  return math.sqrt(self.x * self.x + self.y * self.y)
end
function Point:__add(other)
  return Point(self.x + other.x, self.y + other.y)
end
function Point:__eq(other)
  return self.x == other.x and self.y == other.y
end

-- deep inheritance chain (5 levels) for #3
local Level1 = class()
function Level1:_init() self.tag = "L1" end
function Level1:base_method() return 1 end

local Level2 = class(Level1)
function Level2:_init() self:super() end

local Level3 = class(Level2)
function Level3:_init() self:super() end

local Level4 = class(Level3)
function Level4:_init() self:super() end

local Level5 = class(Level4)
function Level5:_init() self:super() end
-- base_method is only defined on Level1 -> every call walks the full chain

-- polymorphic subclasses for #4 (megamorphic call site)
local Shape = class()
function Shape:_init(kind) self.kind = kind end
function Shape:area() return 0 end

local Circle = class(Shape)
function Circle:_init(r) self:super("circle"); self.r = r end
function Circle:area() return math.pi * self.r * self.r end

local Square = class(Shape)
function Square:_init(s) self:super("square"); self.s = s end
function Square:area() return self.s * self.s end

local Triangle = class(Shape)
function Triangle:_init(b, h) self:super("triangle"); self.b, self.h = b, h end
function Triangle:area() return 0.5 * self.b * self.h end

local shapes = {}
for i = 1, N do
  local m = i % 3
  if m == 0 then shapes[i] = Circle(2)
  elseif m == 1 then shapes[i] = Square(3)
  else shapes[i] = Triangle(4, 5) end
end

-- multiple inheritance / mixins for #6
local Flyable = class()
function Flyable:fly() return "flying" end

local Swimmable = class()
function Swimmable:swim() return "swimming" end

-- Note: pl.class only supports a single base class via class(base) —
-- passing a second argument is silently ignored. True multiple
-- inheritance requires a manual mixin: copy the mixin's methods
-- directly onto the subclass table.
local Duck = class(Flyable)
function Duck:_init(name) self.name = name end
for k, v in pairs(Swimmable) do
  if type(v) == "function" and k:sub(1, 1) ~= "_" then
    Duck[k] = v
  end
end

-- ---------- 1. Instantiation ----------

local function bench_instantiation()
  local pts = {}
  for i = 1, N do
    pts[i] = Point(i, i * 2)
  end
end

-- ---------- 2. Method dispatch (single class, one-hop __index) ----------

local point_pool = {}
for i = 1, N do point_pool[i] = Point(i, i) end

local function bench_method_dispatch()
  local total = 0
  for i = 1, N do
    total = total + point_pool[i]:magnitude()
  end
end

-- ---------- 3. Deep inheritance chain dispatch ----------

local level5_pool = {}
for i = 1, N do level5_pool[i] = Level5() end

local function bench_deep_inheritance()
  local total = 0
  for i = 1, N do
    total = total + level5_pool[i]:base_method()  -- resolves via 4 __index hops
  end
end

-- ---------- 4. Polymorphic dispatch (megamorphic call site) ----------

local function bench_polymorphic_dispatch()
  local total = 0
  for i = 1, N do
    total = total + shapes[i]:area()  -- same call site, 3 different implementations
  end
end

-- ---------- 5. Operator overloading (__add / __eq metamethods) ----------

local function bench_operator_overload()
  local acc = Point(0, 0)
  for i = 1, N do
    acc = acc + point_pool[i]  -- __add dispatch each iteration
  end
  local _ = (acc == acc)        -- __eq dispatch
end

-- ---------- 6. Multiple inheritance (mixin) dispatch ----------

local duck_pool = {}
for i = 1, N do duck_pool[i] = Duck("duck" .. i) end

local function bench_multiple_inheritance()
  local total = 0
  for i = 1, N do
    local d = duck_pool[i]
    if d:fly() then total = total + 1 end
    if d:swim() then total = total + 1 end
  end
end

-- ---------- run suite ----------

print(string.format("Penlight pl.class benchmark  |  N=%d  iters=%d  |  %s\n",
  N, ITERS, _VERSION))

bench("1. Instantiation",                bench_instantiation,        ITERS)
bench("2. Method dispatch (flat)",       bench_method_dispatch,      ITERS)
bench("3. Deep inheritance (5 levels)",  bench_deep_inheritance,     ITERS)
bench("4. Polymorphic dispatch",         bench_polymorphic_dispatch, ITERS)
bench("5. Operator overloading",         bench_operator_overload,    ITERS)
bench("6. Multiple inheritance (mixin)", bench_multiple_inheritance, ITERS)

print("\nDone.")
