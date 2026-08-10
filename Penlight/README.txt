





sudo luarocks install penlight



Penlight's Collections



This one targets Penlight's collection types rather than pure
functional pipelines, so it stresses a different set of mechanisms:

List construct + iterate — array-part table growth and sequential
ipairs access (baseline) List map/filter — closure-heavy higher-order
calls, similar territory to Moses/luafun but through Penlight's
OOP-style List methods Map insert + lookup — hash-part table access
and string-key hashing (distinct cost profile from array access) Set
union/intersection/difference — Penlight overloads +, *, - for set
algebra, so this benchmarks metamethod dispatch under real operator
syntax, not just function calls List sort with comparator — closure
passed into a sort routine; good for comparing sort implementation +
comparator-call overhead across implementations tablex.deepcopy —
recursive traversal over nested tables, allocation-heavy; a good proxy
for serialization-adjacent workloads

Install with:

sudo luarocks install penlight

Penlight is pure Lua with broad version support, so you shouldn't hit the same 5.3-rockspec issue as lua-matrix.

Run:

lua bench_penlight_collections.lua 2000 50
luajit bench_penlight_collections.lua 2000 50

One thing worth flagging for your writeup: Penlight's List/Map/Set are
metatable-wrapped objects with method dispatch (l:append(x)), so part
of what you're measuring here is __index lookup overhead on top of the
raw table operation — that's a genuinely different (and interesting)
axis from the plain-table operations in the lua-matrix benchmark,
since it's closer to how OOP-style Lua libraries actually get used in
practice





-- OO CLasses






This one specifically isolates metatable/inheritance costs, which was underrepresented in the previous two benchmarks:

Instantiation — constructor call overhead plus metatable setup per object (baseline allocation cost for OOP-style code)
Method dispatch (flat) — one-hop __index lookup on a class with no inheritance; the cheapest possible dispatch case
Deep inheritance (5 levels) — base_method is only defined on Level1, so every call on a Level5 instance walks the full __index chain. This is the case where implementations diverge most — PUC-Lua's cost scales roughly linearly with chain depth, while LuaJIT can often flatten/cache the lookup once a trace stabilizes
Polymorphic dispatch — a single call site (shapes[i]:area()) hitting three different concrete implementations in rotation, i.e., a megamorphic call site. This is deliberately adversarial for JIT inline caching/specialization
Operator overloading — __add/__eq metamethod dispatch through real operator syntax (a + b), not explicit method calls, so it measures metamethod resolution specifically
Multiple inheritance (mixins) — Penlight's multi-base class(Flyable, Swimmable) resolution, which walks more than one ancestor chain per lookup

Run:

lua bench_penlight_class.lua 5000 50
luajit bench_penlight_class.lua 5000 50

Worth flagging in your writeup: benchmark #3 (deep inheritance) and #4 (polymorphic/megamorphic) are the two most likely to show large PUC-Lua/LuaJIT deltas, since they hit exactly the kind of dispatch pattern LuaJIT's trace compiler either optimizes aggressively or bails out of. If you see a surprising result, those are the two to dig into first with -jv (LuaJIT's verbose trace flag) to check whether it's actually tracing through the chain or falling back to the interpreter.
