-- @author: 4c65736975, All Rights Reserved
-- @version: 1.0.0.0, 18/03/2023
-- @filename: ShopConfigScreenExtension.lua

local isCreated = false
local soundsCheckDuration = 5000

ShopConfigScreen.L10N_SYMBOL.BUTTON_CAMERA = 'input_CAMERA_SWITCH'
ShopConfigScreen.L10N_SYMBOL.BUTTON_ENGINE = 'action_startMotor'

ShopConfigScreen.playEngineSoundSample = function (self)
	self.lastGameState = g_gameStateManager:getGameState()

	g_gameStateManager:setGameState(GameState.PLAY)

	if self.vehicleSounds ~= nil then
		g_soundManager:playSample(self.vehicleSounds.samples.motorStart)
		g_soundManager:playSamples(self.vehicleSounds.motorSamples, 0, self.vehicleSounds.samples.motorStart)
		g_soundManager:playSamples(self.vehicleSounds.gearboxSamples, 0, self.vehicleSounds.samples.motorStart)
		g_soundManager:playSample(self.vehicleSounds.samples.retarder, 0, self.vehicleSounds.samples.motorStart)

		self.sampleIsPlaying = true

		self.engineButton:setDisabled(true)
	end
end

ShopConfigScreen.stopEngineSoundSample = function (self)
	if self.vehicleSounds ~= nil then
		g_soundManager:stopSamples(self.vehicleSounds.samples)
		g_soundManager:playSample(self.vehicleSounds.samples.motorStop)
		g_soundManager:stopSamples(self.vehicleSounds.motorSamples)
		g_soundManager:stopSamples(self.vehicleSounds.gearboxSamples)
	end
end

ShopConfigScreen.resetEngineSoundSample = function (self)
	if self.lastGameState ~= nil then
		g_gameStateManager:setGameState(self.lastGameState)
	end

	self.sampleIsPlaying = false
	self.soundsCheckTime = 0

	self.engineButton:setDisabled(false)
end

ShopConfigScreen.createIndoorCamera = function (self)
	self.cameraIndoorNode = createCamera('VehicleConfigIndoorCamera', math.rad(60), ShopConfigScreen.NEAR_CLIP_DISTANCE, 100)
	self.rotateIndoorNode = createTransformGroup('VehicleConfigIndoorCameraTarget')
	self.cameraIndoorRootNode = createTransformGroup('VehicleConfigIndoorCameraRootNode')

	setWorldTranslation(self.cameraIndoorRootNode, getWorldTranslation(self.vehicleIndoorCamera.cameraPositionNode))
	link(self.cameraIndoorRootNode, self.rotateIndoorNode)
	setRotation(self.rotateIndoorNode, 0, math.rad(180), 0)
	setTranslation(self.rotateIndoorNode, 0, 0, 0)
	link(self.rotateIndoorNode, self.cameraIndoorNode)
end

ShopConfigScreen.changeToVehicleCamera = function (self)
	if self.cameraIndoorNode ~= nil then
		setCamera(getCamera() ~= self.cameraIndoorNode and self.cameraIndoorNode or self.cameraNode)

		if getCamera() == self.cameraIndoorNode then
			g_depthOfFieldManager:reset()
		end
	end
end

local function onVehicleLoaded(self, vehicle, loadingState, asyncArguments)
	if vehicle ~= nil and vehicle.spec_enterable ~= nil then
		for _, camera in pairs(vehicle.spec_enterable.cameras) do
			if camera.isInside then
				if self.cameraIndoorNode == nil then
					self.vehicleIndoorCamera = camera

					self.indoorRotX = 0
					self.indoorRotY = MathUtil.degToRad(180)

					self:createIndoorCamera()
				end

				self.cameraButton:setVisible(true)

				break
			end
		end

		if vehicle.spec_motorized ~= nil then
			self:resetEngineSoundSample()

			self.engineButton:setVisible(true)

			self.vehicleSounds = vehicle.spec_motorized
		end
	end

	self.buttonsPanel:invalidateLayout()
end

ShopConfigScreen.onVehicleLoaded = Utils.prependedFunction(ShopConfigScreen.onVehicleLoaded, onVehicleLoaded)

local function update(self, dt)
	if self.sampleIsPlaying then
		self.soundsCheckTime = self.soundsCheckTime + dt

		if self.soundsCheckTime > soundsCheckDuration then
			self:stopEngineSoundSample()

			-- after stop engine samples, we waiting a second and a half so as not to cut off the sound suddenly,
			-- that's why we resets here only after this time and not in the function that stopping samples
			if self.soundsCheckTime > soundsCheckDuration + 1500 then
				self:resetEngineSoundSample()
			end
		end
	end
end

ShopConfigScreen.update = Utils.appendedFunction(ShopConfigScreen.update, update)

