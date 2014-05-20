do ->
  class com.roost.MessagePaneModel extends Backbone.Model
    defaults: =>
      attrs = {
        position: null
        lastPositions: []
        messages: new Backbone.Collection()

        showFilters: false
        filters: {}

        showCompose: false
        composeFields: {
          class: ''
          instance: ''
          recipient: ''
          content: ''
        }
        sending: false

        selected: false

        isTopDone: false
        isBottomDone: true

        loaded: false
      }

      attrs.messages.model = com.roost.MessageModel

      return attrs