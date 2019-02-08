function ReplaceChar(str, pos, r)
    return str:sub(1, pos-1) .. r .. str:sub(pos+#r)
end

function NewChunk(x,z)
    local chunk = NewThing(x,0,z)
    chunk.voxels = {}
    chunk.slices = {}
    chunk.heightMap = {}
    chunk.name = "chunk"

    -- store a list of voxels to be updated on next modelUpdate
    chunk.changes = {}

    for i=1, ChunkSize do
        chunk.heightMap[i] = {}
    end

    DefaultGeneration(chunk, x,z)

    chunk.sunlight = function (self)
        for i=1, ChunkSize do
            for j=1, ChunkSize do
                local gx,gz = (x-1)*ChunkSize + i-1, (z-1)*ChunkSize + j-1
                local this = self.heightMap[i][j]
                --print(gx,gz)

                if i == 1 or this > self.heightMap[i-1][j]+1 then
                    NewSunlightDownAddition(gx-1,this,gz, 15)
                end
                if j == 1 or this > self.heightMap[i][j-1] then
                    NewSunlightDownAddition(gx,this,gz-1, 15)
                end
                if i == ChunkSize or this > self.heightMap[i+1][j] then
                    NewSunlightDownAddition(gx+1,this,gz, 15)
                end
                if j == ChunkSize or this > self.heightMap[i][j+1] then
                    NewSunlightDownAddition(gx,this,gz+1, 15)
                end
            end
        end
    end

    -- process all requested blocks upon creation of chunk
    chunk.processRequests = function (self)
        for i=1, #ChunkRequests do
            local request = ChunkRequests[i]
            if request.chunkx == self.x and request.chunky == self.z then
                for j=1, #request.blocks do
                    local block = request.blocks[j]
                    if not TileCollisions(self:getVoxel(block.x,block.y,block.z)) then
                        self:setVoxel(block.x,block.y,block.z, block.value)
                    end
                end
            end
        end
    end

    chunk.initialize = function (self)
        for i=1, WorldHeight/SliceHeight do
            self.slices[i] = NewChunkSlice(self.x,self.y + (i-1)*SliceHeight+1,self.z, self)
        end
        self.changes = {}
    end

    -- get voxel id of the voxel in this chunk's coordinate space
    chunk.getVoxel = function (self, x,y,z)
        x = math.floor(x)
        y = math.floor(y)
        z = math.floor(z)
        if x <= ChunkSize and x >= 1
        and z <= ChunkSize and z >= 1
        and y >= 1 and y <= WorldHeight then
            return string.byte(self.voxels[x][z]:sub((y-1)*2 +1,(y-1)*2 +1)), string.byte(self.voxels[x][z]:sub((y-1)*2 +2,(y-1)*2 +2))
        end

        return 0, 0
    end

    chunk.getVoxelFirstData = function (self, x,y,z)
        x = math.floor(x)
        y = math.floor(y)
        z = math.floor(z)
        if x <= ChunkSize and x >= 1
        and z <= ChunkSize and z >= 1
        and y >= 1 and y <= WorldHeight then
            return string.byte(self.voxels[x][z]:sub((y-1)*2 +2,(y-1)*2 +2))%16
        end

        return 0
    end

    chunk.getVoxelSecondData = function (self, x,y,z)
        x = math.floor(x)
        y = math.floor(y)
        z = math.floor(z)
        if x <= ChunkSize and x >= 1
        and z <= ChunkSize and z >= 1
        and y >= 1 and y <= WorldHeight then
            return math.floor( string.byte(self.voxels[x][z]:sub((y-1)*2 +2,(y-1)*2 +2))/16 )*16
        end

        return 0
    end

    chunk.setVoxelRaw = function (self, x,y,z, value,light)
        if x <= ChunkSize and x >= 1
        and z <= ChunkSize and z >= 1
        and y >= 1 and y <= WorldHeight then
            local gx,gy,gz = (self.x-1)*ChunkSize + x-1, y, (self.z-1)*ChunkSize + z-1
            self.voxels[x][z] = ReplaceChar(self.voxels[x][z], (y-1)*2 +1, string.char(value))

            self.changes[#self.changes+1] = {x,y,z}
        end
    end

    -- set voxel id of the voxel in this chunk's coordinate space
    chunk.setVoxel = function (self, x,y,z, value,light)
        x = math.floor(x)
        y = math.floor(y)
        z = math.floor(z)
        if x <= ChunkSize and x >= 1
        and z <= ChunkSize and z >= 1
        and y >= 1 and y <= WorldHeight then
            local gx,gy,gz = (self.x-1)*ChunkSize + x-1, y, (self.z-1)*ChunkSize + z-1

            local sunlight = self:getVoxelFirstData(x,y+1,z)
            local sunget = self:getVoxel(x,y+1,z)
            local isLightable = TileLightable(value)
            if isLightable then
                -- if removed block or put in lightable block
                if TileLightable(sunget) and sunlight == 15 then
                    NewSunlightDownAddition(gx,gy,gz, sunlight)
                else
                    NewSunlightAdditionCreation(gx+1,gy,gz)
                    NewSunlightAdditionCreation(gx-1,gy,gz)
                    NewSunlightAdditionCreation(gx,gy+1,gz)
                    NewSunlightAdditionCreation(gx,gy-1,gz)
                    NewSunlightAdditionCreation(gx,gy,gz+1)
                    NewSunlightAdditionCreation(gx,gy,gz-1)
                end

                self:setVoxelFirstData(x,y,z, 0)
            else
                -- if TileSemiLightable(value) then
                --     NewSunlightAdditionCreation(gx,gy+1,gz)
                --     NewSunlightAdditionCreation(gx,gy-1,gz)
                --     NewSunlightAdditionCreation(gx+1,gy,gz)
                --     NewSunlightAdditionCreation(gx-1,gy,gz)
                --     NewSunlightAdditionCreation(gx,gy+1,gz)
                --     NewSunlightAdditionCreation(gx,gy-1,gz)
                -- end
                -- if placed block remove sunlight around it
                NewSunlightDownSubtraction(gx,gy-1,gz)

                local nget = GetVoxelFirstData(gx,gy+1,gz)
                if nget < 15 then
                    NewSunlightSubtraction(gx,gy+1,gz, nget+1)
                end
                local nget = GetVoxelFirstData(gx+1,gy,gz)
                if nget < 15 then
                    NewSunlightSubtraction(gx+1,gy,gz, nget+1)
                end
                local nget = GetVoxelFirstData(gx-1,gy,gz)
                if nget < 15 then
                    NewSunlightSubtraction(gx-1,gy,gz, nget+1)
                end
                local nget = GetVoxelFirstData(gx,gy,gz+1)
                if nget < 15 then
                    NewSunlightSubtraction(gx,gy,gz+1, nget+1)
                end
                local nget = GetVoxelFirstData(gx,gy,gz-1)
                if nget < 15 then
                    NewSunlightSubtraction(gx,gy,gz-1, nget+1)
                end
            end

            self.voxels[x][z] = ReplaceChar(self.voxels[x][z], (y-1)*2 +1, string.char(value))

            self.changes[#self.changes+1] = {x,y,z}
        end
    end

    chunk.setVoxelData = function (self, x,y,z, value)
        x = math.floor(x)
        y = math.floor(y)
        z = math.floor(z)
        if x <= ChunkSize and x >= 1
        and z <= ChunkSize and z >= 1
        and y >= 1 and y <= WorldHeight then
            self.voxels[x][z] = ReplaceChar(self.voxels[x][z], (y-1)*2 +2, string.char(value))

            self.changes[#self.changes+1] = {x,y,z}
        end
    end

    -- sunlight data
    chunk.setVoxelFirstData = function (self, x,y,z, value)
        x = math.floor(x)
        y = math.floor(y)
        z = math.floor(z)
        if x <= ChunkSize and x >= 1
        and z <= ChunkSize and z >= 1
        and y >= 1 and y <= WorldHeight then
            local get = string.byte(self.voxels[x][z]:sub((y-1)*2 +2,(y-1)*2 +2))
            local nvalue = math.floor(get/16)*16 + value
            self.voxels[x][z] = ReplaceChar(self.voxels[x][z], (y-1)*2 +2, string.char(nvalue))

            self.changes[#self.changes+1] = {x,y,z}
        end
    end

    -- local light data
    chunk.setVoxelSecondData = function (self, x,y,z, value)
        x = math.floor(x)
        y = math.floor(y)
        z = math.floor(z)
        if x <= ChunkSize and x >= 1
        and z <= ChunkSize and z >= 1
        and y >= 1 and y <= WorldHeight then
            local get = string.byte(self.voxels[x][z]:sub((y-1)*2 +2,(y-1)*2 +2))
            local nvalue = get%16 + value*16
            self.voxels[x][z] = ReplaceChar(self.voxels[x][z], (y-1)*2 +2, string.char(nvalue))

            self.changes[#self.changes+1] = {x,y,z}
        end
    end


    -- update this chunk's model slices based on what changes it has stored
    chunk.updateModel = function (self)
        local sliceUpdates = {}

        for i=1, WorldHeight/SliceHeight do
            sliceUpdates[i] = {false, false, false, false, false}
        end

        -- find which slices need to be updated
        for i=1, #self.changes do
            local index = math.floor((self.changes[i][2]-1)/SliceHeight) +1
            if sliceUpdates[index] ~= nil then
                sliceUpdates[index][1] = true

                if math.floor((self.changes[i][2])/SliceHeight) +1 > index and sliceUpdates[index+1] ~= nil then
                    sliceUpdates[math.min(index+1, #sliceUpdates)][1] = true
                end
                if math.floor((self.changes[i][2]-2)/SliceHeight) +1 < index and sliceUpdates[index-1] ~= nil then
                    sliceUpdates[math.max(index-1, 1)][1] = true
                end

                --print(self.changes[i][1], self.changes[i][2], self.changes[i][3])
                -- neg x
                if self.changes[i][1] == 1 then
                    sliceUpdates[index][2] = true
                    --print("neg x")
                end
                -- pos x
                if self.changes[i][1] == ChunkSize then
                    sliceUpdates[index][3] = true
                    --print("pos x")
                end
                -- neg z
                if self.changes[i][3] == 1 then
                    sliceUpdates[index][4] = true
                    --print("neg z")
                end
                -- pos z
                if self.changes[i][3] == ChunkSize then
                    sliceUpdates[index][5] = true
                    --print("pos z")
                end
            end
        end

        -- update slices that were flagged in previous step
        for i=1, WorldHeight/SliceHeight do
            if sliceUpdates[i][1] then
                self.slices[i]:updateModel()

                if sliceUpdates[i][2] then
                    local chunk = GetChunkRaw(self.x-1,self.z)
                    if chunk ~= nil then
                        chunk.slices[i]:updateModel()
                    end
                end
                if sliceUpdates[i][3] then
                    local chunk = GetChunkRaw(self.x+1,self.z)
                    if chunk ~= nil then
                        chunk.slices[i]:updateModel()
                    end
                end
                if sliceUpdates[i][4] or sliceUpdates[i][5] then
                    local chunk = GetChunkRaw(self.x,self.z-1)
                    if chunk ~= nil then
                        chunk.slices[i]:updateModel()
                    end
                end
                if sliceUpdates[i][4] or sliceUpdates[i][5] then
                    local chunk = GetChunkRaw(self.x,self.z+1)
                    if chunk ~= nil then
                        chunk.slices[i]:updateModel()
                    end
                end
            end
        end

        self.changes = {}
    end

    return chunk
end

function CanDrawFace(get, thisTransparency)
    local tget = TileTransparency(get)

    -- tget > 0 means can only draw faces from outside in (bc transparency of 0 is air)
    -- must be different transparency to draw, except for tree leaves which have transparency of 1
    return (tget ~= thisTransparency or tget == 1) and tget > 0
end

function NewChunkSlice(x,y,z, parent)
    local t = NewThing(x,y,z)
    t.parent = parent
    t.name = "chunkslice"
    local compmodel = Engine.newModel(nil, LightingTexture, {0,0,0})
    compmodel.culling = true
    t:assignModel(compmodel)

    t.updateModel = function (self)
        local model = {}

        -- iterate through the voxels in this chunkslice's domain
        -- if air block, see if any solid neighbors
        -- then place faces down accordingly with proper texture and lighting value
        for i=1, ChunkSize do
            for j=self.y, self.y+SliceHeight-1 do
                for k=1, ChunkSize do
                    local this, thisLight = self.parent:getVoxel(i,j,k)
                    local thisTransparency = TileTransparency(this)
                    local scale = 1
                    local x,y,z = (self.x-1)*ChunkSize + i-1, 1*j*scale, (self.z-1)*ChunkSize + k-1

                    if thisTransparency < 3 then
                        -- if not checking for tget == 0, then it will render the "faces" of airblocks
                        -- on transparent block edges

                        -- simple plant model (flowers, mushrooms)
                        if TileModel(this) == 1 then
                            local otx,oty = NumberToCoord(TileTextures(this)[1], 16,16)
                            otx = otx + 16*thisLight
                            local otx2,oty2 = otx+1,oty+1
                            local tx,ty = otx*TileWidth/LightValues,oty*TileHeight
                            local tx2,ty2 = otx2*TileWidth/LightValues,oty2*TileHeight

                            local diagLong = 0.7071*scale*0.5 + 0.5
                            local diagShort = -0.7071*scale*0.5 + 0.5
                            model[#model+1] = {x+diagShort, y, z+diagShort, tx2,ty2}
                            model[#model+1] = {x+diagLong, y, z+diagLong, tx,ty2}
                            model[#model+1] = {x+diagShort, y+scale, z+diagShort, tx2,ty}
                            model[#model+1] = {x+diagLong, y, z+diagLong, tx,ty2}
                            model[#model+1] = {x+diagLong, y+scale, z+diagLong, tx,ty}
                            model[#model+1] = {x+diagShort, y+scale, z+diagShort, tx2,ty}
                            -- mirror
                            model[#model+1] = {x+diagLong, y, z+diagLong, tx2,ty2}
                            model[#model+1] = {x+diagShort, y, z+diagShort, tx,ty2}
                            model[#model+1] = {x+diagShort, y+scale, z+diagShort, tx,ty}
                            model[#model+1] = {x+diagLong, y+scale, z+diagLong, tx2,ty}
                            model[#model+1] = {x+diagLong, y, z+diagLong, tx2,ty2}
                            model[#model+1] = {x+diagShort, y+scale, z+diagShort, tx,ty}

                            model[#model+1] = {x+diagShort, y, z+diagLong, tx2,ty2}
                            model[#model+1] = {x+diagLong, y, z+diagShort, tx,ty2}
                            model[#model+1] = {x+diagShort, y+scale, z+diagLong, tx2,ty}
                            model[#model+1] = {x+diagLong, y, z+diagShort, tx,ty2}
                            model[#model+1] = {x+diagLong, y+scale, z+diagShort, tx,ty}
                            model[#model+1] = {x+diagShort, y+scale, z+diagLong, tx2,ty}
                            --mirror
                            model[#model+1] = {x+diagLong, y, z+diagShort, tx2,ty2}
                            model[#model+1] = {x+diagShort, y, z+diagLong, tx,ty2}
                            model[#model+1] = {x+diagShort, y+scale, z+diagLong, tx,ty}
                            model[#model+1] = {x+diagLong, y+scale, z+diagShort, tx2,ty}
                            model[#model+1] = {x+diagLong, y, z+diagShort, tx2,ty2}
                            model[#model+1] = {x+diagShort, y+scale, z+diagLong, tx,ty}
                        end

                        -- top
                        local get = self.parent:getVoxel(i,j-1,k)
                        if CanDrawFace(get, thisTransparency) then
                            local otx,oty = NumberToCoord(TileTextures(get)[math.min(2, #TileTextures(get))], 16,16)
                            otx = otx + 16*thisLight
                            local otx2,oty2 = otx+1,oty+1
                            local tx,ty = otx*TileWidth/LightValues,oty*TileHeight
                            local tx2,ty2 = otx2*TileWidth/LightValues,oty2*TileHeight

                            model[#model+1] = {x, y, z, tx,ty}
                            model[#model+1] = {x+scale, y, z, tx2,ty}
                            model[#model+1] = {x, y, z+scale, tx,ty2}
                            model[#model+1] = {x+scale, y, z, tx2,ty}
                            model[#model+1] = {x+scale, y, z+scale, tx2,ty2}
                            model[#model+1] = {x, y, z+scale, tx,ty2}
                        end

                        -- bottom
                        local get = self.parent:getVoxel(i,j+1,k)
                        if CanDrawFace(get, thisTransparency) then
                            local otx,oty = NumberToCoord(TileTextures(get)[math.min(3, #TileTextures(get))], 16,16)
                            otx = otx + 16*math.max(thisLight-3, 0)
                            local otx2,oty2 = otx+1,oty+1
                            local tx,ty = otx*TileWidth/LightValues,oty*TileHeight
                            local tx2,ty2 = otx2*TileWidth/LightValues,oty2*TileHeight

                            model[#model+1] = {x+scale, y+scale, z, tx2,ty}
                            model[#model+1] = {x, y+scale, z, tx,ty}
                            model[#model+1] = {x, y+scale, z+scale, tx,ty2}
                            model[#model+1] = {x+scale, y+scale, z+scale, tx2,ty2}
                            model[#model+1] = {x+scale, y+scale, z, tx2,ty}
                            model[#model+1] = {x, y+scale, z+scale, tx,ty2}
                        end

                        -- positive x
                        local get = self.parent:getVoxel(i-1,j,k)
                        if i == 1 then
                            local chunkGet = GetChunk(x-1,y,z)
                            if chunkGet ~= nil then
                                get = chunkGet:getVoxel(ChunkSize,j,k)
                            end
                        end
                        if CanDrawFace(get, thisTransparency) then
                            local otx,oty = NumberToCoord(TileTextures(get)[1], 16,16)
                            otx = otx + 16*math.max(thisLight-2, 0)
                            local otx2,oty2 = otx+1,oty+1
                            local tx,ty = otx*TileWidth/LightValues,oty*TileHeight
                            local tx2,ty2 = otx2*TileWidth/LightValues,oty2*TileHeight

                            model[#model+1] = {x, y+scale, z, tx2,ty}
                            model[#model+1] = {x, y, z, tx2,ty2}
                            model[#model+1] = {x, y, z+scale, tx,ty2}
                            model[#model+1] = {x, y+scale, z+scale, tx,ty}
                            model[#model+1] = {x, y+scale, z, tx2,ty}
                            model[#model+1] = {x, y, z+scale, tx,ty2}
                        end

                        -- negative x
                        local get = self.parent:getVoxel(i+1,j,k)
                        if i == ChunkSize then
                            local chunkGet = GetChunk(x+1,y,z)
                            if chunkGet ~= nil then
                                get = chunkGet:getVoxel(1,j,k)
                            end
                        end
                        if CanDrawFace(get, thisTransparency) then
                            local otx,oty = NumberToCoord(TileTextures(get)[1], 16,16)
                            otx = otx + 16*math.max(thisLight-2, 0)
                            local otx2,oty2 = otx+1,oty+1
                            local tx,ty = otx*TileWidth/LightValues,oty*TileHeight
                            local tx2,ty2 = otx2*TileWidth/LightValues,oty2*TileHeight

                            model[#model+1] = {x+scale, y, z, tx,ty2}
                            model[#model+1] = {x+scale, y+scale, z, tx,ty}
                            model[#model+1] = {x+scale, y, z+scale, tx2,ty2}
                            model[#model+1] = {x+scale, y+scale, z, tx,ty}
                            model[#model+1] = {x+scale, y+scale, z+scale, tx2,ty}
                            model[#model+1] = {x+scale, y, z+scale, tx2,ty2}
                        end

                        -- positive z
                        local get = self.parent:getVoxel(i,j,k-1)
                        if k == 1 then
                            local chunkGet = GetChunk(x,y,z-1)
                            if chunkGet ~= nil then
                                get = chunkGet:getVoxel(i,j,ChunkSize)
                            end
                        end
                        if CanDrawFace(get, thisTransparency) then
                            local otx,oty = NumberToCoord(TileTextures(get)[1], 16,16)
                            otx = otx + 16*math.max(thisLight-1, 0)
                            local otx2,oty2 = otx+1,oty+1
                            local tx,ty = otx*TileWidth/LightValues,oty*TileHeight
                            local tx2,ty2 = otx2*TileWidth/LightValues,oty2*TileHeight

                            model[#model+1] = {x, y, z, tx,ty2}
                            model[#model+1] = {x, y+scale, z, tx,ty}
                            model[#model+1] = {x+scale, y, z, tx2,ty2}
                            model[#model+1] = {x, y+scale, z, tx,ty}
                            model[#model+1] = {x+scale, y+scale, z, tx2,ty}
                            model[#model+1] = {x+scale, y, z, tx2,ty2}
                        end

                        -- negative z
                        local get = self.parent:getVoxel(i,j,k+1)
                        if k == ChunkSize then
                            local chunkGet = GetChunk(x,y,z+1)
                            if chunkGet ~= nil then
                                get = chunkGet:getVoxel(i,j,1)
                            end
                        end
                        if CanDrawFace(get, thisTransparency) then
                            local otx,oty = NumberToCoord(TileTextures(get)[1], 16,16)
                            otx = otx + 16*math.max(thisLight-1, 0)
                            local otx2,oty2 = otx+1,oty+1
                            local tx,ty = otx*TileWidth/LightValues,oty*TileHeight
                            local tx2,ty2 = otx2*TileWidth/LightValues,oty2*TileHeight

                            model[#model+1] = {x, y+scale, z+scale, tx2,ty}
                            model[#model+1] = {x, y, z+scale, tx2,ty2}
                            model[#model+1] = {x+scale, y, z+scale, tx,ty2}
                            model[#model+1] = {x+scale, y+scale, z+scale, tx,ty}
                            model[#model+1] = {x, y+scale, z+scale, tx2,ty}
                            model[#model+1] = {x+scale, y, z+scale, tx,ty2}
                        end
                    end
                end
            end
        end

        self.model:setVerts(model)
    end

    t:updateModel()

    return t
end

-- used for building structures across chunk borders
-- by requesting a block to be built in a chunk that does not yet exist
function NewChunkRequest(chunkx,chunky, gx,gy,gz, valueg)
    -- assume structures can only cross one chunk
    if gx < 1 then
        chunkx = chunkx-1
    end
    if gx > ChunkSize then
        chunkx = chunkx+1
    end
    if gz < 1 then
        chunky = chunky-1
    end
    if gz > ChunkSize then
        chunky = chunky+1
    end
    local lx,ly,lz = (gx-1)%ChunkSize +1, gy, (gz-1)%ChunkSize +1

    local foundMe = false
    for i=1, #ChunkRequests do
        local request = ChunkRequests[i]
        if request.chunkx == chunkx and request.chunky == chunky then
            foundMe = true
            request.blocks[#request.blocks+1] = {x = lx, y = ly, z = lz, value = valueg}
            break
        end
    end

    if not foundMe then
        ChunkRequests[#ChunkRequests +1] = {}
        local request = ChunkRequests[#ChunkRequests]
        request.chunkx = chunkx
        request.chunky = chunky
        request.blocks = {}
        request.blocks[1] = {x = lx, y = ly, z = lz, value = valueg}
    end
end
