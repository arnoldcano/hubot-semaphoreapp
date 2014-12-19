# Yup, you can only load a custom adapter by path if it has the same name as a builtin.

Adapter = require 'hubot/src/adapter'

# Mock adapter

class MockAdapter extends Adapter
    genericEmit = (evt) ->
        return (envelope, strings...) ->
            @emit evt, envelope, strings...

    constructor: (robot) ->
        super(robot)

        @send =  genericEmit 'send'
        @reply = genericEmit 'reply'
        @topic = genericEmit 'topic'
        @play =  genericEmit 'play'

    run: -> @emit 'connected'
    close: -> @emit 'closed'


exports.use = (robot) ->
    new MockAdapter robot
