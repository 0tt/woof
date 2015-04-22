require("util")
require("lovedebug")
function love.load()
	img = {}
	function loadSprites(name)
		if not love.filesystem.exists("img/" .. name .. "1.png") then error("Invalid sprite name!") end
		local num = 1
		img[name] = {}
		while love.filesystem.exists("img/" .. name .. num .. ".png") do
			img[name][num] = love.graphics.newImage("img/" .. name .. num .. ".png")
			num = num + 1
		end
		return img[name]
	end
	loadSprites("pug")
	loadSprites("lab")
	
	fonts = {}
	fonts.banner = love.graphics.newFont(60)
	fonts.text = love.graphics.newFont(12)
	
	focused = false
	
	ents = {}
	colliders = {}
	
	love.window.setMode(800, 600, {
		fullscreen = true,
		fullscreentype = "desktop",
	})
	WIDTH, HEIGHT = love.window.getDimensions()

	function screenToWorld(x, y)
		return x - WIDTH / 2 - Camera.x * Camera.sx, -(y - HEIGHT / 2) - Camera.y * Camera.sy
	end
	function center(x1, y1, x2, y2)
		return (x1 + x2) / 2, (y1 + y2) / 2
	end
	function distance(x1, y1, x2, y2)
		return math.sqrt((y2 - y1)^2 + (x2 - x1)^2)
	end

	LEFT = 1
	RIGHT = 2
	TOP, UP = 3, 3
	BOTTOM, DOWN = 4, 4
	
	World = {
		gx = 0,
		gy = 500,
	}
	
	Camera = {
		x = 0,
		y = 0,
		sx = 1,
		sy = 1,
		r = 0,
	}
	
	Entity = {
		class = "Entity",
		x = 0,
		y = 0,
		w = 0,
		h = 0,
		cr = 0,
		cg = 0,
		cb = 0,
		ca = 255,
		id = 0,
		rotation = 0,
		collide = true,
	}
	function Entity:new(o)
		o = o or {}
		setmetatable(o, {
			__index = self,
		})
		o.class = o.class or self.class
		return o
	end
	function Entity:getPos()
		return self.x, self.y
	end
	function Entity:setPos(x, y)
		self.x, self.y = x, y
	end
	function Entity:getSize()
		return self.w, self.h
	end
	function Entity:setSize(w, h)
		self.w, self.h = w, h
	end
	function Entity:getColor()
		return self.cr, self.cg, self.cb, self.ca
	end
	function Entity:setColor(r, g, b, a)
		self.cr, self.cg, self.cb = r, g, b
		self.ca = a or self.ca
	end
	function Entity:getRotation()
		return self.rotation
	end
	function Entity:setRotation(r)
		self.rotation = r
	end
	function Entity:getCollide()
		return self.collide
	end
	function Entity:setCollide(b)
		self.collide = b
	end
	function Entity:isTouching(obj_or_x, y, w, h)
		local px, py, pw, ph, ox, oy, ow, oh
		if y then
			px, py = self:getPos()
			pw, ph = self:getSize()
			ox, oy = obj_or_x, y
			ow, oh = w, h
		else
			x, y = self:getPos()
			w, h = self:getSize()
			ox, oy = obj_or_x:getPos()
			ow, oh = obj_or_x:getSize()
		end
		if  x + w / 2 >= ox - ow / 2 --right edge > left edge
		and x - w / 2 <= ox + ow / 2 --left edge < right edge
		and y + h / 2 >= oy - oh / 2 --top edge > bottom edge
		and y - h / 2 -1 <= oy + oh / 2 --bottom edge < top edge
		then
			return true
		end
		return false 
	end
	function Entity:spawn()
		local id = #ents + 1
		ents[id] = self
		local w, h = self:getSize()
		if w + h ~= 0 and self:getCollide() then
			colliders[id] = self
		end
		self.id = id
		self:init(id)
	end
	function Entity:init(id)

	end
	function Entity:draw()
		local w, h = self:getSize()
		love.graphics.rectangle("fill", -w/2, -h/2, w, h)
	end
	function Entity:update(dt)

	end
	function Entity:remove()
		colliders[self.id] = nil
		table.remove(ents, self.id)
		print("removed", self.id)
	end
	
	
	Phys = Entity:new{
		class = "Phys",
		vx = 0,
		vy = 0,
		bounciness = 1,
		friction = 25,
	}
	function Phys:getVel()
		return self.vx, self.vy
	end
	function Phys:setVel(x, y)
		self.vx, self.vy = x, y
	end
	function Phys:getBounciness()
		return self.bounciness
	end
	function Phys:setBounciness(b)
		self.bounciness	= b
	end
	function Phys:getFriction()
		return self.friction
	end
	function Phys:setFriction(f)
		self.friction = f
	end
	function Phys:doVelocity(dt)
		local vx, vy = self:getVel()
		local x, y = self:getPos()
		self:setPos(x + vx * dt, y + vy * dt)
	end
	function Phys:doFriction(dt)
		local vx, vy = self:getVel()
		local ax, ay = 0, 0
		if vx ~= 0 then
			ax = math.abs(vx) / vx
		end
		if vy ~= 0 then
			ay = math.abs(vy) / vy
		end
		local f = self:getFriction()
		vx = vx - math.sqrt(vx * ax) * ax * dt * f
		vy = vy - math.sqrt(vy * ay) * ay * dt * f
		self:setVel(vx, vy)
	end
	function Phys:doCollision(dt)
		local x, y = self:getPos()
		local px, py = x, y
		local w, h = self:getSize()
		local vx, vy = self:getVel()
		local b = self:getBounciness()
		local ob = 0
		local changed = false
		local edges = {}
		for id, obj in pairs(colliders) do
			if obj ~= self then
				if self:isTouching(obj) then
					local ox, oy = obj:getPos()
					local ow, oh = obj:getSize()
					ob = math.max(ob, obj.getBouncines and obj:getBouncines() or 0)
					local right = 	(x + w / 2) - (ox + ow / 2) - w / 2
					local left = 	(ox - ow / 2) - (x - w / 2) - w / 2
					local bottom =	(oy - oh / 2) - (y - h / 2) - h / 2
					local top = 	(y + h / 2) - (oy + oh / 2) - h / 2
					
					local objedges = {
						{key = LEFT, val = right, pos = (ox + ow / 2) + w / 2, obj = obj}, 
						{key = RIGHT, val = left, pos = (ox - ow / 2) - w / 2, obj = obj}, 
						{key = TOP, val = bottom, pos = (oy - oh / 2) - h / 2, obj = obj}, 
						{key = BOTTOM, val = top, pos = (oy + oh / 2) + h / 2, obj = obj}
					}
					for i = 1, #objedges do
						if objedges[i].val > 0 then
							edges[#edges + 1] = objedges[i]
						end
					end
				end
			end
		end
		table.sort(edges, function(a, b)
			return a.val > b.val
		end)
		--Okay so first we need to go through all of the edges.
		--We'll make sure that only an object's greatest edges is included.
		local objs = {}
		for _, e in ipairs(edges) do
			if objs[e.obj] then
				if e.val > objs[e.obj].val then
					objs[e.obj] = e
				end
			else
				objs[e.obj] = e
			end
		end
		--Then we re-add to the edge list, this time making sure the greatest directions are included.
		local max = {}
		for obj, e in pairs(objs) do
			if max[e.key] then
				if max[e.key].val > e.val then
					max[e.key] = e
				end
			else
				max[e.key] = e
			end
		end
		--Finally, we have 1 object per edge, and one direction per edge.
		for dir, e in pairs(max) do
			if dir == LEFT or dir == RIGHT then
				vx = -vx * (b + ob)
				px = e.pos
				changed = true
			else
				vy = -vy * (b + ob)
				py = e.pos
				changed = true
			end
		end
		self:setPos(px, py)
		self:setVel(vx, vy)
		return changed, max
	end
	function Phys:doGravity(dt)
		local vx, vy = self:getVel()
		vx = vx + World.gx * dt
		vy = vy - World.gy * dt
		self:setVel(vx, vy)
	end
	function Phys:update(dt)
		self:doVelocity(dt)
		self:doGravity(dt)
		if self:doCollision(dt) then
			self:doFriction(dt)
		end
	end
	

	Pawn = Phys:new{
		class = "Pawn",
		direction = LEFT,
		onground = false,
		acceleration = 1000,
		speed = 250,
		jump = 260,
	}
	function Pawn:getDirection()
		return self.direction
	end
	function Pawn:setDirection(dir)
		self.direction = dir
	end
	function Pawn:isOnGround()
		return self.onground
	end
	function Pawn:getAcceleration()
		return self.acceleration
	end
	function Pawn:setAcceleration(a)
		self.acceleration = a
	end
	function Pawn:getSpeed()
		return self.speed
	end
	function Pawn:setSpeed(s)
		self.speed = s
	end
	function Pawn:getJump()
		return self.jump
	end
	function Pawn:setJump(j)
		self.jump = j
	end
	function Pawn:update(dt)
		self:doVelocity(dt)
		self:doGravity(dt)
		local hit, es = self:doCollision(dt)
		self.onground = false
		if hit then
			for _, e in pairs(es) do
				if e.key == BOTTOM then
					self:doFriction(dt)
					self.onground = true
				end
			end
			if not self:isOnGround() then
				for _, e in pairs(es) do
					if e.key == TOP then
						local x, y = self:getPos()
						self:setPos(x, y - 1)
					end
				end
			end
		end
		local vx, vy = self:getVel()
		local a = self:getAcceleration()
		if love.keyboard.isDown("a") then
			vx = vx - a * dt
			self:setDirection(LEFT)
		end
		if love.keyboard.isDown("d") then
			vx = vx + a * dt
			self:setDirection(RIGHT)
		end
		if love.keyboard.isDown(" ") and self:isOnGround() then
			vy = vy + self:getJump()
		end
		if vx ~= 0 then
			local ax = math.abs(vx) / vx
			self:setVel(math.min(math.abs(vx), self:getSpeed()) * ax, vy)
		else
			self:setVel(vx, vy)
		end
		Camera.x, Camera.y = self:getPos()
		Camera.x, Camera.y = -Camera.x, -Camera.y
		Camera.y = Camera.y - HEIGHT / 8
		--Camera.sx = 1 - (distance(0, 0, self:getVel()) / self:getSpeed()) * 0.1
		--Camera.sy = 1 - (distance(0, 0, self:getVel()) / self:getSpeed()) * 0.1
	end
	Pawn:setSize(32, 64)
	Pawn:setBounciness(0.1)
	
	
	ImgPawn = Pawn:new{
		class = "Pawn",
		sprites = {},
		img = 1,
	}
	function ImgPawn:getSprites()
		return self.sprites
	end
	function ImgPawn:setSprites(s)
		local tab = img[s]
		if  not tab then
			tab = loadSprites(s)
		end
		self.sprites = tab
	end
	function ImgPawn:getImage()
		return self.img
	end
	function ImgPawn:setImage(i)
		self.img = i
	end
	function ImgPawn:spawn(s)
		Entity.spawn(self)
		self:setSprites(s)
	end
	function ImgPawn:draw()
		local w, h = self:getSize()
		local img = self:getSprites()[self:getImage()]
		local iw, ih = img:getDimensions()
		local dir = self:getDirection() == LEFT and 1 or -1
		love.graphics.draw(img, -iw/2 * dir, ih - h/2, 0, dir, -1)
	end
	function ImgPawn:init()
		self:setColor(255, 255, 255, 255)
		self:setSize(64, 64) 
	end
	
	
	Player = ImgPawn:new()
	Player:spawn("pug")
	

	Ground = Entity:new()
	Ground:setSize(1024, 32)
	Ground:setPos(0, -256)
	Ground:spawn()
	
	
	Ghost = Entity:new()
	Ghost:setSize(32, 32)
	Ghost:setCollide(false)
	function Ghost:update(dt)
		local mx, my = screenToWorld(love.mouse.getPosition())
		mx = mx + 16
		my = my + 16
		self:setPos((mx - mx % 32), (my - my % 32))
	end
	Ghost:setColor(0, 0, 0, 128)
	Ghost:spawn()


	love.graphics.setBackgroundColor(255, 255, 255)
end
local function round(...)
	local args = {...}
	for i = 1, #args do
		args[i] = math.floor(args[i])
	end
	return unpack(args)
end
function love.draw()
	love.graphics.setFont(fonts.text)
	love.graphics.setColor(0, 0, 0, 255)
	love.graphics.print(table.concat({round(Player:getPos())}, ", "), 0, 0)
	love.graphics.print(table.concat({round(Player:getVel())}, ", "), 0, 12)
	love.graphics.print(tostring(Player:isOnGround()), 0, 24)
	love.graphics.push()
		love.graphics.translate(WIDTH / 2, HEIGHT / 2)
		love.graphics.scale(1, -1)
		love.graphics.push()
			love.graphics.translate(Camera.x, Camera.y)
			love.graphics.scale(Camera.sx, Camera.sy)
			love.graphics.rotate(Camera.r)
			for k, v in ipairs(ents) do
				love.graphics.push()
					love.graphics.translate(v:getPos())
					love.graphics.rotate(v:getRotation())
					love.graphics.setColor(v:getColor())
					v:draw()
				love.graphics.pop()
			end
		love.graphics.pop()
	love.graphics.pop()
	if not focused then
		love.graphics.setColor(0, 0, 0, 255)
		love.graphics.setFont(fonts.banner)
		love.graphics.rectangle("fill", 0, HEIGHT / 2 - 32, WIDTH, 64)
		love.graphics.setColor(255, 255, 255, 255)
		love.graphics.printf("Click to focus!", 0, HEIGHT / 2 - 32, WIDTH, "center")
	end
end
function love.update(dt)
	if not focused then return end
	for k, v in ipairs(ents) do
		v:update(dt)
	end
end
function love.keypressed(key)
	if key == "r" then
		Player:setPos(0, 0)
		Player:setVel(0, 0)
	end
end
function love.mousepressed(x, y, but)
	if not focused then return end
	GhostPosX, GhostPosY = Ghost:getPos()
end
function love.mousereleased(x, y, but)
	if not focused then return end
	if but == "l" then
		local gx, gy = Ghost:getPos()
		local w, h = math.abs(GhostPosX - gx), math.abs(GhostPosY - gy)
		w = w + 32
		h = h + 32
		local a = Entity:new()
		a:setSize(w, h)
		a:setPos(center(gx, gy, GhostPosX, GhostPosY))
		a:spawn()
	end
end
function love.focus(f)
	focused = f
end