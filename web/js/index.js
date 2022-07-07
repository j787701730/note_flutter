function Note() {
  var self = this;
  var scrollFlag = '';
  this.selectedRow = '';
  const classMap = {
    // h1: 'ui large header',
    // h2: 'ui medium header',
    // ul: 'ui list',
    // li: 'ui item',
    table: 'table table-bordered'
  }

  const bindings = Object.keys(classMap)
    .map(key => ({
      type: 'output',
      regex: new RegExp(`<${key}(.*)>`, 'g'),
      replace: `<${key} class="${classMap[key]}" $1>`
    }));
  this.converter = new showdown.Converter({
    tables: true, underline: true, strikethrough: true, splitAdjacentBlockquotes: true,
    tasklists: true,
    extensions: [...bindings],
  });

  var editor = $('.editor')[0];
  var rightRef = $('.rightSide')[0];
  this.editorFocus = false;
  this.selectionStart = 0;
  $('.editor')
    .on('focus', function () {
      self.editorFocus = true;
      self.selectionStart = this.selectionStart;
    })
    .on('blur', function () {
      self.editorFocus = false;
      self.selectionStart = this.selectionStart;
    })
    .on('input', function () {
      var html = self.converter.makeHtml(this.value);
      $('.rightSide').html(html);
      $('.rightSide').find('pre code').each(function () {
        hljs.initHighlightingOnLoad();
      })
      self.selectionStart = this.selectionStart;
    })
    .on('scroll', function (e) {
      if (scrollFlag == 'left') {
        rightRef.scrollTop = e.target.scrollTop / (editor.scrollHeight - editor.clientHeight) * (rightRef.scrollHeight - rightRef.clientHeight);
      }
    })
    .on('mouseenter', function () {
      scrollFlag = 'left';
    });

  this.uploadFilesIndex = 0;
  this.uploadFiles = [];
  document.addEventListener("paste", function (e) {
    if (self.editorFocus) {
      self.uploadFiles = e.clipboardData.files;
      self.uploadFilesIndex = 0;
      self.sendImage();
    }
  }, false);

  $('.rightSide')
    .on('scroll', function (e) {
      if (scrollFlag == 'right') {
        editor.scrollTop = e.target.scrollTop / (rightRef.scrollHeight - rightRef.clientHeight) * (editor.scrollHeight - editor.clientHeight);
      }
    })
    .on('mouseenter', function () {
      scrollFlag = 'right';
    });

  $('.modify').click(function () {
    $('.container').toggleClass('container-modify');
    changeBtnTxt();
  })

  function changeBtnTxt() {
    $('.modify').html($('.container').hasClass('container-modify') ? '浏览' : '编辑');
  }

  $('.save').click(function () {
    self.save();
  });


  document.onkeydown = function (e) {
    var keyCode = e.code;
    var ctrlKey = e.ctrlKey || e.metaKey;
    if (ctrlKey && keyCode == 'KeyS') {
      self.save();
      return false;
    } else if (keyCode == 'Tab') {
      self.selectionStart = editor.selectionStart;
      self.editorInsert('  ', 2);
      return false;
    }
  }

  self.getList();

  // 添加
  $('.addNote').click(function () {
    self.selectedRow = '';
    $('.container').addClass('container-modify');
    $('.note-title').removeClass('selected');
    $('.editor').val('');
    $('.title').val('').focus();
    $('.rightSide').html('');
    changeBtnTxt();
  });

  $('.note-list')
    .on('click', '.note-title', function () {
      var data = JSON.parse($(this).children('pre').html());
      console.log(data);
      $('.note-title').removeClass('selected');
      $(this).addClass('selected');
      self.selectedRow = data;
      $('.editor').val(data.data);
      $('.title').val(data.title);
      var html = self.converter.makeHtml(data.data);
      $('.rightSide').html(html);
      $('.rightSide').find('pre code').each(function () {
        hljs.initHighlightingOnLoad();
      })
    })
    .on('click', '.del-note', function (e) {
      // 删除
      var $ths = $(this).parent();
      var data = JSON.parse($(this).parent().children('pre').html());
      dialog("确定删除" + data.title + "?", function () {
        loading(true);
        $.ajax({
          url: 'delete',
          type: 'post',
          dataType: 'json',
          data: JSON.stringify({
            uuid: data.uuid,
          }),
          success: function (data) {
            loading(false);
            if ($ths.hasClass('selected')) {
              self.selectedRow = '';
              $('.editor').val('');
              $('.title').val('');
              $('.rightSide').empty();
            }
            self.getList();
            $('.dialog-mask').hide();
            toast("删除成功");
          }
        });
      })
      e.stopPropagation();
    })


  // 获取列表
  $('.get-list').click(function () {
    self.getList();
  })

  // 工具栏
  var toolObj = {
    "粗体": function () {
      self.editorInsert('****', 2);
    },
    "斜体": function () {
      self.editorInsert('**', 1)
    },
    "下划线": function () {
      self.editorInsert('____', 2);
    },
    "删除线": function () {
      self.editorInsert('~~~~', 2);
    },
    "标题1": function () {
      self.editorInsert('# ', 2);
    },
    "标题2": function () {
      self.editorInsert('## ', 3);
    },
    "标题3": function () {
      self.editorInsert('### ', 4);
    },
    "水平线": function () {
      self.editorInsert('\n---\n', 5);
    },
    "引用": function () {
      self.editorInsert('> ', 3);
    },
    "无序列表": function () {
      self.editorInsert('- ', 3);
    },
    "有序列表": function () {
      self.editorInsert('1. ', 3);
    },
    "表格": function () {
      self.editorInsert('\n|       |         |         |\n' +
        '|:------|:-------:|--------:|\n' +
        '|      |     |     |\n', 2);
    },
    "未完成任务": function () {
      self.editorInsert("- [ ] ", 6)
    },
    "已完成任务": function () {
      self.editorInsert("- [x] ", 6)
    },
    "插入代码": function () {
      self.editorInsert("```\n\n```", 4)
    },
    "插入链接": function () {
      self.editorInsert("[link](https://) ", 15)
    },
  }


  $('.toolbar').on('click', 'i', function () {
    toolObj[$(this).attr('title')]();
  })

}

