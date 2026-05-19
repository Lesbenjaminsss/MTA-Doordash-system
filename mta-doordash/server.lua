-- DoorDash Server Script

local deliveries = {}
local activeDeliveries = {}
local playerStats = {}

local restaurants = {
    {name = "PİZZA", x = 2096.6301269531, y = -1800.2086181641, z = 12.89640712738},
}

local customerLocations = {
    {x = 1854.0620117188, y = -1914.2642822266, z = 15.256797790527},
}

local foodNames = {
    "Whopper Menu", "Pizza Margherita", "Tavuk Bucket", "Footlong Sandwich",
    "Big Mac Menu", "Caramel Macchiato", "Chicken Wings", "Sushi Set",
    "Taco Combo", "Pasta Carbonara", "Doner Durum", "Lahmacun",
    "Pide", "Kofte Menu", "Balik Ekmek", "Corba Seti"
}

local customerNames = {
    "Ahmet Y.", "Mehmet K.", "Ayse D.", "Fatma S.",
    "Ali R.", "Zeynep B.", "Mustafa T.", "Emine G.",
    "Hasan P.", "Hatice M.", "Ibrahim C.", "Elif N.",
    "Omer L.", "Merve A.", "Burak F.", "Selin H."
}

function getPlayerStats(player)
    local account = getPlayerAccount(player)
    if not account or isGuestAccount(account) then return nil end
    local accName = getAccountName(account)
    if not playerStats[accName] then
        playerStats[accName] = {completed = 0, earned = 0}
    end
    return playerStats[accName]
end

function setPlayerStats(player, stats)
    local account = getPlayerAccount(player)
    if not account or isGuestAccount(account) then return end
    local accName = getAccountName(account)
    playerStats[accName] = stats
end

function getRandomRestaurant()
    return restaurants[math.random(#restaurants)]
end

function getRandomCustomerLocation()
    return customerLocations[math.random(#customerLocations)]
end

function generateOffer()
    local restaurant = getRandomRestaurant()
    local customer = getRandomCustomerLocation()
    local food = foodNames[math.random(#foodNames)]
    local customerName = customerNames[math.random(#customerNames)]
    local distance = math.random(500, 3000)
    local payment = math.floor(distance / 50) + math.random(10, 50)
    local tip = math.random(5, 30)

    return {
        restaurant = restaurant,
        customer = customer,
        food = food,
        customerName = customerName,
        distance = distance,
        payment = payment,
        tip = tip,
        totalPayment = payment + tip
    }
end

addCommandHandler("doordash", function(player)
    local account = getPlayerAccount(player)
    if not account or isGuestAccount(account) then
        outputChatBox("[DoorDash] Sisteme kayitli olmalisiniz! /register veya /login kullanin.", player, 255, 0, 0)
        return
    end

    local accName = getAccountName(account)

    if activeDeliveries[accName] then
        outputChatBox("[DoorDash] Zaten aktif bir teslimatiniz var!", player, 255, 165, 0)
        return
    end

    triggerClientEvent(player, "doordash:openPhone", player)
end)

function requestNewOffer()
    local player = source
    if not player or not isElement(player) then return end

    local account = getPlayerAccount(player)
    if not account then return end

    local accName = getAccountName(account)

    if deliveries[accName] and deliveries[accName].cooldown then
        return
    end

    local offer = generateOffer()
    deliveries[accName] = {
        offer = offer,
        cooldown = true
    }

    triggerClientEvent(player, "doordash:newOffer", player, offer)

    setTimer(function()
        if deliveries[accName] then
            deliveries[accName].cooldown = nil
        end
    end, 5000, 1)
end

addEvent("doordash:requestOffer", true)
addEventHandler("doordash:requestOffer", root, requestNewOffer)

function acceptDelivery(offerData)
    local player = source
    if not player or not isElement(player) then return end

    local account = getPlayerAccount(player)
    if not account then return end

    local accName = getAccountName(account)

    if not deliveries[accName] or not deliveries[accName].offer then
        return
    end

    activeDeliveries[accName] = {
        offer = deliveries[accName].offer,
        stage = "pickup",
        player = player
    }

    deliveries[accName] = nil

    triggerClientEvent(player, "doordash:startDelivery", player, activeDeliveries[accName].offer, "pickup")
    outputChatBox("[DoorDash] Teslimati kabul ettiniz! Restorana gidin.", player, 0, 255, 0)
end

addEvent("doordash:acceptDelivery", true)
addEventHandler("doordash:acceptDelivery", root, acceptDelivery)

function declineDelivery()
    local player = source
    if not player or not isElement(player) then return end

    local account = getPlayerAccount(player)
    if not account then return end

    local accName = getAccountName(account)
    deliveries[accName] = nil
    outputChatBox("[DoorDash] Teslimati reddettiniz.", player, 255, 165, 0)
end

addEvent("doordash:declineDelivery", true)
addEventHandler("doordash:declineDelivery", root, declineDelivery)

function reachedPickup()
    local player = source
    if not player or not isElement(player) then return end

    local account = getPlayerAccount(player)
    if not account then return end

    local accName = getAccountName(account)
    local delivery = activeDeliveries[accName]

    if not delivery or delivery.stage ~= "pickup" then
        return
    end

    delivery.stage = "deliver"
    triggerClientEvent(player, "doordash:updateStage", player, "deliver")
    outputChatBox("[DoorDash] Yemegi aldiniz! Musteriye ulastirin.", player, 0, 255, 0)
end

addEvent("doordash:reachedPickup", true)
addEventHandler("doordash:reachedPickup", root, reachedPickup)

function completedDelivery()
    local player = source
    if not player or not isElement(player) then return end

    local account = getPlayerAccount(player)
    if not account then return end

    local accName = getAccountName(account)
    local delivery = activeDeliveries[accName]

    if not delivery or delivery.stage ~= "deliver" then
        return
    end

    local payment = delivery.offer.totalPayment
    givePlayerMoney(player, payment)

    local stats = getPlayerStats(player)
    stats.completed = stats.completed + 1
    stats.earned = stats.earned + payment
    setPlayerStats(player, stats)

    outputChatBox("[DoorDash] Teslimat tamamlandi! $" .. payment .. " kazandiniz!", player, 0, 255, 0)
    outputChatBox("[DoorDash] Toplam: " .. stats.completed .. " teslimat, $" .. stats.earned .. " kazanc", player, 0, 200, 255)

    activeDeliveries[accName] = nil
end

addEvent("doordash:completedDelivery", true)
addEventHandler("doordash:completedDelivery", root, completedDelivery)

function cancelDelivery()
    local player = source
    if not player or not isElement(player) then return end

    local account = getPlayerAccount(player)
    if not account then return end

    local accName = getAccountName(account)

    if activeDeliveries[accName] then
        activeDeliveries[accName] = nil
        outputChatBox("[DoorDash] Teslimat iptal edildi.", player, 255, 0, 0)
    end
end

addEvent("doordash:cancelDelivery", true)
addEventHandler("doordash:cancelDelivery", root, cancelDelivery)

addCommandHandler("dashstats", function(player)
    local stats = getPlayerStats(player)
    if not stats then
        outputChatBox("[DoorDash] Kayitli degilsiniz!", player, 255, 0, 0)
        return
    end

    outputChatBox("[DoorDash] Istatistikleriniz:", player, 0, 200, 255)
    outputChatBox("[DoorDash] Tamamlanan teslimat: " .. stats.completed, player, 255, 255, 255)
    outputChatBox("[DoorDash] Toplam kazanc: $" .. stats.earned, player, 255, 255, 255)
end)