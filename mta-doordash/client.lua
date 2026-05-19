-- DoorDash Client Script

local phoneOpen = false
local currentDelivery = nil
local currentStage = nil
local pickupMarker = nil
local deliverMarker = nil
local deliveryBlip = nil

local offerTimer = 0
local offerTimeLeft = 0
local currentOffer = nil

local phoneW = 380
local phoneH = 600

function getPhonePos()
    local screenW, screenH = guiGetScreenSize()
    local px = (screenW - phoneW) / 2
    local py = (screenH - phoneH) / 2
    return px, py, screenW, screenH
end

function getButtons()
    local px, py = getPhonePos()
    return {
        accept = {x = px + 10, y = py + 480, w = 175, h = 45},
        decline = {x = px + 195, y = py + 480, w = 175, h = 45},
        refresh = {x = px + 40, y = py + 450, w = 300, h = 50},
        cancel = {x = px + 40, y = py + 500, w = 300, h = 50},
        close = {x = px + 340, y = py + 5, w = 35, h = 35}
    }
end

function getMousePos()
    local success, mx, my = getCursorPosition()
    if not success then return 0, 0 end
    local screenW, screenH = guiGetScreenSize()
    return mx * screenW, my * screenH
end

function isMouseInBounds(mx, my, bx, by, bw, bh)
    return mx >= bx and mx <= bx + bw and my >= by and my <= by + bh
end

function openPhone()
    if phoneOpen then return end
    phoneOpen = true
    showCursor(true)
    triggerServerEvent("doordash:requestOffer", localPlayer)
end

addEvent("doordash:openPhone", true)
addEventHandler("doordash:openPhone", root, openPhone)

function closePhone()
    if not phoneOpen then return end
    phoneOpen = false
    showCursor(false)
end

function onNewOffer(offer)
    currentOffer = offer
    offerTimeLeft = 30
    offerTimer = getTickCount()
end

addEvent("doordash:newOffer", true)
addEventHandler("doordash:newOffer", root, onNewOffer)

function startDelivery(offer, stage)
    currentDelivery = offer
    currentStage = stage
    createDeliveryMarkers()
    outputChatBox("[DoorDash] GPS'e isaretlendi!", 0, 255, 0)
    closePhone()
end

addEvent("doordash:startDelivery", true)
addEventHandler("doordash:startDelivery", root, startDelivery)

function updateStage(stage)
    currentStage = stage
    createDeliveryMarkers()
end

addEvent("doordash:updateStage", true)
addEventHandler("doordash:updateStage", root, updateStage)

function createDeliveryMarkers()
    if pickupMarker and isElement(pickupMarker) then destroyElement(pickupMarker) end
    if deliverMarker and isElement(deliverMarker) then destroyElement(deliverMarker) end
    if deliveryBlip and isElement(deliveryBlip) then destroyElement(deliveryBlip) end

    if not currentDelivery then return end

    if currentStage == "pickup" then
        local r = currentDelivery.restaurant
        pickupMarker = createMarker(r.x, r.y, r.z - 1, "cylinder", 2.0, 255, 165, 0, 150)
        deliveryBlip = createBlip(r.x, r.y, r.z, 0, 2, 255, 165, 0, 255, 0, 99999.0, localPlayer)
    elseif currentStage == "deliver" then
        local c = currentDelivery.customer
        deliverMarker = createMarker(c.x, c.y, c.z - 1, "cylinder", 2.0, 0, 255, 0, 150)
        deliveryBlip = createBlip(c.x, c.y, c.z, 0, 2, 0, 255, 0, 255, 0, 99999.0, localPlayer)
    end
end

function checkMarkerHit(hitElement)
    if hitElement ~= localPlayer then return end
    if not currentDelivery then return end

    if currentStage == "pickup" and source == pickupMarker then
        triggerServerEvent("doordash:reachedPickup", localPlayer)
    elseif currentStage == "deliver" and source == deliverMarker then
        triggerServerEvent("doordash:completedDelivery", localPlayer)
        cleanupDelivery()
    end
end

addEventHandler("onClientMarkerHit", root, checkMarkerHit)

function cleanupDelivery()
    if pickupMarker and isElement(pickupMarker) then destroyElement(pickupMarker); pickupMarker = nil end
    if deliverMarker and isElement(deliverMarker) then destroyElement(deliverMarker); deliverMarker = nil end
    if deliveryBlip and isElement(deliveryBlip) then destroyElement(deliveryBlip); deliveryBlip = nil end
    currentDelivery = nil
    currentStage = nil
end

