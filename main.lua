require("util")
require("lovedebug")
function love.load()
	love.window.setMode(1280, 720)
	love.window.setTitle("woof (the vidya)")
	WIDTH, HEIGHT = love.window.getDimensions()
	img = {}
	function loadSprites(name)
		if img[name] then return img[name] end
		if not love.filesystem.exists("img/" .. name) then error("Invalid sprite folder!") end
		img[name] = {}
		local files = love.filesystem.getDirectoryItems("img/" .. name)
		for _, file in ipairs(files) do
			img[name][file] = love.graphics.newImage("img/" .. name .. "/" .. file)
		end
		return img[name]
	end
	
	bg = {}
	
	function addBackground(img, p, w1, w2)
		local t = {}
		t.i = love.graphics.newImage(img)
		t.i:setWrap(w1, w2)
		t.q = love.graphics.newQuad(0, 0, WIDTH, HEIGHT, t.i:getDimensions())
		t.p = p
		bg[#bg + 1] = t
	end
	addBackground("img/forest/sky.png", 0.1, "repeat", "clamp")
	addBackground("img/forest/trees3.png", 0.7, "repeat", "clamp")
	addBackground("img/forest/trees2.png", 0.8, "repeat", "clamp")
	addBackground("img/forest/trees1.png", 0.9, "repeat", "clamp")
	bg[5] = {}
	bg[5].i = love.graphics.newImage("img/forest/grass.png")
	bg[5].i:setWrap("repeat")
	bg[5].q = love.graphics.newQuad(0, HEIGHT - bg[5].i:getHeight(), WIDTH, bg[5].i:getHeight(), bg[5].i:getDimensions())
	bg[5].p = 1
	fonts = {}
	fonts.banner = love.graphics.newFont(60)
	fonts.text = love.graphics.newFont(12)
	
	focused = false
	
	ents = {}
	colliders = {}
	draw = {}

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
		layer = 10,
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
	function Entity:spawn(layer)
		local id = #ents + 1
		ents[id] = self
		local w, h = self:getSize()
		if w + h ~= 0 and self:getCollide() then
			colliders[id] = self
		end
		self.id = id
		self.layer = layer
		self:init(id)
		draw[#draw + 1] = self
		reorder = true
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
		for k, v in pairs(draw) do
			if v == self then
				table.remove(draw, k)
				break
			end
		end
		reorder = true
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
		layer = 5,
		sprites = {},
		img = "idle",
		imgtimer = 0,
		crouched = false,
		crouchdir = LEFT,
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
	function Pawn:getSprites()
		return self.sprites
	end
	function Pawn:setSprites(s)
		local tab = img[s]
		if  not tab then
			tab = loadSprites(s)
		end
		self.sprites = tab
	end
	function Pawn:getImage()
		return self.img
	end
	function Pawn:setImage(i)
		self.img = i
	end
	function Pawn:update(dt)
		self.imgtimer = self.imgtimer + dt
		if self.imgtimer > 0.25 then
			if not self.crouched and self:isOnGround() then
				if math.abs(self:getVel()) > 200 then
					self.imgtimer = 0
					if self:getImage() == "run1" then
						self:setImage("run2")
					else
						self:setImage("run1")
					end
				else
					self:setImage("idle")
				end
			end
		end 
		if not self:isOnGround() then
			self:setImage("jump")
		end
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
		if love.keyboard.isDown("lctrl") then
			if not self.crouched then
				self.crouched = true
				self:setImage("crouch")
				self.crouchdir = self:getDirection()
			end
			if (love.keyboard.isDown("a") and self.crouchdir ~= LEFT) or (love.keyboard.isDown("d") and self.crouchdir ~= RIGHT) then
				self:setImage("look")
			else
				self:setImage("crouch")
			end
		else
			if self.crouched then
				self:setImage("idle")
				self.crouched = false
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
		end
		Camera.x = lerp(Camera.x, -self:getPos(), 0.1)
		--Camera.sx = 1 - (distance(0, 0, self:getVel()) / self:getSpeed()) * 0.1
		--Camera.sy = 1 - (distance(0, 0, self:getVel()) / self:getSpeed()) * 0.1
	end
	function Pawn:draw()
		local w, h = self:getSize()
		local img = self:getSprites()[self:getImage() .. ".png"]
		local iw, ih = img:getDimensions()
		local dir = self:getDirection() == LEFT and 1 or -1
		love.graphics.draw(img, -iw/2 * dir, ih - h/2, 0, dir, -1)
	end
	function Pawn:init()
		self:setColor(255, 255, 255, 255)
		self:setSize(64, 64) 
	end
	Pawn:setSize(32, 64)
	Pawn:setBounciness(0.1)
	
	
	Player = Pawn:new()
	Player:setSprites("pug")
	Player:spawn()
	

	Ground = Entity:new()
	Ground:setSize(64 * 1024, 128)
	Ground:setPos(0, -256 - 64 - 24) 
	Ground:setColor(0, 0, 0, 0)
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
	if reorder then
		print("re-sorting")
		table.sort(draw, function(a, b)
			if a.layer == b.layer then
				return a.id > b.id
			end
			return a.layer > b.layer
		end)
		reorder = false
	end
	love.graphics.setColor(255, 255, 255, 255)
	
	for i = 1, #bg - 1 do
		love.graphics.draw(bg[i].i, bg[i].q)
	end
	love.graphics.draw(bg[#bg].i, bg[#bg].q, 0, HEIGHT - 256 + 16)
	
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
			for k, v in ipairs(draw) do
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
	for i = 1, #bg - 1 do
		bg[i].q:setViewport(-Camera.x * bg[i].p, 0, WIDTH, HEIGHT)
	end
	bg[#bg].q:setViewport(-Camera.x, HEIGHT - bg[#bg].i:getHeight(), WIDTH, bg[#bg].i:getHeight())
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
