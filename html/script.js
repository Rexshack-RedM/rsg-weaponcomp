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

    init() {
        // Ensure app is hidden on load
        this.hide();
        this.bindEvents();
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
                    this.updatePriceDisplay(data.price);
                    break;
                case 'notify':
                    this.showNotification(data.type, data.message);
                    break;
            }
        });
    },

    open(data) {
        
        
        // Reset state
        this.weaponData = data;
        this.selectedComponents = {};
        this.selectedLabels = {};
        this.totalPrice = 0;
        this.filteredComponents = {};
        
        // Deep copy components to avoid reference issues
        try {
            this.components = JSON.parse(JSON.stringify(data.components || {}));
            this.prices = JSON.parse(JSON.stringify(data.prices || {}));
        } catch (e) {
            this.components = {};
            this.prices = {};
        }

        // Set weapon info
        const weaponNameEl = document.getElementById('weaponName');
        const weaponSerialEl = document.getElementById('weaponSerial');
        
        if (weaponNameEl) {
            weaponNameEl.textContent = data.weaponName || 'UNKNOWN WEAPON';
        }
        if (weaponSerialEl) {
            weaponSerialEl.innerHTML = '<i class="fas fa-fingerprint"></i> Serial: #' + (data.serial || '000000');
        }

        // Build main menu
        this.buildMainMenu();
        
        // Update price display
        this.updatePriceDisplay(0);
        
        // Show UI
        this.show();
        this.showMainMenu();
        
        // Store saved components for later use
        this.savedComponents = data.savedComponents || {};
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
            { action: 'parts', icon: 'fa-wrench', label: 'Parts & Attachments' },
            { action: 'packup', icon: 'fa-box-open', label: 'Pack Up Workbench' }
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
                this.showComponentMenu('ALL PARTS & ATTACHMENTS');
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
                'No options available for this weapon.' +
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
                    '<span class="category-name">' + this.formatLabel(category) + '</span>' +
                    '<span class="category-value">' + displayName + '</span>' +
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

        // Calculate initial price with saved components
        this.calculatePrice();
        
        // Bind drag events to sliders
        this.bindSliderDragEvents();
    },

    bindSliderDragEvents() {
        const sliders = document.querySelectorAll('.slider-container');
        for (let i = 0; i < sliders.length; i++) {
            const slider = sliders[i];
            const track = slider.querySelector('.slider-track');
            const thumb = slider.querySelector('.slider-thumb');
            if (!track || !thumb) continue;

            const category = track.closest('.component-category')?.getAttribute('data-category');
            if (!category) continue;

            let isDragging = false;

            const handleDrag = (e) => {
                if (!isDragging) return;
                e.preventDefault();
                
                const rect = track.getBoundingClientRect();
                const clientX = e.type.includes('touch') ? e.touches[0].clientX : e.clientX;
                let percent = (clientX - rect.left) / rect.width;
                percent = Math.max(0, Math.min(1, percent));

                const items = this.filteredComponents[category];
                if (!items || items.length === 0) return;

                const totalItems = items.length;
                const newIndex = Math.round(percent * (totalItems - 1));

                const selectedItem = items[newIndex];
                if (!selectedItem) return;

                this.selectedComponents[category] = {
                    index: newIndex,
                    hash: selectedItem.hash,
                    name: selectedItem.name
                };
                this.selectedLabels[category] = selectedItem.label || selectedItem.name;

                this.updateSliderUI(category, newIndex, totalItems, selectedItem);
                this.calculatePrice();

                this.postToGame('componentChanged', {
                    category: category,
                    component: selectedItem.name,
                    hash: selectedItem.hash
                });
            };

            const startDrag = (e) => {
                isDragging = true;
                e.preventDefault();
                handleDrag(e);
            };

            const endDrag = () => {
                isDragging = false;
            };

            thumb.addEventListener('mousedown', startDrag);
            thumb.addEventListener('touchstart', startDrag, { passive: false });
            track.addEventListener('click', (e) => {
                const rect = track.getBoundingClientRect();
                let percent = (e.clientX - rect.left) / rect.width;
                percent = Math.max(0, Math.min(1, percent));

                const items = this.filteredComponents[category];
                if (!items || items.length === 0) return;

                const totalItems = items.length;
                const newIndex = Math.round(percent * (totalItems - 1));

                const selectedItem = items[newIndex];
                if (!selectedItem) return;

                this.selectedComponents[category] = {
                    index: newIndex,
                    hash: selectedItem.hash,
                    name: selectedItem.name
                };
                this.selectedLabels[category] = selectedItem.label || selectedItem.name;

                this.updateSliderUI(category, newIndex, totalItems, selectedItem);
                this.calculatePrice();

                this.postToGame('componentChanged', {
                    category: category,
                    component: selectedItem.name,
                    hash: selectedItem.hash
                });
            });

            document.addEventListener('mousemove', handleDrag);
            document.addEventListener('mouseup', endDrag);
            document.addEventListener('touchmove', handleDrag, { passive: false });
            document.addEventListener('touchend', endDrag);
        }
    },

    changeComponent(category, direction) {
        const items = this.filteredComponents[category];
        if (!items || items.length === 0) return;

        // Get current index
        let currentIndex = 0;
        if (this.selectedComponents[category] && typeof this.selectedComponents[category].index === 'number') {
            currentIndex = this.selectedComponents[category].index;
        }
        
        // Calculate new index
        if (direction === 'left') {
            currentIndex = currentIndex - 1;
            if (currentIndex < 0) currentIndex = items.length - 1;
        } else {
            currentIndex = currentIndex + 1;
            if (currentIndex >= items.length) currentIndex = 0;
        }

        const selectedItem = items[currentIndex];
        if (!selectedItem) return;
        
        // Store selection (simple object, no circular refs)
        this.selectedComponents[category] = {
            index: currentIndex,
            hash: selectedItem.hash,
            name: selectedItem.name
        };
        this.selectedLabels[category] = selectedItem.label || selectedItem.name;

        // Update UI
        this.updateSliderUI(category, currentIndex, items.length, selectedItem);

        // Calculate new price
        this.calculatePrice();

        // Send to game
        this.postToGame('componentChanged', {
            category: category,
            component: selectedItem.name,
            hash: selectedItem.hash
        });
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

    calculatePrice() {
        let total = 0;
        const categories = Object.keys(this.selectedComponents);
        
        for (let i = 0; i < categories.length; i++) {
            const cat = categories[i];
            // Only count if there's a valid selection (not empty/undefined)
            if (this.selectedComponents[cat] && this.selectedComponents[cat].name) {
                const price = this.prices[cat];
                if (typeof price === 'number') {
                    total += price;
                }
            }
        }
        
        this.totalPrice = total;
        this.updatePriceDisplay(total);
        
        // Send price update to game
        this.postToGame('updatePrice', { price: total });
    },

    updatePriceDisplay(price) {
        const priceEl = document.getElementById('totalPrice');
        if (priceEl) {
            const displayPrice = typeof price === 'number' ? price.toFixed(2) : '0.00';
            priceEl.textContent = '$' + displayPrice;
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
        if (this.totalPrice <= 0 || Object.keys(this.selectedComponents).length === 0) {
            this.showNotification('error', 'No modifications selected!');
            return;
        }

        // Build simple data objects (no circular refs)
        const cacheToSend = {};
        const labelsToSend = {};
        
        const keys = Object.keys(this.selectedComponents);
        for (let i = 0; i < keys.length; i++) {
            const key = keys[i];
            const sel = this.selectedComponents[key];
            cacheToSend[key] = {
                index: sel.index,
                hash: sel.hash,
                name: sel.name
            };
            labelsToSend[key] = this.selectedLabels[key] || sel.name;
        }

        this.postToGame('purchase', {
            selectedCache: cacheToSend,
            selectedLabels: labelsToSend,
            price: this.totalPrice
        });
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