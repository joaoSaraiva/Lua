-- bench_lua_matrix.lua
-- Benchmark suite for the "lua-matrix" library (https://github.com/davidm/lua-matrix)
-- Exercises 6 distinct matrix operations to probe different interpreter/JIT cost centers:
--   1. Construction/fill      -> table allocation, array-part growth
--   2. Addition                -> tight nested loop, elementwise arithmetic
--   3. Multiplication          -> O(n^3) loop nesting, register pressure, cache behavior
--   4. Transpose                -> non-sequential (strided) table access pattern
--   5. Determinant (recursive)  -> recursive call overhead, closures over sub-tables
--   6. Scalar multiplication    -> simple broadcast loop, baseline throughput reference
--
-- Usage: lua bench_lua_matrix.lua [size] [iterations]
--   luajit bench_lua_matrix.lua [size] [iterations]

local matrix = require "matrix"

local N     = tonumber(arg and arg[1]) or 40   -- matrix dimension (NxN)
local ITERS = tonumber(arg and arg[2]) or 50    -- repetitions per benchmark

-- ---------- helpers ----------

local function make_random_matrix(n)
  local m = {}
  for i = 1, n do
    m[i] = {}
    for j = 1, n do
      m[i][j] = math.random() * 100
    end
  end
  return setmetatable(m, matrix)
end

local function make_small_matrix(n)
  -- smaller matrix for the O(n^3) recursive determinant, which is
  -- factorial/exponential in cost for naive cofactor expansion
  return make_random_matrix(n)
end

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
    "%-28s  total: %8.4fs   avg/iter: %8.6fs   mem_delta: %8.1f KB",
    name, elapsed, elapsed / iters, end_mem - start_mem
  ))
  return elapsed
end

-- ---------- pre-generated fixtures ----------

local A = make_random_matrix(N)
local B = make_random_matrix(N)
local small = make_small_matrix(8) -- keep determinant tractable

-- ---------- 1. Construction / fill ----------

local function bench_construct()
  local m = {}
  for i = 1, N do
    m[i] = {}
    for j = 1, N do
      m[i][j] = i * j
    end
  end
end

-- ---------- 2. Addition ----------

local function bench_add()
  local C = matrix.add(A, B)
end

-- ---------- 3. Multiplication ----------

local function bench_mul()
  local C = matrix.mul(A, B)
end

-- ---------- 4. Transpose ----------

local function bench_transpose()
  local T = matrix.transpose(A)
end

-- ---------- 5. Determinant (recursive cofactor expansion) ----------

local function bench_determinant()
  local d = matrix.det(small)
end

-- ---------- 6. Scalar multiplication ----------

local function bench_scalar_mul()
  local C = matrix.mulnum(A, 3.14159)
end

-- ---------- run suite ----------

print(string.format("lua-matrix benchmark  |  N=%d  iters=%d  |  %s\n",
  N, ITERS, _VERSION))

local results = {}
results.construct  = bench("1. Construction/fill",        bench_construct,  ITERS)
results.add         = bench("2. Addition",                 bench_add,        ITERS)
results.mul         = bench("3. Multiplication (O(n^3))",  bench_mul,        ITERS)
results.transpose   = bench("4. Transpose",                 bench_transpose,  ITERS)
results.determinant = bench("5. Determinant (recursive)",  bench_determinant, ITERS)
results.scalar_mul  = bench("6. Scalar multiplication",     bench_scalar_mul, ITERS)

print("\nDone.")