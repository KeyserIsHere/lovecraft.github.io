function NewPlayer(x,y,z)
    local t = NewThing(x,y,z)
    t.friction = 0.9
    t.moveSpeed = 0.01
    t.viewBob = 0
    t.viewBobMult = 0
    t.name = "player"
    t.voxelCursor = CreateThing(NewVoxelCursor(0,0,0))
    t.cursorpos = {}
    t.cursorposPrev = {}
    t.onGround = false

    t.update = function (self, dt)
        local Camera = Scene.camera
        self.xSpeed = self.xSpeed * self.friction
        self.zSpeed = self.zSpeed * self.friction
        self.ySpeed = self.ySpeed - 0.01
        self.onGround = false
        if TileEnums(GetVoxel(self.x,self.y-1.5+self.ySpeed,self.z)).isSolid then
            self.ySpeed = 0
            self.onGround = true
        end

        local mx,my = 0,0
        local moving = false

        if love.keyboard.isDown("w") then
            mx = mx + 0
            my = my - 1

            moving = true
        end
        if love.keyboard.isDown("a") then
            mx = mx - 1
            my = my + 0

            moving = true
        end
        if love.keyboard.isDown("s") then
            mx = mx + 0
            my = my + 1

            moving = true
        end
        if love.keyboard.isDown("d") then
            mx = mx + 1
            my = my + 0

            moving = true
        end

        if love.keyboard.isDown("space") and self.onGround then
            self.ySpeed = self.ySpeed + 0.165
        end

        if moving then
            local angle = math.angle(0,0, mx,my)
            self.direction = (Camera.angle.x + angle)*-1 +math.pi/2
            self.xSpeed = self.xSpeed + math.cos(Camera.angle.x + angle) * self.moveSpeed
            self.zSpeed = self.zSpeed + math.sin(Camera.angle.x + angle) * self.moveSpeed
        end
        if not TileEnums(GetVoxel(self.x+self.xSpeed,self.y,self.z)).isSolid
        and not TileEnums(GetVoxel(self.x+self.xSpeed,self.y-1,self.z)).isSolid then
            self.x = self.x + self.xSpeed
        else
            self.xSpeed = 0
        end
        if not TileEnums(GetVoxel(self.x,self.y,self.z+self.zSpeed)).isSolid
        and not TileEnums(GetVoxel(self.x,self.y-1,self.z+self.zSpeed)).isSolid then
            self.z = self.z + self.zSpeed
        else
            self.zSpeed = 0
        end
        self.y = self.y + self.ySpeed

        local speed = math.dist(0,0, self.xSpeed,self.zSpeed)
        self.viewBob = self.viewBob + speed*2
        self.viewBobMult = math.min(speed, 1)

        Scene.camera.pos.x = self.x
        Scene.camera.pos.y = self.y + math.sin(self.viewBob)*self.viewBobMult*0.5
        Scene.camera.pos.z = self.z

        local rx,ry,rz = Scene.camera.pos.x,Scene.camera.pos.y,Scene.camera.pos.z
        local step = 0.1
        self.voxelCursor.model.visible = false
        for i=1, 5, step do
            local chunk, cx,cy,cz, hashx,hashy = GetChunk(rx,ry,rz)
            if chunk ~= nil and chunk:getVoxel(cx,cy,cz) ~= 0 then
                self.cursorpos = {x=cx,y=cy,z=cz, chunk=chunk}
                self.voxelCursor.model.visible = true
                self.voxelCursor.model:setTransform({math.floor(rx), math.floor(ry), math.floor(rz)})
                break
            end
            self.cursorposPrev = {x=cx,y=cy,z=cz, chunk=chunk}

            rx = rx + math.cos(Scene.camera.angle.x -math.pi/2)*step*math.cos(Scene.camera.angle.y)
            rz = rz + math.sin(Scene.camera.angle.x -math.pi/2)*step*math.cos(Scene.camera.angle.y)
            ry = ry - math.sin(Scene.camera.angle.y)*step
        end

        return true
    end

    return t
end

function NewVoxelCursor(x,y,z)
    local t = NewThing(x,y,z)
    local model = {}
    local scale = 1.002
    local x,y,z = -0.001,-0.001,-0.001

    -- top
    model[#model+1] = {x, y+scale, z}
    model[#model+1] = {x, y+scale, z}
    model[#model+1] = {x, y+scale, z+scale}
    model[#model+1] = {x+scale, y+scale, z+scale}
    model[#model+1] = {x+scale, y+scale, z+scale}
    model[#model+1] = {x+scale, y+scale, z}
    model[#model+1] = {x+scale, y+scale, z+scale}
    model[#model+1] = {x+scale, y+scale, z+scale}
    model[#model+1] = {x, y+scale, z+scale}
    model[#model+1] = {x+scale, y+scale, z}
    model[#model+1] = {x+scale, y+scale, z}
    model[#model+1] = {x, y+scale, z}

    -- bottom
    model[#model+1] = {x, y, z}
    model[#model+1] = {x, y, z}
    model[#model+1] = {x, y, z+scale}
    model[#model+1] = {x+scale, y, z+scale}
    model[#model+1] = {x+scale, y, z+scale}
    model[#model+1] = {x+scale, y, z}
    model[#model+1] = {x+scale, y, z+scale}
    model[#model+1] = {x+scale, y, z+scale}
    model[#model+1] = {x, y, z+scale}
    model[#model+1] = {x+scale, y, z}
    model[#model+1] = {x+scale, y, z}
    model[#model+1] = {x, y, z}

    -- sides
    model[#model+1] = {x, y+scale, z}
    model[#model+1] = {x, y+scale, z}
    model[#model+1] = {x, y, z}
    model[#model+1] = {x+scale, y+scale, z}
    model[#model+1] = {x+scale, y+scale, z}
    model[#model+1] = {x+scale, y, z}
    model[#model+1] = {x, y+scale, z+scale}
    model[#model+1] = {x, y+scale, z+scale}
    model[#model+1] = {x, y, z+scale}
    model[#model+1] = {x+scale, y+scale, z+scale}
    model[#model+1] = {x+scale, y+scale, z+scale}
    model[#model+1] = {x+scale, y, z+scale}

    local compmodel = Engine.newModel(model, nil, {0,0,0}, {0,0,0})
    compmodel.wireframe = true
    t:assignModel(compmodel)

    return t
end
