require "spec_helper"
require "scoped_search/rails_helper"

module ActionViewHelperStubs
  def html_escape(str)
    CGI.escape_html(str)
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
end
