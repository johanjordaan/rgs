async = require 'async'
_ = require 'prelude-ls'

express = require 'express'
bodyParser = require 'body-parser'

utils = require './utils'

app = express()

# Configure express
app.use bodyParser.json()
app.use '/',express.static(__dirname + '/client')

server = (require 'http').createServer app

LISTEN_PORT = 4000

######## DB Initialisation
mongo = require 'mongoskin'
db_name = "mongodb://localhost/rgs"
db = mongo.db db_name, {native_parser:true}
db.bind 'matches'
db.bind 'match_states'
db.bind 'match_requests'


/* istanbul ignore if */
if require.main == module
  server.listen LISTEN_PORT, ->
     console.log "rgs API Server - Listening on port #{LISTEN_PORT}"
else
  module.exports = (test_db) ->
    /* istanbul ignore else */
    if test_db?
      db := test_db
      db.bind 'matches'
      db.bind 'match_states'
      db.bind 'match_requests'
    app

######## Game registration
ttt = require './ttt'

games =
  ttt:
    * game_id: 'ttt'
      description: 'Tic-Tac-Toe'
      options:
        min_players: 2
        max_players: 2
        choose_role: true
      module: ttt
  ttt_fast:
    * game_id: 'ttt_fast'
      description: 'Tic-Tac-Toe(fast)'
      options: {game_id:'ttt_fast',required_players:2}
      module: ttt

games_list = games |> _.values |> _.map (game) -> { game_id: game.game_id, description: game.description }


########## Batchy stuff
## Queueie stuff



_build_player_list = (source,min,max,current,cb) ->
  if source.length == 0
    if current.length < min
      cb("failure",null)
    else
      mark "create match",current, ->
        mark "unmark all",current, ->
          cb("created",current)
  else
    item = source.pop!
    mark "busy",item, (success) ->
      if success
        current.push item
        if current.length >= max
          source := []   # on the next recursion stop

      build_list source,min,max,current,cb

_match_options = (source_options,dest_options) ->
  true

_find_matching_requests = (source,options,current,cb) ->
  if source.length == 0
    if current.length < options.min
      cb null
    else
      cb current
  else
    item = source.pop!

    switch _match_options options,item
    | true =>
      _mark_as_busy item.match_request_id, (success) ->
        switch success
        | false =>
        | otherwise => current.push item

        switch current.length >= options.max
        | false =>
        | otherwise => source = []

        _find_matching_requests source,options,current
    | otherwise =>
      _find_matching_requests source,options,current


_mark_as_not_busy = (match_request_ids,cb) ->
  db.match_requests.update { match_request_id: { '$in': match_request_ids } , _busy: true }
  , { '$set' : { _busy: false } }
  , (err) ->
    | err? => cb(false)
    | otherwise => cb(true)

# cb(locked/true or false)
_mark_as_busy = (match_request_id,cb) ->
  db.match_requests.findAndModify { match_request_id: match_request_id , _busy: false }
  , []
  , { '$set' : { _busy: true } }
  , {new:true}
  , (err,updated_match_request) ->
    | err? => cb(false)
    | !updated_match_request? => cb(false)
    | otherwise => cb(true)

find_matching_requests = (match_request) ->
  _mark_as_busy match_request.match_request_id,(success) ->
    | false =>
    | otherwise =>
      now = new Date()
      active_date = new Date((now.getSeconds()-30)*1000)
      db.match_requests.findItems do
        last_seen_date: { '$gt': active_date }
        match_request_id: { '$ne': match_request.match_request.id }
        game_details:
          game_id: match_request.game_details.game_id
        _busy: false
      , (err, match_requests) ->
        _find_matching_requests match_requests,match_request.game_options,[match_request], (matching_requests)->
          | null => # Cannot create a match yet
          | otherwise =>
            # Create a match using the players and the options


################################


######## Rest Interface
app.post '/api/v1/'

