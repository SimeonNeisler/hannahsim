
module bvm

export run_sim, param_sweep, make_graph

import Cairo
using LightGraphs
using GraphPlot, Compose
using ColorSchemes, Colors
using Random
using Glob
using Plots
using DataFrames
using Bootstrap
using Gadfly
using Statistics


#file that makes an agent struct
include("agent.jl")
#file that saves your store_dir, see config-example.jl as a template
include("config.jl")
@enum Opinion Red Blue

"""
    function make_graph(n=20, p=0.2)

Create and return a random connected Erdos-Renyi graph with ``n`` nodes and
probability ``p`` that any two nodes are neighbors.
"""
function make_graph(n=20, p=0.2)
    # puts us in the dir that will save all files from this run, and remove any old files from previous runs
    cd("$(store_dir)")
    rm.(glob("graph*.png"))
    rm.(glob("graph*.svg"))
    #makes sure the random erdos renyi graph is connected
    graph = erdos_renyi(n,p)
    while is_connected(graph) == false
        graph = erdos_renyi(n,p)
    end

    return graph
end


"""
    function set_opinion(graph, node_list, agent_list, random_influencer::Bool, replacement::Bool)

Choose an agent at random from the environment, and change its (or one of its randomly chosen graph neighbor's) opinion to match the neighbor (or agent).

# Arguments

- `graph`, `node_list`, `agent_list`: the current state of the simulation, as embodied in the graph and agent states.

- `random_influencer`: if `true`, the randomly-chosen agent will influence (change the opinion of) its randomly-chosen graph neighbor. Otherwise, the neighbor will change it.

- `replacement`: if `true`, puts back the last randomly selected node in the list of next nodes that can be selected. If `false`, takes out the last randomly selected node from the list of next nodes that can be selected.
"""
function set_opinion(graph, node_list, agent_list, random_influencer::Bool,
    replacement::Bool)

    #picks a randomly selected node, and finds the corresponding agent
    this_node = rand(node_list)
    this_agent = agent_list[this_node]
    #picks a randomly selected neighbor of this node, and finds the corresponding agent
    neighbor_list = neighbors(graph, this_node)
    next_node = rand(neighbor_list)
    next_agent = agent_list[next_node]
    #sets the orginial node's opinion to the neighbor node's opinion
    if random_influencer
        next_opinion = getOpinions(this_agent)[1]
        setOpinion(next_agent, next_opinion, 1)
    else
        next_opinion = getOpinions(next_agent)[1]
        setOpinion(this_agent, next_opinion, 1)
    end
    if replacement==false
        #takes the last node that was selected out of the list of next nodes to be selected
        filter!(x -> x ≠ this_node, node_list)
    end
end




