require "/vendor/mootools-core.js"
require "/vendor/handlebars.js"
require "/vendor/metamorph.js"
require "/rickshaw.js"

describe "Controller", ->
  beforeEach setupCustomMatchers

  describe "creating", ->
    beforeEach ->
      @Todo = new Model()
      @todo = new @Todo {num: "one"}
      @TodoController = new Controller({
        Template: "todo"
      })

    it "has an associated model", ->
      todoController = new @TodoController( @todo )
      expect( todoController.model ).toBe( @todo )

    it "can be created without a model", ->
      todoController = new @TodoController()
      expect( todoController.model ).toBeNull()
      # and add model later
      expect( todoController.setModel( @todo ) ).toBe( todoController )
      expect( todoController.model ).toBe( @todo )

  describe "preattached events", ->
    it "attaches on initialize", ->
      fired = false
      args = null
      MyController = new Controller
        onCoolEvent: ->
          fired = true
          args = Array.from( arguments )
      controller = new MyController()
      controller.fireEvent( "coolEvent", [1, "cool"] )
      expect( fired ).toBe( true )
      expect( args ).toEqualArray( [1, "cool"] )

  describe "model events", ->
    beforeEach ->
      @Todo = new Model()
      @todo = new @Todo {num: "one"}
      @TodoController = new Controller({
        Template: "todo"
      })
      @todoController = new @TodoController()
      # TODO: This is so awful. God.
      spyOn( @todoController, "_modelChanged" ).andCallThrough()
      @todoController.setModel( @todo )
      @todoController._modelChanged.reset()

    it "binds events to the model", ->
      @todo.set neat: true, rad: true
      expect( @todoController._modelChanged.callCount ).toBe( 1 )
      expect( @todoController._modelChanged.argsForCall[0] ).toEqualArray( [@todo, ["neat", "rad"]] )

    it "removes the events when setting a new model", ->
      @todo2 = new @Todo()
      @todoController.setModel( @todo2 )
      @todo.set sweet: true
      expect( @todoController._modelChanged ).not.toHaveBeenCalled()

  describe "defer to model", ->
    beforeEach ->
      @Todo = new Model()
      @todo = new @Todo num: "one"
      @TodoController = new Controller DeferToModel: ["num"]
      @todoController = new @TodoController @todo

    it "should be able to defer methods to the model", ->
      expect( @todoController.num() ).toEqual( "one" )

  describe "rendering", ->
    beforeEach ->
      @Todo = new Model()
      @todo = new @Todo {text: "do stuff"}
      @TodoController = new Controller({
        Template: "todo"
        klass: -> "neato"
        text: -> "TODO: #{@model.get('text')}"
        Events:
          p:
            click: ->
              @todoClickArguments = Array.from arguments
      })
      rickshawTemplate "todo", "
        <p class='{{klass}}'>{{text}}</p>
      "

    it "renders later without element", ->
      todoController = new @TodoController( @todo )
      expect( $( "test" ).innerHTML ).toEqual( "" )
      expect( todoController.render() ).toBe( false )
      todoController.renderTo( $( "test" ) )
      expect( todoController.render() ).toBe( true )
      expect( todoController.rendered ).toBe( true )
      expect( $( "test" ).innerHTML ).toMatch( /<p class="neato">TODO: do stuff<\/p>/ )

    it "renders on create with element", ->
      todoController = new @TodoController( @todo, $( "test" ) )
      expect( $( "test" ).innerHTML ).toMatch( /<p class="neato">TODO: do stuff<\/p>/ )
      expect( todoController.rendered ).toBe( true )

    it "renders HTML to multiple locations simultaneously", ->
      todoController = new @TodoController( @todo )
      todoController.renderTo( $( "test" ) )
      todoController.renderTo( $( "test" ) )
      expect( $( "test" ).innerHTML ).toMatch( /(<p class="neato">TODO: do stuff<\/p>.+){2}/ )
      expect( todoController.rendered ).toBe( true )

    it "attaches element events", ->
      todoController = new @TodoController( @todo, $( "test" ) )
      $$( "#test p" ).fireEvent( "click", "Boom." )
      expect( todoController.todoClickArguments ).toEqualArray( ["Boom.", $$( "#test p" )[0]] )

    it "doesn't attach element events if `_useRelayedEvents` is true", ->
      todoController = new @TodoController( @todo )
      todoController._useRelayedEvents = true
      todoController.renderTo( $( "test" ) )
      $$( "#test p" ).fireEvent( "click", "Boom." )
      expect( todoController.todoClickArguments ).toBeUndefined()

    it "auto detaches events if they don't match the selector anymore", ->
      # TODO

    it "re-renders when the model changes and re-attaches events", ->
      todoController = new @TodoController( @todo, $( "test" ) )
      @todo.set( "text", "Neato." )
      expect( $$( "#test p" )[0].innerHTML ).toEqual( "TODO: Neato." )
      expect( todoController.rendered ).toBe( true )
