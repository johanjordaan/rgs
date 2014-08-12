_ = require 'prelude-ls'
assert = require('assert')
should = require('chai').should()
expect = require('chai').expect
request = require 'supertest'

rnd = require 'lcg-rnd'

app = require '../api_server'

ttt = require '../ttt'

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
      game_state = ttt.initial_game_state 2

      count = 0
      while not game_state.result.finished
        moves = ttt.get_valid_moves game_state
        move_index = rnd.rnd_int_between 0 moves[game_state.active_role].length-1
        game_state = ttt.next_game_state game_state, game_state.active_role, move_index
        count = count + 1
        #console.log game_state.board

      console.log game_state.result

      done()

  describe 'a call to the server', (done) ->
    var agent

    before (done) ->
      mongo = require 'mongoskin'
      db_name = "mongodb://localhost/rgs_test"
      db = mongo.db db_name, {native_parser:true}
      agent := request app(db)
      done()

    describe 'some scenarios', (done) ->
      it 'should return a list of games', (done) ->
        agent.get '/api/v1/games'
        .expect 200
        .end (err,res) ->
          res.body.length.should.equal 2
          res.body[0].game_id.should.equal "ttt"
          done()

      it 'should return a list of matches', (done) ->
        agent.get '/api/v1/games/ttt/matches'
        .expect 200
        .end (err,res) ->
          res.body.length.should.equal 1
          match_id = res.body[0].match_id
          console.log match_id

          agent.post "/api/v1/games/ttt/matches/#{match_id}/players"
          .send do
            name:'johan'
          .expect 200
          .end (err,res) ->
            match_key = res.body
            console.log match_key
            done()
