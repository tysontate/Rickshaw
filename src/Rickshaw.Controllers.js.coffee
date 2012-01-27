# Rickshaw._BaseController
# ========================
#
# (Private) Forms the basis of all Rickshaw controllers.
#
# Events
# ------
#
#   * onBeforeRender(controller) - Fired before the controller is rendered.
#   * onAfterRender(controller) - Fired after the controller is rendered.
#
Rickshaw._BaseController = new Class({

  Implements: [Events]

  # Options
  # -------

  # Name of template used to render this controller. (Required)
  Template: ""

  # Auto-attached element events. Keyed by element selector. (Optional)
  Events: {}

  # Params:
  #
  #   * `element` (Element, Elements, String, null) - DOM element, elements,
  #     or element id that this controller's rendered template HTML is rendered
  #     to. If this is null, it can be set to an Element or Elements later (as
  #     in the case of subController).
  initialize: (element=null, options={}) ->
    Rickshaw.register( this )
    @_metamorphs = [] # All render destination Metamorphs
    @_deferredSubControllers = [] # Delayed render subControllers
    @Events = Object.clone( @Events )
    Object.each this.__proto__, (fn, name) =>
      if match = name.match( /^on[A-Z][A-Za-z]+$/ )
        this.addEvent match[0], -> fn.apply( this, arguments )
    @rendered = false
    this.renderTo( element ) if element
    return this

  # Rendering
  # ---------

  # Adds a render destination metamorph in the bottom of the given element and
  # renders it.
  renderTo: (element) ->
    morph = new Rickshaw.Metamorph()
    @_metamorphs.push( morph )
    morph.inject( element )
    this._renderMetamorph( morph )

  # Re-render all metamorphs.
  render: ->
    return false unless @_metamorphs.length > 0
    this.fireEvent( "beforeRender", this )
    html = this._html()
    @_metamorphs.each( (morph) =>
      this._renderMetamorph( morph, html, false )
    )
    this._finalizeRender()
    return true

  _finalizeRender: ->
    this._renderSubControllers()
    this.fireEvent( "afterRender", this )

  # (Re-)render a specific metamorph.
  _renderMetamorph: (morph, html=null, fireEvent=true) ->
    html ||= this._html()
    morph.set( "html", html )
    this._attachEvents( morph )
    this._renderSubControllers( morph ) # TODO: move to onAfterRender
    @rendered = true
    this.fireEvent( "afterRender", this ) if fireEvent

  _html: ->
    if template = Rickshaw.Templates[@Template]
      return template( this )
    else
      throw name: "TemplateNotFound", message: "Template \"#{@Template}\" not found."

  # Subcontrollers
  # --------------

  _setupSubcontroller: (subcontroller) ->
    # create and store the metamorph on the subcontroller
    morph = new Rickshaw.Metamorph()
    subcontroller._metamorphs.push( morph )
    # render later
    @_deferredSubControllers.include( subcontroller )
    return morph.outerHTML()

  _renderSubControllers: ->
    while controller = @_deferredSubControllers.shift()
      controller.render()

  # Events
  # ------

  # Attach all element events to a given metamorph's elements.
  _attachEvents: (morph) ->
    Object.each( this._boundElementEvents(), (events, selector) =>
      morph.getElements( selector ).addEvents( events )
    )

  _boundElementEvents: ->
    return @__boundElementEvents if @__boundElementEvents
    controller = this
    @__boundElementEvents ||= Object.map( @Events, (events, selector) ->
      Object.map( events, (fn, eventName) ->
        fn = controller[fn] if typeof fn is "string"
        (e) -> fn.apply( controller, [e, this])
      )
    )

})