# Create a new match request
#
app.post '/api/v1/match_requests', (req, res) ->
  game_id = req.body.game_id
  options = req.body.options
  player = req.body.player

  game = games[game_id]

  switch game?
    | false => res.status(400).send { message: "Game [#{game_id}] does not exist" }
    | otherwise =>
      new_match_request =
        match_request_id: utils.generate_token {}
        player: player
        game_id: game_id
        options: options
        creation_date: new Date()   # Date the request was created - not needed?
        last_seen_date: new Date()  # Date the player checked in for this request
        match_found: false
        match_id: null
        match_key: null
        busy: false                 # Used for locking purposes


      db.match_request.save new_match_request, (err,saved_match_request) ->
        | err? => res.status(500).send err
        | otherwise =>
          res.status(200).send { match_request_id: saved_match_request.match_request_id }

          make_match saved_match_request


# This retuns wheter a match was found or not and updates the request
#
app.get '/api/v1/match_requests/:match_request_id', (req, res) ->
  match_request_id = req.param 'match_request_id'

  db.match_requests.findAndModify { match_request_id: match_request_id }
  , []
  , { '$set' : { last_seen_date:new Date() } }
  , { new:true }
  , (err,saved_match_request) ->
    | err? => res.status(500).send err
    | otherwise => res.status(200).send do
        match_found: saved_match_request.match_found
        match_id: saved_match_request.match_id
        match_key: saved_match_request.match_key

app.delete '/api/v1/match_requests/:match_request_id', (req, res) ->
  match_request_id = req.param 'match_request_id'

  db.match_requests.findOne { match_request_id: match_request_id, busy:false } (err,match_request) ->
    | err? => res.status(500).send err
    | !match_request? => res.status(400).send { message : "Cannot remove this request at this stage" }
    | otherwise =>
      db.match_requests.remove { match_request_id: match_request_id, busy:false }, (err) ->
        | err? => res.status(500).send err
        | otherwise => res.status(200).send {}

        find_matching_requests match_request


# Get a list of games
#
app.get '/api/v1/games', (req, res) ->
  res.status(200).send games_list

# Get a list of matches
# Request parameter filters : game_id,status
#
#
app.get '/api/v1/matches', (req, res) ->
  game_id = req.param 'game_id'
  status = req.param 'status'

  fltr = {}
  if game_id? and game_id != 'null' then fltr.game_id = game_id
  if status? and status != 'null' then fltr.status = status

  # TODO : The matches needs to be sanatised
  # TODO : Remove state info etc so sanatisation might not be required
  # Just do it via find field filter
  #
  db.matches.findItems fltr, (err, matches) ->
    | err? => res.status(500).send err
    | otherwise => res.status(200).send matches

# Creates a new match
# The game_id should be one of the game_id's in the list of games
#
app.post '/api/v1/matches', (req, res) ->
  game_id = req.body.game_id
  game = games[game_id]

  switch game?
    | false => res.status(400).send { message: "Game [#{game_id}] does not exist" }
    | otherwise =>
      options = game.options
      new_match =
        match_id: utils.generate_token {}
        game_id: options.game_id
        status: "waiting"
        required_players: options.required_players
        player_count : 0
        players: []
        current_state: {}
        role_map: {}
        submitted_moves: {}
        submitted_moves_count: 0

      db.matches.save new_match, (err,saved_match) ->
        | err? => res.status(500).send err
        | otherwise => res.status(200).send saved_match

# get the match details
# Request parameter : match_key - if not presented then only public data is returned,
# these restrictions only hold if a game is in progress. Afterwards
#
# This doubles as the keep alive by updating the sessions table
#
app.get '/api/v1/matches/:match_id', (req, res) ->
  match_id = req.param 'match_id'
  match_key = req.param 'match_key'

  # Touch the sessions queue
  #
  db.sessions.update { match_id:match_id, match_key:match_key }
  ,{ '$set': { last_seen:new Date() } }
  ,(err,writeResult) ->


  #todo : players and other stuff like moves etc needs to be sanaitised
  # this is to prevent private game data from being leaked
  #
  db.matches.findOne { match_id: match_id }, (err, amatch) ->
    | err? => res.status(500).send err
    | otherwise =>
      switch
      | !amatch? => res.status(404).send { message:"Cannot find match [#{match_id}]" }
      | otherwise => res.status(200).send amatch

