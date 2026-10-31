class SellerTerms
  VERSION = "seller-marketplace-v3-2026-10-31".freeze

  TEXT = <<~TEXT.freeze
    TERMOS COMERCIAIS DO MARKETPLACE ELOSHOP — VERSÃO 2026-10-31

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

    3. Tarifas, recebimento e saldo
    O Mercado Pago processa o pagamento e pode cobrar tarifas próprias. As
    tarifas do Mercado Pago são de responsabilidade do artesão e são separadas
    da comissão da EloShop. O repasse é feito pelo mecanismo de split autorizado
    pelo Mercado Pago, para a conta conectada pelo artesão, conforme os prazos,
    regras de disponibilidade e retenções do provedor. A EloShop não promete
    prazo de liberação diferente do informado pelo Mercado Pago. O valor das
    vendas é recebido diretamente na conta do artesão: a EloShop não guarda nem
    administra esse dinheiro.
    O artesão deve manter saldo disponível na conta Mercado Pago conectada
    suficiente para reembolsos e chargebacks das suas vendas. No split, o
    reembolso é retirado proporcionalmente da conta do artesão e da conta da
    EloShop, e o Mercado Pago recusa o reembolso quando não há saldo disponível
    em qualquer uma delas.

    4. Cancelamentos, devoluções, reembolsos e chargebacks
    A EloShop recebe e acompanha as solicitações de cancelamento, devolução,
    reembolso e as reclamações relacionadas às compras feitas na plataforma, e
    pode promover cancelamentos e reembolsos, observadas a legislação, as
    regras do Mercado Pago e a Política de Trocas, Devoluções, Cancelamentos e
    Reembolsos. Quando necessário, a EloShop entrará em contato com o artesão
    para obter informações sobre o pedido, o andamento da produção, a entrega
    ou o produto, inclusive pelas mensagens do pedido.
    Os reembolsos são feitos pelo Mercado Pago, na forma de pagamento usada
    pelo comprador. A comissão correspondente é revertida proporcionalmente ao
    valor reembolsado, conforme o registro financeiro do pedido. Os ajustes
    entre a EloShop e o artesão não reduzem o reembolso devido ao comprador.
    Nas devoluções em que a lei assegura ao comprador a devolução sem custo,
    como no exercício do direito de arrependimento, em caso de vício do produto
    ou de entrega em desacordo com a oferta, o frete da devolução é de
    responsabilidade do artesão.
    O início da produção de uma peça sob encomenda, registrado pelo artesão no
    painel, não elimina, por si só, os direitos legais do consumidor.
    Chargebacks, estornos e bloqueios decorrentes de fraude, contestação ou
    descumprimento imputável à venda são debitados pelo Mercado Pago da conta
    conectada pelo artesão, conforme os procedimentos do provedor, respeitados
    a lei e o direito de apresentação de informações e defesa. A EloShop
    poderá solicitar comprovantes de produção, envio, entrega e atendimento.
    Se um reembolso não puder ser concluído por falta de saldo na conta do
    artesão, aplica-se o item 6.

    5. Responsabilidades do artesão
    O artesão é responsável pela exatidão das informações do produto, autoria e
    licitude do catálogo, preço, estoque, prazo de produção, embalagem,
    qualidade, segurança, envio, atendimento, garantia e cumprimento da oferta.
    Deve manter o anúncio correto e completo, observar as características e os
    prazos contratados, entregar o produto nas condições oferecidas e colaborar
    com a solução das solicitações dos compradores.
    Também é responsável por emitir documentos fiscais quando exigidos e por
    recolher tributos, contribuições e demais obrigações fiscais ou regulatórias
    decorrentes de suas vendas. A EloShop não presta consultoria tributária.

    6. Uso da plataforma e suspensão
    O artesão deve manter dados verdadeiros, uma conta Mercado Pago elegível e
    cumprir estes termos, as leis aplicáveis e as regras do gateway. A EloShop
    poderá suspender temporariamente o catálogo, a conta ou os repasses quando
    houver risco de fraude, chargeback, irregularidade, descumprimento,
    falta de saldo para reembolso, solicitação do gateway ou necessidade de
    proteção de clientes e da plataforma. A suspensão não elimina obrigações
    já constituídas.

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
