module ScopedSearch
  # This class will be used to store standard validators.
  class Validators
    NUMERIC = ->(value) { !!(value =~ ScopedSearch::Definition::NUMERICAL_REGXP) }
    INTEGER = ->(value) { !!(value =~ ScopedSearch::Definition::INTEGER_REGXP) }
  end
end
