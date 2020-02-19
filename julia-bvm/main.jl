using LightGraphs
using GraphPlot, Compose
using ColorSchemes, Colors
using Random
using Cairo, Fontconfig
using Glob
using Plots
using DataFrames

include("agent.jl")
include("config.jl")
@enum Opinion Red Blue
function make_graph(n=20, p=0.2, make_anim=false, influencer=false, replacement=false)

    # Set seed for consistency.
    #Random.seed!(12345)

    # Put us in a temp dir, and remove any old files from previous runs.
    #save_dir = pwd()
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
    return numNeighbors/length(vertices(graph))
        

end

function num_isolated(graph)
    numIsolated = 0
    for n in graph.vertices
        if(length(n.neighbors) == 0)
            numIsolated+=1
    
end

function param_sweep(num_runs=10, make_anim=false, influencer=false, replacement=false)
    n_list = []
    p_list = []
    avg_steps_list = []
    for n in 10:10:100
        for p in 0.1:0.1:1.0
            push!(n_list, n)
            push!(p_list, p)
            count_steps = 0
            for x in 1:num_runs
                count_steps += run_sim(n, p, make_anim, influencer, replacement)
            end
            avg_steps = count_steps/num_runs
            push!(avg_steps_list, avg_steps)

        end

    end
    df = DataFrame(N = n_list, P = p_list, STEPS = avg_steps_list)
    showall(df)
    display(plot(n_list, avg_steps_list, title= "number of nodes vs average number of steps", xlabel="number of nodes", ylabel="number of steps"))
    savefig("n_list_plot.png")
    display(plot(p_list, avg_steps_list, title= "probability of neighbor vs average number of steps", xlabel="probability of neighbor", ylabel="number of steps"))
    savefig("p_list_plot.png")
end