Engine = require "engine"
Perspective = require "perspective"
require "things"
require "player"
require "generator"
require "chunk"

function love.load()
    -- window graphics settings
    GraphicsWidth, GraphicsHeight = 520*2, (520*9/16)*2
    InterfaceWidth, InterfaceHeight = GraphicsWidth, GraphicsHeight
    love.graphics.setBackgroundColor(0,0.7,0.95)
    love.mouse.setRelativeMode(true)
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setLineStyle("rough")
    love.window.setMode(GraphicsWidth,GraphicsHeight, {vsync=true})
    love.window.setTitle("lövecraft")

    -- create scene object from SS3D engine
    Scene = Engine.newScene(GraphicsWidth, GraphicsHeight)
    Scene.camera.perspective = TransposeMatrix(cpml.mat4.from_perspective(90, love.graphics.getWidth()/love.graphics.getHeight(), 0.1, 10000))

    -- load assets
    DefaultTexture = love.graphics.newImage("assets/texture.png")
    TileTexture = love.graphics.newImage("assets/terrain.png")
    GuiSprites = love.graphics.newImage("assets/gui.png")
    GuiHotbarQuad = love.graphics.newQuad(0,0, 182,22, GuiSprites:getDimensions())
    GuiHotbarSelectQuad = love.graphics.newQuad(0,22, 24,22+24, GuiSprites:getDimensions())
    GuiCrosshair = love.graphics.newQuad(256-16,0, 256,16, GuiSprites:getDimensions())

    -- make a separate canvas image for each of the tiles in the TileTexture
    TileCanvas = {}
    for i=1, 16 do
        for j=1, 16 do
            local xx,yy = (i-1)*16,(j-1)*16
            local index = (j-1)*16 + i
            TileCanvas[index] = love.graphics.newCanvas(16,16)
            local this = TileCanvas[index]
            love.graphics.setCanvas(this)
            love.graphics.draw(TileTexture, -1*xx,-1*yy)
        end
    end
    love.graphics.setCanvas()

    -- create lighting value textures on LightingTexture canvas
    LightValues = 16
    local width, height = TileTexture:getWidth(), TileTexture:getHeight()
    LightingTexture = love.graphics.newCanvas(width*LightValues, height)
    local mult = 1
    love.graphics.setCanvas(LightingTexture)
    love.graphics.clear(1,1,1,0)
    for i=LightValues, 1, -1 do
        local xx = (i-1)*width
        love.graphics.setColor(mult,mult,mult)
        love.graphics.draw(TileTexture, xx,0)
        mult = mult * 0.8
    end
    love.graphics.setColor(1,1,1)
    love.graphics.setCanvas()

    -- global random numbers used for generation
    Salt = {}
    for i=1, 128 do
        Salt[i] = love.math.random()
    end

    -- global variables used in world generation
    ChunkSize = 16
    SliceHeight = 8
    WorldHeight = 128
    TileWidth, TileHeight = 1/16,1/16

    -- initializing the update queue that holds all entities
    ThingList = {}
    ThePlayer = CreateThing(NewPlayer(0,128,0))
    PlayerInventory = {items = {}, hotbarSelect=1}

    for i=1, 36 do
        PlayerInventory.items[i] = 0
    end
    PlayerInventory.items[1] = 1
    PlayerInventory.items[2] = 4
    PlayerInventory.items[3] = 45
    PlayerInventory.items[4] = 3
    PlayerInventory.items[5] = 5
    PlayerInventory.items[6] = 17
    PlayerInventory.items[7] = 18
    PlayerInventory.items[8] = 20

    -- generate the world, store in 2d hash table
    ChunkList = {}
    ChunkRequests = {}
    local worldSize = 6
    for i=worldSize/-2 +1, worldSize/2 do
        print(i)
        ChunkList[ChunkHash(i)] = {}
        for j=worldSize/-2 +1, worldSize/2 do
            ChunkList[ChunkHash(i)][ChunkHash(j)] = CreateThing(NewChunk(i,j))
        end
    end
    --for i=1, #ChunkRequests do
        --local request = ChunkRequests[i]
        --for j=1, #request.blocks do
            --local block = request.blocks[j]
            --print(request.chunkx,request.chunky, block.x,block.y,block.z, block.value)
        --end
    --end
    for i=worldSize/-2 +1, worldSize/2 do
        for j=worldSize/-2 +1, worldSize/2 do
            ChunkList[ChunkHash(i)][ChunkHash(j)]:processRequests()
        end
    end
    for i=worldSize/-2 +1, worldSize/2 do
        print(i)
        for j=worldSize/-2 +1, worldSize/2 do
            ChunkList[ChunkHash(i)][ChunkHash(j)]:initialize()
        end
    end
