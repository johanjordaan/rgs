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
  .end (err,res) ->
    cb err,res.status,res.body

submit_move = (agent,match_id,match_key,state_number,move_index,cb) ->
  agent.post "/api/v1/matches/#{match_id}/moves/?match_key=#{match_key}"
  .send do
    state_number: state_number
    move_index: move_index
  .expect 200
  .end (err,res) ->
    cb err,res.status,res.body

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

    it 'should return the details of the match', (done) ->
      get_match_details agent,match_id,null, (err,status,res) ->
        status.should.equal 200
        res.status.should.equal 'OK'
        expect(res.match).to.exist
        res.match.status.should.equal 'open'
        done!

    it 'should return an empty match if the math_id does not exist', (done) ->
      get_match_details agent,'xxx',null, (err,status,res) ->
        status.should.equal 404
        expect(res.message).to.exist
        res.message.should.equal 'Cannot find match [xxx]'
        done!

    it 'should add a player to the match if there is open spots and set the game status to in progress if the slots are full', (done) ->
      join_match agent,match_id,players[0], (err,res) ->
        players[0].match_key = res.match_key
        get_match_details agent,match_id,players[0].match_key, (err,status,res) ->
          status.should.equal 200
          amatch = res.match
          amatch.status.should.equal = 'waiting'

          async.parallel [
            (cb) -> join_match agent,match_id,players[1],cb
          , (cb) -> join_match agent,match_id,players[2],cb
          ], (err,results) ->
            results.length.should.equal 2
            for i to 1
              switch results[i].match_key?
              | true =>
                results[i].status.should.equal 'OK'
                players[i+1].match_key = results[i].match_key
              | otherwise =>
                results[i].status.should.equal 'ERROR'
                results[i].message.should.equal 'Match full'
                players[i+1].match_key = null

            # TODO: refcator to use match details call
            db.matches.findOne { match_id:match_id }, (err,amatch) ->
              amatch.players.length.should.equal 2
              amatch.status.should.equal "inprogress"
              expect(amatch.current_state).to.exist
              amatch.current_state.state_number.should.equal 0
              done!

    it 'should apply a valid move once all the players has submitted their moves', (done) ->
      get_match_details agent,match_id,null, (err,status,res) ->
        status.should.equal 200
        res.status.should.equal 'OK'
        amatch = res.match

        moves = players |> _.map (player) ->
          | !player.match_key? => null
          | otherwise => (cb) ->
              submit_move agent,match_id,player.match_key,0,0,cb
        |>  _.filter (move) ->
          move?

        moves[0] (err,status,res) ->
          status.should.equal 200
          # After the first move the state should still be the same
          res.status.should.equal 'OK'
          get_match_details agent,match_id,null, (err,status,res) ->
            status.should.equal 200
            amatch = res.match
            expect(amatch.current_state).to.exist
            amatch.current_state.state_number.should.equal 0

            moves[1] (err,status,res) ->
              status.should.equal 200
              # After the second move the state should be updated
              res.status.should.equal 'OK'

              get_match_details agent,match_id,null, (err,status,res) ->
                status.should.equal 200
                amatch = res.match
                expect(amatch.current_state).to.exist
                amatch.current_state.state_number.should.equal 1

                done!

    end_state_number = 1
    it 'should finish the match started above in less then 10 moves', (done) ->
      q = async.queue (task,cb) ->
        submit_move agent,match_id,task.match_key,task.state_number,0, (err,status,res)->
          amatch = res.match
          if amatch.current_state.finished
            amatch.current_state.state_number.should.be.at.least 5
            amatch.current_state.state_number.should.be.at.most 9
            amatch.status.should.equal 'done'
            end_state_number := amatch.current_state.state_number+1
            done!
          else
            q.push { match_key:task.match_key, state_number:task.state_number+1 }
            cb!
      ,1

      players |> _.each (player) ->
        | !player.match_key? => null
        | otherwise => q.push { match_key:player.match_key,state_number:1 }


    it 'should fail with an error if a move is submitted to a done game',(done) ->
      submit_move agent,match_id,players[0].match_key,end_state_number+1,0, (err,status,res)->
        status.should.equal 400
        done!
