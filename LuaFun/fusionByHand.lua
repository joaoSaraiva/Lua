
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
print('-- Filter/Map fusion (by hand) --')


-- 6. filter/map fusion (by hand)
-- baseline is the map_filter.lua

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



