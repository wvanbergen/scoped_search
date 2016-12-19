module ScopedSearch::RSpec::Mocks

  def tree(array)
    ScopedSearch::QueryLanguage::AST.from_array(array)
  end

  def mock_activerecord_class
    ar_mock = double('ActiveRecord::Base')
    ar_mock.stub(:named_scope).with(:search_for, anything)
    ar_mock.stub(:scope).with(:search_for, anything)
    ar_mock.stub(:connection).and_return(mock_database_connection)
    ar_mock.stub(:ancestors).and_return([ActiveRecord::Base])
    ar_mock.stub(:superclass).and_return(ActiveRecord::Base)
    ar_mock.stub(:columns_hash).and_return({'existing' => double('column')})
    return ar_mock
  end

  def mock_activerecord_subclass(parent)
    ar_mock = mock_activerecord_class
    ar_mock.stub(:superclass).and_return(parent)
    return ar_mock
  end

  def mock_database_connection
    c_mock = double('ActiveRecord::Base.connection')
    return c_mock
  end

end
