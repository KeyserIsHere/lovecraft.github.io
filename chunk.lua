function NewChunk(x,z)
    local chunk = NewThing(x,0,z)
    chunk.voxels = {}
    chunk.slices = {}

    -- chunk generation
    for i=1, ChunkSize do
        chunk.voxels[i] = {}
        for j=WorldHeight, 1, -1 do
            chunk.voxels[i][j] = {}
            for k=1, ChunkSize do
                chunk.voxels[i][j][k] = 0
            end
        end
    end

    local dirt = 6
    local grass = true
    local freq = 16
    local yfreq = 32
    local floor = 48
    local ceiling = 120
    for i=1, ChunkSize do
        for k=1, ChunkSize do
            for j=WorldHeight, 1, -1 do
                local xx = (x-1)*ChunkSize + i
                local zz = (z-1)*ChunkSize + k
                if j < floor then
                    chunk.voxels[i][j][k] = 1
                else
                    if love.math.noise(xx/freq,j/(yfreq),zz/freq) > (j-floor)/(ceiling-floor) then
                        if not grass then
                            if dirt > 0 then
                                dirt = dirt - 1
                                chunk.voxels[i][j][k] = 3
                            else
                                chunk.voxels[i][j][k] = 1
                            end
                        else
                            grass = false
                            chunk.voxels[i][j][k] = 2
                        end
                    else
                        grass = true
                        dirt = 6
                    end
                end
            end
        end
    end

    chunk.getVoxel = function (self, x,y,z)
        x = math.floor(x)
        y = math.floor(y)
        z = math.floor(z)
        if x <= ChunkSize and x >= 1
        and z <= ChunkSize and z >= 1
        and y >= 1 and y <= WorldHeight then
            return self.voxels[x][y][z]
        end

        return 0
    end

    chunk.setVoxel = function (self, x,y,z, value)
        x = math.floor(x)
        y = math.floor(y)
        z = math.floor(z)
        if x <= ChunkSize and x >= 1
        and z <= ChunkSize and z >= 1
        and y >= 1 and y <= WorldHeight then
            self.voxels[x][y][z] = value
        end
    end

    chunk.updateSlice = function (self, y)
        local sy = (y-1)%SliceHeight
        local i = math.floor((y-1)/SliceHeight) +1

        if self.slices[i] ~= nil then
            self.slices[i]:updateModel()
        end
        if sy == 0 and self.slices[i-1] ~= nil then
            self.slices[i-1]:updateModel()
        end
        if sy == SliceHeight-1 and self.slices[i+1] ~= nil then
            self.slices[i+1]:updateModel()
        end
    end

    for i=1, WorldHeight/SliceHeight do
        chunk.slices[i] = CreateThing(NewChunkSlice(chunk.x,chunk.y + (i-1)*SliceHeight,chunk.z, chunk))
    end

    return chunk
end

