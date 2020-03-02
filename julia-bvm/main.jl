using LightGraphs
using GraphPlot, Compose
using ColorSchemes, Colors
using Random
using Cairo, Fontconfig
using Glob
using Plots
using DataFrames
using Bootstrap
using Gadfly
using Statistics

include("agent.jl")
include("config.jl")
@enum Opinion Red Blue
function make_graph(n=20, p=0.2, make_anim=false, influencer=false, replacement=false)

    # Set seed for consistency.
    #Random.seed!(12345)

    # Put us in a temp dir, and remove any old files from previous runs.
    cd("$(store_dir)")
    rm.(glob("graph*.png"))
    rm.(glob("graph*.svg"))

    graph = erdos_renyi(n,p)
    while is_connected(graph) == false
        graph = erdos_renyi(n,p)
    end

    return graph
end

function set_influencee_opinion(this_graph, this_node_list, this_agent_list, replacement)
    graph = this_graph
    use_node_list = this_node_list
    use_agent_list = this_agent_list
    this_node = rand(use_node_list)
    this_agent = use_agent_list[this_node]
    neighbor_list = neighbors(graph, this_node)
    next_node = rand(neighbor_list)
    next_agent = use_agent_list[next_node]
    next_opinion = getOpinion(next_agent)
    setOpinion(this_agent, next_opinion)
    if replacement == false
        filter!(x -> x ≠ this_node, use_node_list)
    end
end

function set_influencer_opinion(this_graph, this_node_list, this_agent_list, replacement)
    graph = this_graph
    use_node_list = this_node_list
    use_agent_list = this_agent_list
    this_node = rand(use_node_list)
    this_agent = use_agent_list[this_node]
    neighbor_list = neighbors(graph, this_node)
    next_node = rand(neighbor_list)
    next_agent = use_agent_list[next_node]
    next_opinion = getOpinion(this_agent)
    setOpinion(next_agent, next_opinion)
    if replacement == false
        filter!(x -> x ≠ this_node, use_node_list)
    end
end

function find_num_red(this_agent_list)
    agent_list = this_agent_list
    num_red = 0
    for a in agent_list
        if getOpinion(a) == Red
            num_red += 1
        end
    end
    return num_red
end

function make_graph_anim(this_graph, this_agent_list, this_iter)
    graph = this_graph
    agent_list = this_agent_list
    iter = this_iter
    locs_x, locs_y = spring_layout(graph)
    # Remember and reuse graph layout for each animation frame.
    remember_layout = x -> spring_layout(x, locs_x, locs_y)
    # Plot this frame of animation to a file.
    graphp = gplot(graph,
        layout=remember_layout,
        NODESIZE=.08,
        nodestrokec=colorant"grey",
        nodestrokelw=.5,
        nodefillc=[ ifelse(a.opinion==Blue::Opinion,colorant"blue",
            colorant"red") for a in agent_list ])
    draw(PNG("$(store_dir)/graph$(lpad(string(iter),3,'0')).png"),
        graphp)
    run(`mogrify -format svg -gravity South -pointsize 15 -annotate 0
        "Iteration $(iter) "
        "$(store_dir)/graph"$(lpad(string(iter),3,'0')).png`)
end

function run_sim(n=20, p=0.2, make_anim=false, influencer=false, replacement=false)
    save_dir = pwd()
    graph = make_graph(n, p, make_anim, influencer, replacement)
    node_list = Array(vertices(graph))
    n = nv(graph)
    agent_list = []
    opin_list = (Red::Opinion, Blue::Opinion)
    for n in node_list
        this_opinion = rand(opin_list)
        push!(agent_list, Agent(this_opinion))
    end
    uniform = false
    iter = 1
    #println("Iterations:")
    percent_red_list = []
    use_node_list = copy(node_list)
    use_agent_list = copy(agent_list)

    while uniform == false
        num_red = find_num_red(agent_list)
        percent_red = num_red/n
        push!(percent_red_list, percent_red)

        if iter % 40 > 0
            #print(".")
        else
            #println(iter)
        end

        if make_anim
            make_graph_anim(graph, agent_list, iter)
        end

        uniform = true
        for i in 1:n-1
            if getOpinion(agent_list[i]) != getOpinion(agent_list[i+1])
                uniform = false
                break
            end
        end

        if influencer == false
            if replacement == false && length(use_node_list) == 0
                    use_node_list = copy(node_list)
                    use_agent_list = copy(agent_list)
            end
            set_influencer_opinion(graph, use_node_list, use_agent_list, replacement)
        else
            if replacement == false && length(use_node_list) == 0
                    use_node_list = copy(node_list)
                    use_agent_list = copy(agent_list)
            end
            set_influencee_opinion(graph, use_node_list, use_agent_list, replacement)
        end
        iter += 1
    end

    #println(iter)
    #display(plot(1:length(percent_red_list),percent_red_list, title="percent red opinion for each iteration", xlabel="number of iterations",ylabel="percent red opinion",seriescolor = :red))
    #savefig("per_red_plot.png")
    if make_anim
        #println("Building animation...")
        run(`convert -delay 15 graph*.svg graph.gif`)
        #println("...animation in $(tempdir())/graph.gif.")
    end

    # Return to user's original directory.
    cd(save_dir)
    return iter
