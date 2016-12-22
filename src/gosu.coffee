try
  Hubot = require 'hubot'
  {Client} = require 'gosu-client'
  {EventEmitter} = require 'events'
catch
  prequire = require('parent-require')
  Hubot = prequire 'hubot'
  {Client} = require 'gosu-client'
  {EventEmitter} = prequire 'events'

#EventEmitter is for global.robot.logger

{GUID} = require('./gosu_uuidgen.coffee')
uuidclass = new GUID
Client = new Client

global.robot = null

class GOSU extends Hubot.Adapter

  constructor: ->
    super
    @robot.logger.info "INIT"

  send: (env, strings...) ->
    global.robot.logger.info 'Send!'

    for string in strings
        regexstring = "#{@robot.name} "
        regexp = new RegExp(regexstring, "gi")
        string = string.replace(regexp, "")
        string = string.trim()

        try
            if env.user.name == global.username # no selftag
                  if string.indexOf('Answer by mentioning me') > -1 # used for trivia
                        substr = string.substring(string.indexOf(":") + 2, string.length - 1)
                        messageobject = {body: string, body_annotations: [{type: 7, pos_start: string.indexOf(":") + 3, pos_end: string.length - 1, replacement: substr}], type: 1}
                  else
                        messageobject = {body: string}
            else
                  if string.indexOf('Answer by mentioning me') > -1 # used for trivia, strip user mention
                        substr = string.substring(string.indexOf(":") + 3, string.length - 1)
                        messageobject = {body: string, body_annotations: [{type: 7, pos_start: string.indexOf(":") + 3, pos_end: string.length - 1, replacement: substr}], type: 1}
                  else
                        string = "@#{env.user.name}\n" + string
                        messageobject = {body: string, body_annotations: [{type: 2, pos_start: 0, pos_end: env.user.name.length + 1, replacement: env.user.name, target: env.user.id}]}
        catch error
            messageobject = {body: string}

        uuid = uuidclass.create()
        ch = env.room

        query = {
            "id": uuid,
            "type": 1,
            "user_id": global.user_id,
            "channel": ch,
            "user_message": messageobject
        }

        string_query = JSON.stringify(query)
        content_length = string_query.length

        funcs = new Functions
        getIdx = funcs.findKeyIndex(global.channels_by_index, 'id', ch)
        title = ''
        if global.channels_by_index[getIdx]
          title = global.channels_by_index[getIdx].title

        global.robot.http(global.api + "/chat/message")
        .headers('Accept': 'application/json', 'Content-Type': 'application/json', 'Content-Length': content_length, 'X-Token': global.user_token)
        .post(string_query) (err, res, body) ->
            try
              if res.statusCode isnt 200
                  global.robot.logger.error "Oh no! We errored under API :( - Response Code: #{res.statusCode}"
                  return
              global.robot.logger.info "Successfully sent message to channel with ID: #{ch}/title: #{title} and content: #{string} with UUID: #{uuid}"
            catch error
                global.robot.logger.error "Oh no! We errored :( - #{error} - API Response Code: #{res.statusCode}"

  reply: (env, strings...) ->
    global.robot.logger.info 'Reply!'

    query = {
        "user_ids": [env.user.id]
    }

    string_query = JSON.stringify(query)
    content_length = string_query.length

    global.robot.http(global.api + "/channels/direct")
    .headers('Accept': 'application/json', 'Content-Type': 'application/json', 'Content-Length': content_length, 'X-Token': global.user_token)
    .post(string_query) (err, res, body) ->
        try
          result = JSON.parse(body)

          for string in strings
              uuid = uuidclass.create()
              ch = result.channel.id
              messageobject = {body: string}

              query = {
                  "id": uuid,
                  "type": 1,
                  "user_id": global.user_id,
                  "channel": ch,
                  "user_message": messageobject
              }

              string_query = JSON.stringify(query)
              content_length = string_query.length
              global.robot.http(global.api + "/chat/message")
              .headers('Accept': 'application/json', 'Content-Type': 'application/json', 'Content-Length': content_length, 'X-Token': global.user_token)
              .post(string_query) (err, res, body) ->
                  try
                    if res.statusCode isnt 200
                        global.robot.logger.error "Oh no! We errored under API :( - Response Code: #{res.statusCode}"
                        return
                    global.robot.logger.info "Successfully sent message to direct channel with ID: #{ch} and content: #{string} with UUID: #{uuid}"

                    funcs = new Functions

                    funcs.leaveChannel(ch)
                  catch error
                      global.robot.logger.error "Oh no! We errored :( - #{error} - API Response Code: #{res.statusCode}"

        catch error
            global.robot.logger.error "Oh no! We errored :( - #{error} - API Response Code: #{res.statusCode}"

  run: ->
    @robot.logger.info "RUN"
    @robot.logger.info "Checking for Environment Variables"

    global.robot = @robot #used on other classes
    global.username = process.env.GOSU_USER

    unless global.username?
        @robot.logger.error "Missing GOSU_USER in environment: please set and try again"
        process.exit(1)
    global.password = process.env.GOSU_PWD
    unless global.password?
        @robot.logger.error "Missing GOSU_PWD in environment: please set and try again"
        process.exit(1)
    global.api = process.env.GOSU_API
    unless global.api?
        @robot.logger.error "Missing GOSU_API in environment: please set and try again"
        process.exit(1)

    global.agent_id = "ee1fdad6-5cdf-4707-863f-46111e6a2e80" #TODO: universal uuid? uuidclass.create()?
    global.agent_name = "HUBOT"
    global.agent_type = 5 # type BOT
    global.channels_by_index = []
    global.loggedin = false

    @robot.logger.info "All Environment variables and needed variables set, switching to LOGIN"

    @robot.on 'message', (roomId, id, account, body, sendAt, updatedAt) =>
        user = @robot.brain.userForId account.account_id,
        name: account.name
        room: roomId
        is_moderator: account.is_moderator
        msg = new Hubot.TextMessage user, body, id
        @robot.receive(msg)

    @emit "connected" #so it loads scripts

    @login()

  login: ->
    @robot.logger.info "LOGIN"
    @robot.logger.info "Trying to login using #{global.username} under #{global.api}"

    query = {
        "username": global.username,
        "password": global.password,
        "agent_id": global.agent_id,
        "agent_name": global.agent_name,
        "agent_type": global.agent_type
    }

    string_query = JSON.stringify(query)
    content_length = string_query.length

    @robot.http(global.api + '/auth/login')
    .headers('Accept': 'application/json', 'Content-Type': 'application/json', 'Content-Length': content_length)
    .post(string_query) (err, res, body) ->
        try
          result = JSON.parse(body)

          global.user_id = result.user.id
          global.user_token = result.token

          global.display_name = result.user.display_name

          global.is_sysop = result.user.is_sysop

          if global.is_sysop == undefined
              global.is_sysop = false

          funcs = new Functions

          i = 0

          if result.user.channels != undefined
              while i < result.user.channels.length
                  if result.user.channels[i].type == 2 or result.user.channels[i].type == 3 or result.user.channels[i].type == 4 or result.user.channels[i].type == 5
                      if funcs.searchArray(result.user.channels[i].id, global.channels_by_index) == false
                          if result.user.channels[i].title == '' and result.user.channels[i].hub != undefined
                              result.user.channels[i].title = result.user.channels[i].hub.short_title

                          global.channels_by_index.push(title: result.user.channels[i].title, id: result.user.channels[i].id, hub_id: result.user.channels[i].hub_id, type: result.user.channels[i].type, ts: null)
                    i++

          global.loggedin = true

          @robot.logger.info "Success!"

          @robot.logger.info "Checking for GOSU_JOIN_COMMUNITIES env var"
          if (process.env.GOSU_JOIN_COMMUNITIES != undefined)
              @robot.logger.info "Found, launching code"
              funcs.joinCommunities()
          else
              @robot.logger.info "GOSU_JOIN_COMMUNITIES env var is not set, resuming normal code."
        catch error
            @robot.logger.error "Oh no! We errored :( - #{error} - API Response Code: #{res.statusCode}"
            process.exit(1)

        @robot.logger.info "Trying to handshake!"

        chatHandshake = Client.chatHandshake(global.user_token)

        if (chatHandshake == false)
            @robot.logger.error "chatHandshake has errored! Falling back to pull!"
            @robot.logger.info "Launching listener via pull!"

            listener = new Listener
            listener.listen()