end

-- convert an index into a point on a 2d plane of given width and height
function NumberToCoord(n, w,h)
    local y = math.floor(n/w)
    local x = n-(y*w)

    return x,y
end

-- hash function used in chunk hash table
function ChunkHash(x)
    if x < 0 then
        return math.abs(2*x)
    end

    return 1 + 2*x
end

-- get chunk from reading chunk hash table at given position
function GetChunk(x,y,z)
    local x = math.floor(x)
    local y = math.floor(y)
    local z = math.floor(z)
    local hashx,hashy = ChunkHash(math.floor(x/ChunkSize)+1), ChunkHash(math.floor(z/ChunkSize)+1)
    local getChunk = nil 
    if ChunkList[hashx] ~= nil then 
        getChunk = ChunkList[hashx][hashy]
    end

    local mx,mz = x%ChunkSize +1, z%ChunkSize +1

    return getChunk, mx,y,mz, hashx,hashy
end

-- get voxel by looking at chunk at given position's local coordinate system
function GetVoxel(x,y,z)
    local chunk, cx,cy,cz = GetChunk(x,y,z)
    local v = 0
    if chunk ~= nil then
        v = chunk:getVoxel(cx,cy,cz)
    end
    return v
end

-- tile enumerations stored as a function called by tile index (base 0 to accomodate air)
function TileEnums(n)
    local list = {
        -- textures are in format: SIDE UP DOWN FRONT
        -- at least one texture must be present
        {texture = {0}, isVisible = false, isSolid = false}, -- 0 air
        {texture = {1}, isVisible = true, isSolid = true}, -- 1 stone
        {texture = {3,0,2}, isVisible = true, isSolid = true}, -- 2 grass
        {texture = {2}, isVisible = true, isSolid = true}, -- 3 dirt
        {texture = {16}, isVisible = true, isSolid = true}, -- 4 cobble
        {texture = {4}, isVisible = true, isSolid = true}, -- 5 planks
        {texture = {15}, isVisible = true, isSolid = false}, -- 6 sapling
        {texture = {17}, isVisible = true, isSolid = true}, -- 7 bedrock
        {texture = {14}, isVisible = true, isSolid = false}, -- 8 water
        {texture = {14}, isVisible = true, isSolid = false}, -- 9 stationary water
        {texture = {63}, isVisible = true, isSolid = false}, -- 10 lava
        {texture = {63}, isVisible = true, isSolid = false}, -- 11 stationary lava
        {texture = {18}, isVisible = true, isSolid = true}, -- 12 sand
        {texture = {19}, isVisible = true, isSolid = true}, -- 13 gravel
        {texture = {32}, isVisible = true, isSolid = true}, -- 14 gold
        {texture = {33}, isVisible = true, isSolid = true}, -- 15 iron
        {texture = {34}, isVisible = true, isSolid = true}, -- 16 coal
        {texture = {20,21,21}, isVisible = true, isSolid = true}, -- 17 log
        {texture = {52}, isVisible = false, isSolid = true}, -- 18 leaves
        {texture = {48}, isVisible = true, isSolid = true}, -- 19 sponge
        {texture = {49}, isVisible = false, isSolid = true}, -- 20 glass
    }
    list[46] = {texture = {7}, isVisible = true, isSolid = true} -- 18 leaves

    -- transforms the list into base 0 to accomodate for air blocks
    return list[n+1]
