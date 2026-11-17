// Wild West Gunsmith UI
const App = {
    visible: false,
    currentMenu: 'main',
    weaponData: null,
    components: {},
    filteredComponents: {},
    selectedComponents: {},
    savedComponents: {},
    prices: {},
    totalPrice: 0,
    hasChanges: false,
    categoryLabels: {},
    drag: null,
    autoFocus: true,
    canAfford: true,
    features: {},
    currentSel: {},
    price: {},
    comparing: false,
    presets: [],
    subKind: null,

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
                if (item && item.classList.contains('disabled')) return;
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

        // Edit tools
        const on = (id, fn) => { const el = document.getElementById(id); if (el) el.addEventListener('click', fn); };
        on('btnUndo', () => this.postToGame('undo', {}));
        on('btnRedo', () => this.postToGame('redo', {}));
        on('btnCompare', () => {
            this.comparing = !this.comparing;
            this.updateTools();
            this.postToGame('compare', { on: this.comparing });
        });
        on('btnRevert', () => this.postToGame('revert', {}));
        on('btnSubBack', () => this.showMainMenu());

        // Text inputs: while typing the game must not receive the keys
        const sub = document.getElementById('subMenuBody');
        if (sub) {
            sub.addEventListener('focusin', (e) => { if (e.target.tagName === 'INPUT') this.postToGame('inputFocus', { focused: true }); });
            sub.addEventListener('focusout', (e) => { if (e.target.tagName === 'INPUT') this.postToGame('inputFocus', { focused: false }); });
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
                    const modals = ['purchaseModal', 'confirmModal'];
                    for (const id of modals) {
                        const m = document.getElementById(id);
                        if (m && !m.classList.contains('hidden')) {
                            m.classList.add('hidden');
                            return;
                        }
                    }
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
                    this.price = data;
                    this.totalPrice = Number(data.price) || 0;
                    this.hasChanges = !!data.changed;
                    this.canAfford = data.canAfford !== false;
                    this.comparing = !!data.comparing;
                    this.updatePriceDisplay(this.totalPrice);
                    this.updateTools();
                    break;
                case 'selection':
                    this.applySelection(data.selected);
                    break;
                case 'presets':
                    this.presets = Array.isArray(data.list) ? data.list : [];
                    if (this.subKind === 'presets') this.renderPresets();
                    break;
                case 'identity':
                    if (this.features.identity && data.identity) {
                        this.features.identity.name = data.identity.name || '';
                        this.features.identity.engraving = data.identity.engraving || '';
                        if (this.subKind === 'identity') this.renderIdentity();
                    }
                    break;
                case 'access':
                    this.features.access = data.access || this.features.access;
                    this.buildMainMenu();
                    break;
                case 'notify':
                    this.showNotification(data.type, data.message);
                    break;
                case 'updateCondition':
                    this.setCondition(data.condition);
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
        this.totalPrice = 0;
        this.hasChanges = false;
        this.canAfford = true;
        this.filteredComponents = {};
        this.savedComponents = (data.savedComponents && !Array.isArray(data.savedComponents)) ? data.savedComponents : {};
        this.currentSel = Object.assign({}, this.savedComponents);
        this.features = data.features || {};
        ['locked', 'materials'].forEach((k) => { if (Array.isArray(this.features[k])) this.features[k] = {}; });
        this.price = {};
        this.comparing = false;
        this.presets = [];
        this.subKind = null;

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
        this.setCondition(data.condition);
        this.setAutoFocus(data.autoFocus !== false);

        // Set weapon info
        const weaponNameEl = document.getElementById('weaponName');
        const weaponSerialEl = document.getElementById('weaponSerial');
        
        if (weaponNameEl) {
            weaponNameEl.textContent = data.weaponName || this.t('ui_unknown_weapon');
        }
        if (weaponSerialEl) {
            weaponSerialEl.innerHTML = '<i class="fas fa-fingerprint"></i> ' + this.escape(this.t('ui_serial')) + ': #' + this.escape(data.serial || '000000');
            const sk = this.features && this.features.skill;
            if (sk) weaponSerialEl.innerHTML += ' &middot; ' + this.escape(this.t('ui_skill') + ' ' + this.t('ui_level') + ' ' + sk.level);
        }

        // Build main menu
        this.buildMainMenu();
        
        // Update price display
        this.updatePriceDisplay(0);
        this.updateTools();
        
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
        ['confirmModal', 'purchaseModal'].forEach((id) => {
            const m = document.getElementById(id);
            if (m) m.classList.add('hidden');
        });
        this.subKind = null;
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

    setCondition(c) {
        c = c || {};
        this.condition = c;
        const setBar = (fillId, valueId, pct) => {
            pct = Math.max(0, Math.min(100, Math.round(Number(pct) || 0)));
            const fill = document.getElementById(fillId);
            const val = document.getElementById(valueId);
            if (fill) {
                fill.style.width = pct + '%';
                fill.className = 'stat-fill ' + (pct >= 70 ? 'stat-good' : pct >= 35 ? 'stat-warn' : 'stat-bad');
            }
            if (val) val.textContent = pct + '%';
        };
        setBar('qualityFill', 'qualityValue', c.quality == null ? 100 : c.quality);
        setBar('cleanFill', 'cleanValue', c.cleanliness == null ? 100 : c.cleanliness);
        this.buildMainMenu();
    },

    buildMainMenu() {
        const c = this.condition || {};
        const menuItems = [
            { action: 'parts', icon: 'fa-wrench', label: this.t('ui_parts') }
        ];
        if (c.hasOil) {
            menuItems.push({ action: 'oil', icon: 'fa-oil-can', label: this.t('ui_clean_oil'), badge: 'x' + (c.oilCount || 0),
                disabled: !c.oilCount || (c.cleanliness != null && c.cleanliness >= 100) });
        }
        if (c.hasKit) {
            menuItems.push({ action: 'repair', icon: 'fa-screwdriver-wrench', label: this.t('ui_repair_kit'), badge: 'x' + (c.kitCount || 0),
                disabled: !c.kitCount || (c.quality != null && c.quality >= 100) });
        }
        const f = this.features || {};
        menuItems.push({ action: 'presets', icon: 'fa-bookmark', label: this.t('ui_presets') });
        if (f.identity && f.identity.enabled) {
            menuItems.push({ action: 'identity', icon: 'fa-signature', label: this.t('ui_identity') });
        }
        if (f.access && f.access.canManage) {
            menuItems.push({ action: 'access', icon: 'fa-lock', label: this.t('ui_access'), badge: this.t('ui_access_' + (f.access.mode || 'everyone')) });
            menuItems.push({ action: 'packup', icon: 'fa-box-open', label: this.t('ui_packup') });
        }

        const container = document.getElementById('mainMenuItems');
        if (!container) return;
        
        let html = '';
        for (let i = 0; i < menuItems.length; i++) {
            const item = menuItems[i];
            html += '<div class="menu-item' + (item.disabled ? ' disabled' : '') + '" data-action="' + item.action + '">' +
                '<span class="menu-item-icon"><i class="fas ' + item.icon + '"></i></span>' +
                '<span class="menu-item-label">' + item.label + '</span>' +
                (item.badge ? '<span class="menu-item-badge">' + item.badge + '</span>' : '') +
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
            case 'oil':
            case 'repair':
                this.postToGame('maintain', { kind: action });
                break;
            case 'packup':
                this.packup();
                break;
            case 'presets':
                this.showSubMenu('presets');
                break;
            case 'identity':
                this.showSubMenu('identity');
                break;
            case 'access': {
                const order = ['everyone', 'owner', 'job', 'gang'];
                const cur = (this.features.access && this.features.access.mode) || 'everyone';
                this.postToGame('setAccess', { mode: order[(order.indexOf(cur) + 1) % order.length] });
                break;
            }
        }
    },

    updateTools() {
        const p = this.price || {};
        const set = (id, disabled) => { const el = document.getElementById(id); if (el) el.disabled = !!disabled; };
        set('btnUndo', !p.canUndo || this.comparing);
        set('btnRedo', !p.canRedo || this.comparing);
        set('btnRevert', this.comparing);
        const cmp = document.getElementById('btnCompare');
        if (cmp) cmp.classList.toggle('active', this.comparing);
    },

    // Selection pushed by the game (undo/redo/compare/preset): move every slider without posting back
    applySelection(sel) {
        if (!sel || Array.isArray(sel)) sel = {};
        this.currentSel = Object.assign({}, sel);
        const cats = Object.keys(this.filteredComponents);
        for (const category of cats) {
            const items = this.filteredComponents[category];
            const want = sel[category] || '';
            let idx = items.findIndex((it) => it.name === want);
            if (idx < 0) idx = 0;
            this.selectedComponents[category] = { index: idx, hash: items[idx].hash, name: items[idx].name };
            this.updateSliderUI(category, idx, items.length, items[idx]);
        }
    },

    showSubMenu(kind) {
        this.subKind = kind;
        document.getElementById('mainMenu').classList.add('hidden');
        document.getElementById('componentMenu').classList.add('hidden');
        document.getElementById('subMenu').classList.remove('hidden');
        document.getElementById('subMenuTitle').textContent = this.t(kind === 'presets' ? 'ui_presets' : 'ui_identity');
        this.currentMenu = 'sub';
        if (kind === 'presets') {
            this.renderPresets();
            this.postToGame('listPresets', {});
        } else {
            this.renderIdentity();
        }
    },

    renderPresets() {
        const body = document.getElementById('subMenuBody');
        if (!body) return;
        const max = this.features.maxPresets || 5;
        let html = '';
        if (!this.presets.length) {
            html += '<div class="sub-empty">' + this.escape(this.t('ui_preset_empty')) + '</div>';
        }
        for (const pr of this.presets) {
            html += '<div class="sub-row"><span class="sub-row-name">' + this.escape(pr.name) + '</span>' +
                '<button class="btn-mini" data-load="' + Number(pr.id) + '" type="button">' + this.escape(this.t('ui_preset_load')) + '</button>' +
                '<button class="btn-mini" data-del="' + Number(pr.id) + '" type="button"><i class="fas fa-trash"></i></button></div>';
        }
        if (this.presets.length < max) {
            html += '<div class="sub-label">' + this.escape(this.t('ui_preset_name')) + ' (' + this.presets.length + '/' + max + ')</div>' +
                '<input class="text-input" id="presetName" maxlength="32" autocomplete="off">' +
                '<button class="btn-western" id="presetSave" type="button">' + this.escape(this.t('ui_preset_save')) + '</button>';
        }
        body.innerHTML = html;
        body.querySelectorAll('[data-load]').forEach((b) => b.addEventListener('click', () => this.postToGame('loadPreset', { id: Number(b.dataset.load) })));
        body.querySelectorAll('[data-del]').forEach((b) => b.addEventListener('click', () => this.postToGame('deletePreset', { id: Number(b.dataset.del) })));
        const save = document.getElementById('presetSave');
        if (save) save.addEventListener('click', () => {
            const input = document.getElementById('presetName');
            const name = input ? input.value.trim() : '';
            if (name) this.postToGame('savePreset', { name: name });
        });
    },

    renderIdentity() {
        const body = document.getElementById('subMenuBody');
        const id = this.features.identity;
        if (!body || !id) return;
        const cur = this.t('ui_currency');
        body.innerHTML =
            '<div class="sub-label">' + this.escape(this.t('ui_custom_name')) + '</div>' +
            '<input class="text-input" id="idName" maxlength="' + Number(id.maxName) + '" autocomplete="off" value="' + this.escape(id.name) + '">' +
            '<div class="sub-hint">' + this.escape(cur + Number(id.namePrice).toFixed(2)) + '</div>' +
            '<div class="sub-label">' + this.escape(this.t('ui_engraving')) + '</div>' +
            '<input class="text-input" id="idEngr" maxlength="' + Number(id.maxEngraving) + '" autocomplete="off" value="' + this.escape(id.engraving) + '">' +
            '<div class="sub-hint">' + this.escape(cur + Number(id.engravePrice).toFixed(2)) + '</div>' +
            '<button class="btn-western btn-purchase" id="idSave" type="button">' + this.escape(this.t('ui_identity_save')) + '</button>';
        document.getElementById('idSave').addEventListener('click', () => {
            this.postToGame('saveIdentity', {
                name: document.getElementById('idName').value,
                engraving: document.getElementById('idEngr').value
            });
        });
    },

    showMainMenu() {
        const mainMenu = document.getElementById('mainMenu');
        const componentMenu = document.getElementById('componentMenu');
        
        if (mainMenu) mainMenu.classList.remove('hidden');
        if (componentMenu) componentMenu.classList.add('hidden');
        const subMenu = document.getElementById('subMenu');
        if (subMenu) subMenu.classList.add('hidden');
        if (this.subKind) this.postToGame('inputFocus', { focused: false });
        this.subKind = null;
        
        this.currentMenu = 'main';
    },

    showComponentMenu(title) {
        const mainMenu = document.getElementById('mainMenu');
        const componentMenu = document.getElementById('componentMenu');
        const menuTitle = document.getElementById('componentMenuTitle');
        
        if (mainMenu) mainMenu.classList.add('hidden');
        const subM = document.getElementById('subMenu');
        if (subM) subM.classList.add('hidden');
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
            const savedCompName = this.currentSel ? this.currentSel[category] : null;
            
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
            
            const currentItem = items[currentIndex] || items[0];
            const displayName = this.formatLabel(currentItem.label || currentItem.name || category);
            const progress = ((currentIndex + 1) / items.length) * 100;
            
            const price = Number(this.prices[category]) || 0;
            const priceTag = price > 0 ? '<span class="category-price">' + this.escape(this.t('ui_currency') + price.toFixed(2)) + '</span>' : '';

            const lockedLevel = (this.features.locked || {})[category];
            const lockTag = lockedLevel ? '<span class="category-lock"><i class="fas fa-lock"></i> ' + this.escape(this.t('ui_level') + ' ' + lockedLevel) + '</span>' : '';
            const mats = (this.features.materials || {})[category];
            const matRow = mats && mats.length ? '<div class="mat-row">' + mats.map((m) =>
                '<span class="mat-tag">' + this.escape(m.label + ' x' + m.amount) + '</span>').join('') + '</div>' : '';

            html += '<div class="component-category' + (lockedLevel ? ' locked' : '') + '" data-category="' + category + '" data-index="' + currentIndex + '">' +
                '<div class="category-header">' +
                    '<span class="category-name">' + this.escape(this.categoryLabels[category] || this.formatLabel(category)) + priceTag + lockTag + '</span>' +
                    '<span class="category-value">' + this.escape(displayName) + '</span>' +
                '</div>' + matRow +
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

        if (this.comparing || (this.features.locked || {})[category]) return;
        const selectedItem = items[newIndex];
        this.selectedComponents[category] = { index: newIndex, hash: selectedItem.hash, name: selectedItem.name };
        this.currentSel[category] = selectedItem.name;
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
            const base = Number(this.price && this.price.base) || 0;
            const old = (this.price && this.price.discount > 0 && base > price)
                ? '<span class="price-old">' + this.escape(this.t('ui_currency') + base.toFixed(2)) + '</span>' : '';
            priceEl.innerHTML = old + this.escape(this.t('ui_currency') + displayPrice);
            priceEl.classList.toggle('over', !this.canAfford);
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
        this.confirmPurchase();
    },

    confirmPurchase() {
        const modal = document.getElementById('purchaseModal');
        const lines = document.getElementById('purchaseLines');
        if (!modal || !lines) return this.postToGame('purchase', {});
        const p = this.price || {};
        const cur = this.t('ui_currency');
        const money = (v) => this.escape(cur + (Number(v) || 0).toFixed(2));
        let html = '<div class="confirm-line"><span class="dim">' + this.escape(this.t('ui_confirm_total')) + '</span><span>' + money(p.price) + '</span></div>';
        if (p.discount > 0) {
            html += '<div class="confirm-line"><span class="dim">' + this.escape(this.t('ui_confirm_discount')) + '</span><span class="ok">-' + Math.round(p.discount * 100) + '%</span></div>';
        }
        if (p.balance != null) {
            const after = Number(p.balance) - Number(p.price || 0);
            html += '<div class="confirm-line"><span class="dim">' + this.escape(this.t('ui_confirm_balance')) + '</span><span>' + money(p.balance) + '</span></div>' +
                '<div class="confirm-line"><span class="dim">' + this.escape(this.t('ui_confirm_after')) + '</span><span class="' + (after < 0 ? 'bad' : 'ok') + '">' + money(after) + '</span></div>';
        }
        for (const m of (p.materials || [])) {
            html += '<div class="confirm-line"><span class="dim">' + this.escape(this.t('ui_confirm_materials')) + ': ' + this.escape(m.label) + '</span>' +
                '<span class="' + (m.have < m.amount ? 'bad' : 'ok') + '">' + Number(m.have) + ' / ' + Number(m.amount) + '</span></div>';
        }
        lines.innerHTML = html;
        modal.classList.remove('hidden');
        const done = (yes) => {
            modal.classList.add('hidden');
            document.getElementById('purchaseYes').onclick = null;
            document.getElementById('purchaseNo').onclick = null;
            if (yes) this.postToGame('purchase', {});
        };
        document.getElementById('purchaseYes').onclick = () => done(true);
        document.getElementById('purchaseNo').onclick = () => done(false);
    },

    reset() {
        this.postToGame('resetWeapon', {});
    },

    packup() {
        const modal = document.getElementById('confirmModal');
        if (!modal) return this.postToGame('packup', {});
        modal.classList.remove('hidden');
        const done = (yes) => {
            modal.classList.add('hidden');
            document.getElementById('confirmYes').onclick = null;
            document.getElementById('confirmNo').onclick = null;
            if (yes) this.postToGame('packup', {});
        };
        document.getElementById('confirmYes').onclick = () => done(true);
        document.getElementById('confirmNo').onclick = () => done(false);
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