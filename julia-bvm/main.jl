using LightGraphs
using GraphPlot, Compose
using ColorSchemes, Colors
using Random
using Cairo, Fontconfig
using Glob
using Plots

include("agent.jl")
store_dir = "/Users/hannahfrederick/Downloads"

@enum Opinion Red Blue
function make_graph(make_anim=false)

    # Set seed for consistency.
    Random.seed!(12345)

    # Put us in a temp dir, and remove any old files from previous runs.
    save_dir = pwd()
    cd("$(store_dir)")
    rm.(glob("graph*.png"))
    rm.(glob("graph*.svg"))

    n = 20
    p = 0.2
    graph = erdos_renyi(n,p)
    while is_connected(graph) == false
        graph = erdos_renyi(n,p)
    end

    # Plot initial graph layout, and remember coordinates.
    if make_anim
        locs_x, locs_y = spring_layout(graph)
    end

    node_list = vertices(graph)
    agent_list = []
    opin_list = (Red::Opinion, Blue::Opinion)
    for n in node_list
        this_opinion = rand(opin_list)
        push!(agent_list, Agent(this_opinion))
    end
    percent_red_list = []
    uniform = false
    iter = 1
    println("Iterations:")

    while uniform == false
        num_red = 0
        for a in agent_list
            if getOpinion(a) == Red
                num_red += 1
            end
        end
        percent_red = num_red/n
        push!(percent_red_list, percent_red)

        if iter % 40 > 0
            print(".")
        else
            println(iter)
        end

        if make_anim
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

        uniform = true
        for i in 1:n-1
            if getOpinion(agent_list[i]) != getOpinion(agent_list[i+1])
                uniform = false
                break
            end
        end
        this_node = rand(node_list)
        this_agent = agent_list[this_node]
        neighbor_list = neighbors(graph, this_node)
        next_node = rand(neighbor_list)
        next_agent = agent_list[next_node]
        next_opinion = getOpinion(next_agent)
        setOpinion(this_agent, next_opinion)
        iter += 1
    end

    println(iter)
    display(plot(1:length(percent_red_list),percent_red_list, title="percent red opinion for each iteration", xlabel="number of iterations",ylabel="percent red opinion",seriescolor = :red))
    savefig("per_red_plot.png")
    if make_anim
        println("Building animation...")
        run(`convert -delay 15 graph*.svg graph.gif`)
        println("...animation in $(tempdir())/graph.gif.")
    end

    # Return to user's original directory.
    cd(save_dir)
end
