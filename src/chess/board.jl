const FILE_A = 0x8080808080808080
const FILE_B = 0x4040404040404040
const FILE_C = 0x2020202020202020
const FILE_D = 0x1010101010101010
const FILE_E = 0x0808080808080808
const FILE_F = 0x0404040404040404
const FILE_G = 0x0202020202020202
const FILE_H = 0x0101010101010101

const FILE_AB = FILE_A | FILE_B
const FILE_GH = FILE_G | FILE_H

const RANK_1 = 0x00000000000000FF
const RANK_2 = 0x000000000000FF00
const RANK_3 = 0x0000000000FF0000
const RANK_4 = 0x00000000FF000000
const RANK_5 = 0x000000FF00000000
const RANK_6 = 0x0000FF0000000000
const RANK_7 = 0x00FF000000000000
const RANK_8 = 0xFF00000000000000

const all_positions = [UInt64(1) << i for i in 0:63]

const WP = 1
const WN = 2
const WB = 3
const WR = 4
const WQ = 5
const WK = 6
const BP = 7
const BN = 8
const BB = 9
const BR = 10
const BQ = 11
const BK = 12

const aligned_pieces = [
    (WP, WN, WB, WR, WQ, WK, BP, BN, BB, BR, BQ, BK),
    (BP, BN, BB, BR, BQ, BK, WP, WN, WB, WR, WQ, WK)
]

const all_pawn_attacks = [
    (((all_positions .& ~FILE_A) .<< 9) .|
    ((all_positions .& ~FILE_H) .<< 7)),
    
    (((all_positions .& ~FILE_A) .>> 7) .|
    ((all_positions .& ~FILE_H) .>> 9))
]

const all_knight_moves = 
    ((all_positions .& ~FILE_A) .<< 17) .| 
    ((all_positions .& ~FILE_H) .<< 15) .|
    ((all_positions .& ~FILE_AB) .<< 10 ) .|
    ((all_positions .& ~FILE_GH) .<< 6 ) .|
    ((all_positions .& ~FILE_AB) .>> 6 ) .|
    ((all_positions .& ~FILE_GH) .>> 10 ) .|
    ((all_positions .& ~FILE_A) .>> 15) .|
    ((all_positions .& ~FILE_H) .>> 17)

const all_king_moves = 
    ((all_positions .& ~ FILE_A) .<< 9) .|
    ((all_positions) .<< 8) .|
    ((all_positions .& ~ FILE_H) .<< 7) .|
    ((all_positions .& ~ FILE_A) .<< 1) .|
    ((all_positions .& ~ FILE_H) .>> 1) .|
    ((all_positions .& ~ FILE_A) .>> 7) .|
    ((all_positions) .>> 8) .|
    ((all_positions .& ~ FILE_H) .>> 9)

const orthogonal_data = generate_orthogonal_magic_data()
const diagonal_data = generate_diagonal_magic_data()

mutable struct Board
    bitboards::Vector{UInt64}
    white_turn::Bool
    en_passants::UInt64
    castling_rights::Vector{Bool}
    half_move::Int
    full_move::Int

    function Board()
        new([
            0x000000000000FF00,
            0x0000000000000042,
            0x0000000000000024,
            0x0000000000000081,
            0x0000000000000010,
            0x0000000000000008,
            0x00FF000000000000,
            0x4200000000000000,
            0x2400000000000000,
            0x8100000000000000,
            0x1000000000000000,
            0x0800000000000000,
        ], true, 0, [true, true, true, true], 0, 1)
    end

    function Board(bitboards::Vector{UInt64}, white_turn::Bool, castling_rights::Vector{Bool}, half_move::Int, full_move::Int)
        new(bitboards, white_turn, 0, castling_rights, half_move, full_move)
    end

    function Board(fen::String)
        pieces, turn, castling, e_p, half, full = split(fen, " ")
        bitboards = zeros(UInt64, 12)
        position_index = 64
        string_index = 0
        while position_index != 0
            character = pieces[string_index += 1]
            if isdigit(character)
                position_index -= parse(Int, character)
            elseif character != '/'
                position = all_positions[position_index]
                if character == 'P'
                    bitboards[1] |= position
                elseif character == 'N'
                    bitboards[2] |= position
                elseif character == 'B'
                    bitboards[3] |= position
                elseif character == 'R'
                    bitboards[4] |= position
                elseif character == 'Q'
                    bitboards[5] |= position
                elseif character == 'K'
                    bitboards[6] |= position
                elseif character == 'p'
                    bitboards[7] |= position
                elseif character == 'n'
                    bitboards[8] |= position
                elseif character == 'b'
                    bitboards[9] |= position
                elseif character == 'r'
                    bitboards[10] |= position
                elseif character == 'q'
                    bitboards[11] |= position
                elseif character == 'k'
                    bitboards[12] |= position
                end
                position_index -= 1
            end
        end
        white_turn = turn == "w"
        castling_rights = [
            occursin("K", castling), 
            occursin("Q", castling), 
            occursin("k", castling), 
            occursin("q", castling)
        ]
        en_passants = if e_p == "-"; 0; else; all_positions[name_to_index(e_p)]; end
        half_move = parse(Int, half)
        full_move = parse(Int, full)
        new(bitboards, white_turn, en_passants, castling_rights, half_move, full_move)
    end
