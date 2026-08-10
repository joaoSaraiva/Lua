This exercises six distinct operations chosen to stress different implementation-specific mechanisms:

Construction/fill — table allocation and array-part growth (baseline allocation cost)
Addition — tight nested-loop elementwise arithmetic (straightforward loop optimization)
Multiplication — O(n³) triple-nested loop (register pressure, cache/locality behavior — a strong LuaJIT-vs-PUC-Lua differentiator)
Transpose — strided, non-sequential table access (tests table indexing overhead patterns different from row-major traversal)
Determinant — recursive cofactor expansion (call overhead, recursion depth, closures over sub-tables — kept to an 8×8 matrix since naive cofactor expansion is factorial-cost)
Scalar multiplication — simple broadcast loop (a low-complexity reference point to normalize the others against)


Run it with:

lua bench_lua_matrix.lua 40 50      # PUC-Lua
luajit bench_lua_matrix.lua 40 50   # LuaJIT


Notes on methodology:

N and iteration count are CLI args so you can do the pipeline/size sweep we discussed earlier.
I separated matrix size (N, default 40) from the determinant fixture (fixed at 8×8) because determinant cost scales very differently from the others — mixing them into one sweep would confound your results.
collectgarbage("count") deltas are logged per-benchmark so you can separate raw throughput from GC pressure, which matters a lot given how much these operations allocate.
You'll need luarocks install lua-matrix (or the module on your Lua path) for require "matrix" to resolve.

Want me to add a CSV/JSON output mode so you can feed results directly into a plotting script for the cross-implementation comparison?


