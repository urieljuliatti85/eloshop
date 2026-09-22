import { Controller } from "@hotwired/stimulus"

const CONSENT_COOKIE = "eloshop_analytics_consent"
const SCRIPT_ID = "eloshop-google-analytics"

export default class extends Controller {
  static targets = ["banner"]
  static values = { measurementId: String, pagePath: String, pageTitle: String }

  connect() {
    if (this.consent === "granted") {
      this.loadAnalytics()
    } else if (!this.consent) {
      this.showBanner()
    }
  }

  accept() {
    this.consent = "granted"
    window[`ga-disable-${this.measurementIdValue}`] = false
    this.hideBanner()
    this.loadAnalytics()
  }

  decline() {
    this.consent = "denied"
    this.disableAnalytics()
    this.hideBanner()
  }

  openPreferences() {
    this.showBanner()
  }

  loadAnalytics() {
    if (!this.measurementIdValue || this.consent !== "granted") return

    window[`ga-disable-${this.measurementIdValue}`] = false
    window.dataLayer = window.dataLayer || []
    window.gtag = window.gtag || function () { window.dataLayer.push(arguments) }

    if (!window.eloshopGoogleAnalyticsConfigured) {
      window.gtag("js", new Date())
      window.gtag("config", this.measurementIdValue, {
        send_page_view: false,
        allow_google_signals: false,
        allow_ad_personalization_signals: false
      })
      window.eloshopGoogleAnalyticsConfigured = true
    }

    if (!document.getElementById(SCRIPT_ID)) {
      const script = document.createElement("script")
      script.id = SCRIPT_ID
      script.async = true
      script.src = `https://www.googletagmanager.com/gtag/js?id=${encodeURIComponent(this.measurementIdValue)}`
      document.head.appendChild(script)
    }

    this.trackPageView()
  }

  trackPageView() {
    if (this.element.dataset.googleAnalyticsTracked === "true") return

    window.gtag("event", "page_view", {
      page_title: this.pageTitleValue,
      page_location: `${window.location.origin}${this.pagePathValue}`,
      page_path: this.pagePathValue
    })
    this.element.dataset.googleAnalyticsTracked = "true"
  }

  disableAnalytics() {
    window[`ga-disable-${this.measurementIdValue}`] = true
    if (window.gtag) window.gtag("consent", "update", { analytics_storage: "denied" })
    document.getElementById(SCRIPT_ID)?.remove()

    document.cookie.split("; ").forEach((entry) => {
      const name = entry.split("=")[0]
      if (!name.startsWith("_ga")) return

      this.expireCookie(name)
    })
  }

  expireCookie(name) {
    const expiry = "Max-Age=0; Path=/; SameSite=Lax"
    document.cookie = `${name}=; ${expiry}`
    document.cookie = `${name}=; ${expiry}; Domain=${window.location.hostname}`
    document.cookie = `${name}=; ${expiry}; Domain=.${window.location.hostname}`
  }

  showBanner() {
    if (this.hasBannerTarget) this.bannerTarget.hidden = false
  }

  hideBanner() {
    if (this.hasBannerTarget) this.bannerTarget.hidden = true
  }

  get consent() {
    const match = document.cookie.split("; ").find((entry) => entry.startsWith(`${CONSENT_COOKIE}=`))
    return match?.split("=")[1]
  }

  set consent(value) {
    const secure = window.location.protocol === "https:" ? "; Secure" : ""
    document.cookie = `${CONSENT_COOKIE}=${value}; Path=/; Max-Age=15552000; SameSite=Lax${secure}`
  }
}
