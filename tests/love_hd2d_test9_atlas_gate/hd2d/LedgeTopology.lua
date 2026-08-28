local root = assert(os.getenv("KRS_ROOT"), "KRS_ROOT is required")
return assert(dofile(root .. "/packages/kanto_rework_hd2d_world/hd2d/LedgeTopology.lua"))
