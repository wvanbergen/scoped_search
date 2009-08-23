module ScopedSearch::Spec::Mocks

  def tree(array)
    ScopedSearch::QueryLanguage::AST.from_array(array)
  end

  def mock_activerecord_class
    ar_mock = mock('ActiveRecord::Base')
    ar_mock.stub!(:named_scope).with(:search_for, anything)
    return ar_mock
  end

end
