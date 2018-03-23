describe("Quickdraw.Bindings.CSS", ->
    parseClassList = (dom) ->
        classes = dom.getProperty('className').trim().split(/ +/)
        applied = {}
        for item in classes
            applied[item] = true
        return applied

    testClassesApplied = (classes, shouldBe, dom) ->
        unless dom?
            dom = createVirtualElement('div')

        initialize = qdGetInitialize('css')
        initialize(classes, dom)

        update = qdGetUpdate('css')
        update(classes, dom)

        # parse the class list
        applied = parseClassList(dom)

        # check applied classes against should be
        for klass in applied
            if shouldBe.indexOf(klass) > -1
                assert.isTrue(applied[klass], "Class correctly added: #{klass}")
            else
                assert.isUndefined(applied[klass], "Class incorrectly added: #{klass}")

        return dom

    it("Handler is bound to css keyword", assertModuleBound('css'))

    it("Adds a single class", ->
        testClassesApplied({
            addMe : true
        }, ['addMe'])
    )

    it("Adds two classes", ->
        testClassesApplied({
            first : true,
            second : true
        }, ['first', 'second']);
    )

    it("Adds only true classes", ->
        testClassesApplied({
            first : true,
            second : false,
            third : true
        }, ['first', 'third']);
    )

    it("If binding data is observable, it unwraps it", ->
        testClassesApplied(sandbox.qd.observable({
            first : true,
            second : false
        }), ['first']);
    )

    it('Class that disappears is removed', ->
        dom = createVirtualElement('div')
        dom.getRawNode().className = 'here there'
        testClassesApplied({
            other : true
        }, ['here', 'there', 'other'], dom)

        testClassesApplied({}, ['here', 'there'], dom)
    )

    it("Ignores any classes not specified", ->
        dom = createVirtualElement('div')
        dom.getRawNode().className = 'here there'
        testClassesApplied({
            other : true
        }, ['here', 'there', 'other'], dom)
    )

    it("Existing classes are not duplicated by binding", ->
        dom = createVirtualElement('div')
        dom.getRawNode().className = 'here there'
        testClassesApplied({
            here : true
        }, ['here', 'there'], dom)
    )

    it("Existing classes can be removed by binding", ->
        dom = createVirtualElement('div')
        dom.getRawNode().className = 'here there'
        testClassesApplied({
            here : false
            other : true
        }, ['there', 'other'], dom)
    )

    it("Does not remove classes specifed on node", ->
        dom = createVirtualElement('div')
        dom.getRawNode().className = 'here there where'
        testClassesApplied({}, ['here', 'where', 'there'], dom)
    )

    it("If binding data is just a string, uses as a class name", ->
        testClassesApplied('cats', ['cats'])
    )

    it('Object attribute \'_$\' has value used as a class', ->
        testClassesApplied({
            _$ : "everything exists",
            reason : true,
            always : false
        }, ['everything', 'exists', 'reason'])
    )

    it('Values applied via \'_$\' are properly updated', ->
        element = testClassesApplied({
            _$ : "everything exists"
            other : true
        }, ['everything', 'exists']);

        testClassesApplied({
            _$ : "nothing"
            other : true
        }, ['nothing'], element)
    )

    it("initialize method properly stores off original data", ->
        originalString = "whats up there"
        dom = createVirtualElement('div')
        dom.getRawNode().className = originalString

        initialize = qdGetInitialize('css')
        initialize({}, dom)

        assert.deepEqual(dom.getValue('original', 'css'), originalString.split(' '), "Original string correctly stored")
    )

    it("cleanup properly returns the data", ->
        originalString = "whats up"
        dom = createVirtualElement('div')
        dom.getRawNode().className = originalString

        initialize = qdGetInitialize('css')
        initialize({}, dom)

        dom.setProperty('className', '')

        cleanup = qdGetCleanup('css')
        cleanup(dom)

        assert.equal(dom.getProperty('className'), originalString, "Should have returned original string")
    )

    it("cleanup returns data previously removed", ->
        originalString = "whats up"
        dom = createVirtualElement('div')
        dom.getRawNode().className = originalString

        initialize = qdGetInitialize('css')
        initialize({}, dom)

        update = qdGetUpdate('css')
        update({
            whats: false
        }, dom)

        cleanup = qdGetCleanup('css')
        cleanup(dom)

        assert.equal(dom.getProperty('className'), originalString, "Should have restored binding removed string")
    )
)
