require "spec_helper"
require "scoped_search/rails_helper"

module ActionViewHelperStubs
  def html_escape(str)
    str
  end

  def tag_options(options)
    ""
  end
end

describe ScopedSearch::RailsHelper do
  include ScopedSearch::RailsHelper
  include ActionViewHelperStubs

  let(:params) { HashWithIndifferentAccess.new(:controller => "resources", :action => "search") }

  it "should generate a link with the order param set" do
    should_receive(:url_for).with(
      "controller" => "resources",
      "action" => "search",
      "order" => "field ASC"
    ).and_return("/example")

    sort("field")
  end

  it "should generate a link with order param set to alternative default sorting order" do
    should_receive(:url_for).with(
      "controller" => "resources",
      "action" => "search",
      "order" => "field DESC"
    ).and_return("/example")

    sort("field", :default => "DESC")
  end

  it "should generate a link with the order param inverted" do
    should_receive(:url_for).with(
      "controller" => "resources",
      "action" => "search",
      "order" => "field DESC"
    ).and_return("/example")

    params[:order] = "field ASC"
    sort("field")
  end

  it "should generate a link with other parameters retained" do
    should_receive(:url_for).with(
      "controller" => "resources",
      "action" => "search",
      "walrus" => "unicorns",
      "order" => "field ASC"
    ).and_return("/example")

    params[:walrus] = "unicorns"
    sort("field")
  end

  it "should replace the current sorting order" do
    should_receive(:url_for).with(
      "controller" => "resources",
      "action" => "search",
      "order" => "other ASC"
    ).and_return("/example")

    params[:order] = "field ASC"
    sort("other")
  end

  it "should add no styling by default" do
    should_receive(:url_for)
    should_receive(:a_link).with('Field', anything, hash_excluding(:class))
    sort("field")
  end

  it "should add ascending style for current ascending sort order " do
    should_receive(:url_for)
    should_receive(:a_link).with('&#9650;&nbsp;Field', anything, hash_including(:class => 'ascending'))

    params[:order] = "field ASC"
    sort("field")
  end

  it "should add descending style for current descending sort order " do
    should_receive(:url_for)
    should_receive(:a_link).with('&#9660;&nbsp;Field', anything, hash_including(:class => 'descending'))

    params[:order] = "field DESC"
    sort("field")
  end

  context 'with ActionController::Parameters' do
    let(:ac_params) { double('ActionController::Parameters') }

    it "should call to_h on passed params object" do
      should_receive(:url_for).with(
        "controller" => "resources",
        "action" => "search",
        "walrus" => "unicorns",
        "order" => "field ASC"
      ).and_return("/example")

      params[:walrus] = "unicorns"

      ac_params.should_receive(:respond_to?).with(:permit).and_return(true)
      ac_params.should_receive(:to_h).and_return(params)

      sort("field", {}, {}, ac_params)
    end
  end
end
