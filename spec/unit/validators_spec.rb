require "spec_helper"

describe ScopedSearch::Validators do
  describe 'NUMERIC' do
    it 'should accept integer value' do
      ScopedSearch::Validators::NUMERIC.call('123').should eq(true)
    end

    it 'should accept float value' do
      ScopedSearch::Validators::NUMERIC.call('123.5').should eq(true)
    end

    it 'should reject string value' do
      ScopedSearch::Validators::NUMERIC.call('abc').should eq(false)
    end
  end

  describe 'INTEGER' do
    it 'should accept numeric value' do
      ScopedSearch::Validators::INTEGER.call('123').should eq(true)
    end

    it 'should reject string value' do
      ScopedSearch::Validators::INTEGER.call('abc').should eq(false)
    end
  end
end
