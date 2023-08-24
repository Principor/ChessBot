struct ChessState
    board::Board
    legal_moves::Vector{Int16}
    num_moves::Int8
    check::Bool

    function ChessState()
        board = Board()
        moves, num_moves, _ = calculate_legal_moves(board)
        new(board, moves, num_moves, false)
    end

    function ChessState(board::Board, legal_moves::Vector{Int16}, num_moves::Int8, check::Bool)
        new(board, legal_moves, num_moves, check)
    end
end

function starting_state()::ChessState
    ChessState()
end

function get_actions(state::ChessState)::Vector{Int16}
    return state.legal_moves
end

function step(state::ChessState, action)::ChessState
    new_board::Board = make_move(state.board, action)
    moves, num_moves, check = calculate_legal_moves(new_board)
    ChessState(
        new_board,
        moves,
        num_moves,
        check
    )
end

function get_score_and_terminated(state::ChessState)::Tuple{Int, Bool}
    # Check mate and stalemate
    if state.num_moves == 0
        state.check && return -1, true
        return 0, true
    end

    !is_check_possible(state.board) && return 0, true

    # Turn limit
    state.board.half_move > 50 && return 0, true
    
    return 0, false
end

function is_white_turn(state::ChessState)::Bool
    state.board.white_turn::Bool
end

function get_encoded_state(state::ChessState)
    get_encoded_board(state.board)
end