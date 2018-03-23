describe("Quickdraw.Internal.Error", ->
    describe('throw(throwable)', ->
        it('Error is thrown normally if no registered handlers', ->
            throwItem = new Error()
            expect(-> sandbox.qd._.errors.throw(throwItem)).to.throw(throwItem)
        )

        it('Error is passed to handler if one is registered', ->
            registered = sinon.spy()
            sandbox.qd.registerErrorHandler(registered)

            throwItem = new Error()
            sandbox.qd._.errors.throw(throwItem)

            assert.isTrue(registered.calledOnce, "Should call registered binding handler")
            assert.equal(registered.firstCall.args[0], throwItem, "Item to be thrown is passed")
        )
    )
)