# Add a player to the match (join the match)
# User has to post a structure with { player_key: player_name }
# Player is returned a player_match_key, this has to be presented to make a
# move or to get player specic data on turns
app.post '/api/v1/matches/:match_id/players', (req, res) ->
  match_id = req.param 'match_id'
  player = req.body

  player.match_key = utils.generate_token {}
  db.matches.findAndModify { match_id: match_id , '$where':'this.player_count<this.required_players' }
  ,[]
  ,{ '$push' : { players:player }, '$inc' : { player_count:1 } }
  , {new:true}
  , (err,saved_match) ->
    | err? => res.status(500).send err
    | !saved_match? => res.status(400).send { message : "Match [#{match_id}] is no longer accepting players" }
    | saved_match.players.length < saved_match.required_players =>
      # Insert the session variable
      #
      db.sessions.save { match_id:match_id, match_key:player.match_key, last_seen:new Date() }
      ,(err,saved_session) ->

      # The match is still open but now with one less spot
      #
      res.status(200).send { match_key: player.match_key }
    | otherwise =>
      # The match is now full. Create the initial state and allocate players to roles
      #
      saved_match.current_state = games[saved_match.game_id].module.initial_game_state!
      saved_match.role_map = [p.match_key for p in saved_match.players]
        |> utils.shuffle
        |> _.zip saved_match.current_state.roles
        |> _.map (item) -> [ item[1], item[0] ]
        |> _.pairs-to-obj
      saved_match.status = "inprogress"
      db.matches.save saved_match, (err,write_status) ->
        | err? => res.status(500).send err
        | otherwise =>

          # Insert the session variable
          #
          db.sessions.save { match_id:match_id, match_key:player.match_key, last_seen:new Date() }
          ,(err,saved_session) ->


          # TODO : What do we do if we fail at this point? We cannot fix anything?
          # Should we maybbe first save this state or should we do this bootstrap on
          # details get if we detect that everything is not in place

          db.match_states.save saved_match.current_state, (err,saved_state) ->
            | err? => res.status(500).send err
            | otherwise => res.status(200).send { match_key: player.match_key }



# Update the match with a move. The move is the index of the last state in the
# game.
# Match key needs to be present in order to make a valid move
# The player with the correct match_key has to be tha active player
# and the move has to be a valid move. Here valid is defined as within the list of moves
# In order to handle simultanious moves all playes has to submit a move,it should be the
# nop move if there is not moves for you for this tuen. This also means that all players
# will get al least the nop move.
#
# If a player has already submitted a move then allow them to update their move ??
# If they submit an invalid move then return an error. ??
#
app.post '/api/v1/matches/:match_id/moves', (req, res) ->
  match_id = req.param 'match_id'
  match_key = req.param 'match_key'

  # Move needs to contain the state_number and the move index
  move  = req.body

  db.matches.findOne { match_id: match_id }, (err, amatch) ->
    | err? => res.status(500).send err
    | !amatch? => res.status(404).send { message: "Match [#{match_id}] not found" }
    | amatch.status != 'inprogress' => res.status(400).send { message: "Match [#{match_id}] not in progress" }
    | otherwise =>
      role = amatch.role_map[match_key]
      switch
      | !role? => res.status(400).send  { message: "Match [#{match_id}] does not accept match_key [#{match_key}]" }
      | amatch.submitted_moves[role]? => res.status(400).send { message : "Move already submitted for match_key [#{match_key}] on match [#{match_id}]" }
      | otherwise =>
        db.matches.findAndModify { match_id: match_id , 'current_state.state_number':move.state_number, '$where':'this.submitted_moves_count<this.player_count'  }
        ,[]
        ,{ '$set' : { "submitted_moves.#{role}":move.move_index }, '$inc':{submitted_moves_count:1} }
        , {new:true}, (err,saved_match) ->
          | err? => res.status(500).send err
          | !saved_match? => res.status(400).send { message : "Invalid state number [#{move.state_number}] for match_id [#{match_id}]" }
          | otherwise =>
            if saved_match.submitted_moves_count == saved_match.player_count

              saved_match.current_state = games[saved_match.game_id].module.next_game_state saved_match.current_state,saved_match.submitted_moves
              saved_match.submitted_moves_count = 0
              saved_match.submitted_moves = {}
              if saved_match.current_state.finished
                saved_match.status = 'done'

              db.matches.save saved_match, (err,write_status) ->
                | err? => res.status(500).send err
                | otherwise =>
                  db.match_states.save saved_match.current_state, (err,saved_state) ->
                    | err? => res.status(500).send err
                    | otherwise => res.status(200).send saved_match
            else
              res.status(200).send saved_match
