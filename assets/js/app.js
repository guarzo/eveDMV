// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Define Phoenix Hooks
import InfiniteScroll from "./hooks/infinite_scroll"

let Hooks = {}
Hooks.InfiniteScroll = InfiniteScroll

Hooks.AutocompleteInput = {
  mounted() {
    console.log('🚀 AutocompleteInput hook mounted for:', this.el.id);
    this.index = this.el.dataset.index;
    this.field = this.el.dataset.field;
    this.input = this.el.querySelector('input');
    this.suggestionsEl = this.el.querySelector('[id$="_suggestions"]');
    
    console.log('🔧 Hook data:', {
      index: this.index,
      field: this.field,
      input: this.input?.id,
      suggestionsEl: this.suggestionsEl?.id,
      hookEl: this.el.id
    });
    
    // Handle suggestion clicks using event delegation
    this.handleSuggestionClick = (e) => {
      console.log('🖱️ HOOK: Click detected on suggestions container!');
      console.log('🎯 HOOK: Click target:', e.target);
      console.log('🏷️ HOOK: Target classes:', e.target.className);
      console.log('📍 HOOK: Target tagName:', e.target.tagName);
      
      // Find the closest suggestion-item (in case user clicks on text inside the div)
      const suggestionItem = e.target.closest('.suggestion-item');
      console.log('🔍 HOOK: Closest suggestion-item:', suggestionItem);
      
      if (suggestionItem) {
        const suggestionId = suggestionItem.dataset.id;
        
        console.log('✅ HOOK: Autocomplete click successful!', {
          id: suggestionId,
          field: this.field,
          index: this.index,
          currentValue: this.input.value
        });
        
        // Update the input immediately to prevent clearing
        const currentValue = this.input.value;
        const newValue = currentValue.trim() ? `${currentValue}, ${suggestionId}` : suggestionId;
        console.log(`🔄 HOOK: Updating input from "${currentValue}" to "${newValue}"`);
        this.input.value = newValue;
        
        // Push event to LiveView
        console.log('📤 HOOK: Pushing select_suggestion event to LiveView...');
        this.pushEvent("select_suggestion", {
          id: suggestionId,
          field: this.field,
          index: this.index
        });
        
        // Also trigger the update_filter_field event to sync with LiveView
        console.log('🔄 HOOK: Triggering update_filter_field event...');
        this.pushEvent("update_filter_field", {
          field: this.field,
          index: this.index,
          value: newValue
        });
        
        // Hide suggestions
        console.log('🙈 HOOK: Hiding suggestions...');
        this.suggestionsEl.classList.add('hidden');
      } else {
        console.log('❌ HOOK: Click target is not within a suggestion-item');
        console.log('🔍 HOOK: Available suggestion items:');
        const items = this.suggestionsEl.querySelectorAll('.suggestion-item');
        items.forEach((item, index) => {
          console.log(`    Item ${index}:`, item, item.dataset);
        });
      }
    };
    
    console.log('👂 HOOK: Adding mousedown listener to:', this.suggestionsEl?.id);
    this.suggestionsEl.addEventListener('mousedown', this.handleSuggestionClick);
    console.log('✅ HOOK: Mousedown listener added successfully');
    
    // Hide suggestions when clicking outside
    this.handleOutsideClick = (e) => {
      if (!this.el.contains(e.target)) {
        this.suggestionsEl.classList.add('hidden');
      }
    };
    
    document.addEventListener('click', this.handleOutsideClick);
  },
  
  destroyed() {
    if (this.suggestionsEl) {
      this.suggestionsEl.removeEventListener('click', this.handleSuggestionClick);
    }
    document.removeEventListener('click', this.handleOutsideClick);
  }
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => {
  try {
    topbar.hide()
  } catch (e) {
    // Ignore topbar errors during hide
    console.debug("Topbar hide error ignored:", e)
  }
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket 