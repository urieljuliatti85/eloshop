require "test_helper"

class Admin::CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @category = Category.create!(name: "Casa")
  end

  test "redirects unauthenticated access to login" do
    get admin_categories_path
    assert_redirected_to new_session_path
  end

  test "authenticated user can list categories" do
    sign_in_as(@user)

    get admin_categories_path
    assert_response :success
  end

  test "authenticated user can view the new category form" do
    sign_in_as(@user)

    get new_admin_category_path
    assert_response :success
  end

  test "creates a top-level category" do
    sign_in_as(@user)

    assert_difference("Category.count", 1) do
      post admin_categories_path, params: { category: { name: "Moda" } }
    end

    assert_redirected_to admin_categories_path
  end

  test "creates a subcategory" do
    sign_in_as(@user)

    post admin_categories_path, params: { category: { name: "Decoração", parent_id: @category.id } }

    subcategory = Category.find_by(name: "Decoração")
    assert_equal @category, subcategory.parent
  end

  test "does not create a category with an invalid name" do
    sign_in_as(@user)

    assert_no_difference("Category.count") do
      post admin_categories_path, params: { category: { name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "updates a category" do
    sign_in_as(@user)

    patch admin_category_path(@category), params: { category: { name: "Casa e Decoração" } }

    assert_redirected_to admin_categories_path
    assert_equal "Casa e Decoração", @category.reload.name
  end

  test "destroys a category without products or children" do
    sign_in_as(@user)

    assert_difference("Category.count", -1) do
      delete admin_category_path(@category)
    end
  end

  test "does not destroy a category that still has products" do
    sign_in_as(@user)
    products(:one).update!(category: @category)

    assert_no_difference("Category.count") do
      delete admin_category_path(@category)
    end

    assert_redirected_to admin_categories_path
  end
end
