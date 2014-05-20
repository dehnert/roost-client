do ->
  TIME_FORMAT = 'MMMM Do YYYY, h:mm:ss a'
  QUOTE_LINE_PREFIX = '> '

  class com.roost.MessageView extends Backbone.View
    className: 'message-view'

    events:
      'click .reply': '_openReplyBox'
      'click .pm': '_openMessageBox'
      'click .quote': '_openQuoteBox'

    initialize: (options) =>
      @message = options.message
      @paneModel = options.paneModel

    render: =>
      @$el.empty()
      template = com.roost.templates['MessageView']
      @$el.append template(_.defaults({}, @message.attributes, {absoluteTime: @message.get('time').format(TIME_FORMAT)}))
      @updateTime()

    updateTime: =>
      @$('.time.from-now').text(@message.get('time').fromNow())

    remove: =>
      @undelegateEvents()
      @stopListening()
      @$el.removeData().unbind()
      super

      delete @$el
      delete @el

    _openReplyBox: =>
      @paneModel.set
        composeFields:
          class: @message.get('class')
          instance: @message.get('instance')
          recipient: ''
          content: ''
        showCompose: true

    _openMessageBox: =>
      @paneModel.set
        composeFields:
          class: 'message'
          instance: 'personal'
          recipient: shortZuser(@message.get('sender'))
          content: ''
        showCompose: true

    _openQuoteBox: =>
      quoted = QUOTE_LINE_PREFIX + @message.get('message').replace('\n', "\n#{QUOTE_LINE_PREFIX}")
      @paneModel.set
        composeFields:
          class: @message.get('class')
          instance: @message.get('instance')
          recipient: ''
          content: quoted
        showCompose: true