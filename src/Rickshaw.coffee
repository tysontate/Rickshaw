window.Rickshaw = {
  
  version: "0.0.0"
  
  Templates: {}
  Controllers: {}
  Persistence: {}
  
  templateRegex: /^Rickshaw-(\w+)-template$/
  
  # Reload all templates from "Rickshaw-*-template" <script> elements. This is
  # called on DOMReady, so you only need to call this if you're adding templates
  # after DOMReady.
  refreshTemplates: (idRegex) ->
    idRegex ||= @templateRegex
    
    Rickshaw.Templates = {}
    
    $$( "script[id^='Rickshaw']" ).each( (el) ->
      if parsedId = idRegex.exec( el.get( "id" ) )
        name = parsedId.getLast()
        Rickshaw.Templates[name] = el.get( "html" )
    )
}

document.addEvent( "domready", Rickshaw.refreshTemplates )

# MooTools Extensions
# ===================

Array.extend({
  # Returns true if the two arrays have the same values in the same order.
  # Handles nested arrays and objects.
  _equal: (arrayA, arrayB) ->
    return false unless typeOf( arrayA ) == "array" && typeOf( arrayB ) == "array"
    return false unless arrayA.length == arrayB.length
    return arrayA.every( (value, index) ->
      switch typeof value
        when "object" then Object._equal( value, arrayB[index] )
        when "array" then Array._equal( value, arrayB[index] )
        else value == arrayB[index]
    )
})

Object.extend({
  # Returns true if the two objects have the same keys and values. Handles
  # nested arrays and objects.
  _equal: (objectA, objectB) ->
    return false unless typeof objectA == "object" && typeof objectB == "object"
    return false unless Object.keys( objectA ).sort().join( "" ) == Object.keys( objectB ).sort().join( "" )
    return Object.every( objectA, (value, key) ->
      switch typeof value
        when "object" then Object._equal( value, objectB[key] )
        when "array" then Array._equal( value, objectB[key] )
        else value == objectB[key]
    )
})
