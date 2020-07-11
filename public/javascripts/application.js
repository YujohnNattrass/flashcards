$(function(){
  $("p.answer").hide();

  $("button.answer").click(function(){
    $("p.answer").toggle();
  });
});
