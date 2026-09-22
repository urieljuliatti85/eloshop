class SellerTerms
  VERSION = "seller-marketplace-v1-2026-09-22".freeze

  TEXT = <<~TEXT.freeze
    TERMOS COMERCIAIS DO MARKETPLACE ELOSHOP — VERSÃO 2026-09-22

    1. Objeto e independência comercial
    A EloShop opera uma plataforma tecnológica e de marketplace para divulgação,
    intermediação e operação de vendas de produtos artesanais. O artesão vende
    como responsável independente por seu catálogo, produção, qualidade,
    disponibilidade, entrega, atendimento e obrigações legais. Estes termos não
    constituem vínculo empregatício, sociedade, representação comercial ou
    garantia de volume mínimo de vendas.

    2. Comissão e base de cálculo
    A comissão da EloShop é de 15% (quinze por cento) do subtotal dos produtos
    efetivamente vendidos, após descontos aplicados ao pedido. O frete não
    integra a base de cálculo da comissão. A comissão e os valores do pedido
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

  def self.version
    VERSION
  end

  def self.text
    TEXT
  end
end