function onClientClick(button, state, x, y)
    if not phoneOpen then return end
    if state ~= "down" then return end

    local btn = getButtons()

    if isMouseInBounds(x, y, btn.close.x, btn.close.y, btn.close.w, btn.close.h) then
        closePhone()
        return
    end

    if currentOffer and offerTimeLeft > 0 then
        if isMouseInBounds(x, y, btn.accept.x, btn.accept.y, btn.accept.w, btn.accept.h) then
            triggerServerEvent("doordash:acceptDelivery", localPlayer, currentOffer)
            currentOffer = nil
            closePhone()
            return
        end
        if isMouseInBounds(x, y, btn.decline.x, btn.decline.y, btn.decline.w, btn.decline.h) then
            triggerServerEvent("doordash:declineDelivery", localPlayer)
            currentOffer = nil
            return
        end
    else
        if isMouseInBounds(x, y, btn.refresh.x, btn.refresh.y, btn.refresh.w, btn.refresh.h) then
            triggerServerEvent("doordash:requestOffer", localPlayer)
            return
        end
    end

    if currentDelivery and isMouseInBounds(x, y, btn.cancel.x, btn.cancel.y, btn.cancel.w, btn.cancel.h) then
        triggerServerEvent("doordash:cancelDelivery", localPlayer)
        cleanupDelivery()
        closePhone()
        return
    end
end

addEventHandler("onClientClick", root, onClientClick)

function onKeyPress(button, press)
    if button == "escape" and press and phoneOpen then
        closePhone()
    end
end

addEventHandler("onClientKey", root, onKeyPress)

function drawPhone()
    if not phoneOpen then return end

    local px, py, screenW, screenH = getPhonePos()
    local mx, my = getMousePos()
    local btn = getButtons()

    local now = getTickCount()
    if currentOffer and offerTimeLeft > 0 then
        local elapsed = (now - offerTimer) / 1000
        offerTimeLeft = math.max(0, 30 - elapsed)
        if offerTimeLeft <= 0 then
            triggerServerEvent("doordash:declineDelivery", localPlayer)
            currentOffer = nil
        end
    end

    dxDrawRectangle(px - 5, py - 5, phoneW + 10, phoneH + 10, tocolor(0, 0, 0, 220))
    dxDrawRectangle(px, py, phoneW, phoneH, tocolor(26, 26, 46))
    dxDrawRectangle(px, py, phoneW, 50, tocolor(0, 0, 0, 100))

    local rt = getRealTime()
    dxDrawText(string.format("%02d:%02d", rt.hour, rt.minute), px + 15, py + 10, px + 100, py + 40, tocolor(255, 255, 255), 1.0, "default", "left", "top")
    dxDrawText("DoorDash", px + 100, py + 10, px + phoneW - 50, py + 40, tocolor(255, 48, 8), 1.2, "default-bold", "center", "top")

    if currentDelivery then
        drawActiveDelivery(px, py, mx, my, btn)
    elseif currentOffer and offerTimeLeft > 0 then
        drawOfferScreen(px, py, mx, my, btn)
    else
        drawWaitingScreen(px, py, mx, my, btn)
    end
end

addEventHandler("onClientRender", root, drawPhone)

function drawWaitingScreen(px, py, mx, my, btn)
    dxDrawText("Musteri teklifleri bekleniyor...", px + 20, py + 150, px + phoneW - 20, py + 200, tocolor(200, 200, 200), 1.0, "default", "center", "top")

    local hover = isMouseInBounds(mx, my, btn.refresh.x, btn.refresh.y, btn.refresh.w, btn.refresh.h)
    dxDrawRectangle(btn.refresh.x, btn.refresh.y, btn.refresh.w, btn.refresh.h, hover and tocolor(255, 60, 20) or tocolor(255, 48, 8))
    dxDrawText("Yeni Teklif Ist", btn.refresh.x, btn.refresh.y, btn.refresh.x + btn.refresh.w, btn.refresh.y + btn.refresh.h, tocolor(255, 255, 255), 1.1, "default-bold", "center", "center")
end

