-- bench_penlight_collections.lua
-- Benchmark suite for Penlight's collection modules (pl.List, pl.Map, pl.Set, pl.tablex)
-- https://github.com/lunarmodules/Penlight
--
-- Exercises 6 distinct operations to probe different interpreter/JIT cost centers:
--   1. List construction + iteration      -> table/array allocation, sequential access
--   2. List map/filter (functional style) -> closures, higher-order call overhead
--   3. Map (dict) insertion + lookup       -> hash-part table access, key hashing
--   4. Set union/intersection              -> table-driven set algebra, membership tests
--   5. List sort with comparator           -> closure-driven comparison, sort algorithm cost
--   6. tablex.deepcopy                     -> recursive table traversal, allocation-heavy
--
-- Usage: lua bench_penlight_collections.lua [size] [iterations]
--   luajit bench_penlight_collections.lua [size] [iterations]

local List   = require "pl.List"
local Map    = require "pl.Map"
local Set    = require "pl.Set"
local tablex = require "pl.tablex"

local N     = tonumber(arg and arg[1]) or 2000  -- collection size
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

-- ---------- fixtures ----------

local base_list = List()
for i = 1, N do base_list:append(i) end

local base_map = Map()
for i = 1, N do base_map:set("key" .. i, i * 2) end

local set_a = Set(List.range(1, N))
local set_b = Set(List.range(N / 2, N + N / 2))

local nested_table = {}
for i = 1, N do
  nested_table[i] = { id = i, tags = { "a", "b", "c" }, meta = { x = i, y = i * 2 } }
end

-- ---------- 1. List construction + sequential iteration ----------

local function bench_list_construct()
  local l = List()
  for i = 1, N do
    l:append(i)
  end
  local total = 0
  for _, v in ipairs(l) do
    total = total + v
  end
end

-- ---------- 2. List map/filter (functional style, closure-heavy) ----------

local function bench_list_map_filter()
  local doubled = base_list:map(function(x) return x * 2 end)
  local evens   = doubled:filter(function(x) return x % 4 == 0 end)
end

-- ---------- 3. Map (dict) insertion + lookup ----------

local function bench_map_insert_lookup()
  local m = Map()
  for i = 1, N do
    m:set("key" .. i, i)
  end
  local total = 0
  for i = 1, N do
    total = total + (m:get("key" .. i) or 0)
  end
end

-- ---------- 4. Set union/intersection ----------

local function bench_set_algebra()
  local u = set_a + set_b   -- union
  local i = set_a * set_b   -- intersection
  local d = set_a - set_b   -- difference
end

-- ---------- 5. List sort with comparator ----------

local function bench_list_sort()
  local l = base_list:clone()
  -- shuffle-ish access pattern via reverse-biased comparator
  l:sort(function(a, b) return a > b end)
end

-- ---------- 6. tablex.deepcopy (recursive, allocation-heavy) ----------

local function bench_deepcopy()
  local copy = tablex.deepcopy(nested_table)
end

-- ---------- run suite ----------

print(string.format("Penlight collections benchmark  |  N=%d  iters=%d  |  %s\n",
  N, ITERS, _VERSION))

bench("1. List construct + iterate",     bench_list_construct,   ITERS)
bench("2. List map/filter",               bench_list_map_filter,  ITERS)
bench("3. Map insert + lookup",           bench_map_insert_lookup, ITERS)
bench("4. Set union/intersect/diff",      bench_set_algebra,      ITERS)
bench("5. List sort (comparator)",        bench_list_sort,        ITERS)
bench("6. tablex.deepcopy",               bench_deepcopy,         ITERS)

print("\nDone.")
