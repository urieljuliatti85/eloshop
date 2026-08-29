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

  test "create with invalid data does not send the message" do
    post contact_path, params: { contact_message: { name: "", email: "", message: "" } }

    assert_enqueued_emails 0
    assert_response :unprocessable_entity
  end
end
