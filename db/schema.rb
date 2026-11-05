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

ActiveRecord::Schema[8.1].define(version: 2026_11_05_141633) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addresses", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "street"
    t.string "number"
    t.string "complement"
    t.string "neighborhood"
    t.string "city"
    t.string "state"
    t.string "zip_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_addresses_on_customer_id"
  end

  create_table "api_clients", force: :cascade do |t|
    t.string "name", null: false
    t.string "token_digest", null: false
    t.datetime "revoked_at"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_api_clients_on_name", unique: true
    t.index ["token_digest"], name: "index_api_clients_on_token_digest", unique: true
  end

  create_table "cart_items", force: :cascade do |t|
    t.bigint "cart_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "product_variant_id"
    t.jsonb "personalizations", default: [], null: false
    t.string "personalization_digest", default: "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945", null: false
    t.index "cart_id, product_id, COALESCE(product_variant_id, (0)::bigint), personalization_digest", name: "index_cart_items_on_cart_product_variant_and_personalization", unique: true
    t.index ["cart_id"], name: "index_cart_items_on_cart_id"
    t.index ["product_id"], name: "index_cart_items_on_product_id"
    t.index ["product_variant_id"], name: "index_cart_items_on_product_variant_id"
  end

  create_table "carts", force: :cascade do |t|
    t.string "session_token", null: false
    t.bigint "customer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "coupon_id"
    t.index ["coupon_id"], name: "index_carts_on_coupon_id"
    t.index ["customer_id"], name: "index_carts_on_customer_id"
    t.index ["session_token"], name: "index_carts_on_session_token", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.bigint "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: true, null: false
    t.index ["parent_id", "name"], name: "index_categories_on_parent_id_and_name", unique: true
    t.index ["parent_id"], name: "index_categories_on_parent_id"
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "category_suggestion_requests", force: :cascade do |t|
    t.bigint "category_suggestion_id", null: false
    t.bigint "seller_id", null: false
    t.datetime "notified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_suggestion_id", "seller_id"], name: "index_category_suggestion_requests_on_suggestion_and_seller", unique: true
    t.index ["category_suggestion_id"], name: "index_category_suggestion_requests_on_category_suggestion_id"
    t.index ["seller_id"], name: "index_category_suggestion_requests_on_seller_id"
  end

  create_table "category_suggestions", force: :cascade do |t|
    t.string "name", limit: 60, null: false
    t.string "normalized_key", limit: 80, null: false
    t.string "status", default: "pending", null: false
    t.bigint "category_id"
    t.bigint "decided_by_user_id"
    t.datetime "decided_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_category_suggestions_on_category_id"
    t.index ["decided_by_user_id"], name: "index_category_suggestions_on_decided_by_user_id"
    t.index ["normalized_key"], name: "index_category_suggestions_on_pending_key", unique: true, where: "((status)::text = 'pending'::text)"
    t.index ["status", "created_at"], name: "index_category_suggestions_on_status_and_created_at"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'accepted'::character varying, 'rejected'::character varying]::text[])", name: "category_suggestions_status_check"
  end

  create_table "coupons", force: :cascade do |t|
    t.string "code", null: false
    t.string "discount_type", null: false
    t.integer "percentage"
    t.integer "amount_cents"
    t.integer "minimum_subtotal_cents"
    t.integer "max_uses"
    t.integer "uses_count", default: 0, null: false
    t.datetime "starts_at"
    t.datetime "expires_at"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_coupons_on_code", unique: true
  end

  create_table "customer_sessions", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_customer_sessions_on_customer_id"
  end

  create_table "customers", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_customers_on_email", unique: true
  end

  create_table "fraud_alerts", force: :cascade do |t|
    t.bigint "seller_id", null: false
    t.string "rule", null: false
    t.jsonb "detail", default: {}, null: false
    t.datetime "detected_at", null: false
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["resolved_at"], name: "index_fraud_alerts_on_resolved_at"
    t.index ["seller_id", "rule"], name: "index_fraud_alerts_one_open_per_seller_rule", unique: true, where: "(resolved_at IS NULL)"
    t.index ["seller_id"], name: "index_fraud_alerts_on_seller_id"
  end

  create_table "funnel_events", force: :cascade do |t|
    t.string "event_name", null: false
    t.date "occurred_on", null: false
    t.bigint "product_id"
    t.bigint "seller_id"
    t.integer "event_count", default: 0, null: false
    t.integer "amount_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_name", "occurred_on", "product_id", "seller_id"], name: "index_funnel_events_on_dimensions", unique: true, nulls_not_distinct: true
    t.index ["occurred_on", "event_name"], name: "index_funnel_events_on_occurred_on_and_event_name"
    t.check_constraint "amount_cents >= 0", name: "funnel_events_amount_cents_check"
    t.check_constraint "event_count >= 0", name: "funnel_events_event_count_check"
  end

  create_table "materials", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_materials_on_lower_name", unique: true
    t.index ["slug"], name: "index_materials_on_slug", unique: true
  end

  create_table "mercado_pago_test_accounts", force: :cascade do |t|
    t.string "account_type", null: false
    t.string "label", null: false
    t.string "email"
    t.string "mercado_pago_user_id"
    t.string "username"
    t.text "password_ciphertext"
    t.string "verification_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_type"], name: "index_mercado_pago_test_accounts_on_account_type"
  end

  create_table "notifications", force: :cascade do |t|
    t.string "recipient_type", null: false
    t.bigint "recipient_id", null: false
    t.string "kind", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.string "url"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recipient_type", "recipient_id", "created_at", "id"], name: "index_notifications_on_recipient_and_created_at", order: { created_at: :desc, id: :desc }
    t.index ["recipient_type", "recipient_id", "read_at"], name: "idx_on_recipient_type_recipient_id_read_at_50191a301d"
  end

  create_table "order_events", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.string "kind", null: false
    t.string "status"
    t.string "error_class"
    t.text "error_message"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id", "created_at"], name: "index_order_events_on_order_id_and_created_at"
    t.index ["order_id"], name: "index_order_events_on_order_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "product_id", null: false
    t.string "product_name", null: false
    t.string "sku", null: false
    t.integer "unit_price_cents", null: false
    t.integer "quantity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "production_time_snapshot"
    t.bigint "product_variant_id"
    t.string "variant_sku"
    t.string "size_snapshot"
    t.string "color_snapshot"
    t.string "material_snapshot"
    t.jsonb "personalizations", default: [], null: false
    t.bigint "seller_order_id", null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id"], name: "index_order_items_on_product_id"
    t.index ["product_variant_id"], name: "index_order_items_on_product_variant_id"
    t.index ["seller_order_id"], name: "index_order_items_on_seller_order_id"
  end

  create_table "order_messages", force: :cascade do |t|
    t.bigint "seller_order_id", null: false
    t.string "sender_type", null: false
    t.bigint "sender_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["seller_order_id", "created_at", "id"], name: "index_order_messages_on_conversation_order"
    t.index ["seller_order_id"], name: "index_order_messages_on_seller_order_id"
    t.index ["sender_type", "sender_id"], name: "index_order_messages_on_sender"
    t.check_constraint "char_length(btrim(body)) >= 1 AND char_length(btrim(body)) <= 2000", name: "order_messages_body_length_check"
    t.check_constraint "sender_type::text = ANY (ARRAY['Customer'::character varying::text, 'User'::character varying::text])", name: "order_messages_sender_type_check"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "status", default: "pending", null: false
    t.integer "subtotal_cents", null: false
    t.integer "shipping_cents", null: false
    t.integer "total_cents", null: false
    t.jsonb "shipping_address_snapshot", null: false
    t.string "idempotency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "coupon_id"
    t.integer "discount_cents", default: 0, null: false
    t.string "recipient_name"
    t.string "recipient_phone"
    t.text "recipient_cpf_ciphertext"
    t.index ["coupon_id"], name: "index_orders_on_coupon_id"
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["idempotency_key"], name: "index_orders_on_idempotency_key", unique: true
  end

  create_table "payment_events", force: :cascade do |t|
    t.bigint "payment_id", null: false
    t.string "gateway_event_id", null: false
    t.jsonb "payload"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["gateway_event_id"], name: "index_payment_events_on_gateway_event_id", unique: true
    t.index ["payment_id"], name: "index_payment_events_on_payment_id"
  end

  create_table "payment_refunds", force: :cascade do |t|
    t.bigint "payment_id", null: false
    t.string "external_id"
    t.string "idempotency_key", null: false
    t.string "status", default: "processing", null: false
    t.integer "amount_cents", null: false
    t.integer "application_fee_amount_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "settlement", default: "gateway", null: false
    t.text "manual_reference"
    t.bigint "recorded_by_id"
    t.index ["idempotency_key"], name: "index_payment_refunds_on_idempotency_key", unique: true
    t.index ["payment_id"], name: "index_payment_refunds_on_payment_id"
    t.index ["recorded_by_id"], name: "index_payment_refunds_on_recorded_by_id"
    t.check_constraint "amount_cents > 0", name: "payment_refunds_amount_check"
    t.check_constraint "application_fee_amount_cents >= 0 AND application_fee_amount_cents <= amount_cents", name: "payment_refunds_fee_check"
    t.check_constraint "settlement::text <> 'manual'::text OR recorded_by_id IS NOT NULL AND char_length(btrim(manual_reference)) >= 3 AND char_length(btrim(manual_reference)) <= 500", name: "payment_refunds_manual_proof_check"
    t.check_constraint "settlement::text = ANY (ARRAY['gateway'::character varying, 'manual'::character varying]::text[])", name: "payment_refunds_settlement_check"
    t.check_constraint "status::text = ANY (ARRAY['processing'::character varying::text, 'approved'::character varying::text, 'failed'::character varying::text])", name: "payment_refunds_status_check"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.string "gateway", null: false
    t.string "external_id"
    t.string "status", default: "pending", null: false
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "pix_qr_code"
    t.text "pix_qr_code_base64"
    t.datetime "expires_at"
    t.string "idempotency_key", null: false
    t.integer "application_fee_cents", default: 0, null: false
    t.integer "processor_fee_cents"
    t.integer "refunded_amount_cents", default: 0, null: false
    t.integer "application_fee_refunded_cents", default: 0, null: false
    t.string "payment_method", default: "pix", null: false
    t.integer "installments", default: 1, null: false
    t.string "card_last_four"
    t.string "card_brand"
    t.index ["idempotency_key"], name: "index_payments_on_idempotency_key", unique: true
    t.index ["order_id"], name: "index_payments_on_order_id"
    t.check_constraint "application_fee_cents >= 0 AND application_fee_cents <= amount_cents", name: "payments_application_fee_check"
    t.check_constraint "application_fee_refunded_cents >= 0 AND application_fee_refunded_cents <= application_fee_cents", name: "payments_application_fee_refunded_check"
    t.check_constraint "installments >= 1", name: "payments_installments_check"
    t.check_constraint "payment_method::text = ANY (ARRAY['pix'::character varying::text, 'credit_card'::character varying::text])", name: "payments_payment_method_check"
    t.check_constraint "processor_fee_cents IS NULL OR processor_fee_cents >= 0", name: "payments_processor_fee_check"
    t.check_constraint "refunded_amount_cents >= 0 AND refunded_amount_cents <= amount_cents", name: "payments_refunded_amount_check"
  end

  create_table "personalization_options", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "label", null: false
    t.boolean "required", default: false, null: false
    t.integer "max_length", default: 100, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "label"], name: "index_personalization_options_on_product_id_and_label", unique: true
    t.index ["product_id"], name: "index_personalization_options_on_product_id"
    t.check_constraint "max_length > 0", name: "personalization_options_max_length_check"
  end

  create_table "platform_settings", force: :cascade do |t|
    t.datetime "sales_opened_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.check_constraint "id = 1", name: "platform_settings_singleton_check"
  end

  create_table "product_materials", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "material_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["material_id"], name: "index_product_materials_on_material_id"
    t.index ["product_id", "material_id"], name: "index_product_materials_on_product_id_and_material_id", unique: true
    t.index ["product_id"], name: "index_product_materials_on_product_id"
  end

  create_table "product_tags", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "tag_id"], name: "index_product_tags_on_product_id_and_tag_id", unique: true
    t.index ["product_id"], name: "index_product_tags_on_product_id"
    t.index ["tag_id"], name: "index_product_tags_on_tag_id"
  end

  create_table "product_techniques", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "technique_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "technique_id"], name: "index_product_techniques_on_product_id_and_technique_id", unique: true
    t.index ["product_id"], name: "index_product_techniques_on_product_id"
    t.index ["technique_id"], name: "index_product_techniques_on_technique_id"
  end

  create_table "product_variants", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "sku", null: false
    t.integer "price_cents", null: false
    t.integer "stock_quantity", default: 0, null: false
    t.string "size"
    t.string "color"
    t.string "material"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "product_id, COALESCE(size, ''::character varying), COALESCE(color, ''::character varying), COALESCE(material, ''::character varying)", name: "index_product_variants_on_product_and_combination", unique: true
    t.index ["product_id"], name: "index_product_variants_on_product_id"
    t.index ["sku"], name: "index_product_variants_on_sku", unique: true
    t.check_constraint "price_cents >= 0", name: "product_variants_price_cents_check"
    t.check_constraint "stock_quantity >= 0", name: "product_variants_stock_quantity_check"
  end

  create_table "products", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.integer "price_cents", null: false
    t.string "currency", default: "BRL", null: false
    t.string "sku", null: false
    t.integer "stock_quantity", default: 0, null: false
    t.string "status", default: "draft", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "availability_type", default: "standard", null: false
    t.integer "production_time_min_days"
    t.integer "production_time_max_days"
    t.bigint "category_id"
    t.integer "weight_grams"
    t.integer "length_cm"
    t.integer "width_cm"
    t.integer "height_cm"
    t.bigint "seller_id", null: false
    t.integer "fixed_shipping_cents"
    t.integer "fixed_shipping_estimated_days"
    t.boolean "local_pickup_enabled", default: false, null: false
    t.boolean "free_shipping", default: false, null: false
    t.integer "fixed_shipping_interstate_cents"
    t.integer "fixed_shipping_interstate_estimated_days"
    t.index ["availability_type"], name: "index_products_on_availability_type"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["seller_id", "sku"], name: "index_products_on_seller_id_and_sku", unique: true
    t.index ["seller_id", "slug"], name: "index_products_on_seller_id_and_slug", unique: true
    t.index ["seller_id"], name: "index_products_on_seller_id"
    t.index ["status"], name: "index_products_on_status"
    t.check_constraint "(fixed_shipping_cents IS NULL) = (fixed_shipping_estimated_days IS NULL)", name: "products_fixed_shipping_complete_check"
    t.check_constraint "(fixed_shipping_interstate_cents IS NULL) = (fixed_shipping_interstate_estimated_days IS NULL)", name: "products_fixed_shipping_interstate_complete_check"
    t.check_constraint "fixed_shipping_cents IS NULL OR fixed_shipping_cents > 0", name: "products_fixed_shipping_cents_check"
    t.check_constraint "fixed_shipping_estimated_days IS NULL OR fixed_shipping_estimated_days > 0", name: "products_fixed_shipping_days_check"
    t.check_constraint "fixed_shipping_interstate_cents IS NULL OR fixed_shipping_cents IS NOT NULL", name: "products_fixed_shipping_interstate_requires_base_check"
    t.check_constraint "fixed_shipping_interstate_cents IS NULL OR fixed_shipping_interstate_cents > 0", name: "products_fixed_shipping_interstate_cents_check"
    t.check_constraint "fixed_shipping_interstate_estimated_days IS NULL OR fixed_shipping_interstate_estimated_days > 0", name: "products_fixed_shipping_interstate_days_check"
    t.check_constraint "stock_quantity >= 0", name: "products_stock_quantity_check"
  end

  create_table "return_request_items", force: :cascade do |t|
    t.bigint "return_request_id", null: false
    t.bigint "order_item_id", null: false
    t.integer "quantity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_item_id"], name: "index_return_request_items_on_order_item_id"
    t.index ["return_request_id", "order_item_id"], name: "idx_on_return_request_id_order_item_id_e928f5b641", unique: true
    t.index ["return_request_id"], name: "index_return_request_items_on_return_request_id"
    t.check_constraint "quantity > 0", name: "return_request_items_quantity_check"
  end

  create_table "return_request_updates", force: :cascade do |t|
    t.bigint "return_request_id", null: false
    t.string "author_type", null: false
    t.bigint "author_id", null: false
    t.text "body"
    t.string "from_status"
    t.string "to_status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_return_request_updates_on_author"
    t.index ["return_request_id"], name: "index_return_request_updates_on_return_request_id"
    t.check_constraint "author_type::text = ANY (ARRAY['Customer'::character varying, 'User'::character varying]::text[])", name: "return_request_updates_author_type_check"
    t.check_constraint "body IS NULL OR char_length(body) <= 2000", name: "return_request_updates_body_length_check"
    t.check_constraint "char_length(btrim(COALESCE(body, ''::text))) >= 1 OR to_status IS NOT NULL", name: "return_request_updates_content_check"
  end

  create_table "return_requests", force: :cascade do |t|
    t.bigint "seller_order_id", null: false
    t.string "kind", null: false
    t.string "status", default: "received", null: false
    t.text "description"
    t.date "respond_by", null: false
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.virtual "protocol", type: :string, as: "((('ELO-'::text || ((EXTRACT(year FROM created_at))::integer)::text) || '-'::text) || lpad((id)::text, 6, '0'::text))", stored: true
    t.index ["protocol"], name: "index_return_requests_on_protocol", unique: true
    t.index ["seller_order_id", "kind"], name: "index_return_requests_one_open_per_kind", unique: true, where: "((status)::text = ANY ((ARRAY['received'::character varying, 'in_progress'::character varying, 'awaiting_return'::character varying])::text[]))"
    t.index ["seller_order_id"], name: "index_return_requests_on_seller_order_id"
    t.index ["status", "respond_by"], name: "index_return_requests_on_status_and_respond_by"
    t.check_constraint "description IS NULL OR char_length(description) <= 2000", name: "return_requests_description_length_check"
    t.check_constraint "kind::text = ANY (ARRAY['withdrawal'::character varying, 'product_issue'::character varying, 'delivery_issue'::character varying]::text[])", name: "return_requests_kind_check"
    t.check_constraint "status::text = ANY (ARRAY['received'::character varying, 'in_progress'::character varying, 'awaiting_return'::character varying, 'resolved'::character varying, 'closed'::character varying]::text[])", name: "return_requests_status_check"
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "product_id", null: false
    t.integer "rating", null: false
    t.text "comment", null: false
    t.string "status", default: "pending", null: false
    t.boolean "verified_purchase", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "seller_reply"
    t.datetime "seller_replied_at"
    t.index ["customer_id", "product_id"], name: "index_reviews_on_customer_id_and_product_id", unique: true
    t.index ["customer_id"], name: "index_reviews_on_customer_id"
    t.index ["product_id"], name: "index_reviews_on_product_id"
    t.index ["status"], name: "index_reviews_on_status"
    t.check_constraint "rating >= 1 AND rating <= 5", name: "reviews_rating_range_check"
  end

  create_table "seller_orders", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "seller_id", null: false
    t.string "status", default: "pending", null: false
    t.string "currency", default: "BRL", null: false
    t.integer "subtotal_cents", null: false
    t.integer "discount_cents", default: 0, null: false
    t.integer "shipping_cents", null: false
    t.integer "total_cents", null: false
    t.integer "platform_fee_rate_bps", default: 1500, null: false
    t.integer "platform_fee_cents", null: false
    t.integer "seller_amount_cents", null: false
    t.integer "refunded_amount_cents", default: 0, null: false
    t.integer "platform_fee_refunded_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "production_started_at"
    t.index ["order_id", "seller_id"], name: "index_seller_orders_on_order_id_and_seller_id", unique: true
    t.index ["order_id"], name: "index_seller_orders_on_order_id"
    t.index ["seller_id"], name: "index_seller_orders_on_seller_id"
    t.check_constraint "discount_cents >= 0 AND discount_cents <= subtotal_cents", name: "seller_orders_discount_check"
    t.check_constraint "platform_fee_cents >= 0 AND platform_fee_cents <= (subtotal_cents - discount_cents)", name: "seller_orders_fee_check"
    t.check_constraint "platform_fee_rate_bps >= 0 AND platform_fee_rate_bps <= 10000", name: "seller_orders_fee_rate_check"
    t.check_constraint "platform_fee_refunded_cents >= 0 AND platform_fee_refunded_cents <= platform_fee_cents", name: "seller_orders_fee_refunded_check"
    t.check_constraint "refunded_amount_cents >= 0 AND refunded_amount_cents <= total_cents", name: "seller_orders_refunded_amount_check"
    t.check_constraint "seller_amount_cents = (total_cents - platform_fee_cents)", name: "seller_orders_seller_amount_check"
    t.check_constraint "shipping_cents >= 0", name: "seller_orders_shipping_check"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'confirmed'::character varying::text, 'cancelled'::character varying::text, 'partially_refunded'::character varying::text, 'refunded'::character varying::text])", name: "seller_orders_status_check"
    t.check_constraint "subtotal_cents >= 0", name: "seller_orders_subtotal_check"
    t.check_constraint "total_cents = (subtotal_cents - discount_cents + shipping_cents)", name: "seller_orders_total_check"
  end

  create_table "seller_reports", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "seller_id", null: false
    t.string "reason", null: false
    t.text "details"
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "seller_id"], name: "index_seller_reports_on_customer_id_and_seller_id", unique: true
    t.index ["customer_id"], name: "index_seller_reports_on_customer_id"
    t.index ["seller_id"], name: "index_seller_reports_on_seller_id"
    t.index ["status"], name: "index_seller_reports_on_status"
  end

  create_table "seller_terms_acceptances", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "seller_id", null: false
    t.string "terms_version", null: false
    t.text "terms_text", null: false
    t.string "terms_digest", null: false
    t.datetime "accepted_at", null: false
    t.string "ip_address", null: false
    t.text "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["seller_id"], name: "index_seller_terms_acceptances_on_seller_id"
    t.index ["user_id", "terms_version"], name: "index_seller_terms_acceptances_on_user_id_and_terms_version", unique: true
  end

  create_table "sellers", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "status", default: "pending", null: false
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "mercado_pago_user_id"
    t.text "mercado_pago_access_token_ciphertext"
    t.text "mercado_pago_refresh_token_ciphertext"
    t.datetime "mercado_pago_token_expires_at"
    t.datetime "mercado_pago_connected_at"
    t.boolean "mercado_pago_live_mode", default: false, null: false
    t.string "origin_zip_code"
    t.string "origin_street"
    t.string "origin_number"
    t.string "origin_complement"
    t.string "origin_neighborhood"
    t.string "origin_city"
    t.string "origin_state"
    t.boolean "mercado_pago_test_account"
    t.string "mercado_pago_public_key"
    t.string "owner_full_name"
    t.text "cpf_ciphertext"
    t.string "cpf_hash"
    t.datetime "hidden_at"
    t.datetime "tour_completed_at"
    t.datetime "pix_key_confirmed_at"
    t.string "footer_text", limit: 300
    t.string "theme_palette", default: "terracota", null: false
    t.string "theme_font", default: "moderna", null: false
    t.string "theme_layout", default: "grade", null: false
    t.string "theme_hero", default: "capa", null: false
    t.string "theme_sections", default: ["catalog", "about", "footer"], null: false, array: true
    t.string "theme_accent_color"
    t.string "theme_corners", default: "suaves", null: false
    t.string "theme_card_style", default: "limpo", null: false
    t.string "about_text", limit: 1000
    t.string "notice_text", limit: 140
    t.string "instagram_handle", limit: 30
    t.string "whatsapp_number", limit: 13
    t.string "theme_background", default: "branco", null: false
    t.string "theme_ornament", default: "nenhum", null: false
    t.string "theme_image_ratio", default: "quadrada", null: false
    t.string "theme_heading_font", default: "igual", null: false
    t.datetime "showcased_at"
    t.text "superfrete_access_token_ciphertext"
    t.string "superfrete_account_id"
    t.string "superfrete_account_email"
    t.datetime "superfrete_connected_at"
    t.boolean "superfrete_sandbox", default: false, null: false
    t.boolean "provider_quotes_preferred", default: false, null: false
    t.datetime "mercado_pago_disconnected_at"
    t.string "superfrete_oauth_state_digest"
    t.datetime "superfrete_oauth_state_issued_at"
    t.datetime "superfrete_revoked_at"
    t.index ["cpf_hash"], name: "index_sellers_on_cpf_hash", unique: true, where: "(cpf_hash IS NOT NULL)"
    t.index ["mercado_pago_user_id"], name: "index_sellers_on_mercado_pago_user_id", unique: true, where: "(mercado_pago_user_id IS NOT NULL)"
    t.index ["slug"], name: "index_sellers_on_slug", unique: true
    t.index ["superfrete_oauth_state_digest"], name: "index_sellers_on_superfrete_oauth_state_digest", unique: true, where: "(superfrete_oauth_state_digest IS NOT NULL)"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'approved'::character varying::text, 'suspended'::character varying::text])", name: "sellers_status_check"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "shipping_labels", force: :cascade do |t|
    t.bigint "shipment_id", null: false
    t.string "status", default: "draft", null: false
    t.string "provider_order_id"
    t.integer "service_code", null: false
    t.string "service_name", null: false
    t.integer "quoted_price_cents", null: false
    t.integer "price_cents"
    t.integer "height_cm", null: false
    t.integer "width_cm", null: false
    t.integer "length_cm", null: false
    t.integer "weight_grams", null: false
    t.string "tracking_code"
    t.boolean "sandbox", null: false
    t.string "superfrete_account_id", null: false
    t.string "failure_message"
    t.datetime "purchased_at"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_order_id"], name: "index_shipping_labels_on_provider_order_id", unique: true
    t.index ["shipment_id"], name: "index_shipping_labels_on_shipment_id"
    t.index ["shipment_id"], name: "index_shipping_labels_one_active_per_shipment", unique: true, where: "((status)::text = ANY ((ARRAY['draft'::character varying, 'cart_created'::character varying, 'purchasing'::character varying, 'purchased'::character varying])::text[]))"
    t.check_constraint "(status::text = ANY (ARRAY['draft'::character varying, 'failed'::character varying, 'cancelled'::character varying]::text[])) OR provider_order_id IS NOT NULL", name: "shipping_labels_provider_order_check"
    t.check_constraint "height_cm > 0 AND width_cm > 0 AND length_cm > 0 AND weight_grams > 0", name: "shipping_labels_package_check"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'cart_created'::character varying, 'purchasing'::character varying, 'purchased'::character varying, 'cancelled'::character varying, 'failed'::character varying]::text[])", name: "shipping_labels_status_check"
  end

  create_table "shipments", force: :cascade do |t|
    t.string "carrier", null: false
    t.string "service", null: false
    t.string "status", default: "pending", null: false
    t.string "tracking_code"
    t.integer "shipping_cents", null: false
    t.integer "estimated_days", null: false
    t.datetime "shipped_at"
    t.datetime "delivered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "seller_order_id", null: false
    t.datetime "customer_reported_delivered_at"
    t.index ["seller_order_id"], name: "index_shipments_on_seller_order_id"
    t.index ["tracking_code"], name: "index_shipments_on_tracking_code", unique: true
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_tags_on_lower_name", unique: true
    t.index ["slug"], name: "index_tags_on_slug", unique: true
  end

  create_table "techniques", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_techniques_on_lower_name", unique: true
    t.index ["slug"], name: "index_techniques_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "admin", null: false
    t.bigint "seller_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["seller_id"], name: "index_users_on_seller_id"
    t.check_constraint "role::text = 'admin'::text AND seller_id IS NULL OR role::text = 'seller'::text AND seller_id IS NOT NULL", name: "users_role_seller_check"
  end

  create_table "versions", force: :cascade do |t|
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.jsonb "object_changes"
    t.datetime "created_at", null: false
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["whodunnit"], name: "index_versions_on_whodunnit"
  end

  create_table "wishlist_items", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "product_id", null: false
    t.datetime "created_at", null: false
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
  add_foreign_key "category_suggestion_requests", "category_suggestions"
  add_foreign_key "category_suggestion_requests", "sellers"
  add_foreign_key "category_suggestions", "categories", on_delete: :nullify
  add_foreign_key "category_suggestions", "users", column: "decided_by_user_id", on_delete: :nullify
  add_foreign_key "customer_sessions", "customers"
  add_foreign_key "fraud_alerts", "sellers", on_delete: :cascade
  add_foreign_key "funnel_events", "products"
  add_foreign_key "funnel_events", "sellers"
  add_foreign_key "order_events", "orders", on_delete: :cascade
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "product_variants"
  add_foreign_key "order_items", "products"
  add_foreign_key "order_items", "seller_orders", on_delete: :cascade
  add_foreign_key "order_messages", "seller_orders", on_delete: :cascade
  add_foreign_key "orders", "coupons"
  add_foreign_key "orders", "customers"
  add_foreign_key "payment_events", "payments"
  add_foreign_key "payment_refunds", "payments", on_delete: :cascade
  add_foreign_key "payment_refunds", "users", column: "recorded_by_id"
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
  add_foreign_key "products", "sellers"
  add_foreign_key "return_request_items", "order_items"
  add_foreign_key "return_request_items", "return_requests"
  add_foreign_key "return_request_updates", "return_requests"
  add_foreign_key "return_requests", "seller_orders"
  add_foreign_key "reviews", "customers"
  add_foreign_key "reviews", "products"
  add_foreign_key "seller_orders", "orders", on_delete: :cascade
  add_foreign_key "seller_orders", "sellers"
  add_foreign_key "seller_reports", "customers"
  add_foreign_key "seller_reports", "sellers"
  add_foreign_key "seller_terms_acceptances", "sellers"
  add_foreign_key "seller_terms_acceptances", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "shipments", "seller_orders", on_delete: :cascade
  add_foreign_key "shipping_labels", "shipments"
  add_foreign_key "users", "sellers"
  add_foreign_key "wishlist_items", "customers"
  add_foreign_key "wishlist_items", "products"
end
