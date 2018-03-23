describe("Quickdraw.Models", ->
    describe("create(model)", ->
        it("Raw model converted to quickdraw model", ->
            model = { raw : true }
            created = sandbox.qd._.models.create(model)
            assert.equal(created.raw, model, "Raw model stored properly")
            assert.isTrue(created.__isModel, "Model properly wrapped")
            assert.isNull(created.__parent, "Parent set to null")
        )

        it("Already wrapped model not modified", ->
            model = sandbox.qd._.models.create({ raw : true })

            assert.equal(sandbox.qd._.models.create(model), model, "Wrapped model directly returned")
        )
    )

    describe("isModel(object)", ->
        it("Given a non-model returns false", ->
            model = {}
            assert.isFalse(sandbox.qd._.models.isModel(model))
        )

        it("Given a model returns true", ->
            model = sandbox.qd._.models.create({ raw : true })
            assert.isTrue(sandbox.qd._.models.isModel(model))
        )
    )
)