end

function index_to_name(index)
    rank = div(index - 1, 8) + 1
    file = 9 - (index - (rank - 1) * 8)
    "abcdefgh"[file] * string(rank)
end

function name_to_index(name)
    return (parse(Int, last(name)) - 1) * 8 + 9 - (Int(first(name)) - 96)
end

function split_move(move)
    move -= 1
    div(move, 64) + 1 => move % 64 + 1
end

function make_move(board::Board, move)::Board
    from_pos, to_pos = split_move(move)

    new_board::Board = Board(copy(board.bitboards), !board.white_turn, copy(board.castling_rights), board.half_move, board.full_move)
    bitboards::Vector{UInt64} = new_board.bitboards
    from_bitboard::UInt64 = all_positions[from_pos]
    to_bitboard::UInt64 = all_positions[to_pos]

    # Moved piece
    moved_piece::Int = 0
    for p in 1:12
        if bitboards[p] & from_bitboard != 0
            bitboards[p] &= ~from_bitboard
            bitboards[p] |= to_bitboard
            moved_piece = p
            break
        end
    end

    # Captured piece
    captured_piece::Int = 0
    for p in 1:12
        if bitboards[p] & to_bitboard != 0 && p != moved_piece
            bitboards[p] &= ~to_bitboard
            captured_piece = p
            break
        end
    end

    # Pawn promotions
    if (moved_piece == WP && 56 < to_pos <= 64)
        bitboards[WP] &= ~to_bitboard
        bitboards[WQ] |= to_bitboard
    end
    if (moved_piece == BP && 0 < to_pos <= 8) 
        bitboards[BP] &= ~to_bitboard
        bitboards[BQ] |= to_bitboard
    end

    # Performed en-passant
    if moved_piece % 6 == 1 && (to_bitboard & board.en_passants != 0)
        en_passant_target = ((to_bitboard >> 8) * board.white_turn) | ((to_bitboard << 8) * (1 - board.white_turn))
        new_board.bitboards[WP] &= ~en_passant_target
        new_board.bitboards[BP] &= ~en_passant_target
        captured_piece = moved_piece + 6 * (1 - 2 * div(moved_piece - 1, 6))
    end

    # Performed castle
    if moved_piece == WK && from_pos == 4
        if to_pos == 2
            bitboards[WR] &= ~all_positions[1]
            bitboards[WR] |= all_positions[3]
        elseif to_pos == 6
            bitboards[WR] &= ~all_positions[8]
            bitboards[WR] |= all_positions[5]
        end
    elseif moved_piece == BK && from_pos == 60
        if to_pos == 58
            bitboards[BR] &= ~all_positions[57]
            bitboards[BR] |= all_positions[59]
        elseif to_pos == 62
            bitboards[BR] &= ~all_positions[64]
            bitboards[BR] |= all_positions[61]
        end
    end

    # Castling rights
    (from_pos == 1 || to_pos == 1) && (new_board.castling_rights[1] = false)
    (from_pos == 8 || to_pos == 8) && (new_board.castling_rights[2] = false)
    from_pos == 4 && (new_board.castling_rights[1:2] .= false)
    (from_pos == 57 || to_pos == 57) && (new_board.castling_rights[3] = false)
    (from_pos == 64 || to_pos == 64) && (new_board.castling_rights[4] = false)
    from_pos == 60 && (new_board.castling_rights[3:4] .= false)

    # Possible en-passants
    moved_piece == WP && to_pos == (from_pos + 16) && (new_board.en_passants = from_bitboard << 8)
    moved_piece == BP && to_pos == (from_pos - 16) && (new_board.en_passants = from_bitboard >> 8)

    # Update clocks
    new_board.full_move += new_board.white_turn
    if captured_piece != 0 || moved_piece % 6 == 1
        new_board.half_move = 0
    else
        new_board.half_move += 1
    end 
    
    new_board