class Functions extends EventEmitter

    leaveChannel: (channelID) ->
        global.robot.http(global.api + "/me/channel/#{channelID}")
        .headers('Accept': 'application/json', 'Content-Type': 'application/json', 'X-Token': global.user_token)
        .delete() (err, res, body) ->
            try
              if res.statusCode isnt 200
                  global.robot.logger.error "Oh no! We errored under API :( - Response Code: #{res.statusCode}"
                  return

              result = JSON.parse(body)

              global.robot.logger.info "Successfully left direct channel with ID: #{channelID}"

              removeByAttr(global.channels_by_index, 'id', channelID)

            catch error
              global.robot.logger.error "Oh no! We errored :( - #{error} - API Response Code: #{res.statusCode}"

    joinCommunities: ->
        existing = []

        i = 0

        while i < global.channels_by_index.length
            existing.push(global.channels_by_index[i].hub_id)
            i++

        arr = process.env.GOSU_JOIN_COMMUNITIES.split(",")
        j = 0

        while j < arr.length
            global.robot.logger.info "Trying to join community with ID: #{arr[j]}"

            existingidx = existing.indexOf(arr[j])

            if existingidx == -1
                query = {
                    "hub_id": arr[j],
                    "user_id": global.user_id
                }

                string_query = JSON.stringify(query)
                content_length = string_query.length

                global.robot.http(global.api + "/hub/#{arr[j]}/join")
                .headers('Accept': 'application/json', 'Content-Type': 'application/json', 'Content-Length': content_length, 'X-Token': global.user_token)
                .post(string_query) (err, res, body) ->
                    try
                      if res.statusCode isnt 200
                          global.robot.logger.error "Oh no! We errored under API :( - Response Code: #{res.statusCode}"
                          return

                      global.robot.logger.info "Successfully joined community!"

                      query = {
                          "username": global.username,
                          "password": global.password,
                          "agent_id": global.agent_id,
                          "agent_name": global.agent_name,
                          "agent_type": global.agent_type
                      }

                      string_query = JSON.stringify(query)
                      content_length = string_query.length

                      global.robot.http(global.api + "/auth/login")
                      .headers('Accept': 'application/json', 'Content-Type': 'application/json', 'Content-Length': content_length)
                      .post(string_query) (err, res, body) ->
                          try
                            result = JSON.parse(body)

                            funcs = new Functions

                            l = 0

                            if result.user.channels != undefined
                                while l < result.user.channels.length
                                    if result.user.channels[l].type == 2 or result.user.channels[l].type == 3 or result.user.channels[l].type == 4 or result.user.channels[l].type == 5
                                        if funcs.searchArray(result.user.channels[l].id, global.channels_by_index) == false
                                            global.channels_by_index.push(title: result.user.channels[l].title, id: result.user.channels[l].id, hub_id: result.user.channels[l].hub_id, type: result.user.channels[l].type, ts: null)
                                    l++
                          catch error
                            global.robot.logger.error "Oh no! We errored :( - #{error} - API Response Code: #{res.statusCode}"
                    catch error
                        global.robot.logger.error "Oh no! We errored :( - #{error} - API Response Code: #{res.statusCode}"
            else
                global.robot.logger.warning "Already in community with ID: #{arr[j]}!"
            j++

    searchArray: (key, arr) ->
        i = 0

        while i < arr.length
            if arr[i].id == key
                return true
            i++
        return false

    findKeyIndex: (arr, key, val) ->
        i = 0

        while i < arr.length
            if arr[i][key] == val
                return i
            i++
        null

    removeByAttr = (arr, attr, value) ->
        i = 0

        while i < arr.length
            if arr[i] and arr[i].hasOwnProperty(attr) and arguments.length > 2 and arr[i][attr] == value
                arr.splice i, 1
            i++
        null

