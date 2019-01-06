Engine = require "engine"
require "player"
require "chunk"

function love.load()
    GraphicsWidth, GraphicsHeight = 520*2, (520*9/16)*2
    love.graphics.setBackgroundColor(0,0.7,0.95)
    love.mouse.setRelativeMode(true)
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.window.setMode(GraphicsWidth,GraphicsHeight, {vsync=true})
    Scene = Engine.newScene(GraphicsWidth, GraphicsHeight)
    Scene.camera.perspective = TransposeMatrix(cpml.mat4.from_perspective(90, love.graphics.getWidth()/love.graphics.getHeight(), 0.1, 10000))

    LightValues = 16
    DefaultTexture = love.graphics.newImage("texture.png")
    TileTexture = love.graphics.newImage("terrain.png")

    local width, height = TileTexture:getWidth(), TileTexture:getHeight()
    LightingTexture = love.graphics.newCanvas(width*LightValues, height)
    local mult = 1
    love.graphics.setCanvas(LightingTexture)
    love.graphics.clear(0,0,0,1)
    for i=LightValues, 1, -1 do
        local xx = (i-1)*width
        love.graphics.setColor(1,1,1, mult)
        love.graphics.draw(TileTexture, xx,0)
        mult = mult * 0.8
    end
    love.graphics.setColor(1,1,1)
    love.graphics.setCanvas()

    ChunkSize = 16
    SliceHeight = 8
    WorldHeight = 128
    TileWidth, TileHeight = 1/16,1/16
    ThingList = {}

    Salt = {}
    for i=1, 256 do
        Salt[i] = love.math.random()
    end

    ChunkList = {}
    local viewSize = 4
    for i=viewSize/-2 +1, viewSize/2 do
        print(i)
        ChunkList[ChunkHash(i)] = {}
        for j=viewSize/-2 +1, viewSize/2 do
            ChunkList[ChunkHash(i)][ChunkHash(j)] = CreateThing(NewChunk(i,j))
        end
    end
    for i=viewSize/-2 +1, viewSize/2 do
        print(i)
        for j=viewSize/-2 +1, viewSize/2 do
            ChunkList[ChunkHash(i)][ChunkHash(j)]:initialize()
        end
    end
    ThePlayer = CreateThing(NewPlayer(0,90,0))
end

function ChunkHash(x)
    if x < 0 then
        return math.abs(2*x)
    end

    return 1 + 2*x
end

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

function CreateThing(thing)
    table.insert(ThingList, thing)
    return thing
end

function NewThing(x,y,z)
    local t = {}
    t.x = x
    t.y = y
    t.z = z
    t.xSpeed = 0
    t.ySpeed = 0
    t.zSpeed = 0
    t.modelID = -1
    t.model = nil
    t.direction = 0
    t.name = "thing"
    t.assignedModel = 0

    t.update = function (self, dt)
        return true
    end

    t.assignModel = function (self, model)
        self.model = model 

        if self.assignedModel == 0 then
            table.insert(Scene.modelList, self.model)
            self.assignedModel = #Scene.modelList
        else
            Scene.modelList[self.assignedModel] = self.model
        end
    end

    t.destroyModel = function (self)
        self.model.dead = true
    end

    t.destroy = function (self)
    end

    t.mousepressed = function (self, b)
    end

    t.distanceToThing = function (self, thing,radius, ignorey)
        for i=1, #ThingList do
            local this = ThingList[i]
            local distcheck = math.dist3d(this.x,this.y,this.z, self.x,self.y,self.z) < radius

            if ignorey then
                distcheck = math.dist3d(this.x,0,this.z, self.x,0,self.z) < radius
            end

            if this.name == thing 
            and this ~= self 
            and distcheck then
                return this
            end
        end

        return nil
    end

    return t
end

