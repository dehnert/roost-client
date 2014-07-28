do ->
  class com.roost.NavBar extends Backbone.View
    className: 'navbar'

    tapClickEvents:
      '.logout': '_handleLogout'
      '.add-pane': '_addPane'
      '.personal-message': '_addPersonalMessagePane'
      '.user-info': '_showSettings'
      '.help': '_showHelp'


    events: ->
      eventsHash = {}
      return eventsHash

    initialize: (options) =>
      @session = options.session
      @userInfo = @session.userInfo
      @uiState = @session.uiStateModel
      @settingsPanel = new com.roost.SettingsPanel(
        uiState: @uiState
        subscriptions: @session.subscriptions
        session: @session)

      # Re-render on login/logout or uiState changes.
      @listenTo @userInfo, 'change', @render
      @listenTo @uiState, 'change:showNavbar change:limitReached', @render

      Mousetrap.bind('alt+s', @_showSettings)

    render: =>
      super()
      @$el.empty()
      template = com.roost.templates['NavBar']

      if not @uiState.get('showNavbar')
        @$el.addClass('hidden')
      else
        @$el.removeClass('hidden')

      @$el.append template(_.defaults({}, @uiState.attributes, @userInfo.attributes))

    _handleLogout: =>
      # Trigger the model, AuthenticationController will handle it
      @userInfo.trigger 'logout'

    _addPane: =>
      if !@uiState.get('limitReached')
        @session.addPane {}

    _addPersonalMessagePane: =>
      # Create a new pane with personal message filtering
      if !@uiState.get('limitReached')
        @session.addPane
          filters:
            is_personal: true

    # Show the settings modal.
    _showSettings: =>
      @settingsPanel.show()
      
      # Flip on/off showing subscriptions
      @uiState.set 'showSubs', !@uiState.get('showSubs')

    _showHelp: =>
      vex.dialog.alert(com.roost.templates['HotkeyHelp']())
