require("util")
require("lovedebug")
function love.load()
	ents = {}
	colliders = {}
	love.window.setMode(800, 600, {
		fullscreen = true,
		fullscreentype = "desktop",
	})
	WIDTH, HEIGHT = love.window.getDimensions()

	function screenToWorld(x, y)
		return x - WIDTH / 2, -(y - HEIGHT / 2)
	end
	function center(x1, y1, x2, y2)
		return (x1 + x2) / 2, (y1 + y2) / 2
	end

	World = {
		gx = 0,
		gy = 500,
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
	function Entity:spawn()
		local id = table.insert(ents, self) 
		local w, h = self:getSize()
		if w + h ~= 0 and self:getCollide() then
			colliders[self] = true
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
		colliders[self] = nil
		table.remove(ents, self.id)
	end
	
	Phys = Entity:new{
		class = "Phys",
		vx = 0,
		vy = 0,
		bounciness = 1,
		friction = 0,
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
	function Phys:isTouching(obj_or_x, y, w, h)
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
		and y - h / 2 <= oy + oh / 2 --bottom edge < top edge
		then
			return true
		end
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
		edges = {}
		for obj in pairs(colliders) do
			if obj ~= self then
				if self:isTouching(obj) then
					local ox, oy = obj:getPos()
					local ow, oh = obj:getSize()
					ob = math.max(ob, obj.getBouncines and obj:getBouncines() or 0)
					local right = 	-((x - w / 2) - (ox - ow / 2)) --left edge	< left edge
					local left = 	((x + w / 2) - (ox + ow / 2)) --right edge	> right edge
					local bottom =	((y - h / 2) - (oy - oh / 2)) --bottom edge	> bottom edge
					local top = 	-((y + h / 2) - (oy + oh / 2)) --top edge	< top edge	
					
					local objedges = {
						{key = "left", val = left, pos = (ox + ow / 2) + w / 2}, 
						{key = "right", val = right, pos = (ox - ow / 2) - w / 2}, 
						{key = "bottom", val = bottom, pos = (oy + oh / 2) + h / 2}, 
						{key = "top", val = top, pos = (oy - oh / 2) - h / 2}
					}
					table.sort(objedges, function(a, b)
						return a.val > b.val
					end)
					for i = 1, #objedges do
						if objedges[i].val > 0 then
							edges[#edges + 1] = objedges[i]
						end
					end
				end
			end
		end
		local max = {
			top = 0,
			bottom = 0,
			left = 0,
			right = 0,
		}
		for i = 1, #edges do
			local e = edges[i]
			if e.val > 0 then
				if e.key == "left" then
					if e.val > max.left then
						px = e.pos
						vx = -vx * (b + ob)
						max.left = e.val
					end
				elseif e.key == "right" then
					if e.val > max.right then
						px = e.pos
						vx = -vx * (b + ob)
						max.right = e.val
					end
				elseif e.key == "top" then
					if e.val > max.top then
						py = e.pos
						vy = -vy * (b + ob)
						max.top = e.val
					end
				elseif e.key == "bottom" then
					if e.val > max.bottom then
						py = e.pos
						vy = -vy * (b + ob)
						max.bottom = e.val
					end
				end 
			end
		end
		self:setPos(px, py)
		self:setVel(vx, vy)
		return changed
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

	Player = Phys:new{
		class = "Player",
	}
	function Player:update(dt)
		self:doVelocity(dt)
		self:doGravity(dt)
		onground = false
		if self:doCollision(dt) then
			self:doFriction(dt)
			onground = true
		end
		local vx, vy = self:getVel()
		if love.keyboard.isDown("a") then
			vx = vx - 500 * dt
		end
		if love.keyboard.isDown("d") then
			vx = vx + 500 * dt
		end
		self:setVel(vx, vy)
	end
	Player:setSize(32, 64)
	Player:setBounciness(0.1)
	Player:spawn()

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
	love.graphics.setColor(0, 0, 0, 255)
	love.graphics.print(table.concat({round(Player:getPos())}, ", "), 0, 0)
	love.graphics.push()
		love.graphics.translate(WIDTH / 2, HEIGHT / 2)
		love.graphics.scale(1, -1)
		for k, v in ipairs(ents) do
			love.graphics.push()
				love.graphics.translate(v:getPos())
				love.graphics.rotate(v:getRotation())
				love.graphics.setColor(v:getColor())
				v:draw()
			love.graphics.pop()
		end
	love.graphics.pop()
end
function love.update(dt)
	for k, v in ipairs(ents) do
		v:update(dt)
	end
end
function love.keypressed(key)
	if key == " " then
		local vx, vy = Player:getVel()
		vy = vy + 200
		Player:setVel(vx, vy)
	end
	if key == "r" then
		Player:setPos(0, 0)
		Player:setVel(0, 0)
	end
end
function love.mousepressed(x, y, but)
	GhostPosX, GhostPosY = Ghost:getPos()
end
function love.mousereleased(x, y, but)
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
