_ = require 'prelude-ls'
assert = require('assert')
should = require('chai').should()
expect = require('chai').expect
request = require 'supertest'

rnd = require 'lcg-rnd'

ttt = require '../dist/ttt'

describe 'Tick-Tac-Toe', (done) ->
#  describe 'get_valid_moves', (done) ->
#    it 'should return the valid moves for the game state', (done) ->
#      game_state = ttt.initial_game_state ['111','222']
#      moves = ttt.get_valid_moves game_state
#
#      moves.X.length.should.equal 9
#      moves.O.length.should.equal 0
#
#      done()


#  describe 'make_move', (done) ->
#    it 'should apply the selected move', (done) ->
      #game_state = ttt.create_game_state!
      #moves = ttt.get_valid_moves game_state

      #next_game_state = ttt.make_move game_state,'X',4

#      done()

  describe 'a simple random game', (done) ->
    it 'should play a simple random game in 9 or less moves', (done) ->
      match_keys = ['a','b']
      game_state = ttt.initial_game_state match_keys

      count = 0
      while not game_state.result.finished
        moves = ttt.get_valid_moves game_state
        move_index = rnd.rnd_int_between 0 moves[game_state.active_role].length-1
        game_state = ttt.next_game_state game_state, game_state.active_role, move_index
        count = count + 1
        console.log game_state.board

      done()




#  describe 'valid_moves', (done) ->
#    it 'should generate valid moves for the given player and board state', (done) ->
#      ttt.make_move game_state, move
#      done()



#describe 'Connectors', ->
#  app = {}
#
#  before (done) ->
#    app_setup true,(local_app) ->
#      app = local_app
#      done()
#
#  describe 'create', ->
#    it "???????", (done) ->
#
#      request(app)
#        .post("/status")
#        .send( {} )
#        .expect(404, { }, done )
#
#  describe 'create', ->
#    it "should return a 400 error if there is no type specified", (done) ->
#
#      request(app)
#        .get("/status")
#        .send( {} )
#        .expect(200)
#        .expect (res) ->
#          res.text.status.should.equal "OK"
#
#        .end (err,res) ->
#          done()
