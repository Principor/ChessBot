using SharedArrays
using Dates
using Distributed

include("../src/ChessBot.jl")
using .ChessBot

addprocs(4)

@everywhere function find_magic_number(dict::Dict{UInt64, UInt64}, best_number, best_shift, steps)
    for _ in 1:steps
        number::UInt64 = rand(1:typemax(UInt64))
        has_overlap::Bool = false
        while !has_overlap
            cur_dict::Dict{UInt64,UInt64} = Dict{UInt64,UInt64}()
            for (obstacles::UInt64,moves::UInt64) in dict
                key =  1 + (obstacles * number) >> (best_shift + 1)
                if haskey(cur_dict, key)
                    if cur_dict[key] != moves
                        has_overlap = true
                        break
                    end
                else
                    cur_dict[key] = moves
                end
            end

            if !has_overlap
                best_number = number
                best_shift += 1
            end
        end
    end
    return best_number, best_shift
end

function print_array(file, name::String, unsigned::Bool, values)
    print(file, "const ", name, " = ")
    if unsigned; print(file, "UInt64"); end
    println(file, "[", join(values,","), "]")
end

function get_required_size(shifts)
    result = sum(Int128(2) .^ (64 .- shifts .+ 3))
    units = ["B","KB","MB","GB","TB","PB","EB","ZB","YB"]
    unit_index = 1
    while unit_index < length(units) && result > (2 << 10)
        result >>= 10
        unit_index += 1
    end
    return string(result) * " " * units[unit_index]
end

best_orthogonal_numbers = SharedArray(Chess.orthogonal_numbers)
best_orthogonal_shifts = SharedArray(Chess.orthogonal_shifts)
best_diagonal_numbers = SharedArray(Chess.diagonal_numbers)
best_diagonal_shifts = SharedArray(Chess.diagonal_shifts)

const steps_per_log = 10_000

function find_all_numbers(dicts, best_numbers, best_shifts)
    println("Start size: ", get_required_size(best_shifts))
    print("Steps to perform: ")
    steps = parse(Int, readline())
    steps == 0 && return

    start_time = now()

    for start_step in 1:steps_per_log:steps
        current_steps = min(steps_per_log, steps - start_step + 1)
        @sync @distributed for i in 1:64
            best_number, best_shift = find_magic_number(
                dicts[i], 
                best_numbers[i], 
                best_shifts[i],
                current_steps
            )
            best_numbers[i] = best_number
            best_shifts[i] = best_shift
        end
        duration = (now() - start_time).value
        println(
            "Step: ", start_step + current_steps - 1, "/", steps, ";   ",
            "Duration: ", round(duration / 1000, digits=2), "s;   ",
            "New size: ", get_required_size(best_shifts),
        )
    end
end

function main()
    _, orthogonal_dicts = Chess.generate_raw_orthogonal_data()
    println("[Orthogonal Numbers] ")
    find_all_numbers(orthogonal_dicts, best_orthogonal_numbers, best_orthogonal_shifts)

    println()

    _, diagonal_dicts = Chess.generate_raw_diagonal_data()
    println("[Diagonal Numbers]")
    find_all_numbers(diagonal_dicts, best_diagonal_numbers, best_diagonal_shifts)
    
    open("src/chess/magic_numbers.jl", "w") do f
        print_array(f, "orthogonal_numbers", true, best_orthogonal_numbers)
        print_array(f, "orthogonal_shifts", false, best_orthogonal_shifts)
        print_array(f, "diagonal_numbers", true, best_diagonal_numbers)
        print_array(f, "diagonal_shifts", false, best_diagonal_shifts)
    end
end

main()