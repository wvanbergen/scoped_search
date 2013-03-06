//extend ui auto-complete to include categories and errors
$.widget( "custom.catcomplete", $.ui.autocomplete, {
  _renderMenu: function( ul, items ) {
    var self = this, currentCategory = "";
    $.each( items, function( index, item ) {
      if ( item.category != undefined && item.category != currentCategory ) {
        ul.append( "<li class='ui-autocomplete-category'>" + item.category + "</li>" );
        currentCategory = item.category;
      }
      if ( item.error != undefined ) {
        ul.append( "<li class='ui-autocomplete-error'>" + item.error + "</li>" );
      }
      self._renderItemData( ul, item );
    });
  },
  _renderItem: function( ul, item ) {
    return $( "<li>" )
        .append( "<a> <i class='ui-autocomplete-completed'>" + item.completed + "</i>" + item.part + "</a>" )
        .appendTo( ul );
  }
});


  $.fn.scopedSearch = function(){
    var options = arguments[0] || {};
    $(this).each(function(i,el){
      var target = $(el);

      target.catcomplete({
        source: options.source || function( request, response ) {
          $.getJSON( target.data("url"), { search: request.term }, response );
        },
        minLength: options.minLength || 0,
        delay: options.delay || 100,
        select: function(event, ui) {
          target.val( ui.item.value );
        },
        search: function(event, ui) {
          $(".autocomplete-clear").hide();
        },
        response: function(event, ui) {
          $(".autocomplete-clear").show();
        },
        close: function(event, ui) {
          $(".autocomplete-input:focus").catcomplete( target.attr('id'));
        }
      });

      target.bind("focus", function( event ){
        $(this).catcomplete( target.attr('id'));
      });
      target.after('<a class="autocomplete-clear" tabindex="-1" title="Clear">&times;</a>')
      target.next().on("click",function(){ target.val(''); })
    })
  };