end

function is_check_possible(board::Board)::Bool
    board.half_move > 0 && return true

    wn::Int = count_bitboard(board.bitboards[WN])
    wb::Int = count_bitboard(board.bitboards[WB])
    wo::Int = count_bitboard(board.bitboards[WP] | board.bitboards[WR] | board.bitboards[WQ])
    bn::Int = count_bitboard(board.bitboards[BN])
    bb::Int = count_bitboard(board.bitboards[BB])
    bo::Int = count_bitboard(board.bitboards[BP] | board.bitboards[BR] | board.bitboards[BQ])

    (wo + bo) != 0 && return true

    ((wn + wb) < 2) && ((bn + bb) < 2) && return false
    (wn == 2) && ((wb + bn + bb) == 0) && return false
    (bn == 2) && ((wb + wn + bb) == 0) && return false

    return true
end

function calculate_legal_moves(board::Board)::Tuple{Vector{Int16},Int8,Bool}
    bitboards::Vector{UInt64} = board.bitboards
    fp, fn, fb, fr, fq, fk, ep, en, eb, er, eq, ek = get_player_piece_indices(board.white_turn)

    friendly_no_king::UInt64 = bitboards[fp] | bitboards[fn] | bitboards[fb] | bitboards[fr] | bitboards[fq]
    friendly::UInt64 = friendly_no_king | bitboards[fk]
    enemy::UInt64 = bitboards[ep] | bitboards[en] | bitboards[eb] | bitboards[er] | bitboards[eq] | bitboards[ek]
    obstacles::UInt64 = friendly | enemy
    empty::UInt64 = ~obstacles
    king_index::Int = trailing_zeros(bitboards[fk]) + 1

    all_moves::Vector{Int16} = zeros(Int16, 256)
    num_moves::Int8 = 0
    
    # Calculate all positions attacked by enemy
    obstacles_no_king::UInt64 = friendly_no_king | enemy
    attacked_positions::UInt64 = calculate_attacked(board, ep, en, eb, er, eq, ek, obstacles_no_king)
    checked::Bool = attacked_positions & bitboards[fk] != 0
    
    # King moves can be handled immediately
    king_move_bits::UInt64 = (all_king_moves[king_index] & ~friendly & ~attacked_positions) |
        get_castles(board.white_turn, board.castling_rights, obstacles, attacked_positions, checked)
    num_moves = append_bitboard_to_movelist(all_moves, num_moves, king_index, king_move_bits)

    check_mask::UInt64 = typemax(UInt64)
    if checked
        checkers::UInt64 = calculate_checkers(board, king_index, ep, en, eb, er, eq, obstacles)
        (checkers & (checkers - 1) != 0) && return all_moves[1:num_moves], num_moves, checked

        # Can capture attacker
        checker_index = trailing_zeros(checkers) + 1
        check_mask = checkers

        if checkers & bitboards[eb] != 0
            check_mask |= get_diagonal_moves(checker_index, obstacles) & get_diagonal_moves(king_index, obstacles)
        elseif checkers & bitboards[er] != 0
            check_mask |= get_orthogonal_moves(checker_index, obstacles) & get_orthogonal_moves(king_index, obstacles)
        elseif checkers & bitboards[eq] != 0
            queen_orthogonal_moves = get_orthogonal_moves(checker_index, obstacles)
            if queen_orthogonal_moves & bitboards[fk] != 0
                check_mask |= queen_orthogonal_moves & get_orthogonal_moves(king_index, obstacles)
            else
                check_mask |= get_diagonal_moves(checker_index, obstacles) & get_diagonal_moves(king_index, obstacles)
            end
        end
    end
    
    num_moves, pinned_pieces::UInt64, blocked_en_passants::UInt64 = handle_pins(board, checked, fp, fb, fr, fq, fk, ep, eb, er, eq,
        friendly_no_king, obstacles, all_moves, num_moves)
    unpinned_pieces::UInt64 = friendly_no_king & ~pinned_pieces
    available_en_passants::UInt64 = board.en_passants & if board.white_turn
        (check_mask & ~blocked_en_passants) << 8
    else
        (check_mask & ~blocked_en_passants) >> 8
    end

    for index in 1:64
        position::UInt64 = all_positions[index]

        position & unpinned_pieces == 0 && continue;

        pawn_moves = (get_pawn_pushes(board.white_turn, position, empty) & check_mask) |
            (get_pawn_attacks(board.white_turn, index) & ((enemy & check_mask) | available_en_passants))
        knight_moves = all_knight_moves[index] & ~friendly & check_mask
        bishop_moves = get_diagonal_moves(index, obstacles) & ~friendly & check_mask
        rook_moves = get_orthogonal_moves(index, obstacles) & ~friendly & check_mask

        move_bits = 
            pawn_moves * (bitboards[fp] & position != 0) |
            knight_moves * (bitboards[fn] & position != 0) |
            bishop_moves * ((bitboards[fb] | bitboards[fq]) & position != 0) |
            rook_moves * ((bitboards[fr] | bitboards[fq]) & position != 0)

        num_moves = append_bitboard_to_movelist(all_moves, num_moves, index, move_bits)
    end

    all_moves[1:num_moves], num_moves, checked
