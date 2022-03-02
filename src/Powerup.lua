Powerup = Class{}

function Powerup:init(power)
    -- simple positional and dimensional variables
    self.width = 16
    self.height = 16
    
    -- an int representing which power and corresponding sprite we want to use
    -- multiball == 4, key == 10
    self.type = power

    self.y = - 10
    self.x = math.random(16, VIRTUAL_WIDTH  - 32)

    -- these variables are for keeping track of our velocity on both the
    -- X and Y axis, since the Powerup can move in two dimensions
    self.dy = 40
    self.dx = 0
end

--[[
    Expects an argument with a bounding box, be that a paddle or a brick,
    and returns true if the bounding boxes of this and the argument overlap.
]]
function Powerup:collides(target)
    -- first, check to see if the left edge of either is farther to the right
    -- than the right edge of the other
    if self.x > target.x + target.width or target.x > self.x + self.width then
        return false
    end

    -- then check to see if the bottom edge of either is higher than the top
    -- edge of the other
    if self.y > target.y + target.height or target.y > self.y + self.height then
        return false
    end 

    -- if the above aren't true, they're overlapping
    return true
end

--[[
    Places the Powerup in the middle of the screen, with no movement.
]]
function Powerup:reset()
   
end

function Powerup:update(dt)
    self.y = self.y + self.dy * dt
end

function Powerup:render()
    love.graphics.draw(gTextures['main'], gFrames['powerups'][self.type], self.x, self.y)
end