local function updateButtons(self, superFunc, storeItem, vehicle, saleItem)
	superFunc(self, storeItem, vehicle, saleItem)

	function swapTableElementPosition(tab, newPos, value)
		for a, b in pairs(tab) do
			if b == value then
				table.remove(tab, a)
				table.insert(tab, newPos, value)
				break
			end
		end
	end

	local cameraButtonText = self.l10n:getText(ShopConfigScreen.L10N_SYMBOL.BUTTON_CAMERA)
	local engineButtonText = self.l10n:getText(ShopConfigScreen.L10N_SYMBOL.BUTTON_ENGINE)

	if not isCreated then
		self.cameraButton = self.buyButton:clone(self.buttonsPanel)

		self.cameraButton:setText(cameraButtonText)
		self.cameraButton:applyProfile(ShopConfigScreen.GUI_PROFILE.BUTTON_BUY)
		self.cameraButton:setInputAction(InputAction.MENU_EXTRA_2)
		self.cameraButton.onClickCallback = function ()
			self:changeToVehicleCamera()
		end

		swapTableElementPosition(self.buttonsPanel.elements, 2, self.cameraButton)

		self.engineButton = self.buyButton:clone(self.buttonsPanel)

		self.engineButton:setText(engineButtonText)
		self.engineButton:applyProfile(ShopConfigScreen.GUI_PROFILE.BUTTON_BUY)
		self.engineButton:setInputAction(InputAction.MENU_EXTRA_1)
		self.engineButton.onClickCallback = function ()
			self:playEngineSoundSample()
		end

		swapTableElementPosition(self.buttonsPanel.elements, 3, self.engineButton)

		isCreated = true
	end

	self.cameraButton:setVisible(false)
	self.engineButton:setVisible(false)
	self.buttonsPanel:invalidateLayout()
end

ShopConfigScreen.updateButtons = Utils.overwrittenFunction(ShopConfigScreen.updateButtons, updateButtons)

local function updateInput(self, superFunc, dt)
	if self.cameraIndoorNode ~= nil and getCamera() == self.cameraIndoorNode then
		self:updateInputContext()

		if self.inputVertical ~= 0 then
			local value = self.inputVertical
			self.inputVertical = 0
			local rotSpeed = 0.001 * dt

			if self.limitRotXDelta > 0.001 then
				self.indoorRotX = math.min(self.indoorRotX - rotSpeed * value, self.indoorRotX)
			elseif self.limitRotXDelta < -0.001 then
				self.indoorRotX = math.max(self.indoorRotX - rotSpeed * value, self.indoorRotX)
			else
				self.indoorRotX = self.indoorRotX - rotSpeed * value
			end
		end

		if self.inputHorizontal ~= 0 then
			local value = self.inputHorizontal
			self.inputHorizontal = 0
			local rotSpeed = 0.001 * dt
			self.indoorRotY = self.indoorRotY - rotSpeed * (value * -1)
		end

		if self.inputZoom ~= 0 then
			self.inputZoom = 0
		end

		self.indoorRotX = math.min(self.vehicleIndoorCamera.rotMaxX, math.max(self.vehicleIndoorCamera.rotMinX, self.indoorRotX))

		local inputHelpMode = self.inputManager:getInputHelpMode()

		if inputHelpMode ~= self.lastInputHelpMode then
			self.lastInputHelpMode = inputHelpMode

			self:updateInputGlyphs()
		end

		if not self.isDragging and self.inputDragging then
			self.isDragging = true

			self.inputManager:setShowMouseCursor(false, true)
		elseif self.isDragging and not self.inputDragging then
			self.isDragging = false

			self.inputManager:setShowMouseCursor(true)

			self.accumDraggingInput = 0
		end

		self.inputDragging = false
	else
		superFunc(self, dt)
	end
end

ShopConfigScreen.updateInput = Utils.overwrittenFunction(ShopConfigScreen.updateInput, updateInput)

local function updateCamera(self, superFunc, dt)
	if self.cameraIndoorNode ~= nil and getCamera() == self.cameraIndoorNode then
		setRotation(self.rotateIndoorNode, self.indoorRotX, self.indoorRotY, 0)
	else
		superFunc(self, dt)
	end
end

ShopConfigScreen.updateCamera = Utils.overwrittenFunction(ShopConfigScreen.updateCamera, updateCamera)

-- we can't appened/prepend/overwrite (I don't know why) onClose/onOpen function,
-- so we attach our clean up function to function that is called in onClose function
local function deletePreviewVehicles(self)
	if self.lastGameState ~= nil then
		self.lastGameState = nil
	end

	if self.sampleIsPlaying ~= nil then
		self.sampleIsPlaying = false
	end

	if self.soundsCheckTime ~= nil then
		self.soundsCheckTime = 0
	end

	if self.vehicleIndoorCamera ~= nil then
		self.vehicleIndoorCamera = nil
	end

	if self.vehicleSounds ~= nil then
		self.vehicleSounds = nil
	end

	if self.cameraIndoorNode ~= nil then
		self.cameraIndoorNode = nil
	end

	if self.cameraIndoorRootNode ~= nil then
		delete(self.cameraIndoorRootNode)

		self.cameraIndoorRootNode = nil
	end

	if self.engineButton ~= nil then
		self.engineButton:setDisabled(false)
	end
end

ShopConfigScreen.deletePreviewVehicles = Utils.appendedFunction(ShopConfigScreen.deletePreviewVehicles, deletePreviewVehicles)