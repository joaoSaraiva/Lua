--[[
  luafun_benchmark.lua

  Benchmarks LuaFun (https://github.com/luafun/luafun) against:
    1. Hand-written imperative for-loops
    2. Naive functional-style code using intermediate tables

  Requires:
    luarocks install fun
    (or drop fun.lua from the LuaFun repo next to this script)

  Run with:
    lua luafun_benchmark.lua
    luajit luafun_benchmark.lua   -- LuaJIT will show much larger deltas
]]

local fun = require('fun')

local N = 10*1e6          -- sequence length
--local N = 1e6          -- sequence length
local REPS = 5         -- times to repeat each benchmark for averaging

local function clock() return os.clock() end

local function bench(name, fn)
  local best = math.huge
  for i = 1, REPS do
    collectgarbage('collect')
    local t0 = clock()
    fn()
    local dt = clock() - t0
    if dt < best then best = dt end
  end
  print(string.format('%-40s %8.4f s (best of %d)', name, best, REPS))
  return best
end

print(string.format('N = %d, REPS = %d\n', N, REPS))

--------------------------------------------------------------------------
-- Task 1: sum of squares of even numbers in [1, N]
--------------------------------------------------------------------------

print('-- sum of squares of evens --')

-- 1. Plain imperative loop (baseline, fastest expected)
local t_imperative = bench('imperative for-loop', function()
  local sum = 0
  for i = 1, N do
    if i % 2 == 0 then
      sum = sum + i * i
    end
  end
  print (sum)   -- EU
  return sum
end)

-- 2. Naive functional style: builds full intermediate tables
local t_naive = bench('naive functional (tables)', function()
  local t = {}
  for i = 1, N do t[#t + 1] = i end

  local evens = {}
  for _, v in ipairs(t) do
    if v % 2 == 0 then evens[#evens + 1] = v end
  end

  local squares = {}
  for _, v in ipairs(evens) do squares[#squares + 1] = v * v end

  local sum = 0
  for _, v in ipairs(squares) do sum = sum + v end
  print (sum)   -- EU
  return sum
end)

------------------------------------------
-- Filter before map vs. map before filter
------------------------------------------

-- 3. LuaFun: lazy pipeline, no intermediate tables materialized
local t_luafun = bench('luafun (filter before map)', function()
   local sum = fun.range(1, N)
               :filter(function(x) return x % 2 == 0 end)
               :map(function(x) return x * x end)
               :reduce(function(acc, x) return acc + x end, 0)
   print (sum)
   return sum
end)


-- EU

-- 4. LuaFun: lazy pipeline, map before filter
local t_luafun2 = bench('luafun (map before filter)', function()
   local sum = fun.range(1, N)
               :map(function(x) return x * x end)
               :filter(function(x) return x % 2 == 0 end)
               :reduce(function(acc, x) return acc + x end, 0)
   print (sum)
   return sum
end)

------------------------------------------
-- One filter vs. two filters
------------------------------------------

-- They are useful for studying whether a pipeline with multiple filter
-- stages incurs any measurable overhead compared with a single filter
-- containing a conjunction

-- 5. LuaFun: single filter with a conjunction
local t_luafunFilter = bench('luafun (single filter)', function()
   local sum = fun.range(1, N)
                  :filter(function(x)      return x % 2 == 0 and x > 1 end)
                  :map(function(x)         return x * x end)
                  :reduce(function(acc, x) return acc + x end, 0)
   print (sum)
   return sum
end)

-- 6. LuaFun: two filters
local t_luafunFilters = bench('luafun (two filters)', function()
local sum = fun.range(1, N)
               :filter(function(x)      return x % 2 == 0 end)
               :filter(function(x)      return x > 1 end)
               :map(function(x)         return x * x end)
               :reduce(function(acc, x) return acc + x end, 0)
   print (sum)
   return sum
end)


------------------------------------------
-- Filter-map fusion
------------------------------------------


--[[

:filter(isEven)
:map(square)

vs


:reduce(function(acc, x)
    if isEven(x) then
        acc[#acc+1] = square(x)
    end
    return acc
end, {})

Measures the overhead of composing combinators versus manual fusion.
]]


-- 6. LuaFun: Fusion
--   the non fused is t_luafun

local t_luafunFusion = bench('luafunFusion', function()
    local sum = fun.range(1, N)
        :reduce(function(acc, x)
            if x % 2 == 0 then
                return acc + x * x
            else
                return acc
            end
        end, 0)
    print (sum)
    return sum
end)


------------------------------------------
-- Map Reduce fusion
------------------------------------------

--[[
:map(square)
:reduce(add,0)

vs

:reduce(function(acc,x)
    return acc + x*x
end,0)

Classic optimization benchmark.
]]





print()
print(string.format('LuaFun vs imperative loop:  %.2fx slower', t_luafun / t_imperative))
print(string.format('LuaFun vs naive tables (??):     %.2fx %s', 
  t_naive / t_luafun,
  (t_naive > t_luafun) and 'faster' or 'slower'))
print(string.format('LuaFun Map-before-Filter vs Filter-before-Map:  %.2fx slower', t_luafun / t_luafun2))
print(string.format('LuaFun one-Filter vs two-Filters :  %.2fx faster', t_luafunFilter / t_luafunFilters))
print(string.format('LuaFun  Filter-Map vs HandFusion :  %.2fx slower',  t_luafun / t_luafunFusion))

--------------------------------------------------------------------------
-- Task 2: iterate without ever materializing a table (LuaFun's real strength)
--------------------------------------------------------------------------

print('\n-- pure iteration, no table built --')

bench('imperative loop (no table)', function()
  local sum = 0
  for i = 1, N do
    if i % 3 == 0 then sum = sum + i end
  end
  print (sum)
  return sum
end)



--bench('luafun (no table)', function()
-- return fun.range(1, N)
--    :filter(function(x) return x % 3 == 0 end)
--    :sum()
--end)


bench('luafun (no table)', function()
  local sum1 =  fun.range(1, N)
    :filter(function(x) return x % 3 == 0 end)
    :sum()
  print (sum1)
  return sum3
end)




--------------------------------------------------------------------------
-- Task 3: take/head on a huge (effectively infinite) generator
-- This is where naive eager approaches fail entirely and LuaFun shines.
--------------------------------------------------------------------------

print('\n-- first 10 results from a huge filtered range --')

bench('luafun (lazy, short-circuits)', function()
  return fun.range(1, 1e9)
    :filter(function(x) return x % 7 == 0 end)
    :take(10)
    :totable()
end)

-- An eager equivalent over 1e9 elements would take ages / OOM,
-- so it's intentionally omitted here.
print('(eager/table-based equivalent omitted: would build a 1e9-element table)')