function drawOfferScreen(px, py, mx, my, btn)
    local y = py + 70

    dxDrawText("Yeni Siparis!", px + 20, y, px + phoneW - 20, y + 30, tocolor(74, 222, 128), 1.3, "default-bold", "center", "top")

    local timerColor = offerTimeLeft <= 10 and tocolor(255, 0, 0) or tocolor(255, 255, 255)
    dxDrawRectangle(px + phoneW - 70, y + 5, 50, 25, tocolor(255, 48, 8))
    dxDrawText(math.ceil(offerTimeLeft) .. "s", px + phoneW - 70, y + 5, px + phoneW - 20, y + 30, timerColor, 1.0, "default-bold", "center", "top")

    y = y + 45

    local items = {
        {"Siparis:", currentOffer.food},
        {"Restoran:", currentOffer.restaurant.name},
        {"Musteri:", currentOffer.customerName},
        {"Mesafe:", string.format("%.1f km", currentOffer.distance / 100)},
    }

    for _, item in ipairs(items) do
        dxDrawText(item[1], px + 20, y, px + 120, y + 25, tocolor(150, 150, 150), 0.9, "default", "left", "top")
        dxDrawText(item[2], px + 120, y, px + phoneW - 20, y + 25, tocolor(255, 255, 255), 1.0, "default-bold", "left", "top")
        y = y + 30
    end

    y = y + 10
    dxDrawRectangle(px + 15, y, phoneW - 30, 80, tocolor(74, 222, 128, 30))
    dxDrawText("Teslimat: $" .. currentOffer.payment, px + 20, y + 5, px + phoneW - 20, y + 25, tocolor(200, 200, 200), 1.0, "default", "left", "top")
    dxDrawText("Bahsis: $" .. currentOffer.tip, px + 20, y + 25, px + phoneW - 20, y + 45, tocolor(200, 200, 200), 1.0, "default", "left", "top")
    dxDrawText("Toplam: $" .. currentOffer.totalPayment, px + 20, y + 50, px + phoneW - 20, y + 75, tocolor(74, 222, 128), 1.2, "default-bold", "left", "top")

    local hoverA = isMouseInBounds(mx, my, btn.accept.x, btn.accept.y, btn.accept.w, btn.accept.h)
    local hoverD = isMouseInBounds(mx, my, btn.decline.x, btn.decline.y, btn.decline.w, btn.decline.h)

    dxDrawRectangle(btn.accept.x, btn.accept.y, btn.accept.w, btn.accept.h, hoverA and tocolor(34, 197, 94) or tocolor(74, 222, 128))
    dxDrawText("Kabul Et", btn.accept.x, btn.accept.y, btn.accept.x + btn.accept.w, btn.accept.y + btn.accept.h, tocolor(255, 255, 255), 1.2, "default-bold", "center", "center")

    dxDrawRectangle(btn.decline.x, btn.decline.y, btn.decline.w, btn.decline.h, hoverD and tocolor(220, 38, 38) or tocolor(239, 68, 68))
    dxDrawText("Reddet", btn.decline.x, btn.decline.y, btn.decline.x + btn.decline.w, btn.decline.y + btn.decline.h, tocolor(255, 255, 255), 1.2, "default-bold", "center", "center")
end

function drawActiveDelivery(px, py, mx, my, btn)
    local y = py + 70

    dxDrawText("Aktif Teslimat", px + 20, y, px + phoneW - 20, y + 30, tocolor(255, 48, 8), 1.3, "default-bold", "center", "top")
    y = y + 50

    if currentStage == "pickup" then
        dxDrawText("Restorana gidin", px + 20, y, px + phoneW - 20, y + 30, tocolor(255, 255, 255), 1.1, "default-bold", "center", "top")
        dxDrawText(currentDelivery.restaurant.name, px + 20, y + 30, px + phoneW - 20, y + 55, tocolor(255, 165, 0), 1.0, "default", "center", "top")
    else
        dxDrawText("Musteriye ulastirin", px + 20, y, px + phoneW - 20, y + 30, tocolor(255, 255, 255), 1.1, "default-bold", "center", "top")
        dxDrawText(currentDelivery.customerName, px + 20, y + 30, px + phoneW - 20, y + 55, tocolor(0, 255, 0), 1.0, "default", "center", "top")
    end

    y = y + 100
    dxDrawText("Kazanc: $" .. currentDelivery.totalPayment, px + 20, y, px + phoneW - 20, y + 30, tocolor(74, 222, 128), 1.2, "default-bold", "center", "top")

    y = y + 50
    local hover = isMouseInBounds(mx, my, btn.cancel.x, btn.cancel.y, btn.cancel.w, btn.cancel.h)
    dxDrawRectangle(btn.cancel.x, btn.cancel.y, btn.cancel.w, btn.cancel.h, hover and tocolor(75, 85, 99) or tocolor(107, 114, 128))
    dxDrawText("Iptal Et", btn.cancel.x, btn.cancel.y, btn.cancel.x + btn.cancel.w, btn.cancel.y + btn.cancel.h, tocolor(255, 255, 255), 1.1, "default-bold", "center", "center")
end

function drawHUD()
    if not currentDelivery then return end

    local screenW, screenH = guiGetScreenSize()
    local y = screenH - 120

    dxDrawRectangle(screenW / 2 - 180, y, 360, 80, tocolor(0, 0, 0, 180))
    dxDrawRectangle(screenW / 2 - 180, y, 360, 3, tocolor(255, 165, 0))

    if currentStage == "pickup" then
        dxDrawText("Restorana gidin: " .. currentDelivery.restaurant.name, screenW / 2 - 170, y + 10, screenW / 2 + 170, y + 40, tocolor(255, 255, 255), 1.0, "default-bold", "center", "top")
    else
        dxDrawText("Musteriye ulastirin: " .. currentDelivery.customerName, screenW / 2 - 170, y + 10, screenW / 2 + 170, y + 40, tocolor(255, 255, 255), 1.0, "default-bold", "center", "top")
    end

    dxDrawText("Odeme: $" .. currentDelivery.totalPayment, screenW / 2 - 170, y + 45, screenW / 2 + 170, y + 75, tocolor(0, 255, 0), 1.1, "default-bold", "center", "top")
end

addEventHandler("onClientRender", root, drawHUD)