end

function TileTransparency(n)
    if n == 0 then -- air (fully transparent)
        return 0
    end

    if n == 18 then -- leaves (not very transparent)
        return 1
    end

    if n == 20 then -- glass (very transparent)
        return 2
    end

    return 3 -- solid (opaque)
end

function TileTextures(n)
    local list = {
        -- textures are in format: SIDE UP DOWN FRONT
        -- at least one texture must be present
        {0}, -- 0 air
        {1}, -- 1 stone
        {3,0,2}, -- 2 grass
        {2}, -- 3 dirt
        {16}, -- 4 cobble
        {4}, -- 5 planks
        {15}, -- 6 sapling
        {17}, -- 7 bedrock
        {14}, -- 8 water
        {14}, -- 9 stationary water
        {63}, -- 10 lava
        {63}, -- 11 stationary lava
        {18}, -- 12 sand
        {19}, -- 13 gravel
        {32}, -- 14 gold
        {33}, -- 15 iron
        {34}, -- 16 coal
        {20,21,21}, -- 17 log
        {52}, -- 18 leaves
        {48}, -- 19 sponge
        {49}, -- 20 glass
    }
    list[46] = 7 -- 18 leaves

    -- transforms the list into base 0 to accomodate for air blocks
    return list[n+1]
end

function love.update(dt)
    -- update 3d scene
    Scene:update()

    -- update all things in ThingList update queue
    local i = 1
    while i<=#ThingList do
        local thing = ThingList[i]
        if thing:update(dt) then
            i=i+1
        else
            table.remove(ThingList, i)
            thing:destroy()
            thing:destroyModel()
        end
    end
end

