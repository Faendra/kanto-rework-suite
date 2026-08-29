-- The official Gen1Recomp v0.2.32 tests/love_stub.lua deliberately omits
-- love.graphics.newMesh so non-rendering engine tests take fallback paths.
-- BUILDING-01 requires meshes in production, therefore this loader-only shim
-- supplies the smallest compatible mesh object while the real LÖVE gate uses
-- LÖVE's actual GPU mesh implementation.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

if not love.graphics.newMesh then
  love.graphics.newMesh = function(vertices)
    local mesh = { vertices = vertices, texture = nil, released = false }
    function mesh:setVertices(value) self.vertices = value end
    function mesh:setTexture(value) self.texture = value end
    function mesh:release() self.released = true end
    return mesh
  end
end

local root = assert(os.getenv("KRS_ROOT"), "KRS_ROOT is required")
dofile(root .. "/tests/building_first_loader_v0232.lua")