function NewBillboard(x,y,z)
    local t = NewThing(x,y,z)
    local verts = {}
    local scale = 6
    local hs = scale/2
    verts[#verts+1] = {0,0,hs, 1,1}
    verts[#verts+1] = {0,0,-hs, 0,1}
    verts[#verts+1] = {0,scale,hs, 1,0}

    verts[#verts+1] = {0,0,-hs, 0,1}
    verts[#verts+1] = {0,scale,-hs, 0,0}
    verts[#verts+1] = {0,scale,hs, 1,0}

    texture = love.graphics.newImage("/textures/enemy1.png")
    local model = Engine.newModel(Engine.luaModelLoader(verts), DefaultTexture, {0,0,0})
    model.lightable = false
    t:assignModel(model)

    t.direction = 0

    t.update = function (self, dt)
        self.direction = -1*Scene.camera.angle.x+math.pi/2 
        self.model:setTransform({self.x,self.y,self.z}, {self.direction, cpml.vec3.unit_y})
        return true
    end

    return t
end

function TileEnums(n)
    local list = {
        -- textures are in format: SIDE UP DOWN FRONT
        -- at least one texture must be present
        {texture = {0}, isVisible = false, isSolid = false}, -- air
        {texture = {1}, isVisible = true, isSolid = true}, -- stone
        {texture = {3,0,2}, isVisible = true, isSolid = true}, -- grass
        {texture = {2}, isVisible = true, isSolid = true}, -- dirt
        {texture = {4}, isVisible = true, isSolid = true}, -- planks
        {texture = {7}, isVisible = true, isSolid = true}, -- bricks
        {texture = {16}, isVisible = true, isSolid = true}, -- cobble
    }

    return list[n+1]
end

function NumberToCoord(n, w,h)
    local y = math.floor(n/w)
    local x = n-(y*w)

    return x,y
end

function GetVoxel(x,y,z)
    local chunk, cx,cy,cz = GetChunk(x,y,z)
    local v = 0
    if chunk ~= nil then
        v = chunk:getVoxel(cx,cy,cz)
    end
    return v
end

function love.update(dt)
    Scene:update()
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

function love.draw()
    Scene:render(true)
    Scene:renderFunction(
        function ()
            love.graphics.setColor(0,0,0)
            love.graphics.print("x: "..math.floor(ThePlayer.x+0.5).."\ny: "..math.floor(ThePlayer.y+0.5).."\nz: "..math.floor(ThePlayer.z+0.5))
            local chunk, cx,cy,cz, hashx,hashy = GetChunk(ThePlayer.x,ThePlayer.y,ThePlayer.z)
            if chunk ~= nil then
                love.graphics.print("kB: "..math.floor(collectgarbage('count')),0,50)
            end
            love.graphics.print("FPS: "..love.timer.getFPS(), 0, 70)
        end, true
    )

    --love.graphics.setColor(1,1,1)
    --local scale = love.graphics.getWidth()/GraphicsWidth
    --love.graphics.draw(Scene.threeCanvas, love.graphics.getWidth()/2,love.graphics.getHeight()/2, 0, scale,-1*scale, GraphicsWidth/2, GraphicsHeight/2)
    --love.graphics.draw(Scene.twoCanvas, love.graphics.getWidth()/2,love.graphics.getHeight()/2 +1, 0, scale,scale, GraphicsWidth/2, GraphicsHeight/2)
end

function love.mousemoved(x,y, dx,dy)
    Scene:mouseLook(x,y, dx,dy)
end

function love.mousepressed(x,y, b)
    for i=1, #ThingList do
        local thing = ThingList[i]
        thing:mousepressed(b)
    end

    local pos = ThePlayer.cursorpos
    local value = 0

    if b == 2 then
        pos = ThePlayer.cursorposPrev
        value = 6
    end

    local cx,cy,cz = pos.x, pos.y, pos.z
    local chunk = pos.chunk
    if chunk ~= nil 
    and ThePlayer.cursorpos.chunk ~= nil 
    and ThePlayer.cursorpos.chunk:getVoxel(ThePlayer.cursorpos.x,ThePlayer.cursorpos.y,ThePlayer.cursorpos.z) ~= 0 then
        chunk:setVoxel(cx,cy,cz, value)
        chunk:updateModel(cx,cy,cz)
        print("---")
        print(cx,cy,cz)
        print(cx%ChunkSize,cy%SliceHeight,cz%ChunkSize)
    end
end

function love.keypressed(k)
end

function lerp(a,b,t) return (1-t)*a + t*b end
function math.angle(x1,y1, x2,y2) return math.atan2(y2-y1, x2-x1) end
function math.dist(x1,y1, x2,y2) return ((x2-x1)^2+(y2-y1)^2)^0.5 end
function math.dist3d(x1,y1,z1, x2,y2,z2) return ((x2-x1)^2+(y2-y1)^2+(z2-z1)^2)^0.5 end
