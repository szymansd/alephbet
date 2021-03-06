test = require('tape')
sinon = require('sinon')
_ = require('lodash')
AlephBet = require('../src/alephbet')

storage = null
tracking = null
experiment = null
activate = sinon.spy()

class TestStorage
  @namespace: 'alephbet'
  constructor: ->
    @storage = {}
  set: (key, value) ->
    @storage[key] = value
  get: (key) ->
    @storage[key]

class TestTracking
  experiment_start: sinon.spy()
  goal_complete: sinon.spy()

setup = ->
  storage = new TestStorage
  tracking = new TestTracking
  activate.reset()
  tracking.experiment_start.reset()
  tracking.goal_complete.reset()

  default_options =
    name: 'experiment'
    variants:
      blue:
        activate: activate
      red:
        activate: activate
    storage_adapter: storage
    tracking_adapter: tracking
  experiment = (options={}) ->
    new AlephBet.Experiment(_.defaults(options, default_options))

describe = (description, fn) ->
  test description, (t) ->
    setup()
    fn(t)

describe 'starts the experiment', (t) ->
  ex = experiment({name: 'my-experiment'})
  t.plan(6)
  t.assert(storage.get('my-experiment:in_sample') == true, 'in sample')
  variant = ex.get_stored_variant()
  t.equal(variant, storage.get('my-experiment:variant'))
  t.assert(variant == 'blue' || variant == 'red', 'assigns blue or red variant')
  t.assert(activate.callCount == 1, 'activate function was called once')
  t.assert(activate.calledWith(ex), 'was called with experiment')
  t.assert(tracking.experiment_start.callCount == 1, 'experiment_start tracking was called once')

describe 'deterministic variant with a given user_id', (t) ->
  ex = experiment({user_id: 'yuzu'})
  t.plan(2)
  t.assert(ex.pick_variant() == 'blue', 'always picks blue variant')
  ex = experiment({user_id: 'gosho'})
  t.assert(ex.pick_variant() == 'red', 'always picks red variant')

describe 'sticks to the same variant after choosing it', (t) ->
  ex = experiment({name: 'variant test'})
  variant = ex.get_stored_variant()
  experiment({name: 'variant test'})
  experiment({name: 'variant test'})
  t.plan(1)
  t.assert(activate.callCount == 3, 'always calling activate for the same variant')

describe 'not in sample', (t) ->
  experiment({sample: 0.0})
  t.plan(2)
  t.equal(storage.get('experiment:in_sample'), false)
  t.assert(tracking.experiment_start.callCount == 0, 'experiment_start tracking was not called')

describe 'trigger is false', (t) ->
  experiment({trigger: -> false})
  t.plan(1)
  t.assert(tracking.experiment_start.callCount == 0, 'experiment_start tracking was not called')

describe 'trigger is false after participating', (t) ->
  experiment({trigger: -> true})
  experiment({trigger: -> false})
  t.plan(1)
  t.assert(activate.callCount == 2, 'activate function is still called')

describe 'tracks goals', (t) ->
  ex = experiment({name: 'with-goals'})
  ex.goal_complete('my goal')
  ex.goal_complete('my goal')
  t.plan(2)
  t.assert(tracking.goal_complete.callCount == 1, 'goal_complete was called only once')
  t.assert(storage.get('with-goals:my goal') == true, 'goal stored')

describe 'tracks non unique goals', (t) ->
  ex = experiment({name: 'with-goals'})
  ex.goal_complete('my goal', unique: false)
  ex.goal_complete('my goal', unique: false)
  t.plan(2)
  t.assert(tracking.goal_complete.callCount == 2, 'goal_complete was called twice')
  t.notOk(storage.get('with-goals:my goal'), 'goal not stored')

describe 'when all variants has weights', (t) ->
  ex = experiment({
    name: 'with-weights',
    variants:
      blue:
        weight: 0
        activate: activate
      green:
        weight: 100
        activate: activate
  })
  t.plan(2)
  t.assert(ex.pick_variant() == 'green', 'always picks green variant')
  t.assert(ex.pick_variant() != 'blue', 'never picks blue variant')

describe 'when only some variants has weights', (t) ->
  try ex = experiment({
    name: 'not-all-weights',
    variants:
      blue:
        activate: activate
      green:
        weight: 100
        activate: activate
  })
  catch e then t.assert(true, 'creating experiment should throw error')
  t.plan(2)
  t.assert(activate.callCount == 0, 'activate function shouldn\'t be called')
