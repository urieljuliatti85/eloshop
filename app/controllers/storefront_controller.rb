class StorefrontController < ApplicationController
  include Carting

  allow_unauthenticated_access
end