"""
    function run_sim(n=20, p=0.2, make_anim=false, influencer=false, replacement=false)

Run a single simulation of the Binary Voter Model on a randomly-generated
graph. Continue until convergence (uniformity of opinion) is reached.

# Arguments

- `n`, `p`: Parameters to the [Erdos-Renyi random graph model](https://en.wikipedia.org/wiki/Erd%C5%91s%E2%80%93R%C3%A9nyi_model) (`n` = number of nodes, `p` = probability of each pair of nodes being adjacent.)

- `make_anim`: if `true`, saves to `store_dir` an animated gif of the simulation.

- `influencer` if `true`, makes the randomly selected node change the opinion of its randomly selected neighbor. If `false`, makes its randomly selected neighbor change the opinion of the randomly selected node

- `replacement`: if `true`, puts back the last randomly selected node in the list of next nodes that can be selected. If `false`, takes out the last randomly selected node from the list of next nodes that can be selected.

# Returns
- the number of iterations until convergence in this simulation.
"""
function run_sim(;n=20, ;p=0.2, ;make_anim=false, ;influencer=false, ;replacement=false)
    save_dir = pwd()
    graph = make_graph(n, p)
    node_list = Array(vertices(graph))
    n = nv(graph)
    #makes a list of agents with randomly assigned opinions, each agent corresponds with a node
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

    #runs the sim until the all agents have one opinion
    while uniform == false
        #saves the percent of agents with red opinion for each iteration
        num_red = count_opinions(agent_list, Red)
        percent_red = num_red/n
        push!(percent_red_list, percent_red)
        #do you think we take this out?
        if iter % 40 > 0
            print(".")
        else
            println(iter)
        end

        if make_anim
            make_graph_anim(graph, agent_list, iter)
        end
        #checks to see if all agents have one opinion yet, if not continue sim
        uniform = true
        for i in 1:n-1
            if getOpinions(agent_list[i]) != getOpinions(agent_list[i+1])
                uniform = false
                break
            end
        end
        #changes the opinion of an agent based on the parameters
        if replacement == false && length(use_node_list) == 0
                use_node_list = copy(node_list)
                use_agent_list = copy(agent_list)
        end
        set_opinion(graph, use_node_list, use_agent_list, replacement, influencer)
        iter += 1
    end
    println(iter)
    #saves and shows a plot of the percent of agents with red opinion for each iteration
    display(Plots.plot(1:length(percent_red_list),percent_red_list, title="percent red opinion for each iteration", xlabel="number of iterations",ylabel="percent red opinion",seriescolor = :red))
    savefig("per_red_plot.png")
    if make_anim
        println("Building animation...")
        run(`convert -delay 15 graph*.svg graph.gif`)
        println("...animation in $(tempdir())/graph.gif.")
    end

    #return to user's original directory
    cd(save_dir)
    return iter
end


"""
    function param_sweep(num_trials=10, this_n=20, this_p=0.2, influencer=false, replacement=false)

Run two entire parameter sweeps of simulations, one for varying values of `n` (number of nodes in random graph) and the other for varying values of `p` (edge probability). Plot output will be created in the files `n_list_plot.png` and `p_list_plot.png` in the `store_dir` directory.

# Arguments

- `num_trials`: the number of trials for each fixed combination of parameters.

- `make_anim`: if `true`, saves to `store_dir` an animated gif of the simulation.

- `this_n`: value of `n` that will be constant as `p` is iterated.

- `this_p`: value of `p` that will be constant as `n` is iterated.

- `influencer`, `replacement`: passed to [`run_sim()`](@ref run_sim) (see notes there).

# Returns
- nothing
"""
function param_sweep(;num_trials=10, ;this_n=20, ;this_p=0.2, ;influencer=false, ;replacement=false)
    n_list = []
    p_list = []
    n_steps_list = []
    p_steps_list = []
    #iterate through n, constant p
    for n in 10:10:100
        #save the num of steps for that val of n for each sim
        for x in 1:num_trials
            num_steps = run_sim(n, this_p, false, influencer, replacement)
            push!(n_list, n)
            push!(n_steps_list, num_steps)
        end
    end
    #iterate through p, constant n
    for p in 0.1:0.1:1.0
        #save the num of steps for that val of p for each sim
        for x in 1:num_trials
            num_steps = run_sim(this_n, p, false, influencer, replacement)
            push!(p_list, p)
            push!(p_steps_list, num_steps)
        end
    end
    #generate dataframe and graph the plot of vals of n and num of steps
    n_data = DataFrame(N = n_list, STEPS = n_steps_list)
    showall(n_data)
    display(Plots.plot(n_list, n_steps_list, seriestype=:scatter, title= "number of nodes vs number of steps", xlabel="number of nodes", ylabel="number of steps", label="influencer = $(influencer), replacement = $(replacement)"))
    savefig("$(store_dir)/n_list_plot.png")
    #generate dataframe and graph the plot of vals of p and num of steps
    p_data = DataFrame(P = p_list, STEPS = p_steps_list)
    showall(p_data)
    display(Plots.plot(p_list, p_steps_list, seriestype=:scatter, title= "probability of neighbor vs number of steps", xlabel="probability of neighbor", ylabel="number of steps", label="influencer = $(influencer), replacement = $(replacement)"))
    savefig("$(store_dir)/p_list_plot.png")
