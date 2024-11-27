$(document).ready(function(){
  searchRecords();

});

function searchRecords() {

  // preventRepeatedEnters();

  $(".xsearch_results").on('click',".usethis", function() {

   var my_record = $(this).data("json").table;
   var short_author, short_title;
   // console.log(my_record);

   // Title should not be longer than 255 characters
   if (my_record.title.length < 250) {
    $("#item_title").val(my_record.title);

   }else {
     short_title = my_record.title.substr(0,250);
     short_title = short_title + " ...";
     $("#item_title").val(short_title);
   }

   // Author 2 can be sometimes greater than 255 characters as per mysql.
   if (my_record.author.length < 250) {
    $("#item_author").val(my_record.author);

   }else {
     short_author = my_record.author.substr(0,250);
     short_author = short_author + " ...";
     $("#item_author").val(short_author);
   }

   $("#item_publisher").val(my_record.publisher);
   $("#item_isbn").val(my_record.isbn);
   $("#item_other_isbn_issn").val(my_record.other_isbn_issn);
   $("#item_callnumber").val(my_record.callnumber);
   $("#item_edition").val(my_record.edition);
   $("#item_publication_date").val(my_record.publish_date);
   $("#item_metadata_source").val(my_record.source);
   $("#item_metadata_source_id").val(my_record.id);
   $("#item_url").val(my_record.url);   // URL will not be populated.

   //Remove the search results from view
   $(".search-panel").hide();
   $(".search_results ul li").each(function() {
     $(this).remove();
   });

  });

  // The Enter key on search box was submitting the whole form
  // Instead of submitting the whole form, redirected it to simulate "Go/Search"
  // Also prevent submitting on keyhold.
   $('.search-string').keypress(function(event) {
       if (event.which == 13) {
           event.preventDefault();
       }
   });
   // // submit the form when the enter key is released instead
   $('.search-string').keyup(function(event) {
       if (event.which == 13) {
           event.preventDefault();
           $(".search_button").click();
       }
   });

  $(".search_button").click(function(){

    // Remove any existing search results
    $(".search_results ul li").each(function() {
      $(this).remove();
    });

    //Show the panel & pass the search string to bib finder
    $(".search-panel").show();
    $('.loading-results').show();
    var term = $(".search-string").val();
    var item_type = $(".search-string").data("type");

    $(".searched-for").text(term);
    // alert(term);
    $.ajax({
      type : 'GET',
      url : '/bib_finders/search_records.js',
      data: {
        term: term,
        max_results: 5,
        on: item_type
      },
      dataType : 'script',
      success: function (data) {
         // console.log("data test");
         // console.log(data);
         $('.loading-results').hide();
         //Popover needed to be called in here for popover to work in ajax and also
         // z-index of 1050, otherwise it won't show up in the modal.
         $('.my_popover').popover({
            html : true,
         });
      }

    });
    return false;
  });

  // On close, clean up results!
  $(".search-close").click(function(){
    clearSearchResults();
  });
}

function clearSearchResults() {
  $(".search-panel").hide();
  $(".search_results ul li").each(function() {
    $(this).remove();
  });
}
