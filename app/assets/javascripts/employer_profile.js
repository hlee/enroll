$(function() {
  $('div[name=employee_family_tabs] > ').children().each( function() {
    $(this).change(function(){
      filter = $(this).val();
      search = $("#census_employee_search input#employee_name").val();
      $('#employees_' + filter).siblings().hide();
      $('#employees_' + filter).show();
      $.ajax({
        url: $('span[name=employee_families_url]').text() + '.js',
        type: "GET",
        data : { 'status': filter, 'employee_name': search }
      });
    })
  })
})

$(document).on('click', ".show_confirm", function(){
  var el_id = $(this).attr('id');
  $( "td." + el_id ).toggle();
  $( "#confirm-terminate-2" ).hide();
  return false
});

$(document).on('click', ".delete_confirm", function(){
  var termination_date = $(this).closest('div').find('input').val();
  var link_to_delete = $(this).data('link');
  console.log(termination_date);
  console.log(link_to_delete);
  $.ajax({
    type: 'get',
    datatype : 'js',
    url: link_to_delete,
    data: {termination_date: termination_date},
    success: function(response){
      if(response=="true") {
        window.location.reload();
      } else {

      }
    },
    error: function(response){
      Alert("Sorry, something went wrong");
    }
  });
});

$(document).on('click', ".rehire_confirm", function(){
  var element_id = $(this).attr('id');
  var rehiring_date = $(this).siblings().val();
  var link_to_delete = $(this).data('link');
  $.ajax({
    type: 'get',
    datatype : 'js',
    url: link_to_delete,
    data: {rehiring_date: rehiring_date}
  });
});

$(document).on('change', '.dependent_info input.dob-picker', function(){
  var element = $(this).val().split("/");
  year = parseInt(element[2]);
  month = parseInt(element[0]);
  day = parseInt(element[1]);
  var mydate = dchbx_enroll_date_of_record();
  mydate.setFullYear(year + 26,month-1,day);
  var target = $(this).parents('.dependent_info').find('select');
  selected_option_index = $(target).get(0).selectedIndex

  if (mydate > dchbx_enroll_date_of_record()){
    data = "<option value=''>SELECT RELATIONSHIP</option><option value='spouse'>Spouse</option><option value='domestic_partner'>Domestic partner</option><option value='child_under_26'>Child</option>";
  }else{
    data = "<option value=''>SELECT RELATIONSHIP</option><option value='spouse'>Spouse</option><option value='domestic_partner'>Domestic partner</option><option value='child_26_and_over'>Child</option>";
  }
  $(target).html(data);
  $(target).prop('selectedIndex', selected_option_index).selectric('refresh');
});

$(function() {
  $("#publishPlanYear .close").click(function(){
    location.reload();
  });
  setProgressBar();
})

function setProgressBar(){
  if($('.form-border .progress-wrapper').length == 0)
    return;

  maxVal = parseInt($('.progress-val .pull-right').data('value'));
  dividerVal = parseInt($('.divider-progress').data('value'));
  currentVal = parseInt($('.progress-bar').data('value'));
  percentageDivider = dividerVal/maxVal * 100;
  percentageCurrent = currentVal/maxVal * 100;

  $('.progress-bar').css({'width': percentageCurrent + "%"});
  $('.divider-progress').css({'left': (percentageDivider - 1) + "%"});

  barClass = currentVal < dividerVal ? 'progress-bar-danger' : 'progress-bar-success';
  $('.progress-bar').addClass(barClass);

  if(maxVal == 0){
    $('.progress-val strong').html('');
  }

  if(dividerVal == 0){
    $('.divider-progress').html('');
  }

  if(currentVal == 0){
    $('.progress-current').html('');
  }
}

$(document).on('click', '#census_employee_search_clear', function() {
  $('form#census_employee_search input#employee_name').val('');
  $("form#census_employee_search").submit();
})

$(document).on('change', '#address_info .office_kind_select select', function() {
  if ($(this).val() == 'mailing') {
    $(this).parents('fieldset').find('#phone_info input.area_code').attr('required', false);
    $(this).parents('fieldset').find('#phone_info input.phone_number7').attr('required', false);
  };
  if ($(this).val() == 'primary' || $(this).val() == 'branch'){
    $(this).parents('fieldset').find('#phone_info input.area_code').attr('required', true);
    $(this).parents('fieldset').find('#phone_info input.phone_number7').attr('required', true);
  };
})
