// Wild West Gunsmith UI
const App = {
    visible: false,
    currentMenu: 'main',
    weaponData: null,
    components: {},
    filteredComponents: {},
    selectedComponents: {},
    selectedLabels: {},
    savedComponents: {},
    prices: {},
    totalPrice: 0,
    hasChanges: false,
    categoryLabels: {},
    drag: null,
    autoFocus: true,

    init() {
        // Ensure app is hidden on load
        this.hide();
        this.bindEvents();
        this.bindTrackEvents();
        this.listenToGame();
        
    },

    bindEvents() {
        // Main menu items - use event delegation
        const mainMenuItems = document.getElementById('mainMenuItems');
        if (mainMenuItems) {
            mainMenuItems.addEventListener('click', (e) => {
                const item = e.target.closest('.menu-item');
                if (item && item.dataset.action) {
                    this.handleMenuClick(item.dataset.action);
                }
            });
        }

        // Back button
        const btnBack = document.getElementById('btnBack');
        if (btnBack) {
            btnBack.addEventListener('click', () => this.showMainMenu());
        }

        // Purchase button
        const btnPurchase = document.getElementById('btnPurchase');
        if (btnPurchase) {
            btnPurchase.addEventListener('click', () => this.purchase());
        }

        // Reset button
        const btnReset = document.getElementById('btnReset');
        if (btnReset) {
            btnReset.addEventListener('click', () => this.reset());
        }

        // Auto focus toggle
        const btnFocus = document.getElementById('btnFocus');
        if (btnFocus) {
            btnFocus.addEventListener('click', () => {
                this.setAutoFocus(!this.autoFocus);
                this.postToGame('setAutoFocus', { enabled: this.autoFocus });
            });
        }

        // Exit button
        const btnExit = document.getElementById('btnExit');
        if (btnExit) {
            btnExit.addEventListener('click', () => this.close());
        }

        // Prevent scroll wheel from being captured by browser - let game handle zoom
        document.addEventListener('wheel', (e) => {
            if (this.visible) {
                e.preventDefault();
                e.stopPropagation();
            }
        }, { passive: false });

        // Keyboard events
        document.addEventListener('keydown', (e) => {
            if (this.visible) {
                // Allow camera control keys (C, V) to pass through to game
                if (e.key === 'c' || e.key === 'C' || e.key === 'v' || e.key === 'V') {
                    // Don't prevent default - let game handle camera controls
                    return;
                }
                
                // Handle ESC for menu navigation
                if (e.key === 'Escape') {
                    e.preventDefault();
                    if (this.currentMenu !== 'main') {
                        this.showMainMenu();
                    } else {
                        this.close();
                    }
                }
            }
        });
    },

    listenToGame() {
        window.addEventListener('message', (event) => {
            const data = event.data;
            if (!data || !data.action) return;
            
            switch (data.action) {
                case 'open':
                    this.open(data);
                    break;
                case 'close':
                    this.hide();
                    break;
                case 'updatePrice':
                    this.totalPrice = Number(data.price) || 0;
                    this.hasChanges = !!data.changed;
                    this.updatePriceDisplay(this.totalPrice);
                    break;
                case 'notify':
                    this.showNotification(data.type, data.message);
                    break;
            }
        });
    },

    locales: {},

    // All UI text comes from the locale files (sent by the client on open)
    t(key) {
        return (this.locales && this.locales[key]) || key;
    },

    applyLocales() {
        document.querySelectorAll('[data-i18n]').forEach((el) => {
            const key = el.getAttribute('data-i18n');
            if (this.locales[key]) el.textContent = this.locales[key];
        });
    },

    open(data) {
        if (data.locales) {
            this.locales = data.locales;
            this.applyLocales();
        }
        
        
        // Reset state
        this.weaponData = data;
        this.selectedComponents = {};
        this.selectedLabels = {};
        this.totalPrice = 0;
        this.hasChanges = false;
        this.filteredComponents = {};
        this.savedComponents = data.savedComponents || {};

        // Components arrive as an ordered array of { category, label, items }
        this.components = {};
        this.categoryLabels = {};
        const list = Array.isArray(data.components) ? data.components : [];
        for (let i = 0; i < list.length; i++) {
            const entry = list[i];
            if (!entry || !entry.category || !Array.isArray(entry.items)) continue;
            this.components[entry.category] = entry.items;
            this.categoryLabels[entry.category] = entry.label || entry.category;
        }
        this.prices = data.prices || {};
        this.setAutoFocus(data.autoFocus !== false);

        // Set weapon info
        const weaponNameEl = document.getElementById('weaponName');
        const weaponSerialEl = document.getElementById('weaponSerial');
        
        if (weaponNameEl) {
            weaponNameEl.textContent = data.weaponName || this.t('ui_unknown_weapon');
        }
        if (weaponSerialEl) {
            weaponSerialEl.innerHTML = '<i class="fas fa-fingerprint"></i> ' + this.escape(this.t('ui_serial')) + ': #' + this.escape(data.serial || '000000');
        }

        // Build main menu
        this.buildMainMenu();
        
        // Update price display
        this.updatePriceDisplay(0);
        
        // Show UI
        this.show();
        this.showMainMenu();
    },

    show() {
        const app = document.getElementById('app');
        if (app) {
            app.classList.remove('hidden');
            app.style.display = 'flex';
        }
        this.visible = true;
       
    },

    hide() {
        const app = document.getElementById('app');
        if (app) {
            app.classList.add('hidden');
            app.style.display = 'none';
        }
        this.visible = false;
        this.currentMenu = 'main';
       
    },

    close() {
        this.hide();
        this.postToGame('closeUI', {});
    },

    postToGame(endpoint, data) {
        const resourceName = typeof GetParentResourceName === 'function' 
            ? GetParentResourceName() 
            : 'rsg-weaponcomp';
            
        fetch('https://' + resourceName + '/' + endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {})
        }).catch(function(err) {
           
        });
    },

    buildMainMenu() {
        const menuItems = [
            { action: 'parts', icon: 'fa-wrench', label: this.t('ui_parts') },
            { action: 'packup', icon: 'fa-box-open', label: this.t('ui_packup') }
        ];

        const container = document.getElementById('mainMenuItems');
        if (!container) return;
        
        let html = '';
        for (let i = 0; i < menuItems.length; i++) {
            const item = menuItems[i];
            html += '<div class="menu-item" data-action="' + item.action + '">' +
                '<span class="menu-item-icon"><i class="fas ' + item.icon + '"></i></span>' +
                '<span class="menu-item-label">' + item.label + '</span>' +
                '<span class="menu-item-arrow"><i class="fas fa-chevron-right"></i></span>' +
            '</div>';
        }
        container.innerHTML = html;
    },

    handleMenuClick(action) {
        switch (action) {
            case 'parts':
                this.showComponentMenu(this.t('ui_all_parts'));
                break;
            case 'packup':
                this.packup();
                break;
        }
    },

    showMainMenu() {
        const mainMenu = document.getElementById('mainMenu');
        const componentMenu = document.getElementById('componentMenu');
        
        if (mainMenu) mainMenu.classList.remove('hidden');
        if (componentMenu) componentMenu.classList.add('hidden');
        
        this.currentMenu = 'main';
    },

    showComponentMenu(title) {
        const mainMenu = document.getElementById('mainMenu');
        const componentMenu = document.getElementById('componentMenu');
        const menuTitle = document.getElementById('componentMenuTitle');
        
        if (mainMenu) mainMenu.classList.add('hidden');
        if (componentMenu) componentMenu.classList.remove('hidden');
        if (menuTitle) menuTitle.textContent = title;
        
        this.currentMenu = 'parts';

        // Use all components, no filtering
        this.filteredComponents = this.getAllComponents();
        this.buildComponentList();
    },

    getAllComponents() {
        const result = {};
        const components = this.components;
        
        if (!components || typeof components !== 'object') {
            return result;
        }
        
        const keys = Object.keys(components);
        
        for (let i = 0; i < keys.length; i++) {
            const category = keys[i];
            const items = components[category];
            
            if (!items || !Array.isArray(items) || items.length === 0) {
                continue;
            }
            
            // Deep copy the items array
            result[category] = [];
            for (let j = 0; j < items.length; j++) {
                result[category].push({
                    name: items[j].name || '',
                    hash: items[j].hash || 0,
                    label: items[j].label || items[j].name || ''
                });
            }
        }
        
        return result;
    },

    buildComponentList() {
        const container = document.getElementById('componentList');
        if (!container) return;
        
        const categories = Object.keys(this.filteredComponents);
        
        if (categories.length === 0) {
            container.innerHTML = '<div class="component-category">' +
                '<p style="text-align: center; color: var(--text-dim);">' +
                this.t('ui_no_options') +
                '</p></div>';
            return;
        }

        let html = '';
        
        for (let i = 0; i < categories.length; i++) {
            const category = categories[i];
            const items = this.filteredComponents[category];
            
            if (!items || items.length === 0) continue;
            
            // Find the correct index based on saved components
            let currentIndex = 0;
            const savedCompName = this.savedComponents ? this.savedComponents[category] : null;
            
            if (savedCompName) {
                // Find the index of the saved component
                for (let j = 0; j < items.length; j++) {
                    if (items[j].name === savedCompName) {
                        currentIndex = j;
                        break;
                    }
                }
            }
            
            // Store selected component data
            this.selectedComponents[category] = {
                index: currentIndex,
                hash: items[currentIndex] ? items[currentIndex].hash : 0,
                name: items[currentIndex] ? items[currentIndex].name : ''
            };
            this.selectedLabels[category] = items[currentIndex] ? (items[currentIndex].label || items[currentIndex].name) : '';
            
            const currentItem = items[currentIndex] || items[0];
            const displayName = this.formatLabel(currentItem.label || currentItem.name || category);
            const progress = ((currentIndex + 1) / items.length) * 100;
            
            html += '<div class="component-category" data-category="' + category + '" data-index="' + currentIndex + '">' +
                '<div class="category-header">' +
                    '<span class="category-name">' + this.escape(this.categoryLabels[category] || this.formatLabel(category)) + '</span>' +
                    '<span class="category-value">' + this.escape(displayName) + '</span>' +
                '</div>' +
                '<div class="slider-container">' +
                    '<button class="slider-btn left" data-cat="' + category + '" data-dir="left"><i class="fas fa-chevron-left"></i></button>' +
                    '<div class="slider-track">' +
                        '<div class="slider-fill" style="width: ' + progress + '%"></div>' +
                        '<div class="slider-thumb" style="left: ' + progress + '%"></div>' +
                    '</div>' +
                    '<button class="slider-btn right" data-cat="' + category + '" data-dir="right"><i class="fas fa-chevron-right"></i></button>' +
                '</div>' +
            '</div>';
        }
        
        container.innerHTML = html;

        // Bind slider button events
        const buttons = container.querySelectorAll('.slider-btn');
        for (let i = 0; i < buttons.length; i++) {
            const btn = buttons[i];
            btn.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                const cat = btn.getAttribute('data-cat');
                const dir = btn.getAttribute('data-dir');
                if (cat && dir) {
                    this.changeComponent(cat, dir);
                }
            });
        }

    },

    selectIndex(category, newIndex) {
        const items = this.filteredComponents[category];
        if (!items || !items[newIndex]) return;
        const current = this.selectedComponents[category];
        if (current && current.index === newIndex) return;

        const selectedItem = items[newIndex];
        this.selectedComponents[category] = { index: newIndex, hash: selectedItem.hash, name: selectedItem.name };
        this.selectedLabels[category] = selectedItem.label || selectedItem.name;
        this.updateSliderUI(category, newIndex, items.length, selectedItem);
        this.postToGame('componentChanged', { category: category, component: selectedItem.name });
    },

    indexFromPointer(track, clientX, category) {
        const items = this.filteredComponents[category];
        if (!items || items.length === 0) return -1;
        const rect = track.getBoundingClientRect();
        const percent = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width));
        return Math.round(percent * (items.length - 1));
    },

    bindTrackEvents() {
        const list = document.getElementById('componentList');
        if (!list) return;
        const pointX = (e) => (e.touches && e.touches[0] ? e.touches[0].clientX : e.clientX);

        const start = (e) => {
            const track = e.target.closest('.slider-track');
            if (!track) return;
            const category = track.closest('.component-category')?.getAttribute('data-category');
            if (!category) return;
            e.preventDefault();
            this.drag = { track, category };
            this.selectIndex(category, this.indexFromPointer(track, pointX(e), category));
        };
        const move = (e) => {
            if (!this.drag) return;
            e.preventDefault();
            this.selectIndex(this.drag.category, this.indexFromPointer(this.drag.track, pointX(e), this.drag.category));
        };
        const end = () => { this.drag = null; };

        list.addEventListener('mousedown', start);
        list.addEventListener('touchstart', start, { passive: false });
        document.addEventListener('mousemove', move);
        document.addEventListener('touchmove', move, { passive: false });
        document.addEventListener('mouseup', end);
        document.addEventListener('touchend', end);
    },

    setAutoFocus(enabled) {
        this.autoFocus = !!enabled;
        const btn = document.getElementById('btnFocus');
        const state = document.getElementById('focusState');
        if (btn) btn.classList.toggle('active', this.autoFocus);
        if (state) state.textContent = this.autoFocus ? this.t('ui_on') : this.t('ui_off');
    },

    escape(str) {
        return String(str == null ? '' : str).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    },

    changeComponent(category, direction) {
        const items = this.filteredComponents[category];
        if (!items || items.length === 0) return;
        const current = this.selectedComponents[category] ? this.selectedComponents[category].index : 0;
        const step = direction === 'left' ? -1 : 1;
        this.selectIndex(category, (current + step + items.length) % items.length);
    },

    updateSliderUI(category, currentIndex, totalItems, selectedItem) {
        const categoryEl = document.querySelector('.component-category[data-category="' + category + '"]');
        if (!categoryEl) return;
        
        const displayName = this.formatLabel(selectedItem.label || selectedItem.name);
        const progress = ((currentIndex + 1) / totalItems) * 100;
        
        const valueEl = categoryEl.querySelector('.category-value');
        const fillEl = categoryEl.querySelector('.slider-fill');
        const thumbEl = categoryEl.querySelector('.slider-thumb');
        
        if (valueEl) valueEl.textContent = displayName;
        if (fillEl) fillEl.style.width = progress + '%';
        if (thumbEl) thumbEl.style.left = progress + '%';
        
        categoryEl.setAttribute('data-index', currentIndex);
    },

    updatePriceDisplay(price) {
        const priceEl = document.getElementById('totalPrice');
        if (priceEl) {
            const displayPrice = typeof price === 'number' ? price.toFixed(2) : '0.00';
            priceEl.textContent = this.t('ui_currency') + displayPrice;
        }
    },

    formatLabel(str) {
        if (!str || typeof str !== 'string') return '';
        
        // Replace underscores with spaces
        let result = str.replace(/_/g, ' ');
        
        // Capitalize first letter of each word
        result = result.replace(/\b\w/g, function(l) { 
            return l.toUpperCase(); 
        });
        
        // Remove common prefixes
        result = result.replace(/^Weapon /i, '');
        result = result.replace(/^Component /i, '');
        
        return result;
    },

    purchase() {
        if (!this.hasChanges) {
            this.showNotification('error', this.t('ui_no_mods_selected'));
            return;
        }
        this.postToGame('purchase', {});
    },

    reset() {
        this.postToGame('resetWeapon', {});
    },

    packup() {
        this.postToGame('packup', {});
    },

    showNotification(type, message) {
        fetch('https://' + (typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-weaponcomp') + '/notify', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ type: type, message: message })
        }).catch(() => {});
    }
};

// Initialize when DOM is ready
(function() {
    function init() {
        App.init();
    }
    
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
    
    // Also ensure hidden on window load
    window.addEventListener('load', function() {
        if (!App.visible) {
            App.hide();
        }
    });
})();