end


#main - finds the num of steps for the graph to converge for different vals of lambda = n*p
#plots the num of steps to converge with a 95% confidence interval for each val of lambda
"""
    function conf_int_sweep(num_trials=10, n=20, influencer=false, replacement=false)

Run a suite of simulations for varying values of `p` (probability of edge in random graph), and plot λ (\$=N×p\$) vs. num-iterations-to-converge with a 95% confidence band. The plot will be stored in `sweep`_n_`.png` in the `store_dir`.

# Arguments

- `num_trials`: the number of trials for each value of `p` (and λ).

- `n`: the number of nodes in the random graph.

- `influencer`, `replacement`: passed to [`run_sim()`](@ref run_sim) (see notes there).

# Returns
- nothing
"""
function conf_int_sweep(;num_trials=10, ;n=20, ;influencer=false, ;replacement=false)
    x_vals_list = []
    num_step_list = []
    mean_step_list = []
    min_step_list = []
    max_step_list = []
    #iterate through p, constant n
    for p in 0.1:0.1:1.0
        #save the num of steps for that val of x = n*p for each sim
        for i in 1:num_trials
            num_steps = run_sim(n, p, false, influencer, replacement)
            push!(num_step_list, num_steps)
        end
        #finds the min, mean, and max of the confidence interval for that val of x
        bs = bootstrap(mean, num_step_list, BasicSampling(length(num_step_list)))
        c = confint(bs, BasicConfInt(0.95));[1]
        ci = c[1]
        m = ci[1]
        min = ci[2]
        max = ci[3]
        #lambda = n*p
        x = n*p
        #saves the x, min, mean, and max of that confidence interval to lists
        push!(mean_step_list, m)
        push!(min_step_list, min)
        push!(max_step_list, max)
        push!(x_vals_list, x)
    end
    #generates dataframe of the min, mean, and max of the confidence interval for each val of x
    df = DataFrame(mean=mean_step_list, min=min_step_list, max=max_step_list, xval=x_vals_list)
    show(df, allrows=true, allcols=true)
    layers = Layer[]
    #the colors of the layers aren't that bad but can we find some pretty colors?
    mean_layer = layer(df, x=:xval, y=:mean, Geom.line, Theme(default_color=colorant"red"))
    min_layer = layer(df, x=:xval, y=:min, Geom.line, Theme(default_color=colorant"pink"))
    max_layer = layer(df, x=:xval, y=:max, Geom.line, Theme(default_color=colorant"pink"))
    fill_layer = layer(df, x=:xval, ymin=:min, ymax=:max, Geom.ribbon, Theme(default_color=colorant"yellow"))
    append!(layers, mean_layer)
    append!(layers, min_layer)
    append!(layers, max_layer)
    append!(layers, fill_layer)
    #plots the num of steps for the graph to converge for different vals of lambda with the confidence interval
    #how can we add a legend that looks like influencer = $(influencer), replacement = $(replacement)?
    p = Gadfly.plot(df, layers, Guide.xlabel("Value of Lambda"), Guide.ylabel("Number of Iterations"), Guide.title("Iterations until Convergence by Lambda"))
    draw(PNG("$(store_dir)/sweep$(n).png"), p)
end

#
# Create one .png file for the current frame of the graph animation.
# FIX: remember_layout no longer being rememberd?
function draw_graph_frame(graph, agent_list, iter)
    locs_x, locs_y = spring_layout(graph)
    # remember and reuse graph layout for each animation frame
    remember_layout = x -> spring_layout(x, locs_x, locs_y)
    # plot this frame of animation to a file
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