# Rickshaw.Controller
# ===================
#
# Render a single model using a template. Controllers can contain
# sub-controllers, rendered in-place with a `subController` Handlebar call in
# the template.
#
# Examples
# --------
#
# Basic:
#
#     # Template "user/greeting"
#     <p>Hello, {{ fullName }}!</p>
#     
#     # Controller
#     UserGreetingController = new Rickshaw.Controller({
#       Template: "user/greeting"
#       fullName: -> "#{@model.firstName} #{@model.firstName}"
#     })
#     controller = new UserRowController( user )
#     controller.renderTo( $( "user-greeting" ) )
#
# Sub-controllers:
#
#     # Template:
#     <p>Hello, {{ firstName }}! {{ subController logoutFormController }}</p>
#     
#     # Controller
#     UserGreetingController = new Rickshaw.Controller({
#       Template: "user/greeting"
#       initialize: (user) ->
#         @logoutFormController = new LogoutFormController( user )
#         this.parent( user )
#     })
#     controller = new UserRowController( user )
#     controller.renderTo( $( "user-greeting" ) )
#
Rickshaw._Controller = new Class({

  Extends: Rickshaw._BaseController

  # Attached model instance. This is set when this controller is created.
  model: null

  # An array of model property strings that will be created as simple defer
  # methods on this controller that return the value of the property.
  DeferToModel: []

  # Params:
  #
  #   * `model` (Rickshaw.Model) - Associated model.
  #   * `element` (Element, Elements, String, null) - DOM element, elements,
  #     or element id that this controller's rendered template HTML is rendered
  #     to. If this is null, it can be set to an Element or Elements later (as
  #     in the case of subController).
  initialize: (model=null, element=null) ->
    this.setModel( model, false ) if model
    this.parent( element )

  # Sets this controller's associated model instance and re-renders all
  # Metamorphs.
  setModel: (model, render=true) ->
    this._detachModelEvents @model if @model
    @model = model
    this._setupModelDefers @model
    this._attachModelEvents @model
    this.render() if render
    return this

  _setupModelDefers: (model) ->
    @DeferToModel.each (property) =>
      this[property] = -> model.get property

  # Hook up the model's events.
  _attachModelEvents: (model) ->
    model.addEvents(
      change: this._modelChanged
    )

  _detachModelEvents: (model) ->
    model.removeEvents(
      change: this._modelChanged
    )

  # Hooks
  # -----

  # bound
  _modelChanged: (model, changedProperties) ->
    this.render() if @rendered

  # TODO: Re-implement model delete / destroy events.

  Binds: ["_modelChanged"]

})

Rickshaw.Controller = Rickshaw.Utils.subclassConstructor( Rickshaw._Controller )


# Rickshaw.ListController
# -----------------------
#
# Render a Rickshaw.List.
#
Rickshaw._ListController = new Class({

  Extends: Rickshaw._BaseController

  # Attached Rickshaw.List instance. This is optionally set when this
  # controller is created.
  collection: null

  # Either a Rickshaw.Controller class or a function that takes a model
  # instance and returns the correct controller class for that model.
  Subcontroller: null

  # Params:
  #
  #   * `collection` (Rickshaw.List) - Associated collection of model
  #     elements to be rendered.
  #   * `element` (Element, Elements, String, null) - DOM element, elements,
  #     or element id that this controller's rendered template HTML is rendered
  #     to. If this is null, it can be set to an Element or Elements later (as
  #     in the case of the `subController` or `list` Handlebars helpers).
  initialize: (collection=null, element=null) ->
    this.setList( collection, false ) if collection
    this.parent( element )

  # Sets this controller's associated collection instance and re-renders all
  # Metamorphs.
  setList: (collection, render=true) ->
    this._detachListEvents( @collection ) if @collection
    @collection = collection
    this._attachListEvents( @collection )
    this.render() if render

  # Subcontrollers
  # --------------

  # Creates subcontroller for the model and hooks it all up.
  # Returns placeholder html.
  _setupSubcontrollerWithModel: (model) ->
    klass = if typeof @Subcontroller is "function"
      this.Subcontroller( model )
    else
      this.Subcontroller
    return this._setupSubcontroller( new klass( model ) )

  # Events
  # ------

  # Hook up the collection's events.
  _attachListEvents: ->
    @collection.addEvents(
      add: this._modelsAdded
      remove: this._modelsRemoved
      sort: this._collectionSorted
      change: this._modelChanged
    )

  # Detach a collection's events.
  _detachListEvents: ->
    @collection.removeEvents(
      add: this._modelsAdded
      remove: this._modelsRemoved
      sort: this._collectionSorted
      change: this._modelChanged
    )

  # Hooks
  # -----

  # TODO: So. The big trick here is going to be figuring out how to do the
  # minimum possible for each hook. When a model is appended, we should only be
  # appending the HTML and hooking up the events for that new HTML instead of
  # re-rendering the whole damn thing. When a model is removed, we should only
  # be removing those elements / sub-controllers. When the collection's
  # sort-order changes, we should figure out how to do the minimum
  # DOM-manipulation possible.

  _modelsAdded: (collection, models, position="unknown") ->
    console.log "_modelsAdded", arguments
    this.render()

  _modelsRemoved: (collection, models, position="unknown") ->
    console.log "_modelsRemoved", arguments
    this.render()

  _collectionSorted: ->
    console.log "_collectionSorted", arguments
    this.render()

  _modelChanged: (model, properties) ->
    console.log "_modelChanged", arguments
    # The model's `Rickshaw.Controller` instace will re-render itself.

  Binds: ["_modelsAdded", "_modelsRemoved", "_collectionSorted", "_modelChanged"]

})

Rickshaw.ListController = Rickshaw.Utils.subclassConstructor( Rickshaw._ListController )
