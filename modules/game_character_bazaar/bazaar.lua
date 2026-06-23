local bazaarWindow
local bazaarButton
local canAuction = false
local pendingRequest = false

local function widget(id)
  return bazaarWindow and bazaarWindow:recursiveGetChildById(id)
end

local function setStatus(message, color)
  local status = widget('statusLabel')
  if status then
    status:setText(message or '')
    status:setColor(color or '$var-text-cip-color')
  end
end

local function setSubmitEnabled(enabled)
  local submit = widget('submitButton')
  if submit then
    submit:setEnabled(enabled)
  end
end

local function formatCoins(value)
  return comma_value(tonumber(value) or 0)
end

function init()
  bazaarWindow = g_ui.displayUI('bazaar')
  bazaarWindow:hide()
  UIModalOverlay.register(bazaarWindow)

  if modules.game_mainpanel and modules.game_mainpanel.addToggleButton then
    bazaarButton = modules.game_mainpanel.addToggleButton(
      'characterBazaarButton', tr('Character Bazaar'), '/images/options/button_taskboard', toggle, false, 1007)
  end

  connect(g_game, {
    onCharacterBazaarRequirements = onRequirements,
    onCharacterBazaarCreateResult = onCreateResult,
    onGameEnd = hide,
  })
end

function terminate()
  disconnect(g_game, {
    onCharacterBazaarRequirements = onRequirements,
    onCharacterBazaarCreateResult = onCreateResult,
    onGameEnd = hide,
  })

  if bazaarButton then
    bazaarButton:destroy()
    bazaarButton = nil
  end
  if bazaarWindow then
    bazaarWindow:destroy()
    bazaarWindow = nil
  end
end

function show()
  if not bazaarWindow or not g_game.isOnline() then return end
  bazaarWindow:show()
  bazaarWindow:raise()
  bazaarWindow:focus()
  if bazaarButton then bazaarButton:setOn(true) end
  requestRequirements()
end

function hide()
  if not bazaarWindow then return end
  bazaarWindow:hide()
  pendingRequest = false
  if bazaarButton then bazaarButton:setOn(false) end
end

function toggle()
  if not bazaarWindow then return end
  if bazaarWindow:isVisible() then
    hide()
  else
    show()
  end
end

function requestRequirements()
  if not g_game.isOnline() then return end
  pendingRequest = false
  canAuction = false
  setSubmitEnabled(false)
  setStatus(tr('Loading Character Bazaar requirements...'))
  g_game.characterBazaarRequest()
end

function onRequirements(allowed, minimumLevel, minimumPrice, minimumDuration, maximumDuration, auctionFee, commissionPercent, transferableCoins, reason)
  canAuction = allowed
  pendingRequest = false

  local priceEdit = widget('priceEdit')
  if priceEdit and priceEdit:getText() == '' then priceEdit:setText(tostring(minimumPrice)) end
  local durationEdit = widget('durationEdit')
  if durationEdit and durationEdit:getText() == '' then durationEdit:setText(tostring(math.floor(minimumDuration / 3600))) end

  local rules = widget('rulesLabel')
  if rules then
    rules:setText(tr('Minimum level: %d | Price: %d | Duration: %d-%d hours', minimumLevel, minimumPrice,
      math.ceil(minimumDuration / 3600), math.floor(maximumDuration / 3600)))
  end
  local balance = widget('balanceLabel')
  if balance then
    balance:setText(tr('Transferable Tibia Coins: %s | Creation fee: %s | Commission: %d%%',
      formatCoins(transferableCoins), formatCoins(auctionFee), commissionPercent))
  end

  setSubmitEnabled(allowed)
  if allowed then
    setStatus(tr('Your character meets the current auction requirements.'), '#7DFF7D')
  else
    setStatus(reason ~= '' and reason or tr('Your character cannot be listed.'), '#FF7777')
  end
end

function submit()
  if pendingRequest or not canAuction then return end

  local price = tonumber(widget('priceEdit'):getText())
  local durationHours = tonumber(widget('durationEdit'):getText())
  local description = widget('descriptionEdit'):getText() or ''
  if not price or price < 1 or math.floor(price) ~= price then
    setStatus(tr('Enter a valid starting price.'), '#FF7777')
    return
  end
  if not durationHours or durationHours < 1 or math.floor(durationHours) ~= durationHours then
    setStatus(tr('Enter a valid duration in hours.'), '#FF7777')
    return
  end
  if #description > 512 then
    setStatus(tr('The description may contain at most 512 characters.'), '#FF7777')
    return
  end

  pendingRequest = true
  setSubmitEnabled(false)
  setStatus(tr('Creating auction. The server is validating your character...'))
  g_game.characterBazaarCreate(price, durationHours * 60 * 60, description)
end

function onCreateResult(success, message)
  pendingRequest = false
  if success then
    setStatus(message, '#7DFF7D')
    scheduleEvent(hide, 500)
  else
    setStatus(message ~= '' and message or tr('The auction could not be created.'), '#FF7777')
    setSubmitEnabled(canAuction)
  end
end