class Listener extends EventEmitter

  listen: ->
    if global.channels_by_index == 0
        global.robot.logger.error "Bot is not in any channel/community, exiting process."
        process.exit(1)
    else
        global.robot.logger.info "Found #{global.channels_by_index.length} joined channels/communities."
        global.active = true
        refresh_loop(refresh_rate)

  refresh_loop = (refresh_rate) ->
      if global.active = true
          chatHandshake = Client.chatHandshake(global.user_token)

          if (chatHandshake == false)
              receive_messages()
              setTimeout((-> refresh_loop(refresh_rate)), refresh_rate)
          else
              global.active = false
      else
          clearTimeout(refresh_rate)

  receive_messages = ->
      global.robot.logger.info "Attempting to receive messages from all joined channels"

      i = 0

      while i < global.channels_by_index.length
          channelID = global.channels_by_index[i].id

          if global.channels_by_index[i].ts == null
              global.robot.http(global.api + "/channel/#{channelID}/messages/99999999999.0")
              .headers('Accept': 'application/json', 'Content-Type': 'application/json', 'X-Token': global.user_token)
              .get() (err, res, body) ->
                  try
                    result = JSON.parse(body)
                    id = result['messages'][0]['channel']
                    funcs = new Functions
                    getIdx = funcs.findKeyIndex(global.channels_by_index, 'id', id)
                    global.channels_by_index[getIdx].ts = result['messages'][0]['timestamp']
                    title = global.channels_by_index[getIdx].title
                    global.robot.logger.info "Timestamp fetched for channel with ID: #{id}/title #{title}"
                  catch error
                      global.robot.logger.error "Oh no! We errored :( - #{error} - API Response Code: #{res.statusCode}"

          if global.channels_by_index[i].ts != null
              global.robot.http(global.api + "/channel/#{channelID}/messagessince/#{global.channels_by_index[i].ts}")
              .headers('Accept': 'application/json', 'Content-Type': 'application/json', 'X-Token': global.user_token)
              .get() (err, res, body) ->
                  try
                      result = JSON.parse(body)

                      k = 0

                      if body.length > 3
                          global.robot.logger.info "Successfully fetched messages..."
                          while k < result['messages'].length
                              if result['messages'][k]['user_message']['body'] != undefined and result['messages'][k].type == 1
                                  searchstr = "@#{global.display_name}:"
                                  bodyidx = result['messages'][k]['user_message']['body'].indexOf(searchstr)
                                  searchstrlength = global.display_name.length + 3

                                  if bodyidx == -1
                                      searchstr = "@#{global.display_name}"
                                      bodyidx = result['messages'][k]['user_message']['body'].indexOf(searchstr)
                                      searchstrlength = global.display_name.length + 2
                                  else if bodyidx == -1
                                      searchstr = " @#{global.display_name}"
                                      bodyidx = result['messages'][k]['user_message']['body'].indexOf(searchstr)

                              if result['messages'][k]['user_message']['body'] != undefined and result['messages'][k].type == 1
                                  id = result['messages'][k]['channel']
                                  funcs = new Functions
                                  getIdx = funcs.findKeyIndex(global.channels_by_index, 'id', id)
                                  global.channels_by_index[getIdx].ts = result['messages'][k]['timestamp']

                                  hardcodedcmds = ['join community']

                                  m = 0
                                  while m < hardcodedcmds.length
                                      arrstr = hardcodedcmds[m]
                                      searchstr = obj.body.search(arrstr)
                                      if searchstr != -1
                                          searchresult = i
                                      m++

                                  if searchresult != null and global.channels_by_index[getIdx].type == 3 or global.channels_by_index[getIdx].type == 3
                                      message_id = result['messages'][k]['id']
                                      account = {name: result['messages'][k]['user_message']['user']['display_name'], account_id: result['messages'][k]['user_message']['user']['id']}
                                      body = result['messages'][k]['user_message']['body']
                                      body = body.toLowerCase()
                                      body = "#{@robot.name} " + body
                                      send_time = global.channels_by_index[getIdx].ts
                                      update_time = global.channels_by_index[getIdx].ts
                                      emit_message(id, message_id, account, body, send_time, update_time)
                                  else if bodyidx == 0 and global.channels_by_index[getIdx].type != 3
                                      message_id = result['messages'][k]['id']
                                      account = {name: result['messages'][k]['user_message']['user']['display_name'], account_id: result['messages'][k]['user_message']['user']['id']}
                                      body = result['messages'][k]['user_message']['body']
                                      rep = body
                                      rep = rep.replace("#{searchstr}", "#{searchstr} #{@robot.name}")
                                      rep = rep.substring(rep.length, searchstrlength)
                                      send_time = global.channels_by_index[getIdx].ts
                                      update_time = global.channels_by_index[getIdx].ts
                                      emit_message(id, message_id, account, rep, send_time, update_time)
                                  else if bodyidx > 0 and global.channels_by_index[getIdx].type != 3
                                      message_id = result['messages'][k]['id']
                                      account = {name: result['messages'][k]['user_message']['user']['display_name'], account_id: result['messages'][k]['user_message']['user']['id']}
                                      body = result['messages'][k]['user_message']['body']
                                      rep = "#{@robot.name} " + body
                                      rep = rep.replace(", #{searchstr}", "")
                                      rep = rep.replace("#{searchstr}", "")
                                      send_time = global.channels_by_index[getIdx].ts
                                      update_time = global.channels_by_index[getIdx].ts
                                      emit_message(id, message_id, account, rep, send_time, update_time)
                                  else
                                     global.robot.logger.info "But no messages for me :("
                              k++
                      else
                          global.robot.logger.info "No messages to fetch."
                  catch error
                      global.robot.logger.error "Oh no! We errored :( - #{error} - API Response Code: #{res.statusCode}"
          else
              global.robot.logger.warning "Awaiting timestamp fetch for channel with ID: #{global.channels_by_index[i].id}"
          i++

  emit_message = (id, message_id, account, body, send_time, update_time) ->
      id = id
      message = {message_id: message_id, account: account, body: body, send_time: send_time, update_time: update_time}

      @robot.emit 'message',
                id,
                message.message_id,
                message.account,
                message.body,
                message.send_time,
                message.update_time

  refresh_rate = 2000

exports.use = (robot) ->
  new GOSU robot