end

function append_bitboard_to_movelist(all_moves::Vector{Int16}, num_moves::Int8, index::Int, move_bits::UInt64)::Int8
    while move_bits != 0
        all_moves[num_moves += 1] = (index - 1) * 64 + trailing_zeros(move_bits) + 1
        move_bits &= (move_bits - 1)
    end
    return num_moves
end

function calculate_attacked(board::Board, ep::Int, en::Int, eb::Int, er::Int, eq::Int, ek::Int, obstacles::UInt64)::UInt64
    bitboards::Vector{UInt64} = board.bitboards
    
    attacked::UInt64 = 0

    # Pawns
    attacked |= if board.white_turn
        ((bitboards[ep] .& ~FILE_H) >> 9) |
        ((bitboards[ep] .& ~FILE_A) >> 7)
    else
        ((bitboards[ep] .& ~FILE_H) << 7) |
        ((bitboards[ep] .& ~FILE_A) << 9)
    end

    # Knights
    attacked |= 
        ((bitboards[en] .& ~FILE_A) << 17) | 
        ((bitboards[en] .& ~FILE_H) << 15) |
        ((bitboards[en] .& ~FILE_AB) << 10 ) |
        ((bitboards[en] .& ~FILE_GH) << 6 ) |
        ((bitboards[en] .& ~FILE_AB) >> 6 ) |
        ((bitboards[en] .& ~FILE_GH) >> 10 ) |
        ((bitboards[en] .& ~FILE_A) >> 15) |
        ((bitboards[en] .& ~FILE_H) >> 17)

    # Kings
    attacked |=
        ((bitboards[ek] .& ~ FILE_A) << 9) |
        ((bitboards[ek]) << 8) |
        ((bitboards[ek] .& ~ FILE_H) << 7) |
        ((bitboards[ek] .& ~ FILE_A) << 1) |
        ((bitboards[ek] .& ~ FILE_H) >> 1) |
        ((bitboards[ek] .& ~ FILE_A) >> 7) |
        ((bitboards[ek]) >> 8) |
        ((bitboards[ek] .& ~ FILE_H) >> 9)

    # Orthogonal sliders
    attacked |= calculate_orthogonal_moves(bitboards[er] | bitboards[eq], obstacles)
    
    # Diagonal sliders
    attacked |= calculate_diagonal_moves(bitboards[eb] | bitboards[eq], obstacles)

    attacked
end

