module ScopedSearch
  module RailsHelper
    # Creates a link that alternates between ascending and descending.
    #
    # Examples:
    #
    #   sort :username
    #   sort :created_at, as: "Created"
    #   sort :created_at, default: "DESC"
    #
    # * <tt>field</tt> - the name of the named scope. This helper will prepend this value with "ascend_by_" and "descend_by_"
    #
    # This helper accepts the following options:
    #
    # * <tt>:as</tt> - the text used in the link, defaults to whatever is passed to `field`
    # * <tt>:default</tt> - default sorting order, DESC or ASC
    # * <tt>:html_options</tt> - is a hash of HTML options for the anchor tag
    # * <tt>:url_options</tt> - is a hash of URL parameters, defaulting to `params`, to preserve the current URL
    #   parameters.
    #
    # On Rails 5 or higher, parameter whitelisting prevents any parameter being used in a link by
    # default, so `params.permit(..)` should be passed for `url_options` for all known and
    # permitted URL parameters, e.g.
    #
    #   sort :username, url_options: params.permit(:search)
    #
    def sort(field, as: nil, default: "ASC", html_options: {}, url_options: params)

      unless as
        id = field.to_s.downcase == "id"
        as = id ? field.to_s.upcase : field.to_s.humanize
      end

      ascend  = "#{field} ASC"
      descend = "#{field} DESC"
      selected_sort = [ascend, descend].find { |o| o == params[:order] }

      case params[:order]
        when ascend
          new_sort = descend
        when descend
          new_sort = ascend
        else
          new_sort = ["ASC", "DESC"].include?(default) ? "#{field} #{default}" : ascend
      end

      unless selected_sort.nil?
        css_classes = html_options[:class] ? html_options[:class].split(" ") : []
        if selected_sort == ascend
          as = "&#9650;&nbsp;".html_safe + as
          css_classes << "ascending"
        else
          as = "&#9660;&nbsp;".html_safe + as
          css_classes << "descending"
        end
        html_options[:class] = css_classes.join(" ")
      end

      url_options = url_options.to_h if url_options.respond_to?(:permit)  # convert ActionController::Parameters if given
      url_options = url_options.merge(:order => new_sort)

      as = raw(as) if defined?(RailsXss)

      content_tag(:a, as, html_options.merge(href: url_for(url_options)))
    end
  end
end
