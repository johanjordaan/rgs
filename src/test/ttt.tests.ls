_ = require 'prelude-ls'
assert = require('assert')
should = require('chai').should()
expect = require('chai').expect
request = require 'supertest'

async = require 'async'

rnd = require 'lcg-rnd'

app = require '../api_server'

ttt = require '../ttt'
utils = require '../utils'

describe 'Tick-Tac-Toe', (done) ->

  describe 'initial_game_state', (done) ->
    game_state = ttt.initial_game_state!

    it 'should return an initial state object that has all the relevant fields defined', (done) ->
      expect(game_state).to.exist
      expect(game_state.roles).to.exist
      expect(game_state.finished).to.exist
      expect(game_state.valid_moves).to.exist
      expect(game_state.results).to.exist
      expect(game_state._private).to.exist
      done!

    it 'should return an initial state with the X and O roles', (done) ->
      game_state.roles.length.should.equal 2
      game_state.roles.should.contain 'X'
      game_state.roles.should.contain 'O'
      done!

    it 'should return an initial state which is not finished', (done) ->
      game_state.finished.should.equal false
      done!

    it 'should return an initial state with 9 moves for X and 0 for O' (done) ->
      game_state.valid_moves.X.length.should.equal 9
      game_state.valid_moves.O.length.should.equal 1
      done!

    it 'should return an initial state with an empty board', (done) ->
      expect(game_state._private.board).to.exist
      game_state._private.board.length.should.equal 3
      for row to 2
        game_state._private.board[row].length.should.equal 3
        for col to 2
          game_state._private.board[row][col].should.equal 0
      done!

    it 'should return an initial state with X as the active role', (done) ->
      expect(game_state._private.active_role).to.exist
      game_state._private.active_role.should.equal 'X'
      done!

  describe 'next_game_state', (done) ->
    game_state = ttt.initial_game_state!
    next_game_state = ttt.next_game_state game_state, { 'X':[0],'O':[0] }

    it 'should return the next game state', (done) ->
      next_game_state.finished.should.equal false
      next_game_state.valid_moves.X.length.should.equal 1
      next_game_state.valid_moves.O.length.should.equal 8
      done!

    it 'should finish the game in between 5 and 9 moves(inclusive)', (done) ->
      next_game_state := ttt.next_game_state next_game_state, { 'X':[0],'O':[0] }
      count = 2
      while !next_game_state.finished and count<11
        next_game_state := ttt.next_game_state next_game_state, { 'X':[0],'O':[0] }
        count := count + 1

      next_game_state.finished.should.equal true
      count.should.be.at.least 5
      count.should.be.at.most 9
      next_game_state.results.X.should.equal 3
      next_game_state.results.O.should.equal 0
      done!
      
