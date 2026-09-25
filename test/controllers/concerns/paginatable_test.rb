require "test_helper"

class PaginatableTest < ActiveSupport::TestCase
  def pagination(current_page:, total_pages:)
    Paginatable::Pagination.new(current_page, total_pages, total_pages * Paginatable::DEFAULT_PER_PAGE, Paginatable::DEFAULT_PER_PAGE)
  end

  test "page_window lists every page when there are few pages" do
    assert_equal [ 1, 2, 3 ], pagination(current_page: 1, total_pages: 3).page_window
  end

  test "page_window shows a single page without gaps" do
    assert_equal [ 1 ], pagination(current_page: 1, total_pages: 1).page_window
  end

  test "page_window adds a gap between the window and the last page when the current page is near the start" do
    assert_equal [ 1, 2, 3, 4, 5, nil, 20 ], pagination(current_page: 3, total_pages: 20).page_window
  end

  test "page_window adds a gap between the first page and the window when the current page is near the end" do
    assert_equal [ 1, nil, 16, 17, 18, 19, 20 ], pagination(current_page: 18, total_pages: 20).page_window
  end

  test "page_window adds gaps on both sides when the current page is in the middle" do
    assert_equal [ 1, nil, 8, 9, 10, 11, 12, nil, 20 ], pagination(current_page: 10, total_pages: 20).page_window
  end

  test "page_window has no gaps when the window already touches both edges" do
    assert_equal [ 1, 2, 3, 4, 5 ], pagination(current_page: 3, total_pages: 5).page_window
  end
end
