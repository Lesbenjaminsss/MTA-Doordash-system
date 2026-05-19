let currentOffer = null;
let offerTimer = null;
let offerTimeLeft = 30;

function sendToMTA(action, data) {
    if (window.mta && typeof mta.triggerEvent === 'function') {
        mta.triggerEvent('doordash:phoneEvent', action, JSON.stringify(data || {}));
    } else {
        console.log('MTA event:', action, data);
    }
}

function initDoorDash() {
    updateTime();
    setInterval(updateTime, 1000);
    showWaitingScreen();
}

function updateTime() {
    const now = new Date();
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const el = document.getElementById('currentTime');
    if (el) el.textContent = hours + ':' + minutes;
}

function showScreen(screenId) {
    document.querySelectorAll('.screen').forEach(function(s) {
        s.classList.add('hidden');
    });
    var target = document.getElementById(screenId);
    if (target) target.classList.remove('hidden');
}

function showWaitingScreen() {
    showScreen('waitingScreen');
}

function showOfferScreen() {
    showScreen('offerScreen');
}

function showActiveScreen() {
    showScreen('activeScreen');
}

function showOffer(offer) {
    currentOffer = offer;

    var foodEl = document.getElementById('offerFood');
    if (foodEl) foodEl.textContent = offer.food;

    var restEl = document.getElementById('offerRestaurant');
    if (restEl) restEl.textContent = offer.restaurant.name;

    var custEl = document.getElementById('offerCustomer');
    if (custEl) custEl.textContent = offer.customerName;

    var distEl = document.getElementById('offerDistance');
    if (distEl) distEl.textContent = (offer.distance / 100).toFixed(1) + ' km';

    var payEl = document.getElementById('offerPayment');
    if (payEl) payEl.textContent = '$' + offer.payment;

    var tipEl = document.getElementById('offerTip');
    if (tipEl) tipEl.textContent = '$' + offer.tip;

    var totalEl = document.getElementById('offerTotal');
    if (totalEl) totalEl.textContent = '$' + offer.totalPayment;

    startOfferTimer();
    showOfferScreen();
}

function startOfferTimer() {
    offerTimeLeft = 30;
    var timerEl = document.getElementById('offerTimer');
    if (timerEl) timerEl.textContent = offerTimeLeft + 's';

    if (offerTimer) clearInterval(offerTimer);

    offerTimer = setInterval(function() {
        offerTimeLeft--;
        var timerEl = document.getElementById('offerTimer');
        if (timerEl) timerEl.textContent = offerTimeLeft + 's';

        if (offerTimeLeft <= 0) {
            clearInterval(offerTimer);
            declineOffer();
        }
    }, 1000);
}

function acceptOffer() {
    if (offerTimer) clearInterval(offerTimer);
    sendToMTA('accept', currentOffer);
}

function declineOffer() {
    if (offerTimer) clearInterval(offerTimer);
    sendToMTA('decline');
    showWaitingScreen();
}

function requestNewOffer() {
    sendToMTA('requestNew');
    showWaitingScreen();
}

function cancelDelivery() {
    sendToMTA('cancel');
    showWaitingScreen();
}

function closePhone() {
    sendToMTA('close');
}

function updateActiveDelivery(stage) {
    var stagePickup = document.getElementById('stagePickup');
    var stageDeliver = document.getElementById('stageDeliver');
    var stageLine = document.querySelector('.stage-line');
    var activeStatus = document.getElementById('activeStatus');

    if (stage === 'pickup') {
        if (stagePickup) stagePickup.className = 'stage active';
        if (stageDeliver) stageDeliver.className = 'stage';
        if (stageLine) stageLine.className = 'stage-line';
        if (activeStatus) activeStatus.textContent = 'Restorana gidin...';
    } else if (stage === 'deliver') {
        if (stagePickup) stagePickup.className = 'stage completed';
        if (stageDeliver) stageDeliver.className = 'stage active';
        if (stageLine) stageLine.className = 'stage-line active';
        if (activeStatus) activeStatus.textContent = 'Musteriye ulastirin...';
    }

    if (currentOffer) {
        var payEl = document.getElementById('activePayment');
        if (payEl) payEl.textContent = '$' + currentOffer.totalPayment;
    }

    showActiveScreen();
}

window.showOffer = showOffer;
window.updateActiveDelivery = updateActiveDelivery;
window.initDoorDash = initDoorDash;
