struct MoveData
    rays::UInt64
    number::UInt64
    shift::Int
    dict::Vector{UInt64}
end

function generate_orthogonal_magic_data()
    orthogonal_data = Vector{MoveData}(undef, 64)
    orthogonal_rays, orthogonal_dicts = generate_raw_orthogonal_data()
    for i in 1:64
        rays = orthogonal_rays[i]
        number = orthogonal_numbers[i]
        shift = orthogonal_shifts[i]
        dict = zeros(UInt64, 2 ^ (64 - shift))
        for (obstacles, move) in orthogonal_dicts[i]
            key =  1 + (obstacles * number) >> shift
            dict[key] = move
        end
        orthogonal_data[i] = MoveData(rays, number, shift, dict)
    end
    return orthogonal_data
end

function generate_diagonal_magic_data()
    diagonal_data = Vector{MoveData}(undef, 64)
    diagonal_rays, diagonal_dicts = generate_raw_diagonal_data()
    for i in 1:64
        rays = diagonal_rays[i]
        number = diagonal_numbers[i]
        shift = diagonal_shifts[i]
        dict = zeros(UInt64, 2 ^ (64 - shift))
        for (obstacles, move) in diagonal_dicts[i]
            key =  1 + (obstacles * number) >> shift
            dict[key] = move
        end
        diagonal_data[i] = MoveData(rays, number, shift, dict)
    end
    return diagonal_data
end

function generate_raw_orthogonal_data()
    all_rays = [UInt64(0) for _ in 1:64]
    all_dicts = [Dict{UInt64, UInt64}() for _ in 1:64]
    index = 1
    for y in 1:8
        for x in 1:8
            position = all_positions[index]
            rays = calculate_orthogonal_rays(position, x, y)
            all_rays[index] = rays
            all_obstacles = calculate_possible_obstacles(rays)
            for obstacles in all_obstacles
                moves = calculate_orthogonal_moves(position, obstacles)
                all_dicts[index][obstacles] = moves
            end
            index += 1
        end
    end
    all_rays, all_dicts
end

function generate_raw_diagonal_data()
    all_rays = [UInt64(0) for _ in 1:64]
    all_dicts = [Dict{UInt64, UInt64}() for _ in 1:64]
    index = 1
    for y in 1:8
        for x in 1:8
            position = all_positions[index]
            rays = calculate_diagonal_rays(position, x, y)
            all_rays[index] = rays
            all_obstacles = calculate_possible_obstacles(rays)
            for obstacles in all_obstacles
                moves = calculate_diagonal_moves(position, obstacles)
                all_dicts[index][obstacles] = moves
            end
            index += 1
        end
    end
    all_rays, all_dicts
end

function calculate_orthogonal_rays(position::UInt64, x, y)
    rays = UInt64(0)
    for i in 2:7
        index = i + 8 * y - 8
        rays |= all_positions[index]
    end
    for i in 2:7
        index = x + 8 * i - 8
        rays |= all_positions[index]
    end
    rays & ~position
end

function calculate_diagonal_rays(position::UInt64, x, y)
    rays = UInt64(0)
    for i in 2:7
        for j in 2:7
            index = j + 8 * i - 8
            if i - j == y - x || i + j == y + x
                rays |= all_positions[index]
            end
        end
    end
    return rays & ~position
end

function calculate_orthogonal_moves(position::UInt64, obstacles::UInt64)
    moves = UInt64(0)

    # Up
    p = position
    while true
        moves |= p
        ((p & obstacles != 0) || (p <<= 8) == 0) && break
    end

    # Down
    p = position
    while true
        moves |= p
        ((p & obstacles != 0) || (p >>= 8) == 0) && break
    end
    
    # Right
    p = position
    while true
        moves |= p
        ((p & obstacles != 0) || ((p <<= 1) & ~FILE_H) == 0) && break
    end

    # Left
    p = position
    while true
        moves |= p
        ((p & obstacles != 0) || ((p >>= 1) & ~FILE_A) == 0) && break
    end

    moves
end

function calculate_diagonal_moves(position::UInt64, obstacles::UInt64)
    moves = UInt64(0)

    # Up-left
    p = position
    while true
        moves |= p
        (p & obstacles != 0 || ((p <<= 7) & ~ FILE_A) == 0) && break
    end

    # Up-right
    p = position
    while true
        moves |= p
        (p & obstacles != 0 || ((p <<= 9) & ~ FILE_H) == 0) && break
    end

    # Down-left
    p = position
    while true
        moves |= p
        (p & obstacles != 0 || ((p >>= 9) & ~ FILE_A) == 0) && break
    end

    # Down-right
    p = position
    while true
        moves |= p
        (p & obstacles != 0 || ((p >>= 7) & ~ FILE_H) == 0) && break
    end

    return moves
end

function calculate_possible_obstacles(ray::UInt64)
    indices = zeros(Int, 12)
    num_bits = 0
    for i in 1:64
        if ray & all_positions[i] != 0
            indices[num_bits+=1] = i
        end
    end
    num_patterns = 2^num_bits
    obstacles = Vector{UInt64}(undef, num_patterns)
    for i in 1:num_patterns
        pattern = UInt64(0)
        for j in 1:num_bits
            l_shift = j - 1
            r_shift = indices[j] - 1
            pattern |= ((i >> l_shift) & 1) << r_shift
        end
        obstacles[i] = pattern
    end
    obstacles
end