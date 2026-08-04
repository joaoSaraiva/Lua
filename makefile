
lua:
	lua imperative_loop.lua
	lua filter_map.lua
	lua map_filter.lua
	lua filterWithConjunction.lua
	lua conjunctionOfFilters.lua
	lua fusionByHand.lua

luajit:
	luajit imperative_loop.lua
	luajit filter_map.lua
	luajit map_filter.lua
	luajit filterWithConjunction.lua
	luajit conjunctionOfFilters.lua
	luajit fusionByHand.lua

all:
	make lua
	make luajit
