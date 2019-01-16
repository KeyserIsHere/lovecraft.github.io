-- tile enumerations stored as a function called by tile index (base 0 to accomodate air)
function TileCollisions(n)
    if n == 0
    or n == 6
    or n == 8
    or n == 9
    or n == 10
    or n == 11 then
        return false
    end

    return true
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
    local tx = list[n+1]
    if type(tx) == "number" then
        textures = {tx}
    end
    return tx
end

