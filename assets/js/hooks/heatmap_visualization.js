import * as d3 from "d3";

export const HeatmapVisualization = {
  mounted() {
    this.handleEvent("update-heatmap", ({data}) => {
      this.renderHeatmap(data);
    });
    
    // Initial render
    const initialData = this.el.dataset.heatmap;
    if (initialData && initialData !== "null") {
      try {
        this.renderHeatmap(JSON.parse(initialData));
      } catch (e) {
        console.warn("Failed to parse heatmap data:", e);
      }
    }
  },
  
  renderHeatmap(data) {
    if (!data || !data.systems || data.systems.length === 0) {
      this.renderEmptyState();
      return;
    }
    
    const container = this.el;
    const width = container.clientWidth || 800;
    const height = 600;
    
    // Clear existing content
    d3.select(container).selectAll("*").remove();
    
    const svg = d3.select(container)
      .append("svg")
      .attr("width", width)
      .attr("height", height)
      .attr("class", "heatmap-svg");
    
    // Color scale for threat levels (reversed so red = danger)
    const colorScale = d3.scaleSequential()
      .interpolator(d3.interpolateRdYlGn)
      .domain([data.maxThreat, 0]);
    
    // Create hexbin layout for EVE Online style map
    const hexRadius = Math.min(width, height) / 50;
    const hexbin = d3.hexbin()
      .radius(hexRadius)
      .extent([[0, 0], [width, height]]);
    
    // Convert system data to hexbin format with scaled positions
    const systems = data.systems.map(system => ({
      x: system.mapX * (width - 100) + 50, // Add margins
      y: system.mapY * (height - 100) + 50,
      threatLevel: system.threatLevel,
      systemName: system.name,
      kills: system.recentKills,
      iskDestroyed: system.iskDestroyed,
      systemId: system.id
    }));
    
    // Create hexagons
    const hexagons = svg.append("g")
      .selectAll(".hexagon")
      .data(hexbin(systems))
      .enter().append("path")
      .attr("class", "hexagon")
      .attr("d", hexbin.hexagon())
      .attr("transform", d => `translate(${d.x},${d.y})`)
      .style("fill", d => {
        const avgThreat = d3.mean(d, s => s.threatLevel) || 0;
        return colorScale(avgThreat);
      })
      .style("stroke", "#374151")
      .style("stroke-width", "1px")
      .style("cursor", "pointer")
      .style("opacity", 0.8)
      .on("click", (event, d) => {
        if (d && d.length > 0) {
          const system = d[0]; // First system in hex
          this.pushEvent("select-system", {system_id: system.systemId});
        }
      })
      .on("mouseover", (event, d) => {
        if (!d || d.length === 0) return;
        
        const system = d[0];
        this.showTooltip(event, system);
        
        // Highlight hexagon
        d3.select(event.currentTarget)
          .style("stroke", "#60a5fa")
          .style("stroke-width", "2px")
          .style("opacity", 1);
      })
      .on("mouseout", (event, d) => {
        this.hideTooltip();
        
        // Remove highlight
        d3.select(event.currentTarget)
          .style("stroke", "#374151")
          .style("stroke-width", "1px")
          .style("opacity", 0.8);
      });
    
    // Add legend
    this.renderLegend(svg, colorScale, width, height);
    
    // Add title
    svg.append("text")
      .attr("x", width / 2)
      .attr("y", 25)
      .attr("text-anchor", "middle")
      .style("fill", "#f9fafb")
      .style("font-size", "16px")
      .style("font-weight", "600")
      .text(`System Threat Heatmap (${data.totalSystems} systems)`);
  },
  
  renderEmptyState() {
    const container = this.el;
    const width = container.clientWidth || 800;
    const height = 600;
    
    d3.select(container).selectAll("*").remove();
    
    const svg = d3.select(container)
      .append("svg")
      .attr("width", width)
      .attr("height", height);
    
    svg.append("text")
      .attr("x", width / 2)
      .attr("y", height / 2)
      .attr("text-anchor", "middle")
      .style("fill", "#9ca3af")
      .style("font-size", "18px")
      .text("No activity data available for the selected timeframe");
  },
  
  renderLegend(svg, colorScale, width, height) {
    const legendWidth = 200;
    const legendHeight = 20;
    const legendX = width - legendWidth - 20;
    const legendY = height - 50;
    
    const legend = svg.append("g")
      .attr("class", "legend")
      .attr("transform", `translate(${legendX}, ${legendY})`);
    
    // Create gradient definition
    const defs = svg.append("defs");
    const gradient = defs.append("linearGradient")
      .attr("id", "threat-gradient")
      .attr("x1", "0%")
      .attr("x2", "100%");
    
    // Add color stops
    const steps = 10;
    for (let i = 0; i <= steps; i++) {
      const position = i / steps;
      gradient.append("stop")
        .attr("offset", `${position * 100}%`)
        .attr("stop-color", colorScale(position));
    }
    
    // Legend rectangle
    legend.append("rect")
      .attr("width", legendWidth)
      .attr("height", legendHeight)
      .style("fill", "url(#threat-gradient)")
      .style("stroke", "#374151");
    
    // Legend labels
    legend.append("text")
      .attr("x", 0)
      .attr("y", -5)
      .text("Low Threat")
      .style("fill", "#f9fafb")
      .style("font-size", "12px");
    
    legend.append("text")
      .attr("x", legendWidth)
      .attr("y", -5)
      .attr("text-anchor", "end")
      .text("High Threat")
      .style("fill", "#f9fafb")
      .style("font-size", "12px");
  },
  
  showTooltip(event, system) {
    const tooltip = d3.select("body")
      .append("div")
      .attr("class", "heatmap-tooltip")
      .style("position", "absolute")
      .style("background", "rgba(17, 24, 39, 0.95)")
      .style("color", "#f9fafb")
      .style("padding", "12px")
      .style("border-radius", "8px")
      .style("border", "1px solid #374151")
      .style("pointer-events", "none")
      .style("font-size", "14px")
      .style("box-shadow", "0 4px 6px rgba(0, 0, 0, 0.3)")
      .style("z-index", "1000")
      .style("left", (event.pageX + 15) + "px")
      .style("top", (event.pageY - 15) + "px");
    
    const iskFormatted = this.formatISK(system.iskDestroyed);
    const threatPercent = (system.threatLevel * 100).toFixed(1);
    
    tooltip.html(`
      <div style="font-weight: 600; margin-bottom: 6px;">${system.systemName}</div>
      <div style="margin-bottom: 4px;">Threat Level: <span style="color: #ef4444;">${threatPercent}%</span></div>
      <div style="margin-bottom: 4px;">Recent Kills: <span style="color: #f59e0b;">${system.kills}</span></div>
      <div>ISK Destroyed: <span style="color: #10b981;">${iskFormatted}</span></div>
    `);
  },
  
  hideTooltip() {
    d3.selectAll(".heatmap-tooltip").remove();
  },
  
  formatISK(value) {
    if (value >= 1e12) {
      return (value / 1e12).toFixed(1) + "T";
    } else if (value >= 1e9) {
      return (value / 1e9).toFixed(1) + "B";
    } else if (value >= 1e6) {
      return (value / 1e6).toFixed(1) + "M";
    } else if (value >= 1e3) {
      return (value / 1e3).toFixed(1) + "K";
    } else {
      return Math.round(value).toString();
    }
  }
};