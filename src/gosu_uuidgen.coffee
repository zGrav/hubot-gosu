class @GUID

  s4: ->
    Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1)

  create_nonv4: () ->
    "#{@s4()}#{@s4()}-#{@s4()}-#{@s4()}-#{@s4()}-#{@s4()}#{@s4()}#{@s4()}"

  create: () ->
      'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->
          r = Math.random() * 16 | 0
          v = if c == 'x' then r else r & 0x3 | 0x8
          v.toString 16
