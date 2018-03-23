describe("Quickdraw.Internal.Async", ->
    describe("immediate(callback)", ->
        it("updates scheduled for the next available time slot", ->
            res = sandbox.qd._.async.immediate(->)
            clearTimeout(res)

            assert.isTrue(sandbox.setTimeout.calledOnce, "Should have called setTimeout")
            assert.equal(sandbox.setTimeout.firstCall.args[1], 0, "Second argument should be 0")
        )
    )

    describe("delayed(callback, time)", ->
        it("updates scheduled for given time", ->
            res = sandbox.qd._.async.delayed((->), 50)
            clearTimeout(res)

            assert.isTrue(sandbox.setTimeout.calledOnce, "Should have called setTimeout")
            assert.equal(sandbox.setTimeout.firstCall.args[1], 50, "Should use the timeout given")
        )

        it("defaults to immediate if no time given", ->
            res = sandbox.qd._.async.delayed(->)
            clearTimeout(res)

            assert.isTrue(sandbox.setTimeout.calledOnce, "Should have called setTimeout")
            assert.equal(sandbox.setTimeout.firstCall.args[1], 0, "should use a timeout of 0")
        )

        it("Given callback is executed", ->
            realCallback = sinon.stub()
            res = sandbox.qd._.async.delayed(realCallback)
            clearTimeout(res)

            assert.isTrue(sandbox.setTimeout.calledOnce, "Should have called setTimeout")

            wrappedCallback = sandbox.setTimeout.firstCall.args[0]
            wrappedCallback()

            assert.isTrue(realCallback.calledOnce, "Should have called the real callback")
        )

        it("if given callback throws an error it is caught and delegated", ->
            errorSpy = sandbox.qd._.errors.throw = sinon.spy()
            realError = new Error("THIGNS BROKE!")
            res = sandbox.qd._.async.delayed(->
                throw realError
            )
            clearTimeout(res)

            assert.isTrue(sandbox.setTimeout.calledOnce, "Should have called setTimeout")
            
            wrappedCallback = sandbox.setTimeout.firstCall.args[0]
            wrappedCallback()

            assert.isTrue(errorSpy.calledOnce, "Should have called the error handler")
            assert.equal(errorSpy.firstCall.args[0].errorInfo().error, realError, "Real error is passed through quickdraw error")
        )
    )

    describe("cancel(timerId)", ->
        it("calls the clearTimeout method with given value", ->
            sandbox.qd._.async.cancel(20)

            assert.isTrue(sandbox.clearTimeout.calledOnce, "Should have called clearTimeout")
            assert.equal(sandbox.clearTimeout.firstCall.args[0], 20, "Should pass the given value")
        )
    )
)