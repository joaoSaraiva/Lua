
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
print('--  Filter -> Map -> Reduce --')


-- 2. Functional: Filter -> Map -> Reduce
local t_luafun = bench('luafun (filter before map)', function()
   local sum = fun.range(1, N)
               :filter(function(x) return x % 2 == 0 end)
               :map(function(x) return x * x end)
               :reduce(function(acc, x) return acc + x end, 0)
   print (sum)
   return sum
end)


