--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.balls = params.balls
    self.level = params.level
    self.containsLockedBrick = params.containsLockedBrick
    self.powerups = {}
    self.multiballTimer = 0
    self.keyTimer = 0
    self.hasKey = false

    self.multiballPowerupTime = math.random(20, 40)
    self.keyPowerupTime = math.random(40, 60)
    self.recoverPoints = 5000
    self.growPoints = 2000

    -- give ball random starting velocity
    ballStartVelocity(self.balls[1])
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)

    -- functions check if time has elapsed to spawn a ower up and if so will spawn them
    self:checkSpawnMultiballPowerup(dt)
    self:checkSpawnKeyPowerup(dt)

    for k, ball in pairs(self.balls) do
        ball:update(dt)
    end
    
    for k, powerup in pairs(self.powerups) do
        powerup:update(dt)
    end
    
    for k, ball in pairs(self.balls) do
        if ball:collides(self.paddle) then
            -- raise ball above paddle in case it goes below it, then reverse dy
            ball.y = self.paddle.y - 8
            ball.dy = -ball.dy

            --
            -- tweak angle of bounce based on where it hits the paddle
            --

            -- if we hit the paddle on its left side while moving left...
            if ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))
            
            -- else if we hit the paddle on its right side while moving right...
            elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
                ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
            end

            gSounds['paddle-hit']:play()
        end
    end

    --detect collision with powerup
    for k, powerup in pairs(self.powerups) do
        if powerup:collides(self.paddle) then
            gSounds['victory']:play()
            if powerup.type == 4 then
                self:activateMultiball()
            elseif powerup.type == 10 then
                self.hasKey = true
            end

            -- remove powerup
            table.remove(self.powerups, k)
        elseif powerup.y >= VIRTUAL_HEIGHT then
            -- remove powerup if it goes off screen
            table.remove(self.powerups, k)
        end
    end

    -- detect collision across all bricks with the ball
    for k, brick in pairs(self.bricks) do
        for k, ball in pairs(self.balls) do
            -- only check collision if we're in play
            if brick.inPlay and ball:collides(brick) then
                if brick.locked == false or (brick.locked == true and self.hasKey == true) then
                    -- if hit brick was the padlocked brick chenge this flag
                    if brick.locked then
                        self.containsLockedBrick = false
                        self.hasKey = false
                    end

                    -- add to score
                    self.score = self.score + (brick.tier * 200 + brick.color * 25)

                    -- trigger the brick's hit function, which removes it from play
                    brick:hit()
                    -- if we have enough points, recover a point of health
                    if self.score > self.recoverPoints then
                        -- can't go above 3 health
                        self.health = math.min(3, self.health + 1)

                        -- multiply recover points by 2
                        self.recoverPoints = self.recoverPoints + math.min(100000, self.recoverPoints * 2)

                        -- play recover sound effect
                        gSounds['recover']:play()
                    end

                    -- if we have enough points grow the paddle size
                    if self.score >= self.growPoints then
                        -- reduce paddle size to a minimum of 1
                        self.paddle.size = math.min(4, self.paddle.size + 1)
                        self.paddle.width = math.min(128, self.paddle.width + 32)

                        -- multiply grow points by 2
                        self.growPoints = math.min(100000, self.growPoints * 2)
                    
                    end

                    -- go to our victory screen if there are no more bricks left
                    if self:checkVictory() then
                        gSounds['victory']:play()

                        gStateMachine:change('victory', {
                            level = self.level,
                            paddle = self.paddle,
                            health = self.health,
                            score = self.score,
                            highScores = self.highScores,
                            ball = ball,
                            recoverPoints = self.recoverPoints,
                            growPoints = self.growPoints
                        })
                    end
                end

                --
                -- collision code for bricks
                --
                -- we check to see if the opposite side of our velocity is outside of the brick;
                -- if it is, we trigger a collision on that side. else we're within the X + width of
                -- the brick and should check to see if the top or bottom edge is outside of the brick,
                -- colliding on the top or bottom accordingly 
                --

                -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                if ball.x + 2 < brick.x and ball.dx > 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x - 8
                
                -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x + 32
                
                -- top edge if no X collisions, always check
                elseif ball.y < brick.y then
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y - 8
                
                -- bottom edge if no X collisions or top collision, last possibility
                else
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y + 16
                end

                -- slightly scale the y velocity to speed up the game, capping at +- 150
                if math.abs(ball.dy) < 150 then
                    ball.dy = ball.dy * 1.02
                end

                -- only allow colliding with one brick, for corners
                break
            end
        end
    end

    -- if ball goes below bounds, revert to serve state and decrease health
    for k, ball in pairs(self.balls) do
        if ball.y >= VIRTUAL_HEIGHT then
            -- remove the ball
            table.remove(self.balls, k)
            -- if last ball reduce health and go to serve
            if #self.balls < 1 then
                self.health = self.health - 1
                gSounds['hurt']:play()

                -- reduce paddle size to a minimum of 1
                self.paddle.size = math.max(1, self.paddle.size - 1)
                self.paddle.width = math.max(32, self.paddle.width - 32)

                if self.health == 0 then
                    gStateMachine:change('game-over', {
                        score = self.score,
                        highScores = self.highScores
                    })
                else
                    gStateMachine:change('serve', {
                        paddle = self.paddle,
                        bricks = self.bricks,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        level = self.level,
                        recoverPoints = self.recoverPoints
                    })
                end
            end
        end
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end

    -- for testing, spawns multiball powerup
    if love.keyboard.wasPressed('p') then
        self:spawnPowerup(4)
    end

    -- for testing spawns key
    if love.keyboard.wasPressed('k') then
        self:spawnPowerup(10)
    end
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    for k, powerup in pairs(self.powerups) do
        powerup:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()

    --render all balls
    for k, ball in pairs(self.balls) do
        ball:render()
    end


    renderScore(self.score)
    renderHealth(self.health)
    renderKey(self.hasKey)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end

function ballStartVelocity(ball)
        -- give ball random starting velocity
        ball.dx = math.random(-200, 200)
        ball.dy = math.random(-50, -60)
end

function PlayState:checkSpawnMultiballPowerup(dt)
    -- check wehter to spawn a multiball powerup
    -- and spawn if needed
    self.multiballTimer = self.multiballTimer + dt
    if self.multiballTimer >= self.multiballPowerupTime then
        self:spawnPowerup(4)
        self.multiballTimer = 0
        self.multiballPowerupTime = math.random(20, 40)
    end
end

function PlayState:checkSpawnKeyPowerup(dt)
    -- check wehter to spawn a key powerup
    -- and spawn if needed
    if self.containsLockedBrick then
        self.keyTimer = self.keyTimer + dt
        if self.keyTimer >= self.keyPowerupTime then
            self:spawnPowerup(10)
            self.keyTimer = 0
            self.keyPowerupTime = math.random(40, 60)
        end
    end
end

function PlayState:spawnPowerup(powerType)
    table.insert(self.powerups, Powerup(powerType))
end

function PlayState:activateMultiball()
    for i = 1, 2, 1 do
        -- add new ball to balls table
        table.insert(self.balls, Ball())
        -- set ball x and y to paddle location
        self.balls[#self.balls].x = self.paddle.x + (self.paddle.width / 2) - 4
        self.balls[#self.balls].y = self.paddle.y - 8
        -- set ball to random colour
        self.balls[#self.balls].skin = math.random(7)
        -- set ball moving
        ballStartVelocity(self.balls[#self.balls])     
    end
end