function DrawHudTile(tile, x,y)
    local textures = TileEnums(tile).texture
    if tile == 0 or textures == nil then
        return
    end
    local x,y = x+16+6,y+16+6
    local size = 16
    local xsize = math.sin(3.14159/3)*16
    local ysize = math.cos(3.14159/3)*16
    love.graphics.setColor(1,1,1)

    local centerPoint = {x,y}

    -- textures are in format: SIDE UP DOWN FRONT
    -- top
    Perspective.quad(TileCanvas[textures[math.min(#textures, 2)]+1], {x,y-size},{x +xsize,y-ysize},centerPoint,{x-xsize,y-ysize})

    -- right side front
    local shade1 = 0.8^3
    love.graphics.setColor(shade1,shade1,shade1)
    local index = 1
    if #textures == 4 then
        index = 4
    end
    Perspective.quad(TileCanvas[textures[index]+1], centerPoint,{x +xsize,y -ysize},{x+xsize,y+ysize},{x,y+size})

    -- left side side
    local shade2 = 0.8^2
    love.graphics.setColor(shade2,shade2,shade2)
    Perspective.flip = true
    Perspective.quad(TileCanvas[textures[1]+1], centerPoint,{x -xsize,y -ysize},{x-xsize,y+ysize},{x,y+size})
    Perspective.flip = false
end

function love.draw()
    -- draw 3d scene
    Scene:render(true)

    -- draw HUD
    Scene:renderFunction(
        function ()
            love.graphics.setColor(0,0,0)
            love.graphics.print("x: "..math.floor(ThePlayer.x+0.5).."\ny: "..math.floor(ThePlayer.y+0.5).."\nz: "..math.floor(ThePlayer.z+0.5))
            local chunk, cx,cy,cz, hashx,hashy = GetChunk(ThePlayer.x,ThePlayer.y,ThePlayer.z)
            if chunk ~= nil then
                love.graphics.print("kB: "..math.floor(collectgarbage('count')),0,50)
            end
            love.graphics.print("FPS: "..love.timer.getFPS(), 0, 70)

            -- draw crosshair
            love.graphics.setColor(1,1,1)
            love.graphics.draw(GuiSprites, GuiCrosshair, InterfaceWidth/2 -16,InterfaceHeight/2 -16, 0, 2,2)

            -- draw hotbar
            love.graphics.draw(GuiSprites, GuiHotbarQuad, InterfaceWidth/2 - 182, InterfaceHeight-22*2, 0, 2,2)
            love.graphics.draw(GuiSprites, GuiHotbarSelectQuad, InterfaceWidth/2 - 182 + 40*(PlayerInventory.hotbarSelect-1) -2, InterfaceHeight-24 -22, 0, 2,2)

            for i=1, 9 do
                DrawHudTile(PlayerInventory.items[i], InterfaceWidth/2 -182 +40*(i-1),InterfaceHeight-22*2)
            end
        end, false
    )

    love.graphics.setColor(1,1,1)
    local scale = love.graphics.getWidth()/InterfaceWidth
    love.graphics.draw(Scene.twoCanvas, love.graphics.getWidth()/2,love.graphics.getHeight()/2 +1, 0, scale,scale, InterfaceWidth/2, InterfaceHeight/2)
end

function love.mousemoved(x,y, dx,dy)
    -- forward mouselook to Scene object for first person camera control
    Scene:mouseLook(x,y, dx,dy)
end

function love.wheelmoved(x,y)
    PlayerInventory.hotbarSelect = math.floor( ((PlayerInventory.hotbarSelect - y -1)%9 +1) +0.5)
end

function love.mousepressed(x,y, b)
    -- forward mousepress events to all things in ThingList 
    for i=1, #ThingList do
        local thing = ThingList[i]
        thing:mousepressed(b)
    end

    -- handle clicking to place / destroy blocks
    local pos = ThePlayer.cursorpos
    local value = 0

    if b == 2 then
        pos = ThePlayer.cursorposPrev
        value = PlayerInventory.items[PlayerInventory.hotbarSelect]
    end

    local cx,cy,cz = pos.x, pos.y, pos.z
    local chunk = pos.chunk
    if chunk ~= nil and ThePlayer.cursorpos.chunk ~= nil and ThePlayer.cursorHit then
        chunk:setVoxel(cx,cy,cz, value)
        chunk:updateModel(cx,cy,cz)
        --print("---")
        --print(cx,cy,cz)
        --print(cx%ChunkSize,cy%SliceHeight,cz%ChunkSize)
    end
end

function love.keypressed(k)
    if k == "escape" then
        love.event.push("quit")
    end
    if k == "1" then
        PlayerInventory.hotbarSelect = 1
    end
    if k == "2" then
        PlayerInventory.hotbarSelect = 2
    end
    if k == "3" then
        PlayerInventory.hotbarSelect = 3
    end
    if k == "4" then
        PlayerInventory.hotbarSelect = 4
    end
    if k == "5" then
        PlayerInventory.hotbarSelect = 5
    end
    if k == "6" then
        PlayerInventory.hotbarSelect = 6
    end
    if k == "7" then
        PlayerInventory.hotbarSelect = 7
    end
    if k == "8" then
        PlayerInventory.hotbarSelect = 8
    end
    if k == "9" then
        PlayerInventory.hotbarSelect = 9
    end
end

function lerp(a,b,t) return (1-t)*a + t*b end
function math.angle(x1,y1, x2,y2) return math.atan2(y2-y1, x2-x1) end
function math.dist(x1,y1, x2,y2) return ((x2-x1)^2+(y2-y1)^2)^0.5 end
function math.dist3d(x1,y1,z1, x2,y2,z2) return ((x2-x1)^2+(y2-y1)^2+(z2-z1)^2)^0.5 end
