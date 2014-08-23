_ = require 'prelude-ls'
Q = require 'q'
express = require 'express'
bodyParser = require 'body-parser'

utils = require './utils'

app = express()

# Configure express
#app.use logging 'dev'
app.use bodyParser.json()
console.log __dirname + '/'
app.use '/',express.static(__dirname + '/client')

server = (require 'http').createServer app

LISTEN_PORT = 4000

######## DB Initialisation
mongo = require 'mongoskin'
db_name = "mongodb://localhost/rgs"
db = mongo.db db_name, {native_parser:true}
db.bind 'matches'
db.bind 'match_states'


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
    app

######## Game registration
ttt = require './ttt'

games =
  ttt:
    * game_id: 'ttt'
      description: 'Tic-Tac-Toe'
      options: {game_id:'ttt',required_players:2}
      module: ttt
  ttt_fast:
    * game_id: 'ttt_fast'
      description: 'Tic-Tac-Toe(fast)'
      options: {game_id:'ttt_fast',required_players:2}
      module: ttt

games_list = games |> _.values |> _.map (game) -> { game_id: game.game_id, description: game.description }


######## Rest Interface

# Get a list of games
#
app.get '/api/v1/games', (req, res) ->
  res.status(200).send games_list

# Get a list of matches
# Request parameter filters : game_status
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
        status: "open"
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
app.get '/api/v1/matches/:match_id', (req, res) ->
  match_id = req.param 'match_id'

  #todo : players and other stuff like moves etc needs to be sanaitised
  # this is to prevent private game data from being leaked
  #
  db.matches.findOne { match_id: match_id }, (err, amatch) ->
    | err? => res.status(500).send err
    | otherwise =>
      switch
      | !amatch? => res.status(404).send { message:"Cannot find match [#{match_id}]" }
      | otherwise => res.status(200).send amatch


# Get the states in the match
# Inside the game the concept of a game might exist but it is not nescesary corelated turj in this
# context
# Request parameter filters : current_turn=true
#app.get '/api/v1/matches/:match_id/states', (req, res) ->
#  game_id = req.param 'game_id'
#  match_id = req.param 'match_id'
#  match_key = req.param 'match_key'
#
#  db.match_states.find({ match_id: match_id }).sort({state_number:1}).toArray (err, match_states) ->
#    | err? => res.status(400).send err
#    | otherwise => res.status(200).send match_states


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
  ,{ '$push' : { players:player }, '$inc' : { player_count:1} /*,'$set':{'status':'open'}*/  }
  , {new:true}
  , (err,saved_match) ->
    | err? => res.status(500).send err
    | !saved_match? => res.status(400).send { message : "Match [#{match_id}] is no longer accepting players" }
    | saved_match.players.length < saved_match.required_players =>
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
      | amatch.submitted_moves[role]? => res.status(400).send { message : "Move already submitted for mathd_key [#{match_key}] on match [#{match_id}]" }
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
