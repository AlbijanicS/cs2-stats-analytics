// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"

// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/cs2_stats_analytics"
import topbar from "../vendor/topbar"
import Chart from "chart.js/auto"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

const parsePoints = (element) => {
  try {
    return JSON.parse(element.dataset.points || "[]")
  } catch (_error) {
    return []
  }
}

const chartFill = (colorStops) => (context) => {
  const {chart} = context
  const {ctx, chartArea} = chart

  if (!chartArea) {
    return colorStops[0][1]
  }

  const gradient = ctx.createLinearGradient(0, chartArea.top, 0, chartArea.bottom)
  colorStops.forEach(([stop, color]) => gradient.addColorStop(stop, color))
  return gradient
}

const chartBaseOptions = {
  responsive: true,
  maintainAspectRatio: false,
  interaction: {
    mode: "index",
    intersect: false,
  },
  plugins: {
    legend: {
      position: "bottom",
      align: "center",
      labels: {
        boxWidth: 8,
        boxHeight: 8,
        color: "#a1a1aa",
        font: {
          family: "system-ui, -apple-system, BlinkMacSystemFont, sans-serif",
          size: 11,
        },
        usePointStyle: true,
        padding: 18,
      },
    },
    tooltip: {
      backgroundColor: "#09090b",
      borderColor: "#3f3f46",
      borderWidth: 1,
      padding: 12,
      titleColor: "#fafafa",
      bodyColor: "#e4e4e7",
      displayColors: true,
      boxPadding: 4,
    },
  },
  elements: {
    line: {
      borderWidth: 3,
      tension: 0.3,
    },
    point: {
      radius: 0,
      hoverRadius: 5,
      borderWidth: 2,
      backgroundColor: "#18181b",
    },
  },
  scales: {
    x: {
      grid: {
        color: "rgba(113, 113, 122, 0.16)",
        borderDash: [4, 6],
        drawTicks: false,
      },
      ticks: {
        autoSkip: true,
        color: "#71717a",
        maxRotation: 0,
        maxTicksLimit: 6,
        padding: 10,
      },
      border: {
        display: false,
      },
    },
  },
}

const chartHook = (buildConfig) => ({
  mounted() {
    this.renderChart()
  },

  updated() {
    this.renderChart()
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
    }
  },

  renderChart() {
    if (this.chart) {
      this.chart.destroy()
    }

    this.chart = new Chart(this.el, buildConfig(parsePoints(this.el)))
  },
})

const Hooks = {
  ...colocatedHooks,

  AdrTrendChart: chartHook((points) => ({
    type: "line",
    data: {
      labels: points.map((point) => point.label),
      datasets: [
        {
          label: "ADR",
          data: points.map((point) => point.adr),
          borderColor: "#ff5a1f",
          pointBorderColor: "#ff5a1f",
          fill: true,
          backgroundColor: chartFill([
            [0, "rgba(255, 90, 31, 0.22)"],
            [1, "rgba(255, 90, 31, 0.02)"],
          ]),
          yAxisID: "adr",
        },
        {
          label: "K/D",
          data: points.map((point) => point.kd_ratio),
          borderColor: "#22c55e",
          borderWidth: 2,
          pointBorderColor: "#22c55e",
          yAxisID: "kd",
        },
      ],
    },
    options: {
      ...chartBaseOptions,
      scales: {
        ...chartBaseOptions.scales,
        adr: {
          type: "linear",
          position: "left",
          beginAtZero: true,
          grid: {
            color: "rgba(113, 113, 122, 0.18)",
            borderDash: [4, 6],
            drawTicks: false,
          },
          ticks: {
            color: "#a1a1aa",
            maxTicksLimit: 4,
            padding: 10,
          },
          title: {
            display: false,
          },
          border: {
            display: false,
          },
        },
        kd: {
          type: "linear",
          position: "right",
          beginAtZero: true,
          display: false,
          grid: {
            drawOnChartArea: false,
          },
        },
      },
    },
  })),

  HeadshotTrendChart: chartHook((points) => ({
    type: "line",
    data: {
      labels: points.map((point) => point.label),
      datasets: [
        {
          label: "Headshot %",
          data: points.map((point) => point.headshot_percent),
          borderColor: "#ff5a1f",
          pointBorderColor: "#ff5a1f",
          fill: true,
          backgroundColor: chartFill([
            [0, "rgba(255, 90, 31, 0.22)"],
            [1, "rgba(255, 90, 31, 0.02)"],
          ]),
        },
      ],
    },
    options: {
      ...chartBaseOptions,
      scales: {
        ...chartBaseOptions.scales,
        y: {
          beginAtZero: true,
          max: 100,
          grid: {
            color: "rgba(113, 113, 122, 0.18)",
            borderDash: [4, 6],
            drawTicks: false,
          },
          ticks: {
            color: "#a1a1aa",
            maxTicksLimit: 4,
            padding: 10,
            callback: (value) => `${value}%`,
          },
          title: {
            display: false,
          },
          border: {
            display: false,
          },
        },
      },
    },
  })),
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks,
})

// Show progress bar on live navigation and form submits.
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300))
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide())

// Connect if there are any LiveViews on the page.
liveSocket.connect()

// Expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload development features.
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    reloader.enableServerLogs()

    let keyDown

    window.addEventListener("keydown", (event) => {
      keyDown = event.key
    })

    window.addEventListener("keyup", (_event) => {
      keyDown = null
    })

    window.addEventListener(
      "click",
      (event) => {
        if (keyDown === "c") {
          event.preventDefault()
          event.stopImmediatePropagation()
          reloader.openEditorAtCaller(event.target)
        } else if (keyDown === "d") {
          event.preventDefault()
          event.stopImmediatePropagation()
          reloader.openEditorAtDef(event.target)
        }
      },
      true
    )

    window.liveReloader = reloader
  })
}