Note.prototype = {
  constructor: Note,
  getList: function () {
    var self = this;
    loading(true);
    $.ajax({
      url: 'getList',
      type: 'post',
      dataType: 'json',
      data: {},
      success: function (data) {
        loading(false);
        if (data.code === 0) {
          var str = '';
          $.each(data.data, function (i, el) {
            var cls = '';
            if (self.selectedRow && self.selectedRow.uuid == el.uuid) {
              cls = 'selected';
            }
            str += '<div class="note-title ' + cls + '" title="' + el.title + '"><span>' + el.title +
              '</span><pre style="display: none">' + JSON.stringify(el) +
              '</pre><i class="bi bi-x-lg del-note"></i></div>'
          });
          $('.note-list').html(str);
        }
      }
    })
  },
  save: function () {
    var self = this;
    var data = {
      data: $('.editor').val(), title: $('.title').val(),
      title: $('.title').val().trim(),
      originTitle: self.selectedRow ? self.selectedRow.title : '',
    }
    if (!data.title && !data.data) {
      alert("标题和内容不能为空");
    } else {
      $.ajax({
        url: 'save',
        type: 'post',
        dataType: 'json',
        data: JSON.stringify({
          data: $('.editor').val(),
          title: $('.title').val(),
          uuid: self.selectedRow ? self.selectedRow.uuid : '',
        }),
        success: function (data) {
          if (data) {
            self.selectedRow = {
              data: $('.editor').val(),
              title: $('.title').val(),
              uuid: data.uuid,
            };
            toast("保存成功");
          }
          self.getList();
        }
      });
    }
  },
  editorInsert: function (val, len) {
    var self = this;
    var tc = $('.editor')[0];
    var tclen = tc.value.length;

    tc.value = tc.value.substr(0, self.selectionStart) + val + tc.value.substring(self.selectionStart, tclen);

    var html = self.converter.makeHtml(tc.value);
    $('.rightSide').html(html);
    $('.rightSide').find('pre code').each(function () {
      hljs.initHighlightingOnLoad();
    });
    tc.setSelectionRange(self.selectionStart + (len || 0), self.selectionStart + (len || 0));
    tc.focus();
    self.selectionStart = tc.selectionStart;
  },
  sendImage: function () {
    var self = this;
    if (self.uploadFilesIndex < self.uploadFiles.length) {
      var file = self.uploadFiles[self.uploadFilesIndex];
      if (file.type.indexOf('image/') > -1) {
        loading(true);
        var formData = new FormData();
        formData.append('file', file, file.name);
        $.ajax({
          url: '/upload',
          type: "POST",
          data: formData,
          processData: false,
          contentType: false,
          cache: false,
          success: function (data) {
            loading(false);
            if (data) {
              var res = JSON.parse(data);
              if (res.code === 0) {
                var str = '\n![image](/images/' + res.path + ')\n\n';
                self.editorInsert(str, str.length);
                self.uploadFilesIndex += 1;
                self.sendImage();
              }
            } else {
              self.uploadFilesIndex += 1;
              self.sendImage();
            }

            // layer.closeAll();
            // if (data.err_code == 0) {
            //   // $('.fileupload-btn').find('form input').val('');
            //   // self.ue.execCommand('inserthtml', '<img src="' + data.url + '" alt="">');
            //   // checkUE();
            //   // self.fileData.splice(0, 1);
            //   // if (self.fileData.length) {
            //   //   addWater(self.fileData[0])
            //   // }
            // } else {
            //   // layer.msg(data.err_code + ' : ' + data.err_msg, { icon: 2 });
            // }
          },
          error: function (data) {
            loading(false);
          }
        })
      } else {
        self.uploadFilesIndex += 1;
        self.sendImage();
      }
    }
  }
}

var note = new Note();


['localhost', '192.168.1.131'].indexOf(location.hostname) >= 0 && ((new WebSocket('ws://192.168.1.131:4444/ws')).onmessage = function (e) {
  if (e.data === '1') location.reload(true)
});