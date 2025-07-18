/**
 * Sprint 15A: Infinite scroll hook for seamless pagination.
 * 
 * Automatically triggers load more events when user scrolls near
 * the bottom of the container, providing a smooth UX for large datasets.
 */

const InfiniteScroll = {
  mounted() {
    this.threshold = Number.parseInt(this.el.dataset.threshold) || 200;
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
    
    // Also listen for manual clicks on load more buttons
    this.el.addEventListener('click', (e) => {
      // Only prevent default and load more if clicking on a load more button
      if (e.target.matches('[data-load-more]') || e.target.closest('[data-load-more]')) {
        e.preventDefault();
        this.loadMore();
      }
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
    
    // Validate cursor before sending
    const cursor = this.cursor || this.el.dataset.cursor;
    if (cursor && typeof cursor === 'string') {
      // Trigger the load more event
      this.pushEvent('load_more', {
        cursor: cursor
      });
    } else {
      // Reset loading state if cursor is invalid
      this.loading = false;
      this.el.classList.remove('loading');
    }
  },
  
  updated() {
    // Update cursor when component updates
    const newCursor = this.el.dataset.cursor;
    if (newCursor) {
      this.cursor = newCursor;
    }
  },
  
  resetLoading() {
    this.loading = false;
    this.el.classList.remove('loading');
  },
  
  destroyed() {
    if (this.observer) {
      this.observer.disconnect();
    }
  }
};

export default InfiniteScroll;