"""
    function count_opinions(agent_list, o::Opinion, x::Int)

Return the number of agents who hold opinion `o`.

# Arguments

- `x`: FIX ??

"""
function count_opinions(agent_list, o::Opinion, x::Int=1)
    num_with_opinion = 0
    for a in agent_list
        if getOpinions(a)[x] == o
            num_with_opinion += 1
        end
    end
    return num_with_opinion
end



#############################################################################
##################### HF's new stuff for Jinn model #########################
#############################################################################


function new_run_sim(;n=20, ;p=0.2, ;num_opinions=2, ;make_anim=false, ;influencer=false,
    ;cog_rebalance=true, ;indirect_minority=true, ;direct_majority=true)
    save_dir = pwd()
    #none of the old nodes can be selected until all of the new nodes are selected because of cognitive rebalancing
    replacement=false
    graph = make_graph(n, p)
    node_list = Array(vertices(graph))
    n = nv(graph)
    #makes a list of agents with two randomly assigned opinions - each opinion can be red or blue
    agent_list = []
    opin_list = (Red::Opinion, Blue::Opinion)
    #are either opinion in each attribute as likely to happen as the other?
    for n in node_list
        this_agent = Agent()
        push!(agent_list, this_agent)
    end
    uniform = false
    iter = 1
    #println("Iterations:")
    #the percent of agents with the red opinion for attribute 1 and attribute 2
    percent_red_list_1 = []
    percent_red_list_2 = []
    use_node_list = copy(node_list)
    #the percent of agents that are interally consistent for each iteration
    percent_consistent_list = []
    percent_consistent_list_acr = []

    while uniform == false
        #saves the percent of agents with red opinion for attribute 1 and attribute 2 in each iteration
        num_red_1 = count_opinions(agent_list, Red, 1)
        percent_red_1 = num_red_1/n
        push!(percent_red_list_1, percent_red_1)
        num_red_2 = count_opinions(agent_list, Red, 2)
        percent_red_2 = num_red_2/n
        push!(percent_red_list_2, percent_red_2)
        push!(percent_consistent_list, sum(isConsistent(a) for a in agent_list)/length(agent_list))
        if iter % 40 > 0
            print(".")
        else
            println(iter)
        end

        if make_anim
            make_graph_anim(graph, agent_list, iter)
        end

        #checks to see if we should stop the sim
        uniform = reached_stopping_condition(agent_list, node_list, graph, iter)
        if uniform == true
            #println(percent_red_list_1)
            #println(percent_red_list_2)
        end
        #each agent does cognitive rebalancing when there are no new agents left
        if cog_rebalance==true && length(use_node_list) == 0
            #cognitive rebalance
            #println("cognitive rebalance!")
            for a in agent_list
                cognitive_rebalance(a)
            end
            use_node_list = copy(node_list)
        end
        push!(percent_consistent_list_acr, sum(isConsistent(a) for a in agent_list)/length(agent_list))
        #changes the opinion of an agent based on the parameters
        new_set_opinion(graph, use_node_list, agent_list, influencer, replacement, indirect_minority, direct majority)
        iter += 1
    end
    println(iter)
    #saves and shows a plot of the percent of agents with red opinion for each iteration
    display(Plots.plot(1:length(percent_red_list_1),percent_red_list_1, title="percent red opinion of attribute 1 for each iteration", xlabel="number of iterations",ylabel="percent red opinion",seriescolor = :red))
    savefig("per_red_1_plot.png")
    display(Plots.plot(1:length(percent_red_list_2),percent_red_list_2, title="percent red opinion of attribute 2 for each iteration", xlabel="number of iterations",ylabel="percent red opinion",seriescolor = :red))
    savefig("per_red_2_plot.png")
    display(Plots.plot(1:length(percent_consistent_list),percent_consistent_list, title="percent consistent agents for each iterations", xlabel="number of iterations",ylabel="percent consistent",seriescolor = :black))
    savefig("per_const_plot.png")
    display(Plots.plot(1:length(percent_consistent_list_acr),percent_consistent_list_acr, title="percent consistent agents for each iterations (ACR)", xlabel="number of iterations",ylabel="percent consistent",seriescolor = :black))
    savefig("per_const_plot_acr.png")
    if make_anim
        println("Building animation...")
        run(`convert -delay 15 graph*.svg graph.gif`)
        println("...animation in $(tempdir())/graph.gif.")
    end

    #return to user's original directory
    cd(save_dir)
    return iter
