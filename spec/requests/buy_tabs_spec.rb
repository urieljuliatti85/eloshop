require "rails_helper"

RSpec.describe "Abas de Quero comprar", type: :request do
  def current_tab
    Nokogiri::HTML(response.body).css("nav[aria-label='Quero comprar'] a[aria-current='page']").map { |link| link.text.strip }
  end

  it "marks \"Já sou cliente\" on the login page" do
    get new_customer_session_path

    expect(response.body).to include("Já sou cliente", "Quero me cadastrar", new_customer_path)
    expect(current_tab).to eq([ "Já sou cliente" ])
  end

  it "marks \"Quero me cadastrar\" on the sign-up page" do
    get new_customer_path

    expect(response.body).to include(new_customer_session_path)
    expect(current_tab).to eq([ "Quero me cadastrar" ])
  end

  it "flags every sign-up field as required, in red, with an asterisk" do
    get new_customer_path

    doc = Nokogiri::HTML(response.body)
    inputs = doc.css("form[action='#{customers_path}'] input").reject { |input| %w[hidden submit].include?(input["type"]) }
    expect(inputs.size).to eq(4)
    expect(inputs).to all(satisfy { |input| input["required"] && input["class"].include?("border-red-400") })
    expect(doc.css("form[action='#{customers_path}'] label span.text-red-600").size).to eq(4)
  end

  it "keeps the sign-up tab selected when the form has errors" do
    post customers_path, params: { customer: { name: "", email: "", password: "x", password_confirmation: "y" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(current_tab).to eq([ "Quero me cadastrar" ])
  end

  describe "GET e-mail availability" do
    it "reports a taken e-mail regardless of case and spaces" do
      Customer.create!(name: "Ana", email: "ana@example.com", password: "password123")

      get customer_email_availability_path(email: "  ANA@Example.com ")

      expect(response.parsed_body).to eq("valid" => true, "available" => false)
    end

    it "reports a free e-mail" do
      get customer_email_availability_path(email: "livre@example.com")

      expect(response.parsed_body).to eq("valid" => true, "available" => true)
    end

    it "reports an invalid e-mail without querying accounts" do
      get customer_email_availability_path(email: "isso-nao-e-email@")

      expect(response.parsed_body).to eq("valid" => false, "available" => false)
    end

    it "is rate limited" do
      21.times { get customer_email_availability_path(email: "x@example.com") }

      expect(response).to have_http_status(:too_many_requests)
    end

    it "wires the sign-up e-mail field to the check" do
      get new_customer_path

      expect(response.body).to include("data-controller=\"email-availability\"", customer_email_availability_path)
    end
  end
end
