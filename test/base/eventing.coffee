describe("Quickdraw.Internal.Eventing", ->
    describe("addEventing(obj)", ->
        beforeEach(->
            sandbox.simpleObject = {}
            sandbox.qd._.eventing.add(sandbox.simpleObject)
        )

        it("Objects have event methods added to them after call", ->
            simpleObject = sandbox.simpleObject

            assert.isTrue(simpleObject.on?, "Should have 'on' registration method")
            assert.isTrue(simpleObject.once?, "Should have 'once' registration method")
            assert.isTrue(simpleObject.removeListener?, "Should have 'removeListener' method")
            assert.isTrue(simpleObject.emit?, "Should have 'emit' method")
        )

        it("Methods registered via 'on' called every time registed event fired", ->
            simpleObject = sandbox.simpleObject

            handler = sinon.spy()
            simpleObject.on('testCall', handler)

            for i in [0 ... 10]
                simpleObject.emit('testCall', [], false)

            assert.equal(handler.callCount, 10, "Should have called test handler 10 times")
        )

        it("Methods registered via 'once' called only on first event and never again", ->
            simpleObject = sandbox.simpleObject

            handler = sinon.spy()
            simpleObject.once('testCall', handler)

            for i in [0 ... 10]
                simpleObject.emit('testCall', [], false)

            assert.equal(handler.callCount, 1, "Should only call method once")
        )

        it("Handler is removed if requested", ->
            simpleObject = sandbox.simpleObject

            handler = sinon.spy()
            simpleObject.on('testCall', handler)

            simpleObject.emit('testCall', [], false)

            simpleObject.removeListener('testCall', handler)

            simpleObject.emit('testCall', [], false)

            assert.isTrue(handler.calledOnce, "Should only have been called once since removed before second call")
        )

        it("Emit properly calls all handlers registered for event", ->
            simpleObject = sandbox.simpleObject

            handlers = []
            for i in [0 ... 5]
                handler = sinon.spy()
                simpleObject.on('testCall', handler)
                handlers.push(handler)

            simpleObject.emit('testCall', [], false)

            for handle in handlers
                assert.isTrue(handle.calledOnce, "Should call each handle once")

            # remove implicit return
            return
        )

        it("Emit defaults to an async call", ->
            simpleObject = sandbox.simpleObject
            simpleObject.on('testCall', ->)

            asyncSpy = sandbox.qd._.async.immediate = sinon.spy()

            simpleObject.emit('testCall', [])

            assert.isTrue(asyncSpy.calledOnce, "Should have tried to setup async call")
        )

        it("Registrations removed before async call executed are still executed", ->
            simpleObject = sandbox.simpleObject
            handler = sinon.spy()
            simpleObject.on('testCall', handler)

            asyncSpy = sandbox.qd._.async.immediate = sinon.spy()

            simpleObject.emit('testCall', [])

            assert.isFalse(handler.called, "Should not have called handler yet since async")

            simpleObject.removeListener('testCall', handler)
            # call async call now
            asyncSpy.firstCall.args[0]()

            assert.isTrue(handler.calledOnce, "Should have called handler now since registered on initial emit")
        )

        it("Arguments given to emit are given to callback", ->
            simpleObject = sandbox.simpleObject

            handler = sinon.spy()
            simpleObject.on('testCall', handler)

            args = [1, 2, 3]
            simpleObject.emit('testCall', args, false)

            assert.isTrue(handler.calledOnce, "Should have called handler")
            assert.equal(args.length, handler.firstCall.args.length, "Correct number of arguments given")
            for arg, i in args
                assert.equal(arg, handler.firstCall.args[i], "Argument #{i} in correct order")

            # remove implicit return
            return
        )

        it("'this' of callback is the object", ->
            simpleObject = sandbox.simpleObject

            ranCheck = false
            handler = sinon.spy(->
                assert.equal(simpleObject, @, "Should have passed object as 'this'")
                ranCheck = true
            )
            simpleObject.on('testCall', handler)

            simpleObject.emit('testCall', [], false)

            assert.isTrue(ranCheck, "Should have run handler")
        )
    )
)