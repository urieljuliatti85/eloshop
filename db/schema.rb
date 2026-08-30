# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_30_222845) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addresses", force: :cascade do |t|
    t.string "city"
    t.string "complement"
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.string "neighborhood"
    t.string "number"
    t.string "state"
    t.string "street"
    t.datetime "updated_at", null: false
    t.string "zip_code"
    t.index ["customer_id"], name: "index_addresses_on_customer_id"
  end

  create_table "cart_items", force: :cascade do |t|
    t.bigint "cart_id", null: false
    t.datetime "created_at", null: false
    t.string "personalization_digest", default: "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", null: false
    t.jsonb "personalizations", default: [], null: false
    t.bigint "product_id", null: false
    t.bigint "product_variant_id"
    t.integer "quantity", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index "cart_id, product_id, COALESCE(product_variant_id, (0)::bigint), personalization_digest", name: "index_cart_items_on_cart_product_variant_and_personalization", unique: true
    t.index ["cart_id"], name: "index_cart_items_on_cart_id"
    t.index ["product_id"], name: "index_cart_items_on_product_id"
    t.index ["product_variant_id"], name: "index_cart_items_on_product_variant_id"
  end

  create_table "carts", force: :cascade do |t|
    t.bigint "coupon_id"
    t.datetime "created_at", null: false
    t.bigint "customer_id"
    t.string "session_token", null: false
    t.datetime "updated_at", null: false
    t.index ["coupon_id"], name: "index_carts_on_coupon_id"
    t.index ["customer_id"], name: "index_carts_on_customer_id"
    t.index ["session_token"], name: "index_carts_on_session_token", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "parent_id"
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id", "name"], name: "index_categories_on_parent_id_and_name", unique: true
    t.index ["parent_id"], name: "index_categories_on_parent_id"
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "coupons", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "amount_cents"
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "discount_type", null: false
    t.datetime "expires_at"
    t.integer "max_uses"
    t.integer "minimum_subtotal_cents"
    t.integer "percentage"
    t.datetime "starts_at"
    t.datetime "updated_at", null: false
    t.integer "uses_count", default: 0, null: false
    t.index ["code"], name: "index_coupons_on_code", unique: true
  end

  create_table "customer_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["customer_id"], name: "index_customer_sessions_on_customer_id"
  end

  create_table "customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_customers_on_email", unique: true
  end

  create_table "materials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_materials_on_lower_name", unique: true
    t.index ["slug"], name: "index_materials_on_slug", unique: true
  end

  create_table "order_items", force: :cascade do |t|
    t.string "color_snapshot"
    t.datetime "created_at", null: false
    t.string "material_snapshot"
    t.bigint "order_id", null: false
    t.jsonb "personalizations", default: [], null: false
    t.bigint "product_id", null: false
    t.string "product_name", null: false
    t.bigint "product_variant_id"
    t.string "production_time_snapshot"
    t.integer "quantity", null: false
    t.string "size_snapshot"
    t.string "sku", null: false
    t.integer "unit_price_cents", null: false
    t.datetime "updated_at", null: false
    t.string "variant_sku"
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id"], name: "index_order_items_on_product_id"
    t.index ["product_variant_id"], name: "index_order_items_on_product_variant_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "coupon_id"
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.integer "discount_cents", default: 0, null: false
    t.string "idempotency_key", null: false
    t.jsonb "shipping_address_snapshot", null: false
    t.integer "shipping_cents", null: false
    t.string "status", default: "pending", null: false
    t.integer "subtotal_cents", null: false
    t.integer "total_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["coupon_id"], name: "index_orders_on_coupon_id"
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["idempotency_key"], name: "index_orders_on_idempotency_key", unique: true
  end

  create_table "payment_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "gateway_event_id", null: false
    t.jsonb "payload"
    t.bigint "payment_id", null: false
    t.datetime "processed_at"
    t.datetime "updated_at", null: false
    t.index ["gateway_event_id"], name: "index_payment_events_on_gateway_event_id", unique: true
    t.index ["payment_id"], name: "index_payment_events_on_payment_id"
  end

  create_table "payments", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "external_id", null: false
    t.string "gateway", null: false
    t.bigint "order_id", null: false
    t.text "pix_qr_code"
    t.text "pix_qr_code_base64"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_payments_on_order_id"
  end

  create_table "personalization_options", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "label", null: false
    t.integer "max_length", default: 100, null: false
    t.bigint "product_id", null: false
    t.boolean "required", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "label"], name: "index_personalization_options_on_product_id_and_label", unique: true
    t.index ["product_id"], name: "index_personalization_options_on_product_id"
    t.check_constraint "max_length > 0", name: "personalization_options_max_length_check"
  end

  create_table "product_materials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "material_id", null: false
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["material_id"], name: "index_product_materials_on_material_id"
    t.index ["product_id", "material_id"], name: "index_product_materials_on_product_id_and_material_id", unique: true
    t.index ["product_id"], name: "index_product_materials_on_product_id"
  end

  create_table "product_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "tag_id"], name: "index_product_tags_on_product_id_and_tag_id", unique: true
    t.index ["product_id"], name: "index_product_tags_on_product_id"
    t.index ["tag_id"], name: "index_product_tags_on_tag_id"
  end

  create_table "product_techniques", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.bigint "technique_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "technique_id"], name: "index_product_techniques_on_product_id_and_technique_id", unique: true
    t.index ["product_id"], name: "index_product_techniques_on_product_id"
    t.index ["technique_id"], name: "index_product_techniques_on_technique_id"
  end

  create_table "product_variants", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "color"
    t.datetime "created_at", null: false
    t.string "material"
    t.integer "price_cents", null: false
    t.bigint "product_id", null: false
    t.string "size"
    t.string "sku", null: false
    t.integer "stock_quantity", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index "product_id, COALESCE(size, ''::character varying), COALESCE(color, ''::character varying), COALESCE(material, ''::character varying)", name: "index_product_variants_on_product_and_combination", unique: true
    t.index ["product_id"], name: "index_product_variants_on_product_id"
    t.index ["sku"], name: "index_product_variants_on_sku", unique: true
    t.check_constraint "price_cents >= 0", name: "product_variants_price_cents_check"
    t.check_constraint "stock_quantity >= 0", name: "product_variants_stock_quantity_check"
  end

  create_table "products", force: :cascade do |t|
    t.string "availability_type", default: "standard", null: false
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.string "currency", default: "BRL", null: false
    t.text "description"
    t.integer "height_cm"
    t.integer "length_cm"
    t.string "name", null: false
    t.integer "price_cents", null: false
    t.integer "production_time_max_days"
    t.integer "production_time_min_days"
    t.string "sku", null: false
    t.string "slug", null: false
    t.string "status", default: "draft", null: false
    t.integer "stock_quantity", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "weight_grams"
    t.integer "width_cm"
    t.index ["availability_type"], name: "index_products_on_availability_type"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["sku"], name: "index_products_on_sku", unique: true
    t.index ["slug"], name: "index_products_on_slug", unique: true
    t.index ["status"], name: "index_products_on_status"
    t.check_constraint "stock_quantity >= 0", name: "products_stock_quantity_check"
  end

  create_table "reviews", force: :cascade do |t|
    t.text "comment", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.bigint "product_id", null: false
    t.integer "rating", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.boolean "verified_purchase", default: false, null: false
    t.index ["customer_id", "product_id"], name: "index_reviews_on_customer_id_and_product_id", unique: true
    t.index ["customer_id"], name: "index_reviews_on_customer_id"
    t.index ["product_id"], name: "index_reviews_on_product_id"
    t.index ["status"], name: "index_reviews_on_status"
    t.check_constraint "rating >= 1 AND rating <= 5", name: "reviews_rating_range_check"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "shipments", force: :cascade do |t|
    t.string "carrier", null: false
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.integer "estimated_days", null: false
    t.bigint "order_id", null: false
    t.string "service", null: false
    t.datetime "shipped_at"
    t.integer "shipping_cents", null: false
    t.string "status", default: "pending", null: false
    t.string "tracking_code"
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_shipments_on_order_id"
    t.index ["tracking_code"], name: "index_shipments_on_tracking_code", unique: true
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_tags_on_lower_name", unique: true
    t.index ["slug"], name: "index_tags_on_slug", unique: true
  end

  create_table "techniques", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_techniques_on_lower_name", unique: true
    t.index ["slug"], name: "index_techniques_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.string "role", default: "admin", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "wishlist_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "product_id"], name: "index_wishlist_items_on_customer_id_and_product_id", unique: true
    t.index ["customer_id"], name: "index_wishlist_items_on_customer_id"
    t.index ["product_id"], name: "index_wishlist_items_on_product_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "addresses", "customers"
  add_foreign_key "cart_items", "carts"
  add_foreign_key "cart_items", "product_variants"
  add_foreign_key "cart_items", "products"
  add_foreign_key "carts", "coupons"
  add_foreign_key "carts", "customers"
  add_foreign_key "categories", "categories", column: "parent_id"
  add_foreign_key "customer_sessions", "customers"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "product_variants"
  add_foreign_key "order_items", "products"
  add_foreign_key "orders", "coupons"
  add_foreign_key "orders", "customers"
  add_foreign_key "payment_events", "payments"
  add_foreign_key "payments", "orders"
  add_foreign_key "personalization_options", "products"
  add_foreign_key "product_materials", "materials"
  add_foreign_key "product_materials", "products"
  add_foreign_key "product_tags", "products"
  add_foreign_key "product_tags", "tags"
  add_foreign_key "product_techniques", "products"
  add_foreign_key "product_techniques", "techniques"
  add_foreign_key "product_variants", "products"
  add_foreign_key "products", "categories"
  add_foreign_key "reviews", "customers"
  add_foreign_key "reviews", "products"
  add_foreign_key "sessions", "users"
  add_foreign_key "shipments", "orders", on_delete: :cascade
  add_foreign_key "wishlist_items", "customers"
  add_foreign_key "wishlist_items", "products"
end
