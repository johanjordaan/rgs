_ = require 'prelude-ls'
assert = require('assert')
should = require('chai').should()
expect = require('chai').expect
request = require 'supertest'
async = require 'async'

app = require '../api_server'

list_games  = (agent,filter,cb) ->
  agent.get '/api/v1/games'
  .expect 200
  .end (err,res) ->
    cb err,res.body

list_matches = (agent,game_id_filter,cb) ->
  agent.get "/api/v1/matches/?game_id=#{game_id_filter}"
  .expect 200
  .end (err,res) ->
    cb err,res.body

create_match = (agent,game_id,cb) ->
  agent.post '/api/v1/matches'
  .send { game_id: game_id }
  .expect 200
  .end (err,res) ->
    cb err,res.body

join_match = (agent,match_id,player,cb) ->
  agent.post "/api/v1/matches/#{match_id}/players"
  .send player
  .expect 200
  .end (err,res) ->
    cb err,res.body


get_match_details = (agent,match_id,match_key,cb) ->
  agent.get "/api/v1/matches/#{match_id}/?match_key=#{match_key}"
  .expect 200
  .end (err,res) ->
    cb err,res.body

submit_move = (agent,match_id,match_key,move_id,cb) ->
  agent.post "/api/v1/matches/#{match_id}/moves/?match_key=#{match_key}"
  .send { move_id:move_id }
  .expect 200
  .end (err,res) ->
    cb err,res.body

describe 'api server : ', (done) ->
  var agent
  var db

  before (done) ->
    mongo = require 'mongoskin'
    db_name = "mongodb://localhost/rgs_test"
    db := mongo.db db_name, {native_parser:true}
    db.dropDatabase!
    agent := request app(db)
    done!

  describe '/api/v1/games : ', (done) ->
    it 'should return a list of games available', (done) ->
      list_games agent,null, (err,res) ->
        res.status.should.equal 'OK'
        res.games.length.should.equal 2
        res.games[0].game_id.should.equal "ttt"
        done!

  describe '/api/vi/matches : ', (done) ->
    var match_id
    var amatch
    players = [
      *name: 'johan'
      *name: 'bob'
      *name: 'sue'
    ]

    it 'should return a list of matches', (done) ->
      list_matches agent,null, (err,res) ->
        res.status.should.equal 'OK'
        res.matches.length.should.equal 0
        done!

    it 'should create a new match', (done) ->
      create_match agent,'ttt', (err,res) ->
        res.status.should.equal 'OK'
        match_id := res.match.match_id
        done!

    it 'should return an error if the an invalid game id is specified on match creation', (done) ->
      create_match agent,'xxx', (err,res) ->
        res.status.should.equal 'ERROR'
        done!


    it 'should return a list a matches given a game_id filter', (done) ->
      list_matches agent,'ttt', (err,res) ->
        res.status.should.equal 'OK'
        res.matches.length.should.equal 1
        done!

    it 'should return a list a matches given a game_id filter that doesnt match any matches', (done) ->
      list_matches agent,'xxx', (err,res) ->
        res.status.should.equal 'OK'
        res.matches.length.should.equal 0
        done!

    it 'should add a player to the match if there is open spots and set the game status to in progress if the slots are full', (done) ->
      async.parallel [
        (cb) -> join_match agent,match_id,players[0],cb
      , (cb) -> join_match agent,match_id,players[1],cb
      , (cb) -> join_match agent,match_id,players[2],cb
      ], (err,results) ->
        results.length.should.equal 3
        for i to 2
          switch results[i].match_key?
          | true =>
            results[i].status.should.equal 'OK'
            players[i].match_key = results[i].match_key
          | otherwise =>
            results[i].status.should.equal 'ERROR'
            results[i].message.should.equal 'Match full'
            players[i].match_key = null

        db.matches.findOne { match_id:match_id }, (err,amatch) ->
          amatch.players.length.should.equal 2
          amatch.status.should.equal "inprogress"
          expect(amatch.current_state).to.exist
          amatch.current_state.state_number.should.equal 0
          done!

    it 'should return the details of the match', (done) ->
      get_match_details agent,match_id,null, (err,res) ->
        res.status.should.equal 'OK'
        expect(res.match).to.exist
        done!

    it 'should return an empty match if the math_id does not exist', (done) ->
      get_match_details agent,'xxx',null, (err,res) ->
        res.status.should.equal 'OK'
        expect(res.match).to.be.null
        done!

    describe 'expected resuts from making a move', (done) ->
      it 'should apply a valid move once all the players has submitted their moves', (done) ->
        get_match_details agent,match_id,null, (err,res) ->
          res.status.should.equal 'OK'
          amatch = res.match

          moves = players |> _.map (player) ->
            | !player.match_key? => null
            | otherwise => (cb) ->
                submit_move agent,match_id,player.match_key,0,cb
          |>  _.filter (move) ->
            move?

          moves[0] (err,res) ->
            # After the first move the state should still be the same
            res.status.should.equal 'OK'
            get_match_details agent,match_id,null, (err,res) ->
              amatch = res.match
              expect(amatch.current_state).to.exist
              amatch.current_state.state_number.should.equal 0

              moves[1] (err,res) ->
                # After the second move the state should be updated
                res.status.should.equal 'OK'

                get_match_details agent,match_id,null, (err,res) ->
                  amatch = res.match
                  expect(amatch.current_state).to.exist
                  amatch.current_state.state_number.should.equal 1

                  done!



/*
              match_key = "xxxx"
              mq = async.queue (task,cb) ->
                poll_and_make_move agent,match_id,task.match_key, (finished) ->
                  if !finished
                    mq.push { match_key:match_key }
                    cb()
                  else
                    done()
              ,10

              mq.push {count:0}*/
