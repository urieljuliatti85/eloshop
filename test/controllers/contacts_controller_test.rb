require "test_helper"

class ContactsControllerTest < ActionDispatch::IntegrationTest
  # Token de um formulário aberto há tempo suficiente para ser humano.
  def aged_token
    travel_to(10.seconds.ago) { ContactMessage.issue_token }
  end

  def post_contact(contact_message, **extra)
    post contact_path, params: { contact_message: contact_message, form_token: aged_token }.merge(extra)
  end

  # Minitest 6 não traz mais `stub`; troca o método só durante o bloco.
  def with_turnstile(method, result)
    original = Turnstile.method(method)
    Turnstile.define_singleton_method(method) { |*, **| result }
    yield
  ensure
    Turnstile.define_singleton_method(method, original)
  end

  test "new" do
    get new_contact_path
    assert_response :success
  end

  test "create with valid data sends the message and redirects" do
    post_contact({ name: "Maria", email: "maria@example.com", message: "Olá!" })

    assert_enqueued_email_with ContactMailer, :notify, args: [ { name: "Maria", email: "maria@example.com", subject: nil, message: "Olá!" } ]
    assert_redirected_to new_contact_path

    follow_redirect!
    assert_match "Mensagem enviada", flash[:notice]
  end

  test "create also confirms receipt to the visitor, without echoing what they typed" do
    post_contact({ name: "Maria Golpista", email: "maria@example.com", message: "Clique aqui no meu link" })

    assert_enqueued_email_with ContactMailer, :confirmation, args: [ { email: "maria@example.com" } ]
    email = ContactMailer.confirmation(email: "maria@example.com")
    assert_match "2 dias úteis", email.html_part.body.to_s
    assert_no_match(/Golpista|meu link/, email.html_part.body.to_s + email.text_part.body.to_s)
  end

  test "confirms at most once per hour for the same e-mail, but still delivers every message" do
    message = { name: "Maria", email: "maria@example.com", message: "Olá!" }

    post_contact(message)
    post_contact(message)

    enqueued = enqueued_jobs.map { |job| job["arguments"][1] }
    assert_equal 2, enqueued.count("notify")
    assert_equal 1, enqueued.count("confirmation")
  end

  test "a different e-mail gets its own confirmation" do
    post_contact({ name: "Maria", email: "maria@example.com", message: "Oi" })
    post_contact({ name: "João", email: "joao@example.com", message: "Oi" })

    enqueued = enqueued_jobs.select { |job| job["arguments"][1] == "confirmation" }
    assert_equal 2, enqueued.size
  end

  test "create with invalid data does not send the message" do
    post_contact({ name: "", email: "", message: "" })

    assert_enqueued_emails 0
    assert_response :unprocessable_entity
  end

  test "the form carries a hidden decoy field and a signed token" do
    get new_contact_path

    assert_select "input[name=website][tabindex='-1'][autocomplete=off]"
    assert_select "input[type=hidden][name=form_token]"
  end

  test "a filled decoy field looks like success but sends nothing" do
    post_contact({ name: "Robertkic", email: "bot@example.com", message: "price?" }, website: "http://spam.example")

    assert_redirected_to new_contact_path
    assert_enqueued_emails 0
  end

  test "a missing token sends nothing" do
    post contact_path, params: { contact_message: { name: "Bot", email: "bot@example.com", message: "price?" } }

    assert_response :unprocessable_entity
    assert_enqueued_emails 0
  end

  test "a forged token sends nothing" do
    post contact_path, params: { contact_message: { name: "Bot", email: "bot@example.com", message: "x" }, form_token: "forjado" }

    assert_response :unprocessable_entity
    assert_enqueued_emails 0
  end

  test "submitting right after the form was rendered sends nothing" do
    post contact_path, params: { contact_message: { name: "Bot", email: "bot@example.com", message: "x" }, form_token: ContactMessage.issue_token }

    assert_response :unprocessable_entity
    assert_enqueued_emails 0
  end

  test "an expired token sends nothing" do
    token = travel_to(2.days.ago) { ContactMessage.issue_token }
    post contact_path, params: { contact_message: { name: "Maria", email: "maria@example.com", message: "x" }, form_token: token }

    assert_response :unprocessable_entity
    assert_enqueued_emails 0
  end

  test "stops sending once the global daily limit is reached" do
    limit = ContactsController::DAILY_NOTIFY_LIMIT
    Rails.cache.write("email_budget:contact_notify:#{Date.current.iso8601}", limit, expires_in: 1.day)

    post_contact({ name: "Maria", email: "maria@example.com", message: "Olá!" })

    assert_redirected_to new_contact_path
    assert_match "muitas mensagens", flash[:alert]
    assert_enqueued_emails 0
  end

  test "stops confirming once the daily confirmation limit is reached, but still delivers the message" do
    Rails.cache.write("email_budget:contact_confirmation:#{Date.current.iso8601}", ContactsController::DAILY_CONFIRMATION_LIMIT, expires_in: 1.day)

    post_contact({ name: "Maria", email: "maria@example.com", message: "Olá!" })

    enqueued = enqueued_jobs.map { |job| job["arguments"][1] }
    assert_equal [ "notify" ], enqueued
  end

  test "blocks the message when the Turnstile refuses the token" do
    with_turnstile(:verify, :failed) do
      post_contact({ name: "Bot", email: "bot@example.com", message: "Spam" })
    end

    assert_response :unprocessable_entity
    assert_no_enqueued_emails
  end

  test "sends the message when the Turnstile confirms the token" do
    with_turnstile(:verify, :ok) do
      post_contact({ name: "Maria", email: "maria@example.com", message: "Olá!" })
    end

    assert_redirected_to new_contact_path
    assert_enqueued_email_with ContactMailer, :notify, args: [ { name: "Maria", email: "maria@example.com", subject: nil, message: "Olá!" } ]
  end

  test "fails open when the Turnstile is unavailable" do
    with_turnstile(:verify, :unavailable) do
      post_contact({ name: "Maria", email: "maria@example.com", message: "Olá!" })
    end

    assert_redirected_to new_contact_path
  end

  test "renders the widget only when the Turnstile is enabled" do
    get new_contact_path
    assert_no_match "cf-turnstile", response.body

    with_turnstile(:enabled?, true) do
      get new_contact_path
    end
    assert_match "cf-turnstile", response.body
    assert_match "challenges.cloudflare.com/turnstile/v0/api.js", response.body
  end
end
