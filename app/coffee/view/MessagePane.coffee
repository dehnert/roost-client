do ->
  class com.roost.MessagePane extends Backbone.View
    className: 'message-pane'

    events: ->
      eventsHash = {}
      if !com.roost.ON_MOBILE
        eventsHash["click .message-pane-view"] = '_setSelectionOnClick'
      return eventsHash

    initialize: (options) =>
      @session = options.session
      @messageLists = options.messageLists
      @uiStateModel = @session.uiStateModel

      # When a model is added to the list (courtesy of the session),
      # add a new view to the DOM as well.
      @listenTo @messageLists, 'add', @_addPaneView
      @listenTo @messageLists, 'remove', @_removePaneView

      @listenTo @session.userInfo, 'change', @_toggleVisibility

      # Since we handle panes, pane selection, and keyboard shortcuts,
      # listen for any uiState changes and act accordingly
      @listenTo @uiStateModel, 'change:showNavbar', @_toggleNavbar

      # Hotkeys related to the selected pane.
      # Feel free to add more, just be sure to add any new hotkeys
      # to the HotkeyHelp modal.
      Mousetrap.bind('left', ((e) => @_moveSelection(1, e)))
      Mousetrap.bind('shift+left', ((e) => @_shiftSelection(-1, e)))
      Mousetrap.bind('right', ((e) => @_moveSelection(-1, e)))
      Mousetrap.bind('shift+right', ((e) => @_shiftSelection(1, e)))
      Mousetrap.bind('up', ((e) => @_moveMessageSelection(-1, e)))
      Mousetrap.bind('down', ((e) => @_moveMessageSelection(1, e)))
      Mousetrap.bind(['end', '>'], @_sendPaneToBottom)
      Mousetrap.bind(['home', '<'], @_sendPaneToTop)
      Mousetrap.bind('shift+v', @_clearPaneFilters)
      Mousetrap.bind('z', @_showPaneCompose)
      Mousetrap.bind('shift+f', @_showPaneFilters)

      # Hotkeys that affect the selected message
      Mousetrap.bind('r', @_selectedMessageReply)
      Mousetrap.bind('q', @_selectedMessageQuote)
      Mousetrap.bind('p', @_selectedMessagePM)
      Mousetrap.bind('alt+n', (=> @_selectedMessageFilter(false)))
      Mousetrap.bind('alt+shift+n', (=> @_selectedMessageFilter(true)))

      # Awkward that this is here, since all it does is call something
      # in the session.
      Mousetrap.bind('alt+x', @_closeSelectedPane)

      # Hotkeys for showing/hiding the hotkey help.
      Mousetrap.bind('?', @_showHelp)

      # Hotkeys for toggling uiState
      Mousetrap.bind('alt+h', @_toggleNavbarSetting)

      # By default HammerJS disables selecting, so we tell it not to put any CSS
      # properties on it. We also set touchAction to auto because whatever
      # Hammer does to emulate it on iOS Safari sucks.
      @hammer = new Hammer(@$el[0],
        recognizers: [[Hammer.Swipe, direction: Hammer.DIRECTION_HORIZONTAL]]
        cssProps: {}
        touchAction: 'auto')
        .on('swipeleft', => @_moveSelection(-1))
        .on('swiperight', => @_moveSelection(1))

    render: =>
      super()
      @$el.empty()
      @childViews = []
      @selectedPosition = 0

      for paneModel in @messageLists.models
        @_addPaneView(paneModel)

      if @childViews.length > 0
        @_setSelection()

      # Prevent scrolling in X, rely on swiping
      if com.roost.ON_MOBILE
        @$el.addClass('mobile')

      @_checkUiState()

    _checkUiState: =>
      @_toggleNavbar()

    _toggleNavbar: =>
      if not @uiStateModel.get('showNavbar')
        @$el.addClass('expanded')
      else
        @$el.removeClass('expanded')

    _toggleVisibility: =>
      if @session.userInfo.get('username')?
        @$el.show()
      else
        @$el.hide()

    _setSelectionOnClick: (evt) =>
      # Set the selection to a pane if that pane has received a click event
      @selectedPosition = @$('.message-pane-view').index(evt.currentTarget)
      @_setSelection()

    _moveSelection: (diff, e) =>
      # Keep our selected position within proper bounds.
      @selectedPosition = @selectedPosition - diff
      @selectedPosition = Math.min(@selectedPosition, @childViews.length - 1)
      @selectedPosition = Math.max(@selectedPosition, 0)

      @_setSelection()

      e?.preventDefault()
      e?.stopPropagation()

    _setSelection: =>
      selectedView = @childViews[@selectedPosition]

      # If we actually have a selected view, make sure to set the model and move the scroll
      if selectedView?
        for view in @childViews
          # Make sure the other views stop being selected
          if view.cid != selectedView.cid
            view.model.set('selected', false)

        # Mark our new selected view model as selected
        selectedView.model.set('selected', true)

        # Figure out how much we need to scroll left/right to get the new selected pane on screen
        offset = selectedView.$el.offset().left
        width = selectedView.$el.width()
        if offset < 0
          @$el.scrollLeft(@$el.scrollLeft() + offset)
        else if (offset + width) > @$el.width()
          @$el.scrollLeft(@$el.scrollLeft() + (offset + width - @$el.width()))

    _shiftSelection: (diff, e) =>
      # No point in doing this if we will overshoot the ends.
      if (@selectedPosition + diff) <= @childViews.length - 1 and (@selectedPosition + diff) >= 0
        currentSelected = @childViews[@selectedPosition]
        jumpTarget = @childViews[@selectedPosition + diff]

        # We want to save off where the moving view is scrolled.
        # After the move, we have to restore it.
        oldScroll = currentSelected.$el.scrollTop()

        # Jump before or after target, depending on diff
        if diff < 0
          jumpTarget.$el.before(currentSelected.$el)
        else
          jumpTarget.$el.after(currentSelected.$el)

        # Swap places in the childViews array
        @childViews[@selectedPosition] = jumpTarget
        @childViews[@selectedPosition + diff] = currentSelected

        # Update our selected position
        @selectedPosition = @selectedPosition + diff
        @_setSelection()

        # Restore the scroll position
        currentSelected.$el.scrollTop(oldScroll)

        # Update our session to make sure the models are ordered properly as well
        @session.movePane(@childViews[@selectedPosition].model.cid, @selectedPosition)

      e?.preventDefault()
      e?.stopPropagation()

    _toggleNavbarSetting: (e)=>
      @uiStateModel.set 'showNavbar', !@uiStateModel.get('showNavbar')
      e?.preventDefault()
      e?.stopPropagation()

    _toggleSubSetting: (e) =>
      @uiStateModel.set 'showSubs', !@uiStateModel.get('showSubs')
      e?.preventDefault()
      e?.stopPropagation()

    # Lots of tunneling into the selected pane for hotkeying
    _sendPaneToBottom: =>
      @childViews[@selectedPosition].model.set('position', null)
      @childViews[@selectedPosition].model.trigger 'reload'

    _sendPaneToTop: =>
      @childViews[@selectedPosition].model.set('position', null)
      @childViews[@selectedPosition].model.trigger 'toTop'

    _moveMessageSelection: (diff, e) =>
      @childViews[@selectedPosition].moveSelectedMessage(diff)
      e?.preventDefault()
      e?.stopPropagation()

    _clearPaneFilters: =>
      @childViews[@selectedPosition].model.set('filters', {})

    _showPaneCompose: (e) =>
      @childViews[@selectedPosition].model.set('showCompose', true)
      e?.preventDefault()
      e?.stopPropagation()

    _showPaneFilters: (e) =>
      @childViews[@selectedPosition].model.set('showFilters', true)
      e?.preventDefault()
      e?.stopPropagation()

    _closeSelectedPane: =>
      @session.removePane(@childViews[@selectedPosition].model.cid)

    # Tunneling down even further to the message
    _selectedMessageReply: (e) =>
      @childViews[@selectedPosition].selectedMessageReply()
      e?.preventDefault()
      e?.stopPropagation()

    _selectedMessageQuote: (e) =>
      @childViews[@selectedPosition].selectedMessageQuote()
      e?.preventDefault()
      e?.stopPropagation()

    _selectedMessagePM: (e) =>
      @childViews[@selectedPosition].selectedMessagePM()
      e?.preventDefault()
      e?.stopPropagation()

    _selectedMessageFilter: (withInstance) =>
      @childViews[@selectedPosition].selectedMessageFilter(withInstance)
      
    _addPaneView: (paneModel, collection, options) =>
      # Well, we have a pane now.
      @$('.no-panes').remove()

      # Create the pane, save it off
      paneView = new com.roost.MessagePaneView
        session: @session
        model: paneModel

      # Render and add to $el at right position
      index = options.at
      paneView.render()
      if @childViews.length > 0
        @childViews.splice(index, 0, paneView)
        @childViews[index - 1].$el.after(paneView.$el)
      else
        @childViews.push paneView
        @$el.append(paneView.$el)

      # Select the newly added pane, in the case that it's added during use.
      # Alternatively, if this model comes in as flagged selected, it's part of the
      # state load, so we should update the position.
      if options.select or paneModel.get('selected')
        @selectedPosition = index
        @_setSelection()

    _removePaneView: (model) =>
      for view in @childViews
        if view.model.cid == model.cid
          toDelete = view
      toDelete.remove()
      @childViews = _.reject(@childViews, ((view) => view.cid == toDelete.cid))

      # Move the selection off this model
      if model.get('selected')
        @_moveSelection(1)

      # Show a no-panes message if there are no panes.
      # Also make sure the navbar is out and we can see it.
      if @messageLists.length == 0
        @$el.append($('<div class="no-panes">').text('Click "+ New Pane" above to start browsing your messages.'))
        @session.uiStateModel.set('showNavbar', true)

    _showHelp: =>
      vex.dialog.alert(com.roost.templates['HotkeyHelp']())
