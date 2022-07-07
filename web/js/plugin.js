function dialog(content, onOk, onCancel) {
  $('.dialog-mask').show();
  $('.dialog-content').html(content);
  $('.dailog-cancel').click(function () {
    if (onCancel) {
      onCancel();
    } else {
      $('.dialog-mask').hide();
    }
  });

  $('.dialog-ok').click(function () {
    if (onOk) {
      onOk();
    } else {
      $('.dialog-mask').hide();
    }
  });

  $('.dialog').click(function (e) {
    e.stopPropagation();
  });
  $('.dialog-mask').click(function () {
    $(this).hide();
  })
}

// 加载动画
function loading(show) {
  if (show) {
    $('.loading').show();
  } else {
    $('.loading').hide();
  }
}

// 加载动画
function toast(msg) {
  $('.toast-msg').html(msg);
  $('.toast').show();
  setTimeout(function () {
    $('.toast').hide();
  }, 1500)
}