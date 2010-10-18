module ScopedSearch::RSpec::Mocks

  def tree(array)
    ScopedSearch::QueryLanguage::AST.from_array(array)
  end

  def mock_activerecord_class
    ar_mock = mock('ActiveRecord::Base')
    ar_mock.stub!(:named_scope).with(:search_for, anything)
    ar_mock.stub!(:scope).with(:search_for, anything)
    ar_mock.stub!(:connection).and_return(mock_database_connection)
    ar_mock.stub!(:ancestors).and_return([ActiveRecord::Base])
    return ar_mock
  end

  def mock_database_connection
    c_mock = mock('ActiveRecord::Base.connection')
    return c_mock
  end

end