function calculate_checkers(board::Board, king_index, ep, en, eb, er, eq, obstacles)
    bitboards = board.bitboards
    
    attackers::UInt64 = 0

    attackers |= get_pawn_attacks(board.white_turn, king_index) & bitboards[ep]
    attackers |= all_knight_moves[king_index] & bitboards[en]
    attackers |= get_orthogonal_moves(king_index, obstacles) & (bitboards[er] | bitboards[eq])
    attackers |= get_diagonal_moves(king_index, obstacles) & (bitboards[eb] | bitboards[eq])

    attackers
end

function handle_pins(board::Board, checked::Bool, fp::Int, fb::Int, fr::Int, fq::Int, fk::Int,
    ep::Int, eb::Int, er::Int, eq::Int, friendly_no_king::UInt64, obstacles::UInt64, all_moves::Vector{Int16}, num_moves::Int8)
    bitboards::Vector{UInt64} = board.bitboards
    
    enemy_orthogonal_pieces::UInt64 = bitboards[er] | bitboards[eq]
    enemy_diagonal_pieces::UInt64 = bitboards[eb] | bitboards[eq]

    enemy_orthogonal_1::UInt64 = calculate_orthogonal_moves_1(enemy_orthogonal_pieces, obstacles)
    king_orthogonal_1::UInt64 = calculate_orthogonal_moves_1(bitboards[fk], obstacles)
    pinned_orthogonal_1::UInt64 = friendly_no_king & enemy_orthogonal_1 & king_orthogonal_1

    enemy_orthogonal_2::UInt64 = calculate_orthogonal_moves_2(enemy_orthogonal_pieces, obstacles)
    king_orthogonal_2::UInt64 = calculate_orthogonal_moves_2(bitboards[fk], obstacles)
    pinned_orthogonal_2::UInt64 = friendly_no_king & enemy_orthogonal_2 & king_orthogonal_2

    enemy_diagonal_1::UInt64 = calculate_diagonal_moves_1(enemy_diagonal_pieces, obstacles)
    king_diagonal_1::UInt64 = calculate_diagonal_moves_1(bitboards[fk], obstacles)
    pinned_diagonal_1::UInt64 = friendly_no_king & enemy_diagonal_1 & king_diagonal_1

    enemy_diagonal_2::UInt64 = calculate_diagonal_moves_2(enemy_diagonal_pieces, obstacles)
    king_diagonal_2::UInt64 = calculate_diagonal_moves_2(bitboards[fk], obstacles)
    pinned_diagonal_2::UInt64 = friendly_no_king & enemy_diagonal_2 & king_diagonal_2

    all_pinned::UInt64 = pinned_orthogonal_1 | pinned_orthogonal_2 | pinned_diagonal_1 | pinned_diagonal_2

    blocked_en_passants = (pinned_diagonal_1 | pinned_diagonal_2) & ep
    blocked_en_passants |= ((king_orthogonal_2 & ~FILE_A) >> 1) & enemy_orthogonal_2
    blocked_en_passants |= ((king_orthogonal_2 & ~FILE_H) << 1) & enemy_orthogonal_2

    checked && return num_moves, all_pinned, blocked_en_passants

    pinned_orthogonal_pawns::UInt64 = pinned_orthogonal_1 & bitboards[fp]
    while pinned_orthogonal_pawns != 0
        index = trailing_zeros(pinned_orthogonal_pawns) + 1
        move_bits::UInt64 = get_pawn_pushes(board.white_turn, all_positions[index], ~obstacles)
        num_moves = append_bitboard_to_movelist(all_moves, num_moves, index, move_bits)
        pinned_orthogonal_pawns &= pinned_orthogonal_pawns - 1
    end

    pinned_diagonal_pawns_1::UInt64 = pinned_diagonal_1 & bitboards[fp]
    while pinned_diagonal_pawns_1 != 0
        index = trailing_zeros(pinned_diagonal_pawns_1) + 1
        move_bits::UInt64 = calculate_diagonal_moves_1(pinned_diagonal_pawns_1, obstacles) &
            get_pawn_attacks(board.white_turn, index) &
            (enemy_diagonal_pieces | board.en_passants)
        num_moves = append_bitboard_to_movelist(all_moves, num_moves, index, move_bits)
        pinned_diagonal_pawns_1 &= pinned_diagonal_pawns_1 - 1
    end

    pinned_diagonal_pawns_2::UInt64 = pinned_diagonal_2 & bitboards[fp]
    while pinned_diagonal_pawns_2 != 0
        index = trailing_zeros(pinned_diagonal_pawns_2) + 1
        move_bits::UInt64 = calculate_diagonal_moves_2(pinned_diagonal_pawns_2, obstacles) &
            get_pawn_attacks(board.white_turn, index) &
            (enemy_diagonal_pieces | board.en_passants)
        num_moves = append_bitboard_to_movelist(all_moves, num_moves, index, move_bits)
        pinned_diagonal_pawns_2 &= pinned_diagonal_pawns_2 - 1
    end

    pinned_orthogonal_sliders_1::UInt64 = pinned_orthogonal_1 & (bitboards[fr] | bitboards[fq])
    while pinned_orthogonal_sliders_1 != 0
        index = trailing_zeros(pinned_orthogonal_sliders_1) + 1
        move_bits::UInt64 = calculate_orthogonal_moves_1(all_positions[index], obstacles) & ~bitboards[fk]
        num_moves = append_bitboard_to_movelist(all_moves, num_moves, index, move_bits)
        pinned_orthogonal_sliders_1 &= pinned_orthogonal_sliders_1 - 1
    end

    pinned_orthogonal_sliders_2::UInt64 = pinned_orthogonal_2 & (bitboards[fr] | bitboards[fq])
    while pinned_orthogonal_sliders_2 != 0
        index = trailing_zeros(pinned_orthogonal_sliders_2) + 1
        move_bits::UInt64 = calculate_orthogonal_moves_2(all_positions[index], obstacles) & ~bitboards[fk]
        num_moves = append_bitboard_to_movelist(all_moves, num_moves, index, move_bits)
        pinned_orthogonal_sliders_2 &= pinned_orthogonal_sliders_2 - 1
    end

    pinned_diagonal_sliders_1::UInt64 = pinned_diagonal_1 & (bitboards[fb] | bitboards[fq])
    while pinned_diagonal_sliders_1 != 0
        index = trailing_zeros(pinned_diagonal_sliders_1) + 1
        move_bits::UInt64 = calculate_diagonal_moves_1(pinned_diagonal_sliders_1, obstacles) & ~bitboards[fk]
        num_moves = append_bitboard_to_movelist(all_moves, num_moves, index, move_bits)
        pinned_diagonal_sliders_1 &= pinned_diagonal_sliders_1 - 1
    end

    pinned_diagonal_sliders_2::UInt64 = pinned_diagonal_2 & (bitboards[fb] | bitboards[fq])
    while pinned_diagonal_sliders_2 != 0
        index = trailing_zeros(pinned_diagonal_sliders_2) + 1
        move_bits::UInt64 = calculate_diagonal_moves_2(pinned_diagonal_sliders_2, obstacles) & ~bitboards[fk]
        num_moves = append_bitboard_to_movelist(all_moves, num_moves, index, move_bits)
        pinned_diagonal_sliders_2 &= pinned_diagonal_sliders_2 - 1
    end

    return num_moves, all_pinned, blocked_en_passants
