# Infinite Scroll Implementation for Kill Feed

## Overview
The kill feed now supports infinite scrolling, automatically loading more killmails as users scroll near the bottom of the feed. This provides a seamless browsing experience for viewing historical killmail data.

## Features Implemented

### 1. Backend Pagination Support
- **Offset-based pagination** in `DisplayService.load_recent_killmails/3`
- **Page metadata** via `DisplayService.load_killmails_page/3` that returns:
  - `killmails`: The page of killmail data
  - `has_more`: Boolean indicating if more data exists
  - `next_offset`: Offset for the next page

### 2. LiveView State Management
- **Pagination state tracking**:
  - `:offset` - Current offset for next page load
  - `:has_more` - Whether more killmails exist
  - `:loading_more` - Loading state to prevent duplicate requests
- **Stream-based updates** - New killmails are appended to the existing stream

### 3. JavaScript Infinite Scroll Hook
- **Scroll position monitoring** - Detects when user is within 200px of bottom
- **Automatic loading** - Triggers "load_more" event when threshold reached
- **Loading state management** - Prevents duplicate requests while loading

### 4. UI Enhancements
- **Loading indicator** - Spinning animation while loading more killmails
- **End of feed indicator** - Shows when all killmails have been loaded
- **Smooth integration** - Works seamlessly with existing filters

## Technical Implementation

### DisplayService Changes
```elixir
def load_recent_killmails(limit \\ @feed_limit, filters \\ %{}, offset \\ 0) do
  query =
    KillmailRaw
    |> Ash.Query.new()
    |> Ash.Query.sort(killmail_time: :desc)
    |> Ash.Query.limit(limit)
    |> Ash.Query.offset(offset)
  # ... rest of implementation
end

def load_killmails_page(limit \\ @feed_limit, filters \\ %{}, offset \\ 0) do
  # Load one extra to check if there are more
  killmails = load_recent_killmails(limit + 1, filters, offset)
  
  has_more = length(killmails) > limit
  page_killmails = if has_more, do: Enum.take(killmails, limit), else: killmails
  
  %{
    killmails: page_killmails,
    has_more: has_more,
    next_offset: offset + length(page_killmails)
  }
end
```

### LiveView Event Handler
```elixir
def handle_event("load_more", _params, socket) do
  if socket.assigns.has_more and not socket.assigns.loading_more do
    socket = assign(socket, :loading_more, true)
    
    # Load next page
    page_data = DisplayService.load_killmails_page(
      @feed_limit, 
      socket.assigns.filters, 
      socket.assigns.offset
    )
    
    # Append to existing killmails
    all_killmails = socket.assigns.killmails ++ page_data.killmails
    
    socket =
      socket
      |> assign(:killmails, all_killmails)
      |> assign(:has_more, page_data.has_more)
      |> assign(:loading_more, false)
      |> assign(:offset, page_data.next_offset)
      |> stream(:killmail_stream, page_data.killmails)
    
    {:noreply, socket}
  else
    {:noreply, socket}
  end
end
```

### JavaScript Hook
```javascript
Hooks.InfiniteScroll = {
  mounted() {
    this.pending = false
    this.scrollContainer = this.el
    this.scrollThreshold = 200 // pixels from bottom
    
    this.handleScroll = this.handleScroll.bind(this)
    this.scrollContainer.addEventListener("scroll", this.handleScroll)
  },
  
  handleScroll() {
    const hasMore = this.el.dataset.hasMore === "true"
    
    if (this.pending || !hasMore) return
    
    const scrollPosition = this.scrollContainer.scrollTop + this.scrollContainer.clientHeight
    const scrollHeight = this.scrollContainer.scrollHeight
    const distanceFromBottom = scrollHeight - scrollPosition
    
    if (distanceFromBottom < this.scrollThreshold) {
      this.pending = true
      this.pushEvent("load_more", {})
    }
  }
}
```

## Usage

### For Users
1. Scroll down in the kill feed
2. New killmails load automatically when near the bottom
3. Loading indicator shows while fetching data
4. "End of kill feed" message appears when all data is loaded

### Filter Compatibility
- Infinite scroll works with all existing filters
- Applying new filters resets pagination to the first page
- Filtered results also support infinite scrolling

## Performance Considerations

### Database Optimization
- Uses database-level `OFFSET` and `LIMIT` for efficient queries
- Sorted by `killmail_time DESC` index for fast ordering
- Filters applied at database level when possible

### Client Optimization
- Scroll events are throttled by pending state
- Only loads when within threshold distance
- Phoenix streams minimize DOM updates

### Memory Management
- LiveView streams ensure efficient memory usage
- Old killmails remain in DOM but don't consume server memory
- Client-side JavaScript is lightweight

## Future Enhancements

1. **Virtual Scrolling** - Render only visible killmails for better performance with thousands of items
2. **Cursor-based Pagination** - More efficient than offset for very large datasets
3. **Scroll Position Restoration** - Remember scroll position when navigating back
4. **Progressive Loading** - Load smaller chunks more frequently for smoother experience
5. **Intersection Observer API** - More efficient scroll detection
6. **Prefetching** - Load next page before user reaches bottom