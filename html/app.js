const app = document.getElementById('app');
const amountModal = document.getElementById('amountModal');

let state = {
    activeTab: 'sell',
    activeMarketCategory: 'All',
    data: {},
    pendingSale: null
};

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify(data)
    }).then((response) => response.json()).catch(() => {
        return {
            success: false,
            message: 'NUI callback failed.'
        };
    });
}

function escapeHtml(value) {
    if (value === null || value === undefined) return '';

    return String(value)
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;');
}

function showToast(message) {
    const toast = document.getElementById('toast');

    toast.textContent = message;
    toast.classList.remove('hidden');

    setTimeout(() => {
        toast.classList.add('hidden');
    }, 2600);
}

function setOpen(open) {
    app.classList.toggle('hidden', !open);

    if (!open) {
        closeAmountModal();
    }
}

function formatMoney(value) {
    if (value === 'Pending') return 'Pending';
    return `$${Number(value || 0).toLocaleString()}`;
}

function formatSeconds(seconds) {
    seconds = Math.max(0, Number(seconds || 0));

    const minutes = Math.floor(seconds / 60);
    const secs = seconds % 60;

    return `${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
}

function setTab(tab) {
    state.activeTab = tab;

    document.querySelectorAll('.tab').forEach((button) => {
        button.classList.toggle('active', button.dataset.tab === tab);
    });

    document.querySelectorAll('.action-card[data-tab]').forEach((button) => {
        button.classList.toggle('active', button.dataset.tab === tab);
    });

    document.querySelectorAll('.panel').forEach((panel) => {
        panel.classList.remove('active');
    });

    const panel = document.getElementById(`${tab}Panel`);

    if (panel) {
        panel.classList.add('active');
    }
}

function setData(payload) {
    state.data = payload || {};

    const rep = state.data.rep || {};
    const script = state.data.script || {};
    const cooldowns = state.data.cooldowns || {};
    const statusText = state.data.statusText || {};

    document.getElementById('scriptName').textContent = script.name || 'Distortionz Underground';
    document.getElementById('scriptVersion').textContent = `v${script.version || 'Unknown'}`;
    document.getElementById('uiTitle').textContent = 'Underground Contact';

    const repValue = Number(rep.value || 0);
    const repLevel = Number(rep.level || 0);
    const repNeeded = 500;
    const currentLevelRep = repValue % repNeeded;
    const repPercent = Math.max(0, Math.min(100, (currentLevelRep / repNeeded) * 100));

    document.getElementById('repText').textContent = `Rep: ${rep.label || 'Unknown'} (${repValue}) · Level ${repLevel}`;
    document.getElementById('repFill').style.width = `${repPercent}%`;
    document.getElementById('repNext').textContent = `Next Level: ${repNeeded - currentLevelRep} rep`;

    document.getElementById('sellStatus').textContent = statusText.sell || 'Ready to sell valuables.';
    document.getElementById('deliveryStatus').textContent = statusText.delivery || 'Ready for work.';
    document.getElementById('blackMarketStatus').textContent = statusText.blackmarket || 'Market is open.';

    const hasActiveDelivery = state.data.activeDelivery === true;
    const deliveryOnCooldown = Number(cooldowns.delivery || 0) > 0;

    document.getElementById('cancelDeliveryBtn').classList.toggle('disabled', !hasActiveDelivery);
    document.getElementById('cancelStatus').textContent = hasActiveDelivery ? 'Cancel your current job.' : 'No active delivery.';
    document.getElementById('deliveryBtn').classList.toggle('disabled', hasActiveDelivery || deliveryOnCooldown || state.data.busy === true);

    renderSellItems();
    renderBlackMarketCategories();
    renderBlackMarketItems();
    renderDeliveryPanel();
}

function renderSellItems() {
    const container = document.getElementById('sellItems');
    const items = Array.isArray(state.data.sellItems) ? state.data.sellItems : [];

    if (!items.length) {
        container.innerHTML = `
            <div class="item-row empty">
                <div>
                    <h4>No sellable items configured.</h4>
                    <p>Check config.lua.</p>
                </div>
            </div>
        `;
        return;
    }

    container.innerHTML = items.map((item) => {
        const owned = Number(item.owned || 0);
        const disabled = owned <= 0;

        return `
            <div class="item-row ${disabled ? 'empty' : ''}">
                <div>
                    <h4>${escapeHtml(item.label)}</h4>
                    <p>Owned: ${owned} · ${formatMoney(item.minPrice)} - ${formatMoney(item.maxPrice)} each ${item.highValue ? '· High value' : ''}</p>
                </div>

                <button class="btn primary" ${disabled ? 'disabled' : ''} onclick="openSellModal('${escapeHtml(item.name)}')">
                    Sell
                </button>
            </div>
        `;
    }).join('');
}

function getMarketCategories() {
    const items = Array.isArray(state.data.blackMarketItems) ? state.data.blackMarketItems : [];
    const categories = ['All'];

    items.forEach((item) => {
        const category = item.category || 'General';

        if (!categories.includes(category)) {
            categories.push(category);
        }
    });

    return categories;
}

function renderBlackMarketCategories() {
    const container = document.getElementById('blackMarketCategories');
    const categories = getMarketCategories();

    if (!categories.includes(state.activeMarketCategory)) {
        state.activeMarketCategory = 'All';
    }

    container.innerHTML = categories.map((category) => {
        return `
            <button class="category-tab ${state.activeMarketCategory === category ? 'active' : ''}" onclick="setMarketCategory('${escapeHtml(category)}')">
                ${escapeHtml(category)}
            </button>
        `;
    }).join('');
}

function setMarketCategory(category) {
    state.activeMarketCategory = category || 'All';

    renderBlackMarketCategories();
    renderBlackMarketItems();
}

function renderBlackMarketItems() {
    const container = document.getElementById('blackMarketItems');
    const items = Array.isArray(state.data.blackMarketItems) ? state.data.blackMarketItems : [];
    const cooldowns = state.data.cooldowns || {};
    const blackMarketCooldown = Number(cooldowns.blackmarket || 0) > 0;

    const filteredItems = state.activeMarketCategory === 'All'
        ? items
        : items.filter((item) => (item.category || 'General') === state.activeMarketCategory);

    if (!filteredItems.length) {
        container.innerHTML = `
            <div class="item-row empty">
                <div>
                    <h4>No black market items found.</h4>
                    <p>Check config.lua or switch category.</p>
                </div>
            </div>
        `;
        return;
    }

    container.innerHTML = filteredItems.map((item) => {
        const disabled = item.locked || blackMarketCooldown;
        const info = item.locked
            ? `Locked · Required Level ${item.requiredLevel}`
            : `${formatMoney(item.price)} · Amount: ${item.amount} · Required Level ${item.requiredLevel}`;

        return `
            <div class="item-row ${disabled ? 'locked' : ''}">
                <div>
                    <h4>${item.locked ? '🔒 ' : ''}${escapeHtml(item.label)}</h4>
                    <p>${escapeHtml(info)}</p>
                </div>

                <button class="btn primary" ${disabled ? 'disabled' : ''} onclick="buyBlackMarket('${escapeHtml(item.name)}')">
                    Buy
                </button>
            </div>
        `;
    }).join('');
}

function renderDeliveryPanel() {
    const hasActiveDelivery = state.data.activeDelivery === true;
    const delivery = state.data.delivery || {};
    const cooldowns = state.data.cooldowns || {};
    const cooldown = Number(cooldowns.delivery || 0);

    document.getElementById('deliveryTitle').textContent = hasActiveDelivery ? `Active: ${delivery.label || 'Package'}` : 'No Active Delivery';

    document.getElementById('deliveryInfo').textContent = hasActiveDelivery
        ? `Time left: ${formatSeconds(delivery.secondsLeft || 0)}. Follow the GPS and hand it off.`
        : cooldown > 0
            ? `No work right now. Cooldown: ${formatSeconds(cooldown)}.`
            : 'Start a suspicious delivery and follow the GPS drop-off.';

    document.getElementById('deliveryDifficulty').textContent = delivery.difficulty || (hasActiveDelivery ? 'Medium' : 'Unknown');
    document.getElementById('deliveryPayout').textContent = formatMoney(delivery.payout || 0);
    document.getElementById('deliveryState').textContent = hasActiveDelivery ? 'Active' : cooldown > 0 ? 'Cooldown' : 'Ready';

    document.getElementById('deliveryStartPanelBtn').disabled = hasActiveDelivery || cooldown > 0 || state.data.busy === true;
    document.getElementById('deliveryCancelPanelBtn').disabled = !hasActiveDelivery;
}

function openSellModal(itemName) {
    const item = (state.data.sellItems || []).find((entry) => entry.name === itemName);

    if (!item) return;

    state.pendingSale = item;

    document.getElementById('amountTitle').textContent = `Sell ${item.label}`;
    document.getElementById('amountDescription').textContent = `You have ${item.owned}. Price range: ${formatMoney(item.minPrice)} - ${formatMoney(item.maxPrice)} each.`;
    document.getElementById('amountInput').value = '1';
    document.getElementById('amountInput').max = String(item.owned || 1);

    amountModal.classList.remove('hidden');
}

function closeAmountModal() {
    state.pendingSale = null;
    amountModal.classList.add('hidden');
}

async function confirmSell() {
    if (!state.pendingSale) return;

    const amount = Math.floor(Number(document.getElementById('amountInput').value || 0));

    if (!amount || amount <= 0) {
        showToast('Enter a valid amount.');
        return;
    }

    if (amount > Number(state.pendingSale.owned || 0)) {
        showToast('You do not have that many.');
        return;
    }

    await post('sellItem', {
        item: state.pendingSale.name,
        amount
    });
}

async function buyBlackMarket(itemName) {
    await post('buyBlackMarketItem', {
        item: itemName
    });
}

async function startDelivery() {
    const cooldowns = state.data.cooldowns || {};

    if (state.data.activeDelivery === true || Number(cooldowns.delivery || 0) > 0 || state.data.busy === true) {
        showToast('Delivery is not available right now.');
        return;
    }

    await post('startDelivery');
}

async function cancelDelivery() {
    if (state.data.activeDelivery !== true) {
        showToast('No active delivery.');
        return;
    }

    await post('cancelDelivery');
}

window.openSellModal = openSellModal;
window.buyBlackMarket = buyBlackMarket;
window.setMarketCategory = setMarketCategory;

document.querySelectorAll('.tab').forEach((button) => {
    button.addEventListener('click', () => setTab(button.dataset.tab));
});

document.querySelectorAll('.action-card[data-tab]').forEach((button) => {
    button.addEventListener('click', () => setTab(button.dataset.tab));
});

document.getElementById('closeBtn').addEventListener('click', () => post('close'));
document.getElementById('refreshBtn').addEventListener('click', () => post('refreshData'));
document.getElementById('deliveryBtn').addEventListener('click', startDelivery);
document.getElementById('deliveryStartPanelBtn').addEventListener('click', startDelivery);
document.getElementById('cancelDeliveryBtn').addEventListener('click', cancelDelivery);
document.getElementById('deliveryCancelPanelBtn').addEventListener('click', cancelDelivery);
document.getElementById('streetWorkBtn').addEventListener('click', () => post('streetWork'));
document.getElementById('amountCloseBtn').addEventListener('click', closeAmountModal);
document.getElementById('confirmSellBtn').addEventListener('click', confirmSell);

document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') return;

    if (!amountModal.classList.contains('hidden')) {
        closeAmountModal();
        return;
    }

    post('close');
});

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') {
        setOpen(true);
        setData(data.payload || {});
        setTab('sell');
    }

    if (data.action === 'setData') {
        setData(data.payload || {});
    }

    if (data.action === 'openSell') {
        setOpen(true);
        setData(data.payload || {});
        setTab('sell');
    }

    if (data.action === 'openBlackMarket') {
        setOpen(true);
        setData(data.payload || {});
        setTab('blackmarket');
    }

    if (data.action === 'close') {
        setOpen(false);
    }
});