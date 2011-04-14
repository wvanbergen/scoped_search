module ScopedSearch
  module RailsHelper
    # Creates a link that alternates between ascending and descending.
    #
    # Examples:
    #
    #   sort @search, :by => :username
    #   sort @search, :by => :created_at, :as => "Created"
    #
    # This helper accepts the following options:
    #
    # * <tt>:by</tt> - the name of the named scope. This helper will prepend this value with "ascend_by_" and "descend_by_"
    # * <tt>:as</tt> - the text used in the link, defaults to whatever is passed to :by
    def sort(field, options = {}, html_options = {})

      unless options[:as]
        id           = field.to_s.downcase == "id"
        options[:as] = id ? field.to_s.upcase : field.to_s.humanize
      end

      ascend  = "#{field} ASC"
      descend = "#{field} DESC"

      ascending = params[:order] == ascend
      new_sort = ascending ? descend : ascend
      selected = [ascend, descend].include?(params[:order])

      if selected
        css_classes = html_options[:class] ? html_options[:class].split(" ") : []
        if ascending
          options[:as] = "&#9650;&nbsp;#{options[:as]}"
          css_classes << "ascending"
        else
          options[:as] = "&#9660;&nbsp;#{options[:as]}"
          css_classes << "descending"
        end
        html_options[:class] = css_classes.join(" ")
      end

      url_options = params.merge(:order => new_sort)

      options[:as] = raw(options[:as]) if defined?(RailsXss)

      a_link(options[:as], html_escape(url_for(url_options)),html_options)
    end

    # Adds AJAX auto complete functionality to the text input field with the
    # DOM ID specified by +field_id+.
    #
    # Required   +options+ is:
    # <tt>:url</tt>::                  URL to call for auto completion results
    #                                  in url_for format.
    #
    # Additional +options+ are:
    # <tt>:update</tt>::               Specifies the DOM ID of the element whose
    #                                  innerHTML should be updated with the auto complete
    #                                  entries returned by the AJAX request.
    #                                  Defaults to <tt>field_id</tt> + '_auto_complete'
    # <tt>:with</tt>::                 A JavaScript expression specifying the
    #                                  parameters for the XMLHttpRequest. This defaults
    #                                  to 'fieldname=value'.
    # <tt>:frequency</tt>::            Determines the time to wait after the last keystroke
    #                                  for the AJAX request to be initiated.
    # <tt>:indicator</tt>::            Specifies the DOM ID of an element which will be
    #                                  displayed while auto complete is running.
    # <tt>:tokens</tt>::               A string or an array of strings containing
    #                                  separator tokens for tokenized incremental
    #                                  auto completion. Example: <tt>:tokens => ','</tt> would
    #                                  allow multiple auto completion entries, separated
    #                                  by commas.
    # <tt>:min_chars</tt>::            The minimum number of characters that should be
    #                                  in the input field before an Ajax call is made
    #                                  to the server.
    # <tt>:on_hide</tt>::              A Javascript expression that is called when the
    #                                  auto completion div is hidden. The expression
    #                                  should take two variables: element and update.
    #                                  Element is a DOM element for the field, update
    #                                  is a DOM element for the div from which the
    #                                  innerHTML is replaced.
    # <tt>:on_show</tt>::              Like on_hide, only now the expression is called
    #                                  then the div is shown.
    # <tt>:after_update_element</tt>:: A Javascript expression that is called when the
    #                                  user has selected one of the proposed values.
    #                                  The expression should take two variables: element and value.
    #                                  Element is a DOM element for the field, value
    #                                  is the value selected by the user.
    # <tt>:select</tt>::               Pick the class of the element from which the value for
    #                                  insertion should be extracted. If this is not specified,
    #                                  the entire element is used.
    # <tt>:method</tt>::               Specifies the HTTP verb to use when the auto completion
    #                                  request is made. Defaults to POST.
    def auto_complete_field(field_id, options = {})
      function =  "var #{field_id}_auto_completer = new Ajax.Autocompleter("
      function << "'#{field_id}', "
      function << "'" + (options[:update] || "#{field_id}_auto_complete") + "', "
      function << "'#{url_for(options[:url])}'"

      js_options = {}
      js_options[:tokens] = array_or_string_for_javascript(options[:tokens])            if options[:tokens]
      js_options[:callback]   = "function(element, value) { return #{options[:with]} }" if options[:with]
      js_options[:indicator]  = "'#{options[:indicator]}'"                              if options[:indicator]
      js_options[:select]     = "'#{options[:select]}'"                                 if options[:select]
      js_options[:paramName]  = "'#{options[:param_name]}'"                             if options[:param_name]
      js_options[:frequency]  = "#{options[:frequency]}"                                if options[:frequency]
      js_options[:method]     = "'#{options[:method].to_s}'"                            if options[:method]

      { :after_update_element => :afterUpdateElement,
        :on_show => :onShow, :on_hide => :onHide, :min_chars => :minChars }.each do |k,v|
        js_options[v] = options[k] if options[k]
      end

      function << (', ' + options_for_javascript(js_options) + ')')

      javascript_tag(function)
    end

    def auto_complete_field_jquery(method, url, options = {})
      function = <<-EOF
      $.widget( "custom.catcomplete", $.ui.autocomplete, {
        _renderMenu: function( ul, items ) {
          var self = this,
          currentCategory = "";
          $.each( items, function( index, item ) {
            if ( item.category != undefined && item.category != currentCategory ) {
              ul.append( "<li class='ui-autocomplete-category'>" + item.category + "</li>" );
              currentCategory = item.category;
            }
            if ( item.error != undefined ) {
              ul.append( "<li class='ui-autocomplete-error'>" + item.error + "</li>" );
            }
            if( item.completed != undefined ) {
              $( "<li></li>" ).data( "item.autocomplete", item )
				      .append( "<a>" + "<strong class='ui-autocomplete-completed'>" + item.completed + "</strong>" + item.part + "</a>" )
				      .appendTo( ul );
            } else {
              self._renderItem( ul, item );
            }
          });
        }
      });

      $("##{method}")
      .catcomplete({
			source: function( request, response ) {	$.getJSON( "#{url}", { #{method}: request.term }, response );	},
			minLength: #{options[:min_length] || 0},
      delay: #{options[:delay] || 200},
      select: function(event, ui) { $( this ).catcomplete( "search" , ui.item.value); },
      search: function(event, ui) { $(".auto_complete_clear").hide(); },
      open: function(event, ui) { $(".auto_complete_clear").show(); }
      });

      $("##{method}").bind( "focus", function( event ) {
        if( $( this )[0].value == "" ) {
					$( this ).catcomplete( "search" );
        }
			});

 EOF


      javascript_tag(function)
    end

    def auto_complete_clear_value_button(field_id)
      html_options = {:tabindex => '-1',:class=>"auto_complete_clear",:title =>'Clear Search', :onclick=>"document.getElementById('#{field_id}').value = '';"}
      a_link("", "#", html_options)
    end

    def a_link(name, href, html_options)
      tag_options = tag_options(html_options)
      link = "<a href=\"#{href}\"#{tag_options}>#{name}</a>"
      return link.respond_to?(:html_safe) ? link.html_safe : link
    end

    # Use this method in your view to generate a return for the AJAX auto complete requests.
    #
    # The auto_complete_result can of course also be called from a view belonging to the
    # auto_complete action if you need to decorate it further.
    def auto_complete_result(entries, phrase = nil)
      return unless entries
      items = entries.map { |entry| content_tag("li", phrase ? highlight(entry, phrase) : h(entry)) }
      content_tag("ul", items)
    end

    # Wrapper for text_field with added AJAX auto completion functionality.
    #
    # In your controller, you'll need to define an action called
    # auto_complete_method to respond the AJAX calls,
    def auto_complete_field_tag(method, val,tag_options = {}, completion_options = {})
      auto_completer_options = { :url => { :action => "auto_complete_#{method}" } }.update(completion_options)

      text_field_tag(method, val,tag_options.merge(:class => "auto_complete_input")) +
          auto_complete_clear_value_button(method) +
          content_tag("div", "", :id => "#{method}_auto_complete", :class => "auto_complete") +
          auto_complete_field(method, auto_completer_options)
    end

    # Wrapper for text_field with added JQuery auto completion functionality.
    #
    # In your controller, you'll need to define an action called
    # auto_complete_method to respond the JQuery calls,
    def auto_complete_field_tag_jquery(method, val,tag_options = {}, completion_options = {})
      url = url_for(:action => "auto_complete_#{method}")
      options = tag_options.merge(:class => "auto_complete_input")
      text_field_tag(method, val, options) + auto_complete_clear_value_button(method) +
          auto_complete_field_jquery(method, url, completion_options)
    end

  end
end
