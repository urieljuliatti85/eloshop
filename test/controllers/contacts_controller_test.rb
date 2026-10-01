require "test_helper"

class ContactsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_contact_path
    assert_response :success
  end

  test "create with valid data sends the message and redirects" do
    post contact_path, params: { contact_message: { name: "Maria", email: "maria@example.com", message: "Olá!" } }

    assert_enqueued_email_with ContactMailer, :notify, args: [ { name: "Maria", email: "maria@example.com", subject: nil, message: "Olá!" } ]
    assert_redirected_to new_contact_path

    follow_redirect!
    assert_match "Mensagem enviada", flash[:notice]
  end

  test "create also confirms receipt to the visitor, without echoing what they typed" do
    post contact_path, params: { contact_message: { name: "Maria Golpista", email: "maria@example.com", message: "Clique aqui no meu link" } }

    assert_enqueued_email_with ContactMailer, :confirmation, args: [ { email: "maria@example.com" } ]
    email = ContactMailer.confirmation(email: "maria@example.com")
    assert_match "2 dias úteis", email.html_part.body.to_s
    assert_no_match(/Golpista|meu link/, email.html_part.body.to_s + email.text_part.body.to_s)
  end

  test "confirms at most once per hour for the same e-mail, but still delivers every message" do
    params = { contact_message: { name: "Maria", email: "maria@example.com", message: "Olá!" } }

    post contact_path, params: params
    post contact_path, params: params

    enqueued = enqueued_jobs.map { |job| job["arguments"][1] }
    assert_equal 2, enqueued.count("notify")
    assert_equal 1, enqueued.count("confirmation")
  end

  test "a different e-mail gets its own confirmation" do
    post contact_path, params: { contact_message: { name: "Maria", email: "maria@example.com", message: "Oi" } }
    post contact_path, params: { contact_message: { name: "João", email: "joao@example.com", message: "Oi" } }

    enqueued = enqueued_jobs.select { |job| job["arguments"][1] == "confirmation" }
    assert_equal 2, enqueued.size
  end

  test "create with invalid data does not send the message" do
    post contact_path, params: { contact_message: { name: "", email: "", message: "" } }

    assert_enqueued_emails 0
    assert_response :unprocessable_entity
  end
end
