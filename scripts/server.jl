using WebSockets
using Sockets
using Dates
using Random
include("../src/ChessBot.jl")
using .ChessBot

@enum PlayerColour white black both spectator

global connection_count = 0
global sockets = Dict{Int, WebSocket}()
global messages = Dict{Int, Vector{String}}()
global connections = Dict{Int, Bool}()

function coroutine(ws)
    id = connection_count

    global connection_count += 1
    push!(sockets, id => ws)
    push!(messages, id => [])
    push!(connections, id => true)

    @async begin
        ws = sockets[id]
        while connections[id]
            data, success = readguarded(ws)
            if success; push!(messages[id], String(data))
            else; connections[id] = false; end
        end
    end

    state = Chess.starting_state()
    player_colour = white
    terminated = false
    messages_read = 0
    while connections[id]
        action = 0
        if length(messages[id]) > messages_read
            msg = messages[id][messages_read += 1]
            
            # Restart game
            needs_restart = false
            if msg == "white"
                player_colour = white
                needs_restart = true
            elseif msg == "black"
                player_colour = black
                needs_restart = true
            elseif msg == "both"
                player_colour = both
                needs_restart = true
            elseif msg == "spectator"
                player_colour = spectator
                needs_restart = true
            end
            if needs_restart
                terminated = false
                state = Chess.starting_state()
                continue
            end
            
            # Get player move
            if !terminated && player_colour != spectator && (
                (Chess.is_white_turn(state) && player_colour != black) || 
                (!Chess.is_white_turn(state) && player_colour != white))
                input_action = (Chess.name_to_index(msg[1:2]) - 1) * 64 + Chess.name_to_index(msg[3:4])
                !(input_action in Chess.get_actions(state)) && continue
                action = input_action
            end
        end

        # Get bot move
        if !terminated && player_colour != both && (
            (Chess.is_white_turn(state) && player_colour != white) || 
            (!Chess.is_white_turn(state) && player_colour != black))
            
            probs = mcts(state, 500)
            action = Chess.get_actions(state)[argmax(probs)]
        end

        # Perform move
        if action != 0
            from_pos, to_pos = Chess.split_move(action)
            msg = Chess.index_to_name(from_pos) * Chess.index_to_name(to_pos)
            writeguarded(ws, msg)
            state = Chess.step(state, action)
            score, terminated = Chess.get_score_and_terminated(state)
            if terminated
                if score == -1
                    if Chess.is_white_turn(state); writeguarded(ws, "black wins");
                    else; writeguarded(ws, "white wins"); end
                else; writeguarded(ws, "draw"); end
            end
        else
            sleep(0.01)
        end
    end
    delete!(sockets, id)
    delete!(messages, id)
    delete!(connections, id)
end

function req2response(req)
    if req.target == "/"
        return WebSockets.Response(200, read("server/index.html"))    
    else
        path = "server" * req.target
        if isfile(path)
            return WebSockets.Response(200, read(path))
        end
    end
    return WebSockets.Response(404)
end

server = WebSockets.ServerWS(req2response, coroutine)
WebSockets.serve(server, string(Sockets.localhost), 8080)

