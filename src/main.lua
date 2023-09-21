-- @author: 4c65736975, All Rights Reserved
-- @version: 1.0.0.1, 21|09|2023
-- @filename: main.lua

-- Changelog (1.0.0.1):
-- cleaned code

source(g_currentModDirectory .. "src/shared/table.lua")

local isCreated = false

ShopConfigScreen.L10N_SYMBOL.BUTTON_CAMERA = "input_CAMERA_SWITCH"
ShopConfigScreen.L10N_SYMBOL.BUTTON_ENGINE_START = "action_startMotor"
ShopConfigScreen.L10N_SYMBOL.BUTTON_ENGINE_STOP = "action_stopMotor"

ShopConfigScreen.playEngineSamples = function (self)
  if self.motorizedVehicle ~= nil and self.motorizedVehicle.spec_motorized ~= nil then
    local spec = self.motorizedVehicle.spec_motorized

    self.lastGameState = g_gameStateManager:getGameState()

    g_gameStateManager:setGameState(GameState.PLAY)

    g_soundManager:stopSample(spec.samples.motorStop)
    g_soundManager:playSample(spec.samples.motorStart)
    g_soundManager:playSamples(spec.motorSamples, 0, spec.samples.motorStart)
    g_soundManager:playSamples(spec.gearboxSamples, 0, spec.samples.motorStart)
    g_soundManager:playSample(spec.samples.retarder, 0, spec.samples.motorStart)

    self.stopSamplesTimer = 0
    self.motorSampleIsPlaying = true
    self.engineButton:setText(self.l10n:getText(ShopConfigScreen.L10N_SYMBOL.BUTTON_ENGINE_STOP))
  end
end

ShopConfigScreen.stopEngineSamples = function (self)
  if self.motorizedVehicle ~= nil and self.motorizedVehicle.spec_motorized ~= nil then
    local spec = self.motorizedVehicle.spec_motorized

    g_soundManager:stopSamples(spec.samples)
    g_soundManager:playSample(spec.samples.motorStop)
    g_soundManager:stopSamples(spec.motorSamples)
    g_soundManager:stopSamples(spec.gearboxSamples)

    self.stopSamplesTimer = 1500

    self.engineButton:setText(self.l10n:getText(ShopConfigScreen.L10N_SYMBOL.BUTTON_ENGINE_START))
    self.engineButton:setDisabled(true)
  end
end

ShopConfigScreen.resetEngineSamples = function (self)
  self.motorSampleIsPlaying = false

  if self.lastGameState ~= nil then
    g_gameStateManager:setGameState(self.lastGameState)
  end

  self.engineButton:setDisabled(false)
end

ShopConfigScreen.createIndoorCamera = function (self)
  self.indoorCameraNode = createCamera("VehicleConfigIndoorCamera", math.rad(60), 0.01, 100)
  self.indoorCameraRotateNode = createTransformGroup("VehicleConfigIndoorCameraTarget")
  self.indoorCameraRootNode = createTransformGroup("VehicleConfigIndoorCameraRootNode")

  setWorldTranslation(self.indoorCameraRootNode, getWorldTranslation(self.indoorCamera.cameraPositionNode))
  link(self.indoorCameraRootNode, self.indoorCameraRotateNode)
  setRotation(self.indoorCameraRotateNode, 0, math.rad(180), 0)
  setTranslation(self.indoorCameraRotateNode, 0, 0, 0)
  link(self.indoorCameraRotateNode, self.indoorCameraNode)
end

ShopConfigScreen.changeVehicleCamera = function (self)
  if self.indoorCameraNode ~= nil then
    setCamera(getCamera() ~= self.indoorCameraNode and self.indoorCameraNode or self.cameraNode)

    if getCamera() == self.indoorCameraNode then
      g_depthOfFieldManager:reset()
    end
  end
end

local function onVehicleLoaded(self, vehicle, loadingState, asyncArguments)
  if vehicle ~= nil and vehicle.spec_motorized ~= nil then
    self.motorizedVehicle = vehicle
  end

  if vehicle ~= nil and vehicle.spec_enterable ~= nil then
    for _, camera in ipairs(vehicle.spec_enterable.cameras) do
      if camera.isInside and self.indoorCameraNode == nil then
        self.indoorCamera = camera
        self.indoorRotX = 0
        self.indoorRotY = MathUtil.degToRad(180)

        self:createIndoorCamera()

        break
      end
    end
  end

  if self.indoorCamera == nil then
    self.cameraButton:setDisabled(true)
  end
