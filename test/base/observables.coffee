describe("Quickdraw.Observables", ->
    describe("observable():", ->
        it("Function returned has initial value passed", ->
            numWrap = sandbox.qd.observable(2)
            assert.equal(numWrap(), 2, "Integer returned properly")

            boolWrap = sandbox.qd.observable(true)
            assert.equal(boolWrap(), true, "Boolean returned properly")

            stringWrap = sandbox.qd.observable("Hello World")
            assert.equal(stringWrap(), "Hello World", "String returned properly")

            assert.equal(numWrap.raw, null, "No model initially attached to observable")
        )

        it("Function value updates properly", ->
            numWrap = sandbox.qd.observable(2)
            numWrap(10)
            assert.equal(numWrap(), 10, "Integer updated properlty")

            boolWrap = sandbox.qd.observable(true)
            boolWrap(false)
            assert.equal(boolWrap(), false, "Boolean updated properly")

            stringWrap = sandbox.qd.observable("Hello World")
            stringWrap("Goodbye World")
            assert.equal(stringWrap(), "Goodbye World", "String updated properly")
        )

        it("Function value is allowed to change types", ->
            wrapper = sandbox.qd.observable(2)
            assert.equal(wrapper(), 2, "Initial value correct")
            wrapper(false)
            assert.equal(wrapper(), false, "Update to boolean okay")
            wrapper("world")
            assert.equal(wrapper(), "world", "Update to string okay")
            wrapper(null)
            assert.isNull(wrapper(), "Set value to null okay")
        )

        it("Observable enqueues dependencies when updated", ->
            # prevent actual updates from occuring
            scheduleStub = sinon.stub(sandbox.qd._.updates, 'schedule')
            wrapped = sandbox.qd.observable(1)
            fakeModel = {things : "stuff"}
            element = sandbox.document.createElement("div")
            sandbox.qd._.storage.setInternalValue(element, 'handlers', {})
            sandbox.qd._.observables.addDependency.call(wrapped, fakeModel, element)
            wrapped(23)
            assert.equal(sandbox.qd._.state.updates.queue.length, wrapped.__dependencies.length, "All dependencies enqueued")
            for dependency, i in wrapped.__dependencies
                assert.equal(sandbox.qd._.state.updates.queue[i], dependency.domNode, "All dependencies correct")
            assert.isTrue(scheduleStub.called, 'Should have called schedule stub to setup next update')
        )
    )

    describe("observableArray():", ->
        it("Function returned has initial value passed", ->
            initialData = [1, 2, 3]
            wrapped = sandbox.qd.observableArray(initialData)
            assert.equal(wrapped(), initialData, "Initial data correctly stored")
        )

        it("Index of works properly", ->
            initialData = [1, 2, 3]
            wrapped = sandbox.qd.observableArray(initialData)
            assert.equal(wrapped.indexOf(2), 1, "Correct index found")
            assert.equal(wrapped.indexOf(4), -1, "-1 on error")
        )

        it("Slice calls the slice of the internal array", ->
            initialData = [1, 2, 3]
            wrapped = sandbox.qd.observableArray(initialData)
            sinon.spy(wrapped.value, "slice")
            wrapped.slice(1, 2)
            assert.isTrue(wrapped.value.slice.calledOnce, "Internal slice called")
        )

        it("Push adds internally and calls signal update", ->
            wrapped = sandbox.qd.observableArray()
            spy = sinon.spy(sandbox.qd._.observables, "updateDependencies")
            wrapped.push(1)
            assert.isTrue(spy.calledOnce, "Called update dependencies")
            assert.equal(wrapped().length, 1, "Array has 1 item now")
            assert.equal(wrapped()[0], 1, "Item given is added")
        )

        it("Pop removes internally and calls signal update", ->
            wrapped = sandbox.qd.observableArray([2])
            spy = sinon.spy(sandbox.qd._.observables, "updateDependencies")
            assert.equal(wrapped.pop(), 2, "Item poped off and returned")
            assert.isTrue(spy.calledOnce, "Called update dependencies")
            assert.equal(wrapped().length, 0, "Array has no items")
        )

        it("Unshift adds internally and calls signal update", ->
            wrapped = sandbox.qd.observableArray()
            spy = sinon.spy(sandbox.qd._.observables, "updateDependencies")
            wrapped.unshift("hi")
            assert.isTrue(spy.calledOnce, "Called update dependencies")
            assert.equal(wrapped().length, 1, "Array has 1 item now")
            assert.equal(wrapped()[0], "hi", "Item given is added")
        )

        it("Shift removes internally and calls signal update", ->
            wrapped = sandbox.qd.observableArray([1])
            spy = sinon.spy(sandbox.qd._.observables, "updateDependencies")
            assert.equal(wrapped.shift(), 1, "Value is removed and returned")
            assert.isTrue(spy.calledOnce, "Called update dependencies")
            assert.equal(wrapped().length, 0, "No items left in the array")
        )

        it("Reverse interally reverse and updates", ->
            wrapped = sandbox.qd.observableArray([1, 2])
            spy = sinon.spy(sandbox.qd._.observables, "updateDependencies")
            wrapped.reverse()

            assert.isTrue(spy.calledOnce, "Called update dependencies")
            assert.equal(wrapped()[0], 2, "2 is first")
            assert.equal(wrapped()[1], 1, "1 is second")
        )

        it("Sort internally sorts and updates", ->
            wrapped = sandbox.qd.observableArray([2, 1])
            spy = sinon.spy(sandbox.qd._.observables, "updateDependencies")
            wrapped.sort()

            assert.isTrue(spy.calledOnce, "Called update dependencies")
            assert.equal(wrapped()[0], 1, "1 is first")
            assert.equal(wrapped()[1], 2, "2 is second")
        )

        it("Splice calls internal splice and updates", ->
            wrapped = sandbox.qd.observableArray([1, 4])
            stub = sinon.stub(sandbox.qd._.observables, "updateDependencies")
            stub2 = sinon.stub(wrapped.value, "splice")

            wrapped.splice(1, 0, 2, 3)

            assert.isTrue(stub.calledOnce, "Called update dependencies")
            assert.isTrue(stub2.calledOnce, "Called splice internally")

            [start, deleteCount, elements...] = stub2.firstCall.args
            assert.equal(start, 1, "Didn't pass correct start position")
            assert.equal(deleteCount, 0, "Didn't pass correct delete count")
            assert.deepEqual(elements, [2, 3], "Didn't pass new elements to splice")
        )

        it("Remove takes out all the matching items", ->
            wrapped = sandbox.qd.observableArray([1, 2, 2, 2, 3])
            stub = sinon.stub(sandbox.qd._.observables, "updateDependencies")
            removed = wrapped.remove(2)

            assert.isTrue(stub.calledOnce, "Called update dependencies")
            assert.equal(removed.length, 3, "Removed all the items")
            assert.equal(wrapped().length, 2, "Items left over")
        )

        it("Remove takes out all items matching function", ->
            wrapped = sandbox.qd.observableArray([1, 2, 2, 2, 3])
            stub = sinon.stub(sandbox.qd._.observables, "updateDependencies")
            removed = wrapped.remove((item) -> return item == 2)

            assert.isTrue(stub.calledOnce, "Called update dependencies")
            assert.equal(removed.length, 3, "Removed all the items")
            assert.equal(wrapped().length, 2, "Items left over")
        )

        it("Remove all takes out all requested items", ->
            wrapped = sandbox.qd.observableArray([1, 2, 2, 2, 3])
            stub = sinon.stub(sandbox.qd._.observables, "updateDependencies")
            removed = wrapped.removeAll([2, 3])

            assert.isTrue(stub.calledOnce, "Called update dependencies")
            assert.equal(removed.length, 4, "Removed all requested items")
            assert.equal(wrapped().length, 1, "Left only one")
            assert.equal(wrapped()[0], 1, "Only number 1 is left")
        )

        it("Remove all items if nothing passed to removeAll", ->
            wrapped = sandbox.qd.observableArray([1, 2, 2, 2, 3])
            stub = sinon.stub(sandbox.qd._.observables, "updateDependencies")
            removed = wrapped.removeAll()

            assert.isTrue(stub.calledOnce, "Called update dependencies")
            assert.equal(removed.length, 5, "Removed all")
            assert.equal(wrapped().length, 0, "Nothing left")
        )
    )

    describe("computed():", ->
        it("Return value of function given is properly returned", ->
            computed = sandbox.qd.computed(->
                return 3
            , this, [sandbox.qd.observable()])

            assert.equal(computed(), 3, "Value should still be returned")
        )

        it("Parameters computed called with are handed to internal function", ->
            stub = sinon.stub()
            computed = sandbox.qd.computed(stub, this, [sandbox.qd.observable()])
            computed(1, 2, 3, 4)

            assert.isTrue(stub.calledOnce, "Called the internal function")
            assert.equal(stub.getCall(0).args.length, 4, "All arguments passed through")
        )

        it("This object is properly bound for internal function", ->
            that = {
                something : true
            }
            computed = sandbox.qd.computed(->
                assert.isTrue(this.something, "This value properly bound")
            , that, [sandbox.qd.observable()])

            computed()
        )

        describe("Throws an error:", ->
            computedCallback = ->
            that = {
                something : true
            }

            it("with no thisBinding", ->
                assert.throws(-> sandbox.qd.computed(computedCallback, null, [sandbox.qd.observable()]))
            )

            it("with no observables", ->
                assert.throws(-> sandbox.qd.computed(computedCallback, that, []))
            )

            it("with invalid observables", ->
                assert.throws(-> sandbox.qd.computed(computedCallback, that, [null]))
            )
        )

    )

    describe("unwrapObservable(possible)", ->
        it("Non observable, non function value directly returned", ->
            value = "cats"
            assert.equal(sandbox.qd.unwrapObservable(value), value, "Value returned")
        )

        it("Non observable function directly returned", ->
            value = ->
                return false
            assert.equal(sandbox.qd.unwrapObservable(value), value, "Value returned")
        )

        it("Observable value unwrapped and returned", ->
            value = sandbox.qd.observable("cats")
            assert.equal(sandbox.qd.unwrapObservable(value), "cats", "Value unwrapped")
        )

        it("Recursive observables not unwrapped by default", ->
            thisObs = sandbox.qd.observable('that')
            value = sandbox.qd.observable({
                this : thisObs
            })
            assert.equal(sandbox.qd.unwrapObservable(value).this, thisObs, "Should not unwrap recursive property")
        )

        it("Recursive unwrap of null wrapped observable is still null", ->
            value = sandbox.qd.observable(null)
            assert.isNull(sandbox.qd.unwrapObservable(value, true), 'Wrapped nulls should remain null')
        )

        it("Recursive observables all unwrapped and returned", ->
            value = sandbox.qd.observable({
                this : sandbox.qd.observable('that')
                other : sandbox.qd.observable(2)
                thing : 4
                nest : sandbox.qd.observable({
                    foo : sandbox.qd.observable('bar')
                })
            })
            unwrapped = sandbox.qd.unwrapObservable(value, true)
            assert.equal(unwrapped.this, 'that', "This should point to that")
            assert.equal(unwrapped.other, 2, "Other should be two")
            assert.equal(unwrapped.thing, 4, "Thing should be 4")
            assert.equal(unwrapped.nest.foo, 'bar', "Nested unwrapping works")
        )
    )
)

