module AuthenticationHelpers
  def clear_product_data!
    ActiveRecord::Base.connection.execute(
      <<~SQL
        TRUNCATE TABLE
          cart_items,
          order_items,
          personalization_options,
          product_variants,
          product_tags,
          product_materials,
          product_techniques,
          reviews,
          wishlist_items,
          products
        RESTART IDENTITY CASCADE
      SQL
    )
  end

  def sign_in_as(user, password: "password123")
    post session_path, params: { email_address: user.email_address, password: password }
    follow_redirect! if response.redirect?
  end

  def sign_out
    delete session_path if respond_to?(:delete)
  end
end