end

function new_set_opinion(graph, node_list, agent_list, random_influencer::Bool,
    replacement::Bool, indirect_minority::Bool, direct_majority::Bool)
    replacement = false
    #picks a randomly selected attribute
    this_attribute = rand([1,2])
    if this_attribute == 1
        other_attribute = 2
    else
        other_attribute = 1
    end
    #picks a randomly selected node, and finds the corresponding agent
    this_node = rand(node_list)
    this_agent = agent_list[this_node]
    #picks a randomly selected neighbor of this node, and finds the corresponding agent
    neighbor_list = neighbors(graph, this_node)
    next_node = rand(neighbor_list)
    next_agent = agent_list[next_node]
    #finds the original node's opinion of the chosen attribute
    this_opinion = getOpinions(this_agent)[this_attribute]
    #finds the neighbor node's opinion of the chosen attribute
    next_opinion = getOpinions(next_agent)[this_attribute]
    #checks if the two node's opinions of that attribute are different
    if this_opinion != next_opinion
        #checks if the majority of the node's neighbors has the opinion of the neighbor node
        num_neighbors_agree = 0
        for i in neighbor_list
            if getOpinions(agent_list[i])[this_attribute] == next_opinion
                num_neighbors_agree += 1
            end
        end
        #direct majority influence
        if direct_majority==true && num_neighbors_agree/length(neighbor_list) >= 0.5
            if random_influencer
                setOpinion(next_agent, this_opinion, this_attribute)
            else
                setOpinion(this_agent, next_opinion, this_attribute)
            end
        #indirect minority influence
        elseif indirect_minority==true
            #checks if the neighbor node has the same opinion for both of its attributes
            if getOpinions(next_agent)[this_attribute] == getOpinions(next_agent)[other_attribute]
                if random_influencer
                    setOpinion(next_agent, this_opinion, this_attribute)
                else
                    setOpinion(this_agent, next_opinion, this_attribute)
                end
            end
        end
    end

    #even if a node's opinion is not changed we still take it out of the list of next nodes
    if replacement==false
        #takes the last node that was selected out of the list of next nodes to be selected
        filter!(x -> x ≠ this_node, node_list)
    end
end

function cognitive_rebalance(this_agent)
    this_attribute = rand([1,2])
    if this_attribute == 1
        other_attribute = 2
    else
        other_attribute = 1
    end
    if getOpinions(this_agent)[this_attribute] != getOpinions(this_agent)[other_attribute]
        next_opinion = getOpinions(this_agent)[other_attribute]
        setOpinion(this_agent, next_opinion, this_attribute)
    end
end

function reached_stopping_condition(agent_list, node_list, graph, iter)
    uniform = true
    n = length(agent_list)
    for i in 1:n-1
        #checks to see if all agents have the same set of opinions
        if getOpinions(agent_list[i]) != getOpinions(agent_list[i+1])
            uniform = false
            break
        elseif iter == 10000
            uniform = false
            break
        #else - checks to see if the majority of the neighbors of each agent have the same opinions as that agent
        else
            num_neighbors_agree = 0
            for x in node_list
                neighbor_list = neighbors(graph, x)
                for y in neighbor_list
                    if getOpinions(agent_list[y])[1] == getOpinions(agent_list[x])[1] && getOpinions(agent_list[y])[2] == getOpinions(agent_list[x])[2]
                        num_neighbors_agree += 1
                    end
                end
                if num_neighbors_agree/length(neighbor_list) < 0.5
                    uniform = false
                    break
                end
            end
        end
    end
    return uniform
end


end # module bvm
