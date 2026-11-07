class SellerTerms
  VERSION = "seller-marketplace-v2-2026-10-03".freeze

  TEXT = <<~TEXT.freeze
    TERMOS COMERCIAIS DO MARKETPLACE ELOSHOP — VERSÃO 2026-10-03

    1. Objeto e independência comercial
    A EloShop opera uma plataforma tecnológica e de marketplace para divulgação,
    intermediação e operação de vendas de produtos artesanais. O artesão vende
    como responsável independente por seu catálogo, produção, qualidade,
    disponibilidade, entrega, atendimento e obrigações legais. Estes termos não
    constituem vínculo empregatício, sociedade, representação comercial ou
    garantia de volume mínimo de vendas.

    2. Comissão e base de cálculo
    A comissão da EloShop é de 8% (oito por cento) do subtotal dos produtos
    efetivamente vendidos, após descontos aplicados ao pedido, durante os 3
    (três) primeiros meses contados da data de aprovação do artesão pela
    EloShop. Encerrado esse prazo, a comissão passa a ser de 15% (quinze por
    cento) sobre a mesma base. A taxa aplicável é a vigente no momento da
    compra e fica registrada no pedido; pedidos já realizados não mudam de
    taxa. Não há mensalidade, no momento. O frete não integra a base de
    cálculo da comissão. A comissão e os valores do pedido
    são calculados em centavos e registrados no pedido e no SellerOrder.

    3. Tarifas e recebimento
    O Mercado Pago processa o pagamento e pode cobrar tarifas próprias. As
    tarifas do Mercado Pago são de responsabilidade do artesão e são separadas
    da comissão da EloShop. O repasse é feito pelo mecanismo de split autorizado
    pelo Mercado Pago, para a conta conectada pelo artesão, conforme os prazos,
    regras de disponibilidade e retenções do provedor. A EloShop não promete
    prazo de liberação diferente do informado pelo Mercado Pago.

    4. Cancelamentos, reembolsos e chargebacks
    A EloShop pode operar cancelamentos, reembolsos e disputas em nome da
    plataforma, inclusive quando exigido por lei, pelo gateway ou pela política
    aplicável ao consumidor. A comissão correspondente será revertida
    proporcionalmente ao valor reembolsado, conforme o registro financeiro do
    pedido. Chargebacks, estornos, bloqueios e perdas decorrentes de fraude,
    contestação ou descumprimento imputável à venda poderão ser debitados ou
    compensados do saldo do artesão, respeitados a lei, os procedimentos do
    Mercado Pago e o direito de apresentação de informações e defesa. A EloShop
    poderá solicitar comprovantes de produção, envio, entrega e atendimento.

    5. Responsabilidades do artesão
    O artesão é responsável pela exatidão das informações do produto, autoria e
    licitude do catálogo, preço, estoque, prazo de produção, embalagem,
    qualidade, segurança, envio, atendimento, garantia e cumprimento da oferta.
    Também é responsável por emitir documentos fiscais quando exigidos e por
    recolher tributos, contribuições e demais obrigações fiscais ou regulatórias
    decorrentes de suas vendas. A EloShop não presta consultoria tributária.

    6. Uso da plataforma e suspensão
    O artesão deve manter dados verdadeiros, uma conta Mercado Pago elegível e
    cumprir estes termos, as leis aplicáveis e as regras do gateway. A EloShop
    poderá suspender temporariamente o catálogo, a conta ou os repasses quando
    houver risco de fraude, chargeback, irregularidade, descumprimento,
    solicitação do gateway ou necessidade de proteção de clientes e da
    plataforma. A suspensão não elimina obrigações já constituídas.

    7. Encerramento
    O artesão pode solicitar o encerramento da conta, desde que cumpra pedidos,
    reembolsos, disputas, obrigações fiscais e demais responsabilidades
    pendentes. A EloShop poderá encerrar a relação por descumprimento, risco
    operacional ou decisão de descontinuação do serviço. Registros necessários
    para auditoria, prevenção à fraude, obrigações legais e solução de
    controvérsias poderão ser preservados pelo prazo aplicável.

    8. Alterações
    A EloShop poderá alterar estes termos para refletir mudanças legais,
    operacionais, comerciais ou do gateway. Cada alteração terá nova versão.
    Quando a alteração exigir novo aceite, o acesso operacional e a publicação
    permanecerão bloqueados até que o artesão aceite a nova versão. A versão,
    texto integral, data, usuário e evidências técnicas do aceite serão
    registrados.

    9. Aceite
    Ao marcar a caixa de aceite e concluir o cadastro ou a confirmação no
    painel, o artesão declara que leu e concorda com estes termos comerciais.
  TEXT

  # Termos do distribuidor de insumos (ADR 007). RASCUNHO redigido em
  # 2026-11-07 a partir dos termos do ateliê, pendente de revisão do advogado
  # junto com a declaração de nota fiscal — nenhum distribuidor pode ser
  # aprovado para vender antes das Fases 26 a 28, e o texto revisado entra como
  # versão nova. Já descreve a contagem da comissão de lançamento como o código
  # a aplica (o mais tardio entre a aprovação e a abertura das vendas).
  DISTRIBUTOR_VERSION = "distributor-marketplace-v1-2026-11-07".freeze

  DISTRIBUTOR_TEXT = <<~TEXT.freeze
    TERMOS COMERCIAIS DO DISTRIBUIDOR DE INSUMOS — ELOSHOP — VERSÃO 2026-11-07

    1. Objeto e independência comercial
    A EloShop opera uma plataforma tecnológica e de marketplace para divulgação,
    intermediação e operação de vendas. O distribuidor vende, como responsável
    independente, insumos destinados à produção artesanal (como fios, tecidos,
    argila, tintas, ferragens e embalagens). Não é permitido vender produto
    acabado para revenda. O distribuidor responde por seu catálogo, estoque,
    qualidade, disponibilidade, entrega, atendimento e obrigações legais. Estes
    termos não constituem vínculo empregatício, sociedade, representação
    comercial ou garantia de volume mínimo de vendas.

    2. Comissão e base de cálculo
    A comissão da EloShop é de 8% (oito por cento) do subtotal dos produtos
    efetivamente vendidos, após descontos aplicados ao pedido, durante os 3
    (três) primeiros meses contados da data mais tardia entre a aprovação do
    distribuidor pela EloShop e a abertura das vendas da plataforma. Encerrado
    esse prazo, a comissão passa a ser de 15% (quinze por cento) sobre a mesma
    base. A taxa aplicável é a vigente no momento da compra e fica registrada
    no pedido; pedidos já realizados não mudam de taxa. Não há mensalidade, no
    momento. O frete não integra a base de cálculo da comissão. A comissão e os
    valores do pedido são calculados em centavos e registrados no pedido.

    3. Preço, quantidade mínima e faixas
    O preço, a unidade de venda, a quantidade mínima de compra e as faixas de
    preço por quantidade são definidos pelo distribuidor e exibidos
    publicamente. O preço cobrado é o calculado pela plataforma no momento da
    compra, conforme a faixa aplicável, e fica registrado no pedido.

    4. Tarifas e recebimento
    O Mercado Pago processa o pagamento e pode cobrar tarifas próprias. As
    tarifas do Mercado Pago são de responsabilidade do distribuidor e são
    separadas da comissão da EloShop. O repasse é feito pelo mecanismo de split
    autorizado pelo Mercado Pago, para a conta conectada pelo distribuidor,
    conforme os prazos, regras de disponibilidade e retenções do provedor. A
    EloShop não promete prazo de liberação diferente do informado pelo Mercado
    Pago.

    5. Frete
    O frete é cotado pela integração de frete conectada pelo distribuidor ou,
    na falta de cotação, é o valor fixo definido por ele no produto. Sem um dos
    dois, o produto não é vendido. O distribuidor responde pela embalagem
    adequada a volumes pesados ou frágeis e pelo envio dentro do prazo
    informado.

    6. Cancelamentos, reembolsos e chargebacks
    A EloShop pode operar cancelamentos, reembolsos e disputas em nome da
    plataforma, inclusive quando exigido por lei, pelo gateway ou pela política
    aplicável ao comprador. A comissão correspondente será revertida
    proporcionalmente ao valor reembolsado, conforme o registro financeiro do
    pedido. Chargebacks, estornos, bloqueios e perdas decorrentes de fraude,
    contestação ou descumprimento imputável à venda poderão ser debitados ou
    compensados do saldo do distribuidor, respeitados a lei, os procedimentos
    do Mercado Pago e o direito de apresentação de informações e defesa. A
    EloShop poderá solicitar comprovantes de origem, envio, entrega e
    atendimento.

    7. Responsabilidades do distribuidor e nota fiscal
    O distribuidor é responsável pela exatidão das informações do produto,
    licitude e origem do catálogo, rotulagem, informações de segurança e de uso
    exigidas para cada insumo, preço, estoque, embalagem, qualidade, envio,
    atendimento, garantia e cumprimento da oferta. Também é responsável por
    emitir documentos fiscais quando exigidos e por recolher tributos,
    contribuições e demais obrigações fiscais ou regulatórias decorrentes de
    suas vendas. O distribuidor declara publicamente, na loja, se emite nota
    fiscal, e responde pela veracidade dessa declaração. A EloShop não valida
    documentos fiscais nem presta consultoria tributária.

    8. Uso da plataforma e suspensão
    O distribuidor deve manter dados verdadeiros, uma conta Mercado Pago
    elegível e cumprir estes termos, as leis aplicáveis e as regras do gateway.
    A EloShop poderá suspender temporariamente o catálogo, a conta ou os
    repasses quando houver risco de fraude, chargeback, irregularidade,
    descumprimento, solicitação do gateway ou necessidade de proteção de
    compradores e da plataforma. A suspensão alcança também a conta de ateliê
    mantida pelo mesmo titular na EloShop. A suspensão não elimina obrigações
    já constituídas.

    9. Encerramento
    O distribuidor pode solicitar o encerramento da conta, desde que cumpra
    pedidos, reembolsos, disputas, obrigações fiscais e demais
    responsabilidades pendentes. A EloShop poderá encerrar a relação por
    descumprimento, risco operacional ou decisão de descontinuação do serviço.
    Registros necessários para auditoria, prevenção à fraude, obrigações legais
    e solução de controvérsias poderão ser preservados pelo prazo aplicável.

    10. Alterações
    A EloShop poderá alterar estes termos para refletir mudanças legais,
    operacionais, comerciais ou do gateway. Cada alteração terá nova versão.
    Quando a alteração exigir novo aceite, o acesso operacional e a publicação
    permanecerão bloqueados até que o distribuidor aceite a nova versão. A
    versão, texto integral, data, usuário e evidências técnicas do aceite serão
    registrados.

    11. Aceite
    Ao marcar a caixa de aceite e concluir o cadastro ou a confirmação no
    painel, o distribuidor declara que leu e concorda com estes termos
    comerciais.
  TEXT

  VERSIONS = { "atelier" => VERSION, "distributor" => DISTRIBUTOR_VERSION }.freeze
  TEXTS = { "atelier" => TEXT, "distributor" => DISTRIBUTOR_TEXT }.freeze

  # Versão e texto vigentes para o tipo de vendedor (`Seller#kind`). Sem tipo,
  # os do ateliê: a página pública `/painel/termos-comerciais` e o cadastro do
  # ateliê são dele. Tipo desconhecido é erro, não fallback.
  def self.version(kind = "atelier")
    VERSIONS.fetch(kind.to_s)
  end

  def self.text(kind = "atelier")
    TEXTS.fetch(kind.to_s)
  end

  # As versões vigentes de todos os tipos. Como o aceite é gravado com a versão
  # do tipo do próprio vendedor, "aceitou a vigente" é aceitar qualquer uma
  # destas — o ateliê nunca grava a versão do distribuidor.
  def self.current_versions
    VERSIONS.values
  end
end
