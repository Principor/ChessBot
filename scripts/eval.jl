using Dates

include("../src/ChessBot.jl")
using .ChessBot

function perft_recursive(board::Chess.Board, depth::Int)
    depth == 0 && return 1

    moves::Vector{Int16}, num_moves::Int8, _ = Chess.calculate_legal_moves(board)

    depth == 1 && return num_moves
    
    num_nodes::Int = 0
    for i in 1:num_moves
        move::Int16 = moves[i]
        new_board::Chess.Board = Chess.make_move(board, move)
        num_nodes += perft_recursive(new_board, depth-1)
    end
    num_nodes
end

function perft(board::Chess.Board, depth::Int)
    depth == 0 && return 1, Dict{String, Int}()

    moves, num_moves, _ = Chess.calculate_legal_moves(board)

    num_nodes = 0
    dict = Dict{String, Int}()
    for i in 1:num_moves
        move = moves[i]
        new_board::Chess.Board = Chess.make_move(board, move)
        current_nodes = perft_recursive(new_board, depth-1)
        num_nodes += current_nodes
        from, to = Chess.split_move(move)
        dict[Chess.index_to_name(from) * Chess.index_to_name(to)] = current_nodes
    end

    num_nodes, dict
end

function compare(depth, moves)
    if depth < 1
        println("Illegal depth")
    end
    println()
    println("Comparing at depth ", depth, " with starting moves: ", join(moves, " "))

    board = make_moves(Chess.Board(), moves)
    own_total, own_dict = perft(board, depth)

    stockfish = open(`stockfish`, "r+", devnull)

    stockfish_dict = Dict{String, Int}()
    stockfish_total = 0
    println(stockfish, "position startpos moves " * join(moves, " "))
    println(stockfish, "go perft " * string(depth))
    while !eof(stockfish)
        line = readline(stockfish)
        separated = split(line, ": ")
        length(separated) != 2 && continue
        name = separated[1]
        num = parse(Int, separated[2])
        if name == "Nodes searched"
            stockfish_total = num
            break
        else
            stockfish_dict[name] = num
        end
    end
    close(stockfish)

    for (title, total, dict) in [("Own result", own_total, own_dict),("Stockfish result", stockfish_total, stockfish_dict)]
        println(title, ":")
        println(join([name*":"*string(num) for (name, num) in dict],", "))
        println("Total: ", total)
    end
    println()

    for (move, _) in own_dict
        if !haskey(stockfish_dict, move)
            haskey(stockfish_dict, move * "q") && continue
            println("Illegal move - ", move)
            return true
        end
    end

    for (move, _) in stockfish_dict
        if !haskey(own_dict, move)
            length(move) == 5 && continue
            println("Missing move - ", move)
            return true
        end
    end

    for (move, num) in own_dict
        !haskey(stockfish_dict, move) && continue
        if num != stockfish_dict[move]
            println("Mismatched result - ", move)
            println("Own result: ", num, ", Stockfish result: ", stockfish_dict[move])
            return compare(depth - 1, push!(moves, move))
        end
    end

    println("No issues detected")
    return false
end

function make_moves(board, moves)
    for move_name in moves
        move = (Chess.name_to_index(move_name[1:2]) - 1) * 64 + Chess.name_to_index(move_name[3:4])
        board = Chess.make_move(board, move)
    end
    board
end

function main()
    command = ""
    board = Chess.Board()
    while !(command in ["exit", "quit"])
        print(":")
        msg = readline()
        words = split(msg, " ")
        command = words[1]
        args = if length(words) == 1; []; else; words[2:end]; end
        if command == "show"
            println(board)
        elseif command == "fen"
            println(Chess.to_fen(board))
        elseif command == "position"
            if args[1] == "startpos"
                board = Chess.Board()
            elseif length(args) >= 6
                board = Chess.Board(join(args[1:6], " "))
            end
            println(board)
        elseif command == "moves"
            for move_name in args
                move = (Chess.name_to_index(move_name[1:2]) - 1) * 64 + Chess.name_to_index(move_name[3:4])
                board = Chess.make_move(board, move)
            end
            println(board)
        elseif command == "perft"
            start_time = now()
            num_nodes, results_dict = perft(board, parse(Int, args[1]))
            end_time = now()
            for (move, num) in results_dict
                println(move, ": ", num)
            end
            println("\nNodes searched: ", num_nodes)
            println("Duration: ", end_time - start_time)
        elseif command == "compare"
            if length(args) == 0
                println("No depth specified")
                continue
            end
            compare(parse(Int, args[1]), args[2:end])
        elseif command == "multicompare" && isfile("stockfish.exe")
            if length(args) != 3
                println("Wrong number of args")
                continue
            end
            num_samples = parse(Int, args[1])
            starting_depth = parse(Int, args[2])
            search_depth = parse(Int, args[3])
            println("Starting search - num of samples: ", num_samples, ", starting depth: ", starting_depth, ", search_depth: ", search_depth)
            for i in 1:num_samples
                sample_board = Chess.Board()
                moves = String[]
                for j in 1:starting_depth
                    move = rand(Chess.calculate_legal_moves(sample_board)[1])
                    from, to = Chess.split_move(move)
                    push!(moves, Chess.index_to_name(from) * Chess.index_to_name(to))
                    sample_board = Chess.make_move(sample_board, move)
                end
                print("\n\n\n")
                println("Sample #", i, ", moves: ", join(moves, ", "))
                println(sample_board)
                if compare(search_depth, moves)
                    board = sample_board
                    break
                end
            end
        elseif command == "legal"
            move = (Chess.name_to_index(args[1][1:2]) - 1) * 64 + Chess.name_to_index(args[1][3:4])
            moves, _, _ = Chess.calculate_legal_moves(board)
            if move in moves
                println("Legal move")
            else
                println("Illegal move")
            end
        end
    end
end

main()