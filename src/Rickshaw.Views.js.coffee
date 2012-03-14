# View
# ====
#
# Events:
#
#     * onRender( view ) - Fired after the template is rendered to the DOM, but
#       before any subviews are rendered.
#     * onAfterRender( view, subviews ) - Fired after a complete render of this
#       view as well as all of its subviews (and their subviews, and so on).
#
window.View = new Class

  Implements: [Events]

  initialize: (@controller, @templateName, element, position="bottom") ->
    if typeof @templateName is "string"
      unless this.template = Rickshaw.Templates[@templateName]
        throw new Error "Template \"#{template}\" not found in Rickshaw.Templates."
    unless @controller
      throw new Error "The associated controller for #{this} can't be false-y."

    @subviews = []
    @morph = new Rickshaw.Metamorph( this )

    if element
      @morph.inject( element, position )
      this.render()

    return this

  toString: -> "<Rickshaw.View #{@templateName}>"

  # Rendering
  # ---------

  renderTo: (element, position) ->
    @morph.remove() if @rendered
    @morph.inject( element, position )
    this.render()

  render: ->
    @morph.setHTML( this.html() )
    @rendered = true
    this.fireEvent( "render", [this] )
    for view in @subviews
      view.render()
    this.fireEvent( "afterRender", [this, @subviews] )
    true

  html: ->
    return this.template( @controller, data: view: this )

  placeholderHTML: ->
    return @morph.outerHTML()

  injectPlaceholder: (element, location = "bottom") ->
    @morph.inject( element, location )

  # Subcontrollers / subviews
  # -------------------------

  # Returns a new sub-View instance for the given subcontroller.
  _subview: (subcontroller, method = "push") ->
    view = new View( subcontroller, subcontroller.Template )
    @subviews[method]( view )
    return view

  # Returns a new ListView instance for our subcontroller.
  _listview: (listSelector) ->
    @listView = new ListView( @controller, listSelector )
    @subviews.push( @listView )
    return @listView

  # Elements
  # --------

  getElement: (selector) -> @morph.getElement( selector )

  getElements: (selector) -> @morph.getElements( selector )

  # Events
  # ------

  addEvents: (events) ->
    # TODO: Handle relay events in the controller
    Object.each events, (events, selector) =>
      this.getElements( selector ).addEvents( events )

# ListView
# --------
#
# Special kind of view that only manages the List in a ListController.
#
window.ListView = new Class

  Extends: View

  initialize: (controller, @selector, element, position) ->
    this.parent( controller, null, element, position )
    # Add subcontrollers for all our list elements
    for model in @controller.list
      this._subview( @controller.subcontrollerFor( model ) )
    # ListController events
    @controller.addEvents
      modelAppend: this.append
      modelPrepend: this.prepend
    return this

  toString: -> "<Rickshaw.ListView #{@selector}>"

  getElement: (selector) -> @listElement().getElement( selector )

  getElements: (selector) -> @listElement().getElements( selector )

  listElement: ->
    @_listElement ||= @morph.startMarkerElement().getNext()

  html: ->
    listTags = ( new Element( @selector ) ).outerHTML.match( /(<[^>]+>)(<\/[^>]+>)/ )
    html = []
    html.push( listTags[1] )
    for view in @subviews
      html.push( view.placeholderHTML() )
    html.push( listTags[2] )
    return html.join( "" )

  # Adding
  # ------

  append: (subcontroller) ->
    view = this._subview( subcontroller, "push" )
    view.renderTo( this.listElement(), "bottom" )

  prepend: (subcontroller) ->
    view = this._subview( subcontroller, "unshift" )
    view.renderTo( this.listElement(), "top" )

  Binds: ["append", "prepend"]