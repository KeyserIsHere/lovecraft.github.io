function ReplaceChar(str, pos, r)
    return str:sub(1, pos-1) .. r .. str:sub(pos+#r)
end

function NewChunk(x,z)
    local chunk = NewThing(x,0,z)
    chunk.voxels = {}
    chunk.slices = {}
    chunk.lightingQueue = {}

    DefaultGeneration(chunk, x,z)

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

    -- set voxel id of the voxel in this chunk's coordinate space
    chunk.setVoxel = function (self, x,y,z, value,light)
        x = math.floor(x)
        y = math.floor(y)
        z = math.floor(z)
        if x <= ChunkSize and x >= 1
        and z <= ChunkSize and z >= 1
        and y >= 1 and y <= WorldHeight then
            local gx,gy,gz = (self.x-1)*ChunkSize + x-1, y, (self.z-1)*ChunkSize + z-1
            if value == 0 then
                self.lightingQueue[#self.lightingQueue+1] = NewAddition(gx,gy,gz, 15)
            elseif TileTransparency(value) > 0 then
                self.lightingQueue[#self.lightingQueue+1] = NewSubtraction(gx,gy-1,gz, 12)
            end
            self.voxels[x][z] = ReplaceChar(self.voxels[x][z], (y-1)*2 +1, string.char(value)..string.char(12))
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
        end
    end


    -- update this chunk's model after voxels in it have been modified
    -- update only relevant chunkslices to x,y,z value given
    -- mustStop is given as a way to prevent infinite recursion
    chunk.updateModel = function (self, x,y,z, mustStop)
        self:lightingUpdate()

        if mustStop == nil then
            mustStop = false
        end
        local sy = (y)%SliceHeight
        local xx,zz = (self.x-1)*ChunkSize + x-1, (self.z-1)*ChunkSize + z-1
        local i = math.floor((y-1)/SliceHeight) +1

        if self.slices[i] ~= nil then
            self.slices[i]:updateModel()
        end

        -- update vertical neighbors if relevant
        if true and self.slices[i+1] ~= nil then
            self.slices[i+1]:updateModel()
        end
        if (true or sy == 1) and self.slices[i-1] ~= nil then
            self.slices[i-1]:updateModel()
        end

        -- update lateral chunk neighbors if relevant
        if not mustStop then
            local chunkGet = GetChunk(xx-1,y,zz)
            if chunkGet ~= self and chunkGet ~= nil then
                chunkGet:updateModel(ChunkSize,y,z, true)
            end
            local chunkGet = GetChunk(xx+1,y,zz)
            if chunkGet ~= self and chunkGet ~= nil then
                chunkGet:updateModel(1,y,z, true)
            end
            local chunkGet = GetChunk(xx,y,zz-1)
            if chunkGet ~= self and chunkGet ~= nil then
                chunkGet:updateModel(x,y,ChunkSize, true)
            end
            local chunkGet = GetChunk(xx,y,zz+1)
            if chunkGet ~= self and chunkGet ~= nil then
                chunkGet:updateModel(x,y,1, true)
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

    chunk.lightingUpdate = function (self)
        local i=1
        while i <= #self.lightingQueue do
            self.lightingQueue[i]:query()
            table.remove(self.lightingQueue, i)
        end

        self.lightingQueue = {}
    end

    chunk.initialize = function (self)
        self:lightingUpdate()
        for i=1, WorldHeight/SliceHeight do
            self.slices[i] = CreateThing(NewChunkSlice(self.x,self.y + (i-1)*SliceHeight,self.z, self))
        end
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
    local compmodel = Engine.newModel(nil, LightingTexture, {0,0,0})
    compmodel.culling = true
    t:assignModel(compmodel)

    t.updateModel = function (self)
        local model = {}

        -- iterate through the voxels in this chunkslice's domain
        -- if air block, see if any solid neighbors
        -- then place faces down accordingly with proper texture and lighting value
        for i=1, ChunkSize do
            for j=math.max(self.y, 1), self.y+SliceHeight do
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
                            otx = otx + 16*(thisLight-3)
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
                            otx = otx + 16*(thisLight-2)
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
                            otx = otx + 16*(thisLight-2)
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
                            otx = otx + 16*(thisLight-1)
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
                            otx = otx + 16*(thisLight-1)
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
