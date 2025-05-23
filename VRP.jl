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


function solve_vrp(nodes_path::String; parameters=VRPParameters(3,100,true))
    df              = read_nodes(nodes_path)
    n               = nrow(df)
    depot           = findfirst(df.type .== "depot")
    customer        = setdiff(1:n, depot)
    distances       = compute_distance(df)
    vehicles        = 1:parameters.num_vehicles
    demand          = df.demand
    model           = Model(HiGHS.Optimizer)


    # Decision Variables
    @variable(model, x[1:n,1:n,vehicles], Bin) # route selection
    @variable(model, f[1:n,1:n,vehicles] >= 0) # carried demand
    # Objective Function
    @objective(model, Min, sum(distances[i,j]*x[i,j,k] for i=1:n, j=1:n, k in vehicles)) # objective function


    # Constraints
    @constraint(model, [i in 1:n, k in vehicles], x[i,i,k] == 0) # no self-loop
    @constraint(model, [j in customer], sum(x[i,j,k] for i=1:n, k in vehicles) == 1) # each customer is visited once
    @constraint(model, [j in customer], sum(x[j,i,k] for i=1:n, k in vehicles) == 1) # each customer is exited once

    for k in vehicles
        @constraint(model, sum(x[depot,j,k] for j in customer) ≤ 1)  # ≤ 1 exit
        @constraint(model, sum(x[j,depot,k] for j in customer) ≤ 1)  # ≤ 1 return
        if parameters.return_to_depot
            @constraint(model,
                sum(x[depot,j,k] for j in customer) == sum(x[j,depot,k] for j in customer)) # return to depot
        end
    end


    # Capacity Constraints
    @constraint(model, [i in 1:n, j in 1:n, k in vehicles],
        f[i,j,k] <= parameters.capacity * x[i,j,k])
    @constraint(model, [k in vehicles],
        sum(f[depot,j,k] for j in customer) ==
        sum(demand[j] * sum(i-> x[i,j,k], 1:n) for j in customer)) # total demand
    @constraint(model, [k in vehicles, j in customer],
        sum(f[i,j,k] for i in 1:n) -
        sum(f[j,l,k] for l in 1:n) ==
        demand[j] * sum(i-> x[i,j,k], 1:n)) #flow conservation


    optimize!(model)

        Routes = Dict{Int,Vector{Int}}()

    for k in vehicles
        arc = Dict(i => j for i in 1:n, j in 1:n if value(x[i,j,k]) > 0.5)

        cur, route = depot, Int[]
        visited    = Set{Int}()

        while haskey(arc, cur)
            nxt = arc[cur]
            nxt == depot && break       # return to depot      
            nxt in visited && break        # already visited
            push!(route, nxt) # add to route
            push!(visited, nxt) # mark as visited
            cur = nxt
        end

        !isempty(route) && (Routes[k] = route)
    end


        return (Routes=Routes,
                sum_distance=objective_value(model),
                df=df)
end

function plot_routes(df::DataFrame, routes::Dict{Int,Vector{Int}})
    depot    = findfirst(df.type .== "depot")
    customer = setdiff(1:nrow(df), depot)

    scatter(df.x[customer], df.y[customer];
        label="Customers", marker=:circle, markersize=10, color=:blue,xlim=(0,12), ylim=(0,10))
    scatter!([df.x[depot]], [df.y[depot]];
        label="Depot",     marker=:circle, markersize=10, color=:red)
    base_colors = [:red, :green, :blue, :purple, :orange, :cyan, :magenta]
    vehicle_colors = base_colors[1:length(routes)]

    for row in eachrow(df)
        annotate!(row.x + 0.0, row.y + 0.0, text(string(row.id), 12, :white))
    end

    for (k, route) in sort(collect(routes))
        pts = [depot; route; depot]
        xs, ys = df.x[pts], df.y[pts]
        plot!(xs, ys;
            lw=2,
            color=vehicle_colors[k],
            label="Vehicle $k",
        )
        dx = diff(xs)
        dy = diff(ys)
        inset_start_x = xs[1:end-1] .+ 0.1 .* dx
        inset_start_y = ys[1:end-1] .+ 0.1 .* dy
        arrow_dx = 0.7 .* dx
        arrow_dy = 0.7 .* dy

        quiver!(
            inset_start_x, inset_start_y,
            quiver = (arrow_dx, arrow_dy),
            arrow = true,
            lw = 3,
            arrowsize = 0.2,
            color = vehicle_colors[k],
        )
    end

    # 4) Final polish
    xlabel!("X")
    ylabel!("Y")
    title!("VRP Solution")
    plot!(legend = :topright)
    mkpath("plots")
    savefig("plots/vrp_routes.png")
end

function main()
    parameters=VRPParameters(4, 70, true)
    result=solve_vrp("nodes.csv", parameters=parameters)
    plot_routes(result.df, result.Routes)
    println("Distance: ", result.sum_distance)
    println("Routes: ", result.Routes)

end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end