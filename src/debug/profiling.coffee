qdInternal.profiling = {
    getData : ->
        # clean up the data
        for id, timer of @data.timers
            delete timer.depth
            delete timer.start
        return @data

    reset : ->
        @data = {
            timers : {}
            counts : {}
            groupCounts : {}
        }

    startTimer : (id) ->
        return unless qd.getConfig('profilingEnabled')
        timerData = @data.timers[id] ?= {
            depth : 0
            times : []
            average : -1
            max : -1
            min : -1
            start : -1
        }
        timerData.depth++
        if timerData.depth is 1
            timerData.start = (new Date()).getTime()

    endTimer : (id, payload = {}) ->
        # grab end time now for more accurate tracking
        endTime = (new Date()).getTime()

        return unless qd.getConfig('profilingEnabled')
        timerData = @data.timers[id]
        return unless timerData?
        
        timerData.depth--
        if timerData.depth < 1
            # reached final endTimer, consolidate data
            startTime = timerData.start
            # minor validation
            if startTime isnt -1
                totalTime = endTime - startTime
                timerData.times.push({
                    start : timerData.start
                    length : totalTime
                    payload : payload
                })
                if timerData.times.length is 1
                    # setup initial data if first timing
                    timerData.average = totalTime
                    timerData.max = totalTime
                    timerData.min = totalTime
                else
                    # roll into current data
                    timerData.average = (timerData.average + totalTime) / 2
                    timerData.max = Math.max(timerData.max, totalTime)
                    timerData.min = Math.min(timerData.min, totalTime)

            # reset depth
            timerData.depth = 0
            timerData.start = -1

    count : (id) ->
        return unless qd.getConfig('profilingEnabled')
        @data.counts[id] ?= 0
        @data.counts[id]++

    groupCount : (id, count) ->
        return unless qd.getConfig('profilingEnabled')
        group = @data.groupCounts[id]
        if group?
            group.counts.push(count)
            group.average = (group.average + count) / 2
            group.max = Math.max(group.max, count)
            group.min = Math.min(group.min, count)
        else
            @data.groupCounts[id] = {
                counts : [count]
                average : count
                max : count
                min : count
            }

}

qd.setConfig('profilingEnabled', false)

qd.startProfiling = ->
    unless qd.getConfig('profilingEnabled')
        qd.setConfig('profilingEnabled', true)
        qdInternal.profiling.reset()

qd.stopProfiling = ->
    profilingData = null
    if qd.getConfig('profilingEnabled')
        profilingData = qdInternal.profiling.getData()
        # reset the data
        qdInternal.profiling.reset()
        qd.setConfig('profilingEnabled', false)

    # Return the profiling data collected if previously enabled
    return profilingData

