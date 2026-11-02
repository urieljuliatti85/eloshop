// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import { Turbo } from "@hotwired/turbo-rails"
import "controllers"
import { confirmDialog } from "confirm_dialog"

// Confirmações `turbo_confirm` num <dialog> próprio, não no window.confirm
// (que navegador de aplicativo responde "não" sem mostrar). Ver o módulo.
Turbo.config.forms.confirm = confirmDialog
