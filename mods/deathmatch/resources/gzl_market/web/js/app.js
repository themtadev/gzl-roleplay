const MarketApp = (function () {
    let shopState = {
        shopType: 'market',
        name: 'RISK MARKETS',
        subtitle: 'Open 24/7 Market!',
        themeColor: '#F5FF35',
        categories: [],
        activeCategoryIndex: 0,
        cart: [],
        quantities: {}
    };

    const el = {
        viewport: document.getElementById('market-app'),
        title: document.querySelector('.market-title'),
        subtitle: document.querySelector('.market-subtitle'),
        categoryRow: document.getElementById('category-row'),
        productsGrid: document.getElementById('products-grid'),
        closeBtn: document.getElementById('cart-close-btn'),
        cartEmptyView: document.getElementById('cart-empty-view'),
        cartFilledView: document.getElementById('cart-filled-view'),
        cartTotalAmount: document.getElementById('cart-total-amount'),
        payCashBtn: document.getElementById('pay-cash-btn'),
        payCardBtn: document.getElementById('pay-card-btn'),
        toastContainer: document.getElementById('toast-container')
    };

    function init() {
        bindEvents();
        if (!window.mta && (window.location.protocol === 'file:' || window.location.search.includes('preview') || window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1')) {
            setTimeout(() => {
                openShop({
                    shopType: 'market',
                    name: 'RISK MARKETS',
                    subtitle: 'Open 24/7 Market!',
                    themeColor: '#F5FF35',
                    defaultCategory: 'general',
                    categories: [
                        {
                            id: 'tools',
                            label: 'Tools',
                            tabImage: 'cat_tools.png',
                            items: [
                                { id: 'repairkit', name: 'Repair Kit', price: 150, desc: 'Standard roadside vehicle repair toolkit.', image: 'adv_rep_kit.png' },
                                { id: 'flashlight', name: 'Flashlight', price: 35, desc: 'High lumen LED portable flashlight.', image: 'flashlight.png' }
                            ]
                        },
                        {
                            id: 'electronics',
                            label: 'Electronics',
                            tabImage: 'cat_electronics.png',
                            items: [
                                { id: 'laptop', name: 'Laptop', price: 1222, desc: 'A compact laptop. Work from anywhere, anytime.', image: 'cat_electronics.png' }
                            ]
                        },
                        {
                            id: 'general',
                            label: 'General',
                            tabImage: 'cat_general.png',
                            items: [
                                { id: 'needle', name: 'Needle', price: 5, desc: 'A small but sharp needle. Can come in handy.', image: 'item_needle.png' },
                                { id: 'wrist_watch', name: 'Wrist Watch', price: 154, desc: 'An elegant watch to keep track of time in style.', image: 'item_wrist_watch.png' },
                                { id: 'newspaper', name: 'Newspaper', price: 5, desc: 'Keep up with the latest news and events.', image: 'item_newspaper.png' },
                                { id: 'bandage', name: 'Sterile Bandage', price: 20, desc: 'Sterile medical compression bandage.', image: 'bandage.png' }
                            ]
                        },
                        {
                            id: 'fashion',
                            label: 'Fashion',
                            tabImage: 'cat_fashion.png',
                            items: [
                                { id: 'belt', name: 'Leather Belt', price: 45, desc: 'Classic black leather belt with polished metal buckle.', image: 'cat_fashion.png' }
                            ]
                        },
                        {
                            id: 'souvenirs',
                            label: 'Souvenirs',
                            tabImage: 'cat_souvenirs.png',
                            items: [
                                { id: 'postcards', name: 'Postcard Set', price: 12, desc: 'Vintage city landscape and beach postcards.', image: 'cat_souvenirs.png' }
                            ]
                        },
                        {
                            id: 'office',
                            label: 'Office',
                            tabImage: 'cat_office.png',
                            items: [
                                { id: 'notebook', name: 'Ledger Notebook', price: 22, desc: 'Hardcover lined pages journal for bookkeeping.', image: 'cat_office.png' }
                            ]
                        }
                    ]
                });
            }, 80);
        }
    }

    function bindEvents() {
        if (el.closeBtn) {
            el.closeBtn.addEventListener('click', () => {
                closeShop();
            });
        }

        if (el.payCashBtn) {
            el.payCashBtn.addEventListener('click', () => {
                checkout('cash');
            });
        }

        if (el.payCardBtn) {
            el.payCardBtn.addEventListener('click', () => {
                checkout('card');
            });
        }

        window.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                closeShop();
            }
        });

        window.addEventListener('message', (e) => {
            const data = e.data;
            if (!data) return;
            if (data.action === 'open') {
                openShop(data.shop);
            } else if (data.action === 'close') {
                closeShop(true);
            } else if (data.action === 'toast') {
                showToast(data.message, data.type || 'success');
            } else if (data.action === 'purchaseSuccess') {
                handlePurchaseSuccess(data);
            } else if (data.action === 'purchaseError') {
                handlePurchaseError(data);
            }
        });
    }

    function openShop(data) {
        if (!data) return;
        shopState.shopType = data.shopType || 'market';
        shopState.name = data.name || 'RISK MARKETS';
        shopState.subtitle = data.subtitle || 'Open 24/7 Market!';
        shopState.themeColor = data.themeColor || '#F5FF35';
        shopState.categories = data.categories || [];
        shopState.cart = [];
        shopState.quantities = {};

        shopState.activeCategoryIndex = 0;
        if (data.defaultCategory) {
            const foundIndex = shopState.categories.findIndex(c => c.id === data.defaultCategory);
            if (foundIndex !== -1) {
                shopState.activeCategoryIndex = foundIndex;
            }
        }

        if (el.title) el.title.innerText = shopState.name;
        if (el.subtitle) el.subtitle.innerText = shopState.subtitle;

        renderCategoryTabs();
        renderProducts();
        renderCart();

        if (el.viewport) el.viewport.style.display = 'flex';
        SoundEngine.playOpen();
    }

    function closeShop(skipNotify) {
        if (el.viewport) el.viewport.style.display = 'none';
        SoundEngine.playClose();
        if (!skipNotify) {
            if (window.mta && window.mta.triggerEvent) {
                window.mta.triggerEvent('gzl_market:clientClose');
            }
        }
    }

    function renderCategoryTabs() {
        if (!el.categoryRow) return;
        el.categoryRow.innerHTML = '';

        shopState.categories.forEach((cat, index) => {
            const card = document.createElement('div');
            const isActive = (index === shopState.activeCategoryIndex);
            card.className = `category-card-item ${isActive ? 'active' : ''}`;

            const iconSrc = `assets/images/${cat.tabImage || 'box.png'}`;
            card.innerHTML = `
                <div class="cat-top-strip"></div>
                <div class="cat-object-icon">
                    <img src="${iconSrc}" alt="${cat.label}" onerror="this.src='assets/images/box.png'">
                </div>
                <span class="cat-title-text">${cat.label}</span>
            `;

            card.addEventListener('click', () => {
                if (shopState.activeCategoryIndex === index) return;
                shopState.activeCategoryIndex = index;
                SoundEngine.playTab();
                document.querySelectorAll('.category-card-item').forEach(c => c.classList.remove('active'));
                card.classList.add('active');
                renderProducts();
            });

            el.categoryRow.appendChild(card);
        });
    }

    function formatPrice(num) {
        return num.toLocaleString('en-US');
    }

    function renderProducts() {
        if (!el.productsGrid) return;
        el.productsGrid.innerHTML = '';

        const currentCat = shopState.categories[shopState.activeCategoryIndex];
        if (!currentCat || !currentCat.items) return;

        currentCat.items.forEach((item) => {
            const tile = document.createElement('div');
            tile.className = 'product-tile-card';
            const imgPath = `assets/images/${item.image || 'box.png'}`;
            const curQty = shopState.quantities[item.id] || 1;
            const priceFormatted = formatPrice(item.price);

            tile.innerHTML = `
                <div class="product-render-zone">
                    <img class="product-render-img" src="${imgPath}" alt="${item.name}" onerror="this.src='assets/images/box.png'">
                </div>
                <div class="product-title-row">
                    <span class="product-heading-text" title="${item.name}">${item.name}</span>
                    <span class="product-price-tag">$ ${priceFormatted}</span>
                </div>
                <p class="product-desc-snippet" title="${item.desc}">${item.desc}</p>
                <div class="product-buy-bar">
                    <input type="number" class="product-qty-box" min="1" max="99" value="${curQty}">
                    <button class="product-buy-action">Buy</button>
                </div>
            `;

            const qtyInput = tile.querySelector('.product-qty-box');
            const buyBtn = tile.querySelector('.product-buy-action');

            qtyInput.addEventListener('change', (e) => {
                let v = parseInt(e.target.value) || 1;
                if (v < 1) v = 1;
                if (v > 99) v = 99;
                e.target.value = v;
                shopState.quantities[item.id] = v;
                SoundEngine.playQty();
            });

            buyBtn.addEventListener('click', () => {
                const qty = parseInt(qtyInput.value) || 1;
                addToCart(item, qty);
            });

            el.productsGrid.appendChild(tile);
        });
    }

    function addToCart(item, qty) {
        const found = shopState.cart.find(ci => ci.id === item.id);
        if (found) {
            found.quantity += qty;
        } else {
            shopState.cart.push({
                id: item.id,
                name: item.name,
                price: item.price,
                desc: item.desc,
                image: item.image,
                weight: item.weight || 100,
                quantity: qty
            });
        }
        SoundEngine.playAdd();
        renderCart();
    }

    function updateCartItemQty(itemId, delta) {
        const item = shopState.cart.find(ci => ci.id === itemId);
        if (!item) return;
        item.quantity += delta;
        if (item.quantity <= 0) {
            removeCartItem(itemId);
            return;
        }
        SoundEngine.playQty();
        renderCart();
    }

    function removeCartItem(itemId) {
        shopState.cart = shopState.cart.filter(ci => ci.id !== itemId);
        SoundEngine.playDelete();
        renderCart();
    }

    function renderCart() {
        if (!el.cartEmptyView || !el.cartFilledView || !el.cartTotalAmount) return;

        if (shopState.cart.length === 0) {
            el.cartEmptyView.style.display = 'flex';
            el.cartFilledView.style.display = 'none';
            el.cartFilledView.innerHTML = '';
            el.cartTotalAmount.innerText = '$ 0';
            return;
        }

        el.cartEmptyView.style.display = 'none';
        el.cartFilledView.style.display = 'flex';
        el.cartFilledView.innerHTML = '';

        let total = 0;
        shopState.cart.forEach((cartItem) => {
            const itemTotal = cartItem.price * cartItem.quantity;
            total += itemTotal;
            const imgPath = `assets/images/${cartItem.image || 'box.png'}`;

            const row = document.createElement('div');
            row.className = 'cart-item-row';
            row.innerHTML = `
                <div class="cart-thumb-box">
                    <img src="${imgPath}" alt="${cartItem.name}" onerror="this.src='assets/images/box.png'">
                </div>
                <div class="cart-info-col">
                    <div class="cart-item-header">
                        <span class="cart-item-name">${cartItem.name}</span>
                        <span class="cart-item-price">$ ${formatPrice(itemTotal)}</span>
                    </div>
                    <span class="cart-item-desc">${cartItem.desc}</span>
                </div>
                <div class="cart-controls-col">
                    <button class="cart-del-btn" title="Remove">
                        <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <polyline points="3 6 5 6 21 6"></polyline>
                            <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
                        </svg>
                    </button>
                    <div class="cart-stepper-box">
                        <button class="step-btn dec-btn">&lt;</button>
                        <span class="step-num">${cartItem.quantity}</span>
                        <button class="step-btn inc-btn">&gt;</button>
                    </div>
                </div>
            `;

            row.querySelector('.cart-del-btn').addEventListener('click', () => {
                removeCartItem(cartItem.id);
            });

            row.querySelector('.dec-btn').addEventListener('click', () => {
                updateCartItemQty(cartItem.id, -1);
            });

            row.querySelector('.inc-btn').addEventListener('click', () => {
                updateCartItemQty(cartItem.id, 1);
            });

            el.cartFilledView.appendChild(row);
        });

        el.cartTotalAmount.innerText = `$ ${formatPrice(total)}`;
    }

    function checkout(method) {
        if (shopState.cart.length === 0) {
            SoundEngine.playError();
            showToast('Your cart is empty.', 'error');
            return;
        }

        let total = 0;
        shopState.cart.forEach(ci => total += ci.price * ci.quantity);

        const payload = {
            shopType: shopState.shopType,
            method: method,
            items: shopState.cart,
            totalCost: total
        };

        if (window.mta && window.mta.triggerEvent) {
            window.mta.triggerEvent('gzl_market:requestPurchase', JSON.stringify(payload));
        } else {
            handlePurchaseSuccess({ count: shopState.cart.length, totalCost: total, method: method });
        }
    }

    function handlePurchaseSuccess(data) {
        SoundEngine.playSuccess();
        showToast(`Purchased items for $${formatPrice(data.totalCost)}!`, 'success');
        shopState.cart = [];
        renderCart();
    }

    function handlePurchaseError(data) {
        SoundEngine.playError();
        showToast(data.message || 'Transaction failed!', 'error');
    }

    function showToast(message, type = 'success') {
        if (!el.toastContainer) return;
        const toast = document.createElement('div');
        toast.className = `toast-pill ${type}`;
        toast.innerText = message;
        el.toastContainer.appendChild(toast);
        setTimeout(() => {
            if (toast.parentNode) {
                toast.parentNode.removeChild(toast);
            }
        }, 3000);
    }

    return {
        init: init,
        openShop: openShop,
        closeShop: closeShop,
        showToast: showToast,
        handlePurchaseSuccess: handlePurchaseSuccess,
        handlePurchaseError: handlePurchaseError
    };
})();

document.addEventListener('DOMContentLoaded', () => {
    MarketApp.init();
});