# since profiling is meant to be unobtrusive to the rest of the system
# we need to wrap methods that we want to actually track
# any new methods will have to manually wrap here for stats
do ->
    profiling = qdInternal.profiling
    # async methods
    qdInternal.async.immediate = do (original = qdInternal.async.delayed) ->
        return (args...) ->
            profiling.count('internal.async.immediate')
            original.apply(@, args)

    qdInternal.async.delayed = do (original = qdInternal.async.delayed) ->
        return (args...) ->
            profiling.count('internal.async.delayed')
            original.apply(@, args)

    qdInternal.async.cancel = do (original = qdInternal.async.cancel) ->
        return (args...) ->
            profiling.count('internal.async.cancel')
            original.apply(@, args)

    # binding methods
    qd.bindModel = do (original = qd.bindModel) ->
        return (args...) ->
            profiling.count('external.bindModel')
            profiling.startTimer('external.bindModel')
            original.apply(@, args)
            profiling.endTimer('external.bindModel')

    qd.unbindModel = do (original = qd.unbindModel) ->
        return (args...) ->
            profiling.count('external.unbindModel')
            profiling.startTimer('external.unbindModel')
            original.apply(@, args)
            profiling.endTimer('external.unbindModel')

    qd.disableUpdates = do (original = qd.disableUpdates) ->
        return ->
            profiling.count('external.disableUpdates')
            original.apply(@)

    qd.enableUpdates = do (original = qd.enableUpdates) ->
        return (args...) ->
            profiling.count('external.enableUpdates')
            original.apply(@, args)

    qdInternal.binding.runUpdates = do (original = qdInternal.binding.runUpdates) ->
        return ->
            profiling.count('internal.binding.runUpdates')
            profiling.groupCount('state.queues.updates.length', qdInternal.state.queues.updates.length)
            original.apply(@)

    qdInternal.binding.rebindNodes = do (original = qdInternal.binding.rebindNodes) ->
        return (nodes) ->
            profiling.count('internal.binding.rebindNodes')
            profiling.groupCount('internal.binding.rebindNodes.count', nodes.length)
            profiling.startTimer('internal.binding.rebindNodes')
            original.call(@, nodes)
            profiling.endTimer('internal.binding.rebindNodes')

    qdInternal.binding.bindModel = do (original = qdInternal.binding.bindModel) ->
        return (args...) ->
            profiling.count('internal.binding.bindModel')
            profiling.startTimer('internal.binding.bindModel')
            original.apply(@, args)
            profiling.endTimer('internal.binding.bindModel')

    qdInternal.binding.unbindDomTree = do (original = qdInternal.binding.unbindDomTree) ->
        return (args...) ->
            profiling.count('internal.binding.unbindDomTree')
            profiling.startTimer('internal.binding.unbindDomTree')
            original.apply(@, args)
            profiling.endTimer('internal.binding.unbindDomTree')

    qdInternal.binding.bindDomNode = do (original = qdInternal.binding.bindDomNode) ->
        return (args...) ->
            started = false
            if args[0].hasAttribute(qd.getConfig('bindingAttribute'))
                started = true
                profiling.startTimer('internal.binding.bindDomNode')
            result = original.apply(@, args)
            if started
                profiling.endTimer('internal.binding.bindDomNode', {
                    bindingString : args[0].getAttribute(qd.getConfig('bindingAttribute'))
                })
            return result

    # handlers methods
    qd.registerBindingHandler = do (original = qd.registerBindingHandler) ->
        return (keyword, handler) ->
            for type in ['initialize', 'update', 'cleanup']
                handler[type] = do (type, callback = handler[type]) ->
                    return (args...) ->
                        profiling.startTimer("internal.binding.#{keyword}.#{type}")
                        result = callback.apply(@, args)
                        profiling.endTimer("internal.binding.#{keyword}.#{type}")
                        return result

            return original.call(@, keyword, handler)

    qd.observable =  do (original = qd.observable) ->
        return (args...) ->
            profiling.count('external.observable')
            return original.apply(@, args)

    qd.computed = do (original = qd.computed) ->
        return (args...) ->
            profiling.count('external.computed')
            return original.apply(@, args)

    qd.observableArray = do (original = qd.observableArray) ->
        return (args...) ->
            profiling.count('external.observableArray')
            return original.apply(@, args)

    qdInternal.observables.addDependency = do (original = qdInternal.observables.addDependency) ->
        return (args...) ->
            profiling.count("internal.observables.dependencies")
            original.apply(@, args)

    qdInternal.observables.addComputedDependency = do (original = qdInternal.observables.addComputedDependency) ->
        return (args...) ->
            profiling.count("internal.observables.computedDependencies")
            original.apply(@, args)

    qdInternal.observables.removeDependency = do (original = qdInternal.observables.removeDependency) ->
        return (args...) ->
            profiling.count("internal.observables.removeDependency")
            original.apply(@, args)

    qdInternal.observables.updateDependencies = do (original = qdInternal.observables.updateDependencies) ->
        return (args...) ->
            profiling.count("internal.observables.updateDependencies")
            original.apply(@, args)
