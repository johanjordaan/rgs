_ = require 'prelude-ls'
assert = require('assert')
should = require('chai').should()
expect = require('chai').expect

utils = require '../utils'

describe 'utils', (done) ->

  describe 'generate_token', (done) ->

    it 'should return a 64 characted token using no data', (done) ->
      token = utils.generate_token!
      token.length.should.equal 64
      done!

    it 'should return a 64 characted token using some data', (done) ->
      token = utils.generate_token do
        name: 'bilbo'
        surname: 'baggens'

      token.length.should.equal 64
      done!


  describe 'shuffle',(done) ->
    list = [1 to 20]
    shuffled_list = utils.shuffle list

    it 'should return a list of the same length as the source',(done) ->
      shuffled_list.length.should.equal list.length
      ([0] |> utils.shuffle).length.should.equal 1
      done!

  describe 'pick',(done) ->
    list = [20 to 50]

    it 'should pick a random elemnt form the list', (done)->
      number = utils.random_pick list
      done!
