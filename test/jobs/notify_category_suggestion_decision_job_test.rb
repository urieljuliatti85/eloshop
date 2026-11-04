require "test_helper"

class NotifyCategorySuggestionDecisionJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @seller = sellers(:approved)
    @recipient = @seller.users.order(:created_at).first.email_address
    @admin = users(:one)
  end

  test "an accepted suggestion tells the seller the category path and that products do not change" do
    parent = Category.create!(name: "Casa")
    suggestion = CategorySuggestion.suggest!(seller: @seller, name: "Cestaria").suggestion
    suggestion.accept!(name: "Cestaria", parent: parent, admin: @admin)
    request = suggestion.requests.sole

    assert_emails 1 do
      NotifyCategorySuggestionDecisionJob.perform_now(request)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [ @recipient ], email.to
    assert_match "Cestaria", email.subject
    assert_match "Casa > Cestaria", email.text_part.body.to_s
    assert_match "não mudam sozinhos", email.text_part.body.to_s
    assert_match "/painel/products", email.text_part.body.to_s
    assert_not_nil request.reload.notified_at
  end

  test "a rejected suggestion sends the rejection" do
    suggestion = CategorySuggestion.suggest!(seller: @seller, name: "Taxidermia").suggestion
    suggestion.reject!(admin: @admin)

    assert_emails 1 do
      NotifyCategorySuggestionDecisionJob.perform_now(suggestion.requests.sole)
    end

    email = ActionMailer::Base.deliveries.last
    assert_match "Taxidermia", email.subject
    assert_match "não vai entrar na lista", email.text_part.body.to_s
  end

  test "a request already notified is not emailed again" do
    suggestion = CategorySuggestion.suggest!(seller: @seller, name: "Origami").suggestion
    suggestion.reject!(admin: @admin)
    request = suggestion.requests.sole
    NotifyCategorySuggestionDecisionJob.perform_now(request)

    assert_no_emails do
      NotifyCategorySuggestionDecisionJob.perform_now(request.reload)
    end
  end

  test "a pending suggestion sends nothing" do
    suggestion = CategorySuggestion.suggest!(seller: @seller, name: "Vitral").suggestion

    assert_no_emails do
      NotifyCategorySuggestionDecisionJob.perform_now(suggestion.requests.sole)
    end
  end
end
