# Crédito de uma foto de catálogo. Não é Active Record: a procedência vive em
# db/seeds/images/credits.yml, junto das próprias fotos, e não no banco — é
# dado do repositório, não do negócio.
#
# Existe porque CC BY e CC BY-SA exigem atribuição visível para quem publica a
# imagem. Ver /creditos e db/seeds/images/CREDITS.md.
class ImageCredit
  SOURCE = Rails.root.join("db/seeds/images/credits.yml")

  ATTRIBUTES = %i[sku produto titulo autor licenca licenca_url origem_url].freeze

  attr_reader(*(ATTRIBUTES - %i[licenca_url origem_url]))

  def initialize(attributes)
    ATTRIBUTES.each do |name|
      instance_variable_set("@#{name}", attributes[name.to_s])
    end
  end

  # As duas URLs vão para `href`. Um valor `javascript:...` no YAML viraria XSS
  # ao ser renderizado — é o que o Brakeman aponta em LinkToHref. Hoje o
  # arquivo é do repositório, então exigiria acesso de escrita para ser
  # explorado, mas restringir o esquema custa nada e fecha a classe inteira.
  # Devolve nil quando o esquema não serve, e a view mostra texto simples.
  def licenca_url
    http_url(@licenca_url)
  end

  def origem_url
    http_url(@origem_url)
  end

  # Recarrega a cada chamada em desenvolvimento (editar o YAML reflete sem
  # reiniciar) e memoiza no resto, já que o arquivo não muda em runtime.
  def self.all
    return load_all if Rails.env.development?

    @all ||= load_all
  end

  def self.load_all
    return [] unless SOURCE.exist?

    (YAML.safe_load_file(SOURCE) || []).map { |attributes| new(attributes) }
  end
  private_class_method :load_all

  # CC0 e domínio público dispensam atribuição, mas creditar mesmo assim é
  # cortesia com quem publicou — o que a licença exige é não omitir os demais.
  def attribution_required?
    !licenca.to_s.start_with?("CC0")
  end

  private

  # URI::HTTPS herda de URI::HTTP, então a checagem cobre http e https e
  # rejeita qualquer outro esquema (javascript:, data:, file:).
  def http_url(value)
    uri = URI.parse(value.to_s)
    uri.is_a?(URI::HTTP) ? value : nil
  rescue URI::InvalidURIError
    nil
  end
end