function NewChunkSlice(x,y,z, parent)
    local t = NewThing(x,y,z)
    t.parent = parent

    t.updateModel = function (self)
        local model = {}

        for i=1, ChunkSize do
            for j=self.y, self.y+SliceHeight do
                for k=1, ChunkSize do
                    local this = self.parent:getVoxel(i,j,k)
                    local scale = 1
                    local x,y,z = (self.x-1)*ChunkSize + i-1, 1*j*scale, (self.z-1)*ChunkSize + k-1

                    if this ~= 0 then
                        local otx,oty = NumberToCoord(TileEnums(this).texture[1], 16,16)
                        local otx2,oty2 = otx+1,oty+1

                        tx,ty = otx*TileWidth,oty*TileHeight
                        tx2,ty2 = otx2*TileWidth,oty2*TileHeight

                        local utx,uty = tx,ty
                        local utx2,uty2 = tx2,ty2
                        if #TileEnums(this).texture > 1 then
                            utx,uty = NumberToCoord(TileEnums(this).texture[2], 16,16)
                            utx2,uty2 = utx+1,uty+1

                            utx,uty = utx*TileWidth,uty*TileHeight
                            utx2,uty2 = utx2*TileWidth,uty2*TileHeight
                        end
                        local dtx,dty = tx,ty
                        local dtx2,dty2 = tx2,ty2
                        if #TileEnums(this).texture > 2 then
                            dtx,dty = NumberToCoord(TileEnums(this).texture[3], 16,16)
                            dtx2,dty2 = dtx+1,dty+1

                            dtx,dty = dtx*TileWidth,dty*TileHeight
                            dtx2,dty2 = dtx2*TileWidth,dty2*TileHeight
                        end

                        -- bottom
                        if TileEnums(this).isVisible
                        and not TileEnums(self.parent:getVoxel(i,j-1,k)).isVisible then
                            model[#model+1] = {x, y, z, dtx,dty}
                            model[#model+1] = {x+scale, y, z, dtx2,dty}
                            model[#model+1] = {x, y, z+scale, dtx,dty2}
                            model[#model+1] = {x+scale, y, z+scale, dtx2,dty2}
                            model[#model+1] = {x+scale, y, z, dtx2,dty}
                            model[#model+1] = {x, y, z+scale, dtx,dty2}
                        end
                        -- top
                        if TileEnums(this).isVisible
                        and not TileEnums(self.parent:getVoxel(i,j+1,k)).isVisible then
                            model[#model+1] = {x, y+scale, z, utx,uty}
                            model[#model+1] = {x+scale, y+scale, z, utx2,uty}
                            model[#model+1] = {x, y+scale, z+scale, utx,uty2}
                            model[#model+1] = {x+scale, y+scale, z+scale, utx2,uty2}
                            model[#model+1] = {x+scale, y+scale, z, utx2,uty}
                            model[#model+1] = {x, y+scale, z+scale, utx,uty2}
                        end
                        
                        -- positive x
                        if TileEnums(this).isVisible
                        and not TileEnums(self.parent:getVoxel(i+1,j,k)).isVisible then
                            model[#model+1] = {x+scale, y, z, tx2,ty2}
                            model[#model+1] = {x+scale, y+scale, z, tx2,ty}
                            model[#model+1] = {x+scale, y, z+scale, tx,ty2}
                            model[#model+1] = {x+scale, y+scale, z+scale, tx,ty}
                            model[#model+1] = {x+scale, y+scale, z, tx2,ty}
                            model[#model+1] = {x+scale, y, z+scale, tx,ty2}
                        end
                        -- negative x
                        if TileEnums(this).isVisible
                        and not TileEnums(self.parent:getVoxel(i-1,j,k)).isVisible then
                            model[#model+1] = {x, y, z, tx,ty2}
                            model[#model+1] = {x, y+scale, z, tx,ty}
                            model[#model+1] = {x, y, z+scale, tx2,ty2}
                            model[#model+1] = {x, y+scale, z+scale, tx2,ty}
                            model[#model+1] = {x, y+scale, z, tx,ty}
                            model[#model+1] = {x, y, z+scale, tx2,ty2}
                        end

                        -- positive z
                        if TileEnums(this).isVisible
                        and not TileEnums(self.parent:getVoxel(i,j,k+1)).isVisible then
                            model[#model+1] = {x, y, z+scale, tx,ty2}
                            model[#model+1] = {x, y+scale, z+scale, tx,ty}
                            model[#model+1] = {x+scale, y, z+scale, tx2,ty2}
                            model[#model+1] = {x+scale, y+scale, z+scale, tx2,ty}
                            model[#model+1] = {x, y+scale, z+scale, tx,ty}
                            model[#model+1] = {x+scale, y, z+scale, tx2,ty2}
                        end
                        -- negative z
                        if TileEnums(this).isVisible
                        and not TileEnums(self.parent:getVoxel(i,j,k-1)).isVisible then
                            model[#model+1] = {x, y, z, tx2,ty2}
                            model[#model+1] = {x, y+scale, z, tx2,ty}
                            model[#model+1] = {x+scale, y, z, tx,ty2}
                            model[#model+1] = {x+scale, y+scale, z, tx,ty}
                            model[#model+1] = {x, y+scale, z, tx2,ty}
                            model[#model+1] = {x+scale, y, z, tx,ty2}
                        end
                    end
                end
            end
        end

        if #model > 0 then
            self:assignModel(Engine.newModel(Engine.luaModelLoader(model), TileTexture, {0,0,0}))
        end
    end

    t:updateModel()

    return t
end
