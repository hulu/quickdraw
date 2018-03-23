describe("Quickdraw.Internal.Cache", ->
    it("When get is called and nothing is in the cache the generator is called", ->
        generatorSpy = sinon.spy(-> return 1)

        cache = sandbox.qd._.cache.create(generatorSpy)

        result = cache.get(1)

        assert.equal(result, 1, "Should return the result from the generator")
        assert.isTrue(generatorSpy.calledOnce, "Should have called the generator as cache was empty")
    )

    it("When item is in the cache generator is not called", ->
        generatorSpy = sinon.spy(-> return 1)

        cache = sandbox.qd._.cache.create(generatorSpy)

        cache.put(1, 1)
        result = cache.get(1)

        assert.equal(result, 1, "Should return the previously stored value")
        assert.isFalse(generatorSpy.called, "Should not have called generator as value was available")
    )

    it("When cache is cleared the generator is called", ->
        generatorSpy = sinon.spy(-> return 2)

        cache = sandbox.qd._.cache.create(generatorSpy)
        cache.put(1, 1)
        cache.clear()
        result = cache.get(1)

        assert.equal(result, 2, "Should return the result of the generator")
        assert.isTrue(generatorSpy.calledOnce, "Should have called the generator since cache was cleared")
    )
)