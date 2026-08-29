class StorefrontController < ApplicationController
  include Carting
  include CustomerAuthentication

  allow_unauthenticated_access

  # Autenticação de cliente NÃO é liberada aqui de forma geral: cada
  # controller decide se e quais ações ficam abertas (ver ProductsController,
  # CartsController, CartItemsController, CustomersController,
  # CustomerSessionsController). AddressesController não libera nenhuma,
  # exigindo cliente autenticado em todas as ações.
end
