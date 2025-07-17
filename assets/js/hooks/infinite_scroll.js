/**
 * Sprint 15A: Infinite scroll hook for seamless pagination.
 * 
 * Automatically triggers load more events when user scrolls near
 * the bottom of the container, providing a smooth UX for large datasets.
 */

const InfiniteScroll = {
  mounted() {
    this.threshold = parseInt(this.el.dataset.threshold) || 200;
    this.loading = false;
    
    // Create intersection observer for efficient scroll detection
    this.observer = new IntersectionObserver(
      (entries) => this.handleIntersection(entries),
      {
        rootMargin: `${this.threshold}px`,
        threshold: 0.1
      }
    );
    
    this.observer.observe(this.el);
    
    // Also listen for manual clicks
    this.el.addEventListener('click', (e) => {
      e.preventDefault();
      this.loadMore();
    });
  },
  
  handleIntersection(entries) {
    const entry = entries[0];
    
    if (entry.isIntersecting && !this.loading) {
      this.loadMore();
    }
  },
  
  loadMore() {
    if (this.loading) return;
    
    this.loading = true;
    
    // Add loading visual feedback
    this.el.classList.add('loading');
    
    // Trigger the load more event
    this.pushEvent('load_more', {
      cursor: this.el.dataset.cursor
    });
    
    // Reset loading state after a delay to prevent rapid triggers
    setTimeout(() => {
      this.loading = false;
      this.el.classList.remove('loading');
    }, 1000);
  },
  
  updated() {
    // Update cursor when component updates
    const newCursor = this.el.dataset.cursor;
    if (newCursor) {
      this.cursor = newCursor;
    }
  },
  
  destroyed() {
    if (this.observer) {
      this.observer.disconnect();
    }
  }
};

export default InfiniteScroll;