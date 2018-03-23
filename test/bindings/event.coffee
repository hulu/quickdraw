describe("Quickdraw.Bindings.Event", ->
    prepClick = ->
        event = sandbox.document.createEvent("MouseEvents")
        event.initMouseEvent("click", true, true)
        return event

    beforeEach(->
        sinon.spy(sandbox.document, 'addEventListener')
    )

    it("Handler is bound to event keyword", assertModuleBound("event"))

    it("Events are registered on parent document instead of node", ->
        node = createVirtualElement('div')
        node.addEventListener = sinon.stub()
        data = { click : sinon.stub() }

        callback = qdGetInitialize("event")
        callback(data, node)

        assert.isFalse(node.addEventListener.called, "Should not have added listener to node")
        assert.isTrue(sandbox.document.addEventListener.calledWith('click'), "Should have registered click on body")

        assert.equal(node.getValue('click', 'event'), data.click, "Should have stored the click callback in the node storage")
    )

    it("Events are only registered for once", ->
        node = createVirtualElement('div')
        sandbox.qd._.storage.setValue(sandbox.document, 'registry', {
            click : sinon.stub()
        }, 'event')
        data = { click : sinon.stub() }

        callback = qdGetInitialize("event")
        callback(data, node)

        assert.isFalse(sandbox.document.addEventListener.called, "Should not have called add event, already registered")
    )

    it("Events properly trigger their callbacks", ->
        node = createVirtualElement('div')
        data = { click : sinon.stub() }

        callback = qdGetInitialize("event")
        callback(data, node)

        clickEvent = prepClick()
        # call dispatch so target set correctly, but jsdom does not properly model events
        node.getRawNode().dispatchEvent(clickEvent)
        sinon.spy(clickEvent, 'preventDefault')

        # call into our global handler that would properly 
        dispatchEvent = sandbox.document.addEventListener.firstCall.args[1]
        dispatchEvent(clickEvent)

        assert.isTrue(data.click.called, "Should have called callback for event")
        assert.isTrue(clickEvent.preventDefault.called, 'Should prevent default by default')
    )

    it("Default can be explicitly allowed by event", ->
        node = createVirtualElement('div')
        data = { click : sinon.spy(-> return true) }

        callback = qdGetInitialize("event")
        callback(data, node)

        clickEvent = prepClick()
        node.getRawNode().dispatchEvent(clickEvent)
        sinon.spy(clickEvent, 'preventDefault')

        dispatchEvent = sandbox.document.addEventListener.firstCall.args[1]
        dispatchEvent(clickEvent)

        assert.isFalse(clickEvent.preventDefault.called, "Should not have prevented default")
    )
)