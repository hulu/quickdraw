describe('Quickdraw.Bindings.Complete', ->
    it('Handler is bound to complete keyword', assertModuleBound('complete'))

    it('Errors if given binding data is not a function', ->
        callback = qdGetInitialize('complete')
        errorSpy = sandbox.qd._.errors.throw = sinon.spy()
        callback({})
        assert.isTrue(errorSpy.called, "Should have thrown an error for non-function data")
    )

    it('Given callback is called with bound node, and after binding complete', (cb) ->
        callback = qdGetInitialize('complete')
        dom = sandbox.document.createElement('div')
        callback(->
            assert(true, "Is called")
            cb()
        , dom)
    )
)
