_ = require 'prelude-ls'
assert = require('assert')
should = require('chai').should()
expect = require('chai').expect
request = require 'supertest'
async = require 'async'

app = require '../api_server'

list_games  = (agent,filter,cb) ->
  agent.get '/api/v1/games'
  .end (err,res) ->
    cb err,res.status,res.body

list_matches = (agent,game_id_filter,status_filter,cb) ->
  agent.get "/api/v1/matches/?game_id=#{game_id_filter}&status=#{status_filter}"
  .end (err,res) ->
    cb err,res.status,res.body

create_match = (agent,game_id,cb) ->
  agent.post '/api/v1/matches'
  .send { game_id: game_id }
  .end (err,res) ->
    cb err,res.status,res.body

join_match = (agent,match_id,player,cb) ->
  agent.post "/api/v1/matches/#{match_id}/players"
  .send player
  .end (err,res) ->
    cb err,res.status,res.body


get_match_details = (agent,match_id,match_key,cb) ->
  agent.get "/api/v1/matches/#{match_id}/?match_key=#{match_key}"
  .end (err,res) ->
    cb err,res.status,res.body

submit_move = (agent,match_id,match_key,state_number,move_index,cb) ->
  agent.post "/api/v1/matches/#{match_id}/moves/?match_key=#{match_key}"
  .send do
    state_number: state_number
    move_index: move_index
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
      list_games agent,null, (err,status,res) ->
        status.should.equal 200
        res.length.should.equal 2
        res[0].game_id.should.equal "ttt"
        done!

  describe '/api/vi/matches : ', (done) ->
    var match_id
    var amatch
    players = [
      *name: 'johan'
      *name: 'bob'
      *name: 'sue'
    ]

    it 'should return a list of all matches(no filter)', (done) ->
      list_matches agent,null,null, (err,status,res) ->
        status.should.equal 200
        res.length.should.equal 0
        done!

    it 'should create a new match', (done) ->
      create_match agent,'ttt', (err,status,res) ->
        status.should.equal 200
        res.status.should.equal "waiting"
        match_id := res.match_id
        done!

    it 'should return an error if the an invalid game id is specified on match creation', (done) ->
      create_match agent,'xxx', (err,status,res) ->
        status.should.equal 400
        res.message.should.equal "Game [xxx] does not exist"
        done!


    it 'should return a list a matches given a game_id filter', (done) ->
      list_matches agent,'ttt',null, (err,status,res) ->
        status.should.equal 200
        res.length.should.equal 1
        done!

    it 'should return a list a matches given a game_id filter that doesnt match any matches', (done) ->
      list_matches agent,'xxx',null, (err,status,res) ->
        status.should.equal 200
        res.length.should.equal 0
        done!

    it 'should return a list of matches that match the game_id and a status', (done) ->
      list_matches agent,'ttt','inprogress', (err,status,res) ->
        status.should.equal 200
        res.length.should.equal 0
        done!


    it 'should return the details of the match', (done) ->
      get_match_details agent,match_id,null, (err,status,res) ->
        status.should.equal 200
        res.status.should.equal 'waiting'
        done!

    it 'should return an empty match if the match_id does not exist', (done) ->
      get_match_details agent,'xxx',null, (err,status,res) ->
        status.should.equal 404
        expect(res.message).to.exist
        res.message.should.equal 'Cannot find match [xxx]'
        done!

    it 'should add a player to the match if there is open spots and set the game status to in progress if the slots are full', (done) ->
      join_match agent,match_id,players[0], (err,status,res) ->
        status.should.equal 200
        players[0].match_key = res.match_key
        get_match_details agent,match_id,players[0].match_key, (err,status,res) ->
          status.should.equal 200
          amatch = res
          amatch.status.should.equal = 'waiting'

          async.parallel [
            (cb) -> join_match agent,match_id,players[1],(err,status,res)->
              cb null,{ status:status,res:res }
          , (cb) -> join_match agent,match_id,players[2],(err,status,res)->
            cb null,{ status:status,res:res }
          ], (err,results) ->
            results.length.should.equal 2
            for i to 1
              switch results[i].res.match_key?
              | true =>
                results[i].status.should.equal 200
                players[i+1].match_key = results[i].res.match_key
              | otherwise =>
                results[i].status.should.equal 400
                results[i].res.message.should.equal "Match [#{match_id}] is no longer accepting players"
                players[i+1].match_key = null


            get_match_details agent,match_id,players[0].match_key, (err,status,res) ->
              status.should.equal 200
              amatch = res
              amatch.status.should.equal = 'inprogress'
              done!



    it 'should apply a valid move once all the players has submitted their moves', (done) ->
      get_match_details agent,match_id,null, (err,status,res) ->
        status.should.equal 200
        res.status.should.equal 'inprogress'
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
          get_match_details agent,match_id,null, (err,status,amatch) ->
            status.should.equal 200
            expect(amatch.current_state).to.exist
            amatch.current_state.state_number.should.equal 0


            # If the user submits a move when they have already submitted on then
            # ignore the alst submitted and return an error
            # TODO : ractyror this test case
            moves[0] (err,status,res) ->
              status.should.equal 400

              moves[1] (err,status,res) ->
                status.should.equal 200
                # After the second move the state should be updated
                get_match_details agent,match_id,null, (err,status,amatch) ->
                  status.should.equal 200
                  expect(amatch.current_state).to.exist
                  amatch.current_state.state_number.should.equal 1
                  done!


    it 'should return an error if the match_key does not exist for the game', (done) ->
      submit_move agent,match_id,'xxxxxx',1,0, (err,status,res)->
        status.should.equal 400
        res.message.should.equal "Match [#{match_id}] does not accept match_key [xxxxxx]"
        done!

    it 'should return an error if the state_number of the move do no match the current state of the game', (done) ->
      invalid_state_number = 0
      submit_move agent,match_id,players[0].match_key,invalid_state_number,0, (err,status,res)->
        status.should.equal 400
        res.message.should.equal "Invalid state number [#{invalid_state_number}] for match_id [#{match_id}]"
        done!

    end_state_number = 1
    it 'should finish the match started above in less then 10 moves', (done) ->
      q = async.queue (task,cb) ->
        submit_move agent,match_id,task.match_key,task.state_number,0, (err,status,amatch)->
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

    it 'should fail with an error if a move is submitted to a invalid game',(done) ->
      submit_move agent,'xxxx',players[0].match_key,end_state_number+1,0, (err,status,res)->
        status.should.equal 404
        done!


  describe 'Negative testing', (done) ->
    destabilise = (o,spec) ->
      restore_point = {}
      spec.methods |> _.each (method_name) ->
        restore_point[method_name] = o[method_name]
        o[method_name] = fail_after spec.fail_after,spec.handler,o[method_name]
      restore_point

    restore = (o,restore_point) ->
      restore_point |> _.keys |> _.each (method_name) ->
        o[method_name] = restore_point[method_name]
      o


    fail_after = (threshold,fcb,f) ->
      count = 0
      ->
        if count>=threshold
          fcb.apply this,arguments
        else
          count := count+1
          f.apply this,arguments

    var agent
    var db

    before (done) ->
      mongo = require 'mongoskin'
      db_name = "mongodb://localhost/rgs_test"
      db := mongo.db db_name, {native_parser:true}
      db.dropDatabase!
      agent := request app(db)
      done!

    describe 'xxx',(done) ->
      it 'should return a 500 error since the db is broken when getting a list of matches', (done) ->
        rp = destabilise db.matches,
          methods : ['findItems']
          fail_after: 0
          handler: ->
            arguments[1]("Error",null)

        list_matches agent,null,null, (err,status,res) ->
          status.should.equal 500
          restore db.matches,rp
          done!

      it 'should return a 500 when trying to create a macth since the dbd is broken', (done) ->
        rp = destabilise db.matches,
          methods : ['save']
          fail_after: 0
          handler: ->
            arguments[1]("Error",null)

        create_match agent,'ttt', (err,status,res) ->
          status.should.equal 500
          restore db.matches,rp
          done!

      it 'should return a 500 when returning the details of the match', (done) ->
        rp = destabilise db.matches,
          methods : ['findOne']
          fail_after: 0
          handler: ->
            arguments[1]("Error",null)

        get_match_details agent,'xxxxxx',null, (err,status,res) ->
          status.should.equal 500
          restore db.matches,rp
        done!



      describe 'match match joing failures',(done) ->
        it 'should fail witha 500 if the db fails when trying to find the match to join', (done) ->
          rp = destabilise db.matches,
            methods : ['findAndModify']
            fail_after: 0
            handler: ->
              arguments[4]("Error",null)

          create_match agent,'ttt', (err,status,res) ->
            match_id = res.match_id
            join_match agent, match_id, {name:'johan'}, (err,status,res)->
              status.should.equal 500
              restore db.matches,rp
              done!


        it 'should fail witha 500 if the db fails when trying to save the match to join', (done) ->
          rp = destabilise db.matches,
            methods : ['save']
            fail_after: 1
            handler: ->
              arguments[1]("Error",null)

          create_match agent,'ttt', (err,status,res) ->
            match_id = res.match_id
            join_match agent, match_id, {name:'johan'}, (err,status,res)->
              join_match agent, match_id, {name:'peter'}, (err,status,res)->
                status.should.equal 500
                restore db.matches,rp
                done!

        it 'should fail witha 500 if the db fails when trying to save the match state to join', (done) ->
          rp = destabilise db.match_states,
            methods : ['save']
            fail_after: 0
            handler: ->
              arguments[1]("Error",null)

          create_match agent,'ttt', (err,status,res) ->
            match_id = res.match_id
            join_match agent, match_id, {name:'johan'}, (err,status,res)->
              join_match agent, match_id, {name:'peter'}, (err,status,res)->
                status.should.equal 500
                restore db.match_states,rp
                done!

        describe 'failures on move submission',(done) ->
          start_match = (cb) ->
            create_match agent,'ttt', (err,status,res) ->
              match_id = res.match_id
              players =
                *name:'johan'
                *name:'paul'
              join_match agent, match_id,players[0], (err,status,res)->
                players[0].match_key = res.match_key
                join_match agent, match_id, players[1], (err,status,res)->
                  players[1].match_key = res.match_key
                  cb(match_id,players)

          it 'should retunr 500 if the match find query fails', (done) ->
            start_match (match_id,players) ->

              rp = destabilise db.matches,
                methods : ['findOne']
                fail_after: 0
                handler: ->
                  arguments[1]("Error",null)

              submit_move agent,match_id,players[0].match_key,0,0, (err,status,res) ->
                status.should.equal 500

                restore db.matches,rp
                done!

          it 'should return 500 if the match findAndModify query fails', (done) ->
            start_match (match_id,players) ->

              rp = destabilise db.matches,
                methods : ['findAndModify']
                fail_after: 0
                handler: ->
                  arguments[4]("Error",null)

              submit_move agent,match_id,players[0].match_key,0,0, (err,status,res) ->
                status.should.equal 500

                restore db.matches,rp
                done!

          it 'should return 500 if the match save query fails', (done) ->
            start_match (match_id,players) ->
              rp = destabilise db.matches,
                methods : ['save']
                fail_after: 0
                handler: ->
                  arguments[1]("Error",null)

              submit_move agent,match_id,players[0].match_key,0,0, (err,status,res) ->
                submit_move agent,match_id,players[1].match_key,0,0, (err,status,res) ->
                  status.should.equal 500

                  restore db.matches,rp
                  done!

          it 'should return 500 if the match_state save query fails', (done) ->
            start_match (match_id,players) ->
              rp = destabilise db.match_states,
                methods : ['save']
                fail_after: 0
                handler: ->
                  arguments[1]("Error",null)

              submit_move agent,match_id,players[0].match_key,0,0, (err,status,res) ->
                submit_move agent,match_id,players[1].match_key,0,0, (err,status,res) ->
                  status.should.equal 500

                  restore db.match_states,rp
                  done!