describe("Quickdraw.Internal.Observables", ->
    describe("addDependency(model, element)", ->
        it("Element given is tied to model given", ->
            model = {
                label : sandbox.qd.observable("cats")
            }
            element = sandbox.document.createElement("div")
            sandbox.qd._.observables.addDependency.call(model.label, model, element)
            assert.equal(sandbox.qd._.storage.getInternalValue(element, sandbox.qd.getConfig('baseModelKey')), model, "Model correctly tied to element")
        )

        it("Element given is made a dependency of observable", ->
            model = {
                label : sandbox.qd.observable("cats")
            }
            element = sandbox.document.createElement("div")
            sandbox.qd._.observables.addDependency.call(model.label, model, element)

            dependencies = sandbox.qd._.observables.getDependencies.call(model.label)

            assert.equal(dependencies.length, 1, "Dependency is added when new")
            assert.equal(dependencies[0].domNode, element, "Element was added as dependency")
        )

        it("Element given is not made a dependency if already a dependency", ->
            model = {
                label : sandbox.qd.observable("cats")
            }
            element = sandbox.document.createElement("div")
            sandbox.qd._.observables.addDependency.call(model.label, model, element)
            sandbox.qd._.observables.addDependency.call(model.label, model, element)

            assert.equal(model.label.__dependencies.length, 1, "Dependency is added when new")
            assert.equal(model.label.__dependencies[0].domNode, element, "Element was added as dependency")
        )

        it("Null model or element causes dependencies to remain unchanged", ->
            obv = sandbox.qd.observable("cats")
            sandbox.qd._.observables.addDependency.call(obv, null, null)

            assert.isUndefined(obv.__dependencies, "Dependencies not setup")
        )
    )

    describe("getDependencies()", ->
        it("Dependency array is directly returned if exists", ->
            obv = sandbox.qd.observable("cats")
            obv.__dependencies = [1, 2, 3]

            assert.equal(sandbox.qd._.observables.getDependencies.call(obv), obv.__dependencies, "Array directly returned")
        )

        it("If no dependencies, empty array is returned", ->
            obv = sandbox.qd.observable("cats")
            assert.equal(sandbox.qd._.observables.getDependencies.call(obv).length, 0, "Empty array for no set dependency")
        )

        it("Dependencies from all computeds are returned", ->
            obv = sandbox.qd.observable("cat")
            computed1 = sandbox.qd.computed((->), this, [obv])
            computed2 = sandbox.qd.computed((->), this, [obv])
            computed1.__dependencies = [1, 2, 3, 4]
            computed2.__dependencies = [5, 6, 7, 8]

            dependents = sandbox.qd._.observables.getDependencies.call(obv)

            assert.equal(dependents.length, 8, "All computed dependencies returned")
        )

        it("If no dependences, empty array is returned", ->
            obv = sandbox.qd.observable("cats")
            assert.equal(sandbox.qd._.observables.getDependencies.call(obv).length, 0, "Empty array for no dependencies")
        )
    )

    describe("addComputedDependency(computed)", ->
        it("Computed is added to observable", ->
            obv = sandbox.qd.observable("cat")
            computed = sandbox.qd.computed((->), this, [obv])

            assert.equal(obv.__computedDependencies.length, 1, "Dependency was added")
            assert.equal(obv.__computedDependencies[0], computed, "Computed is the first item")
        )
    )

    describe("updateDependencies()", ->
        it("Non-immediate update enqueues all dependencies and sets timeout", ->
            fakeDepend = [{
                domNode : {
                    _qdData : {
                        _ : {
                            handlers : {}
                        }
                    }
                }
                handlers : []
            }, {
                domNode : {
                    _qdData : {
                        _ : {
                            handlers : {}
                        }
                    }
                }
                handlers : []
            }, {
                domNode : {
                    _qdData : {
                        _ : {
                            handlers : {}
                        }
                    }
                }
                handlers : []
            }]
            obv = sandbox.qd.observable(false)
            getSpy = sinon.stub(sandbox.qd._.observables, "getDependencies", ->
                return fakeDepend
            )
            enqueueSpy = sinon.spy(sandbox.qd._.updates, "enqueue")
            scheduleSpy = sinon.stub(sandbox.qd._.updates, "schedule")

            sandbox.qd._.observables.updateDependencies.call(obv)

            assert.equal(enqueueSpy.callCount, 3, "Should have enqueued three dependencies")
            assert.isTrue(scheduleSpy.called, "Should have enqueued dependencies to update")
        )

        it("Immediate update calles update node set directly", ->
            fakeDepend = [{
                domNode : {
                    _qdData : {
                        _ : {
                            handlers : {}
                        }
                    }
                }
                handlers : []
            }, {
                domNode : {
                    _qdData : {
                        _ : {
                            handlers : {}
                        }
                    }
                }
                handlers : []
            }, {
                domNode : {
                    _qdData : {
                        _ : {
                            handlers : {}
                        }
                    }
                }
                handlers : []
            }]
            obv = sandbox.qd.observable(false)
            getSpy = sinon.stub(sandbox.qd._.observables, "getDependencies", ->
                return fakeDepend
            )
            enqueueSpy = sinon.spy(sandbox.qd._.updates, "enqueue")
            updateSpy = sinon.stub(sandbox.qd._.updates, "updateNodeSet")

            sandbox.qd._.observables.updateDependencies.call(obv, true)

            assert.isFalse(enqueueSpy.called, "Should not enqueue anything as this update is immediate")
            assert.isTrue(updateSpy.called, "Should have called update node set")
            assert.deepEqual(updateSpy.firstCall.args[0], [fakeDepend[0].domNode, fakeDepend[1].domNode, fakeDepend[2].domNode], "Should have called update with depenedencies")
        )
    )
)
