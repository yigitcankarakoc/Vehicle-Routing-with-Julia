using XLSX, CSV, DataFrames, JuMP, HiGHS, Distances, Plots

struct VRPParameters
    num_vehicles::Int
    capacity::Int
    return_to_depot::Bool
end

function read_nodes(path::String)
    if endswith(path, ".xlsx")
        df = XLSX.readtable(path, "Sheet1") |> DataFrame
    else
        df = CSV.read(path, DataFrame)
    end
    df.id .= Int.(df.id)    # convert id to Int
    return df
end

function compute_distance(df::DataFrame)
    n = nrow(df)    # row count
    Distance_matrix = zeros(n, n) 
    for i in 1:n, j in 1:n
        Distance_matrix[i,j] = evaluate(Euclidean(), (df.x[i], df.y[i]), (df.x[j], df.y[j]))    # distance between points
    end
    return Distance_matrix
end

#
        ### MODEL SOLVING FUNCTION WILL BE ADDED HERE

        ### PLOTTING/PRINTING FUNCTION WILL BE ADDED HERE

#

function main()
    parameters=VRPParameters(3, 100, true)
    df = read_nodes("nodes.csv")
    compute_distance(df)

    #
        ### MODEL SOLVING FUNCTION CALL

        ### PLOTTING/PRINTING FUNCTION CALL
    #
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end