end

function get_player_piece_indices(white_turn::Bool)
    [
        (WP, WN, WB, WR, WQ, WK, BP, BN, BB, BR, BQ, BK),
        (BP, BN, BB, BR, BQ, BK, WP, WN, WB, WR, WQ, WK)
    ][2 - white_turn]
end

function get_castles(white_turn::Bool, castling_rights::Vector{Bool}, obstacles::UInt64, attacked::UInt64, checked::Bool)::UInt64
    checked && return 0
    castle_blockers::UInt64 = obstacles | (attacked & ~FILE_B)
    if white_turn
        all_positions[2] * (0x0000000000000006 & castle_blockers == 0) * castling_rights[1] |
        all_positions[6] * (0x0000000000000070 & castle_blockers == 0) * castling_rights[2]
    else
        all_positions[58] * (0x0600000000000000 & castle_blockers == 0) * castling_rights[3]  |
        all_positions[62] * (0x7000000000000000 & castle_blockers == 0) * castling_rights[4]
    end
end

function get_pawn_attacks(white_turn::Bool, index::Int)::UInt64
    return all_pawn_attacks[2 - white_turn][index]
end

function get_pawn_pushes(white_turn::Bool, position::UInt64, empty::UInt64)::UInt64
    if white_turn
        ((position << 8) & empty) | (((position & RANK_2) << 16) & empty & (empty << 8))
    else
        ((position >> 8) & empty) | (((position & RANK_7) >> 16) & empty & (empty >> 8))
    end
