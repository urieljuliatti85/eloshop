// Inicialização do Swagger UI em /api-docs, fora do HTML para respeitar a CSP
// (script-src sem unsafe-inline). Ver swagger/index.erb.
window.addEventListener("load", function () {
  var container = document.getElementById("swagger-ui")
  var configObject = JSON.parse(container.dataset.config)
  var oauthConfigObject = JSON.parse(container.dataset.oauthConfig)

  configObject.dom_id = "#swagger-ui"
  configObject.presets = [SwaggerUIBundle.presets.apis, SwaggerUIStandalonePreset]
  configObject.layout = "StandaloneLayout"

  if (!configObject.hasOwnProperty("oauth2RedirectUrl"))
    configObject.oauth2RedirectUrl = window.location.href.replace("index.html", "oauth2-redirect.html")

  var ui = SwaggerUIBundle(configObject)
  ui.initOAuth(oauthConfigObject)
})
