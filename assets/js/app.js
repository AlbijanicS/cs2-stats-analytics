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
      labels: {
        boxWidth: 10,
        boxHeight: 10,
        color: "#3f3f46",
        font: {
          family: "system-ui, -apple-system, BlinkMacSystemFont, sans-serif",
          size: 12,
        },
        usePointStyle: true,
      },
    },
    tooltip: {
      backgroundColor: "#18181b",
      borderColor: "#3f3f46",
      borderWidth: 1,
      padding: 10,
      titleColor: "#fafafa",
      bodyColor: "#e4e4e7",
      displayColors: true,
    },
  },
  elements: {
    line: {
      borderWidth: 2,
      tension: 0.35,
    },
    point: {
      radius: 3,
      hoverRadius: 5,
      borderWidth: 2,
      backgroundColor: "#ffffff",
    },
  },
  scales: {
    x: {
      grid: {
        display: false,
      },
      ticks: {
        color: "#71717a",
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
          borderColor: "#2563eb",
          pointBorderColor: "#2563eb",
          yAxisID: "adr",
        },
        {
          label: "K/D",
          data: points.map((point) => point.kd_ratio),
          borderColor: "#16a34a",
          pointBorderColor: "#16a34a",
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
            color: "#e4e4e7",
          },
          ticks: {
            color: "#2563eb",
          },
          title: {
            display: true,
            text: "ADR",
            color: "#2563eb",
          },
        },
        kd: {
          type: "linear",
          position: "right",
          beginAtZero: true,
          grid: {
            drawOnChartArea: false,
          },
          ticks: {
            color: "#16a34a",
          },
          title: {
            display: true,
            text: "K/D",
            color: "#16a34a",
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
          borderColor: "#9333ea",
          pointBorderColor: "#9333ea",
          fill: true,
          backgroundColor: "rgba(147, 51, 234, 0.08)",
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
            color: "#e4e4e7",
          },
          ticks: {
            color: "#71717a",
            callback: (value) => `${value}%`,
          },
          title: {
            display: true,
            text: "Headshot %",
            color: "#71717a",
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
