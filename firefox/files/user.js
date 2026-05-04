// Performance & rust
user_pref("toolkit.cosmeticAnimations.enabled", false);
user_pref("browser.tabs.animate", false);
user_pref("browser.fullscreen.autohide", true);

// Tab gedrag
user_pref("browser.tabs.unloadOnLowMemory", true);
user_pref("browser.sessionstore.interval", 60000);

// UI rust
user_pref("browser.toolbars.bookmarks.visibility", "never");
user_pref("browser.compactmode.show", true);

// Minder achtergrondactiviteit
user_pref("dom.ipc.processCount", 2);

// Privacy/light tracking reduction
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("media.autoplay.default", 5);