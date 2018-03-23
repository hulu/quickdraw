describe("Quickdraw.Updates.Internal", ->
    describe("run()", ->
        it("cancels current timer if there is one", ->
            sandbox.qd._.updates.updateNodeSet = ->
            timeoutSpy = sandbox.qd._.async.cancel = sinon.spy()
            sandbox.qd._.state.updates.key = 2
            sandbox.qd._.state.updates.immediate = true
            sandbox.qd._.updates.run()
            assert.isTrue(timeoutSpy.calledWith(2), "Should have cancelled current timeout")
            assert.isNull(sandbox.qd._.state.updates.key, "Should have set key back to null")
            assert.isFalse(sandbox.qd._.state.updates.immediate, "Should have set immediate back to false")
        )

        it("Does not apply updates if updates disabled", ->
            sandbox.qd.setConfig('updatesEnabled', false)
            updateSpy = sandbox.qd._.updates.updateNodeSet = sinon.spy()
            sandbox.qd._.state.updates.queue = [1,2,3,4]
            sandbox.qd._.updates.run()
            assert.isFalse(updateSpy.called, "Should not have called update node set as updates are disabled")
            assert.equal(sandbox.qd._.state.updates.queue.length, 4, "Should not have cleared out update queue")
        )
    )

    describe("updateNodeSet(nodes)", ->
        it("calls update dom node for every valid dom node", ->
            items = []
            for i in [0 ... 20]
                elm = sandbox.document.createElement("div")
                if i < 10
                    sandbox.qd._.storage.setInternalValue(elm, sandbox.qd.getConfig('baseModelKey'), {})
                items.push(elm)
            
            updateSpy = sinon.stub(sandbox.qd._.binding, 'updateDomNode')
            cacheSpy = sinon.stub(sandbox.qd._.templates, 'clearCache')
            renderSpy = sinon.stub(sandbox.qd._.renderer, 'schedule')

            sandbox.qd._.updates.updateNodeSet(items)

            assert.equal(updateSpy.callCount, 10, "Should have called update on 10 nodes")

            assert.isTrue(cacheSpy.called, 'Should have triggered a cache cleanup')
            assert.isTrue(renderSpy.called, 'Should have scheduled a render')
        )
    )

    describe("schedule(immediately)", ->
        it("if called without queue of max size, delayed update scheduled", ->
            delaySpy = sandbox.qd._.async.delayed = sinon.spy()
            sandbox.qd._.updates.schedule()
            assert.isTrue(delaySpy.calledWith(sandbox.qd._.updates.run, sandbox.qd.getConfig('defaultUpdateTimeout')), "Should have set delayed update")
        )

        it("if called with queue over max size, immediate update scheduled", ->
            immediateSpy = sandbox.qd._.async.immediate = sinon.spy()
            sandbox.qd._.state.updates.queue = [1,2,3,4]
            sandbox.qd.setConfig('maxQueuedUpdates', 1)
            sandbox.qd._.updates.schedule()
            assert.isTrue(immediateSpy.calledWith(sandbox.qd._.updates.run), "Should have set immediate update")
        )

        it("if called with immediate, immediate update scheduled", ->
            immediateSpy = sandbox.qd._.async.immediate = sinon.spy()
            sandbox.qd._.updates.schedule(true)
            assert.isTrue(immediateSpy.calledWith(sandbox.qd._.updates.run), "Should have set immediate update")
        )
    )

    describe("enqueue(domNode)", ->
        it("enqueues a given node into the update queue", ->
            fakeNode = {}
            sandbox.qd._.updates.enqueue(fakeNode)
            assert.isTrue(fakeNode in sandbox.qd._.state.updates.queue, "Should have node in queue")
        )

        it("Prevents double enqueuing of the same node", ->
            fakeNode = {}
            sandbox.qd._.updates.enqueue(fakeNode)
            sandbox.qd._.updates.enqueue(fakeNode)
            assert.equal(sandbox.qd._.state.updates.queue.length, 1, "Should only have one thing enqueued")
        )
    )
)

describe("Quickdraw.Updates.External", ->
    describe("disableUpdates()", ->
        it("When updates are disabled configuration is set", ->
            sandbox.qd.disableUpdates()
            assert.isFalse(sandbox.qd._.config.updatesEnabled, "Should disable updates in configuration")
        )

        it("When updates are disabled pending updates are cancelled", ->
            cancelSpy = sandbox.qd._.async.cancel = sinon.spy()

            sandbox.qd.disableUpdates()

            assert.isTrue(cancelSpy.calledOnce, "Should have called cancel")
        )
    )

    describe("enableUpdates()", ->
        it("When updates are reenabled configuration is set", ->
            sandbox.qd._.config.updatesEnabled = "foo"
            assert.equal(sandbox.qd.getConfig('updatesEnabled'), "foo", "fake variable observed")
            sandbox.qd.enableUpdates()

            assert.isTrue(sandbox.qd.getConfig('updatesEnabled'), "updates enabled properly set")
        )

        it("If no updates available not updates are scheduled", ->
            spy = sandbox.qd._.updates.schedule = sinon.spy()

            sandbox.qd.enableUpdates()
            assert.isFalse(spy.called, "Should not have called schedule updates")
        )

        it("If updates available when enabled they are scheduled", ->
            sandbox.qd._.state.updates.queue = [1,2,3]
            spy = sandbox.qd._.updates.schedule = sinon.spy()

            sandbox.qd.enableUpdates()
            assert.isTrue(spy.calledOnce, "Should call schedule updates when updates in queue")
            assert.isTrue(spy.firstCall.args[0], "Should have been called with immediate")
        )

        it("if requested run the queue before returning", ->
            sandbox.qd._.state.updates.queue = [1,2,3]
            spy = sandbox.qd._.updates.schedule = sinon.spy()
            runSpy = sandbox.qd._.updates.run = sinon.spy()

            sandbox.qd.enableUpdates(true)
            assert.isTrue(spy.calledWith(true), "Should have called schedule updates")
            assert.isTrue(runSpy.called, "Should have called run synchronously")
        )
    )
)