end

function calculate_orthogonal_moves(positions::UInt64, obstacles::UInt64)::UInt64
    calculate_orthogonal_moves_1(positions, obstacles) | calculate_orthogonal_moves_2(positions, obstacles)
end

function calculate_diagonal_moves(positions::UInt64, obstacles::UInt64)::UInt64
    calculate_diagonal_moves_1(positions, obstacles) | calculate_diagonal_moves_2(positions, obstacles)
end

function calculate_orthogonal_moves_1(positions::UInt64, obstacles::UInt64)::UInt64
    fill_up(positions, ~obstacles) | fill_down(positions, ~obstacles)
end

function calculate_orthogonal_moves_2(positions::UInt64, obstacles::UInt64)::UInt64
    fill_left(positions, ~obstacles) | fill_right(positions, ~obstacles)
end

function calculate_diagonal_moves_1(positions::UInt64, obstacles::UInt64)::UInt64
    fill_up_left(positions, ~obstacles) | fill_down_right(positions, ~obstacles)
end

function calculate_diagonal_moves_2(positions::UInt64, obstacles::UInt64)::UInt64
    fill_down_left(positions, ~obstacles) | fill_up_right(positions, ~obstacles)
end

function get_orthogonal_moves(index::Int, obstacles::UInt64)::UInt64
    move_data::MoveData = orthogonal_data[index]
    key::UInt64 = 1 + (obstacles & move_data.rays * move_data.number) >> move_data.shift
    move_data.dict[key]
end

function get_diagonal_moves(index::Int, obstacles::UInt64)::UInt64
    move_data::MoveData = diagonal_data[index]
    obstacles &= move_data.rays
    key::UInt64 = 1 + (obstacles * move_data.number) >> move_data.shift
    move_data.dict[key]
end

function count_bitboard(bitboard::UInt64)::Int
    bitboard == 0 && return 0
    (bitboard & (bitboard - 1)) == 0 && return 1
    return 2
end

function to_fen(board::Board)
    pieces = ""

    gap = 0
    for index in 64:-1:1
        piece = 0
        for p in 1:12
            (board.bitboards[p] & all_positions[index] != 0) && (piece = p)
        end
        if piece != 0
            gap != 0 && (pieces *= string(gap))
            gap = 0
            pieces *= ["P","N","B","R","Q","K","p","n","b","r","q","k"][piece]
        else
            gap += 1
        end
        if index % 8 == 1
            gap != 0 && (pieces *= string(gap))
            gap = 0
            index != 1 && (pieces *= "/")
        end
    end

    turn = if board.white_turn; "w"; else; "b"; end
    castling = castling_rights_string(board.castling_rights)
    e_p = if board.en_passants == 0; "-" else; index_to_name(trailing_zeros(board.en_passants) + 1); end
    half = string(board.half_move)
    full = string(board.full_move)

    join([pieces, turn, castling, e_p, half, full], " ")
end

function castling_rights_string(castling_rights::Vector{Bool})
    if sum(castling_rights) == 0
        "-"
    else
        "KQkq"[findall(castling_rights)]
    end
end

function Base.show(io::IO, board::Board)
    for i in 1:8
        for j in 1:8
            index = (9 - i) * 8 - j + 1
            piece = 13
            for p in 1:12
                (board.bitboards[p] & all_positions[index] != 0) && (piece = p)
            end
            print(io, ["P","N","B","R","Q","K","p","n","b","r","q","k","⋅"][piece], " ")
        end
        println(io)
    end
end

function print_bitboard(bitboard::UInt64)
    for i in 1:8
        shift = (8 - i) * 8
        line = (bitboard >> shift) & 0xff
        word = Base.bin(line, 8, false)
        word = replace(replace(word, "0"=>"⋅"), "1"=>"◯")
        word = join(split(word, ""), " ")
        println(word)
    end
end