end

function average_neighbors(graph)
    numNeighbors = 0
    for n in vertices(graph)
        numNeighbors += length(neighbors(n, graph))
    end
    return numNeighbors/length(vertices(graph))
end

function num_isolated(graph)
    numIsolated = 0
    for n in graph.vertices
        if(length(n.neighbors) == 0)
            numIsolated+=1
        end
    end
end

function param_sweep(num_runs=10, this_n=20, this_p=0.2, make_anim=false, influencer=false, replacement=false)
    n_list = []
    p_list = []
    n_steps_list = []
    p_steps_list = []
    #iterate through n, constant p
    for n in 10:10:100
        for x in 1:num_runs
            num_steps = run_sim(n, this_p, make_anim, influencer, replacement)
            push!(n_list, n)
            push!(n_steps_list, num_steps)
        end
    end
    #iterate through p, constant n
    for p in 0.1:0.1:1.0
        for x in 1:num_runs
            num_steps = run_sim(this_n, p, make_anim, influencer, replacement)
            push!(p_list, p)
            push!(p_steps_list, num_steps)
        end
    end
    #generate dataframe of n and steps
    n_data = DataFrame(N = n_list, STEPS = n_steps_list)
    showall(n_data)
    display(Plots.plot(n_list, n_steps_list, seriestype=:scatter, title= "number of nodes vs number of steps", xlabel="number of nodes", ylabel="number of steps", label="influencer = $(influencer), replacement = $(replacement)"))
    savefig("n_list_plot.png")
    #generate dataframe of p and steps
    p_data = DataFrame(P = p_list, STEPS = p_steps_list)
    showall(p_data)
    display(Plots.plot(p_list, p_steps_list, seriestype=:scatter, title= "probability of neighbor vs number of steps", xlabel="probability of neighbor", ylabel="number of steps", label="influencer = $(influencer), replacement = $(replacement)"))
    savefig("p_list_plot.png")
end

function conf_int_sweep(num_runs=10, this_n=20, make_anim=false, influencer=false, replacement=false)
    x_vals_list = []
    num_step_list = []
    mean_step_list = []
    min_step_list = []
    max_step_list = []
    n = this_n
    for p in 0.1:0.1:1.0
        for i in 1:num_runs
            num_steps = run_sim(this_n, p, make_anim, influencer, replacement)
            push!(num_step_list, num_steps)
        end
        bs = bootstrap(mean, num_step_list, BasicSampling(length(num_step_list)))
        c = confint(bs, BasicConfInt(0.95));[1]
        ci = c[1]
        m = ci[1]
        min = ci[2]
        max = ci[3]
        x = n*p
        push!(mean_step_list, m)
        push!(min_step_list, min)
        push!(max_step_list, max)
        push!(x_vals_list, x)
    end
    df = DataFrame(mean=mean_step_list, min=min_step_list, max=max_step_list, xval=x_vals_list)
    show(df, allrows=true, allcols=true)
    layers = Layer[]
    mean_layer = layer(df, x=:xval, y=:mean, Geom.line, Theme(default_color=colorant"red"))
    min_layer = layer(df, x=:xval, y=:min, Geom.line, Theme(default_color=colorant"pink"))
    max_layer = layer(df, x=:xval, y=:max, Geom.line, Theme(default_color=colorant"pink"))
    fill_layer = layer(df, x=:xval, ymin=:min, ymax=:max, Geom.ribbon, Theme(default_color=colorant"yellow"))
    append!(layers, mean_layer)
    append!(layers, min_layer)
    append!(layers, max_layer)
    append!(layers, fill_layer)
    p = Gadfly.plot(df, layers)
    draw(PNG("$(store_dir)/sweep$(this_n).png"), p)
end