end

ShopConfigScreen.onVehicleLoaded = Utils.prependedFunction(ShopConfigScreen.onVehicleLoaded, onVehicleLoaded)

local function update(self, dt)
  if self.motorSampleIsPlaying then
    if self.stopSamplesTimer > 0 then
      self.stopSamplesTimer = self.stopSamplesTimer - dt
    elseif self.stopSamplesTimer < 0 then
      self:resetEngineSamples()
    end
  end
end

ShopConfigScreen.update = Utils.appendedFunction(ShopConfigScreen.update, update)

local function updateButtons(self, superFunc, storeItem, vehicle, saleItem)
  superFunc(self, storeItem, vehicle, saleItem)

  if isCreated then
    local isMotorized = storeItem.configurations ~= nil and storeItem.configurations.motor ~= nil

    self.cameraButton:setDisabled(not isMotorized)
    self.cameraButton:setVisible(isMotorized)
    self.engineButton:setDisabled(not isMotorized)
    self.engineButton:setVisible(isMotorized)
  else
    self.cameraButton = self.buyButton:clone(self.buttonsPanel)
    self.cameraButton:setText(self.l10n:getText(ShopConfigScreen.L10N_SYMBOL.BUTTON_CAMERA))
    self.cameraButton:applyProfile(ShopConfigScreen.GUI_PROFILE.BUTTON_BUY)
    self.cameraButton:setInputAction(InputAction.MENU_EXTRA_2)
    self.cameraButton.onClickCallback = function ()
      self:changeVehicleCamera()
    end

    table.moveTo(self.buttonsPanel.elements, self.cameraButton, 2)

    self.engineButton = self.buyButton:clone(self.buttonsPanel)
    self.engineButton:setText(self.l10n:getText(ShopConfigScreen.L10N_SYMBOL.BUTTON_ENGINE_START))
    self.engineButton:applyProfile(ShopConfigScreen.GUI_PROFILE.BUTTON_BUY)
    self.engineButton:setInputAction(InputAction.MENU_EXTRA_1)
    self.engineButton.onClickCallback = function ()
      if not self.motorSampleIsPlaying then
        self:playEngineSamples()
      else
        self:stopEngineSamples()
      end
    end

    table.moveTo(self.buttonsPanel.elements, self.engineButton, 3)

    isCreated = true
  end

  self.buttonsPanel:invalidateLayout()
end

ShopConfigScreen.updateButtons = Utils.overwrittenFunction(ShopConfigScreen.updateButtons, updateButtons)

local function updateInput(self, superFunc, dt)
  if self.indoorCameraNode ~= nil and getCamera() == self.indoorCameraNode then
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

    self.indoorRotX = math.min(self.indoorCamera.rotMaxX, math.max(self.indoorCamera.rotMinX, self.indoorRotX))

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
  if self.indoorCameraNode ~= nil and getCamera() == self.indoorCameraNode then
    setRotation(self.indoorCameraRotateNode, self.indoorRotX, self.indoorRotY, 0)
  else
    superFunc(self, dt)
  end
end

ShopConfigScreen.updateCamera = Utils.overwrittenFunction(ShopConfigScreen.updateCamera, updateCamera)

local function deletePreviewVehicles(self)
  if self.lastGameState ~= nil then
    self.lastGameState = nil
  end

  if self.stopSamplesTimer ~= nil then
    self.stopSamplesTimer = 0
  end

  if self.motorizedVehicle ~= nil then
    self.motorizedVehicle = nil
  end

  if self.motorSampleIsPlaying ~= nil then
    self.motorSampleIsPlaying = false
  end

  if self.indoorCamera ~= nil then
    self.indoorCamera = nil
  end

  if self.indoorCameraNode ~= nil then
    delete(self.indoorCameraNode)

    self.indoorCameraNode = nil
  end

  if self.indoorCameraRotateNode ~= nil then
    delete(self.indoorCameraRotateNode)

    self.indoorCameraRotateNode = nil
  end

  if self.indoorCameraRootNode ~= nil then
    delete(self.indoorCameraRootNode)

    self.indoorCameraRootNode = nil
  end
end

ShopConfigScreen.deletePreviewVehicles = Utils.appendedFunction(ShopConfigScreen.deletePreviewVehicles, deletePreviewVehicles)