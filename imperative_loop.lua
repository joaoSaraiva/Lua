
local fun = require('fun')

--local N = 10*1e6          -- sequence length
local N = 1e6          -- sequence length
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

print('-- sum of squares of evens --')
print('-- imperative loop --')


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

