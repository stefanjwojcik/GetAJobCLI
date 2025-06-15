module GetAJobCLI

using Term
using ReplMaker
import PromptingTools as PT
using PromptingTools: aiclassify, aigenerate, aiextract
using JSON3
import RAGTools as RT
using CSV, DataFrames
using ProgressMeter

include("LessonsFromText.jl")
include("modes.jl")

export Lesson, 
       lessonfromchunks,
       display_lesson_summary, 
       generate_file_paths,
       interactive_lesson_quiz, 
       get_chunks, 
       load_sample_lessons, 
       list_topics, 
       show_lesson_by_topic,
       quiz_by_topic,
       show_quiz_help,
       show_learn_help,
       quiz_mode,
       learn_mode


# Configuration management
const CONFIG_DIR = joinpath(homedir(), ".getajobcli")
const CONFIG_FILE = joinpath(CONFIG_DIR, "config.json")

function ensure_config_dir()
    if !isdir(CONFIG_DIR)
        mkpath(CONFIG_DIR)
    end
end

function load_api_keys()
    ensure_config_dir()
    if !isfile(CONFIG_FILE)
        return Dict("openai_api_key" => nothing, "anthropic_api_key" => nothing)
    end
    
    try
        config_data = JSON3.read(read(CONFIG_FILE, String))
        return Dict(
            "openai_api_key" => get(config_data, :openai_api_key, nothing),
            "anthropic_api_key" => get(config_data, :anthropic_api_key, nothing)
        )
    catch e
        println("Warning: Could not load config file: $e")
        return Dict("openai_api_key" => nothing, "anthropic_api_key" => nothing)
    end
end

function save_api_keys(openai_key::Union{String,Nothing}, anthropic_key::Union{String,Nothing})
    ensure_config_dir()
    try
        config_data = Dict(
            :openai_api_key => openai_key,
            :anthropic_api_key => anthropic_key
        )
        write(CONFIG_FILE, JSON3.write(config_data))
        return true
    catch e
        println("Error: Could not save config file: $e")
        return false
    end
end

function check_and_warn_api_keys()
    keys = load_api_keys()
    
    openai_available = !isnothing(keys["openai_api_key"]) || haskey(ENV, "OPENAI_API_KEY")
    anthropic_available = !isnothing(keys["anthropic_api_key"]) || haskey(ENV, "ANTHROPIC_API_KEY")
    
    if !openai_available && !anthropic_available
        warning_text = """
⚠️  **No API Keys Detected**

You need to set up API keys to use the full functionality of this application.

**Available Providers:**
- OpenAI (for GPT models)
- Anthropic (for Claude models)

**Commands:**
- Type 'setup-keys' to configure your API keys
- Type 'check-keys' to see current key status

Some features may not work without proper API key configuration.
"""
        println(Term.Panel(warning_text, title="API Key Warning", style="bold yellow"))
        return false
    elseif !openai_available
        println(Term.Panel("📝 OpenAI API key not found. Type 'setup-keys' to configure.", title="Info", style="blue"))
    elseif !anthropic_available
        println(Term.Panel("📝 Anthropic API key not found. Type 'setup-keys' to configure.", title="Info", style="blue"))
    else
        println(Term.Panel("✅ API keys are configured and ready!", title="Status", style="bold green"))
    end
    
    # Set environment variables if keys are available
    if !isnothing(keys["openai_api_key"])
        ENV["OPENAI_API_KEY"] = keys["openai_api_key"]
    end
    if !isnothing(keys["anthropic_api_key"])
        ENV["ANTHROPIC_API_KEY"] = keys["anthropic_api_key"]
    end
    
    return true
end

function setup_api_keys()
    println(Term.Panel("""
# 🔑 API Key Setup

Configure your API keys for OpenAI and Anthropic services.

**Note:** Your keys will be saved locally and are not shared.
Press Enter to skip a provider if you don't want to configure it.
""", title="API Key Setup", style="bold cyan"))

    keys = load_api_keys()
    
    # OpenAI setup
    current_openai = keys["openai_api_key"]
    openai_status = isnothing(current_openai) ? "Not configured" : "Configured (hidden)"
    println("OpenAI API Key Status: $openai_status")
    print("Enter OpenAI API Key (or press Enter to skip): ")
    openai_input = strip(readline())
    
    if !isempty(openai_input)
        keys["openai_api_key"] = openai_input
        println("✅ OpenAI API key updated")
    end
    
    # Anthropic setup  
    current_anthropic = keys["anthropic_api_key"]
    anthropic_status = isnothing(current_anthropic) ? "Not configured" : "Configured (hidden)"
    println("Anthropic API Key Status: $anthropic_status")
    print("Enter Anthropic API Key (or press Enter to skip): ")
    anthropic_input = strip(readline())
    
    if !isempty(anthropic_input)
        keys["anthropic_api_key"] = anthropic_input
        println("✅ Anthropic API key updated")
    end
    
    # Save configuration
    if save_api_keys(keys["openai_api_key"], keys["anthropic_api_key"])
        println(Term.Panel("API keys saved successfully!", title="Success", style="bold green"))
        
        # Set environment variables
        if !isnothing(keys["openai_api_key"])
            ENV["OPENAI_API_KEY"] = keys["openai_api_key"]
        end
        if !isnothing(keys["anthropic_api_key"])
            ENV["ANTHROPIC_API_KEY"] = keys["anthropic_api_key"]
        end
    else
        println(Term.Panel("Failed to save API keys!", title="Error", style="bold red"))
    end
end

function check_api_keys_status()
    keys = load_api_keys()
    
    openai_status = if !isnothing(keys["openai_api_key"])
        "✅ Configured"
    elseif haskey(ENV, "OPENAI_API_KEY")
        "✅ Available in environment"
    else
        "❌ Not configured"
    end
    
    anthropic_status = if !isnothing(keys["anthropic_api_key"])
        "✅ Configured"
    elseif haskey(ENV, "ANTHROPIC_API_KEY")
        "✅ Available in environment"
    else
        "❌ Not configured"
    end
    
    status_text = """
**OpenAI:** $openai_status
**Anthropic:** $anthropic_status

Type 'setup-keys' to configure missing keys.
"""
    
    println(Term.Panel(status_text, title="API Key Status", style="bold blue"))
end

const LOGO = raw"""


____      _                 _       _     
/ ___| ___| |_    __ _      | | ___ | |__  
| |  _ / _ \ __|  / _` |  _  | |/ _ \| '_ \ 
| |_| |  __/ |_  | (_| | | |_| | (_) | |_) |
\____|\___|\__|  \__,_|  \___/ \___/|_.__/ 

          Get a Job
"""

function print_centered_logo()
    width = displaysize(stdout)[2]
    lines = split(LOGO, '\n')
    centered_lines = [
        lpad(line, div(width + length(line), 2)) for line in lines
    ]
    return centered_lines
end

const CENTERED_LOGO = print_centered_logo()


logo_and_info = join(CENTERED_LOGO, "\n") * "\n\n" * """
GET A JOB CLI

Natural language STUDY assistant

Type 'help' for available commands
Type 'exit' to quit
"""

logo_banner = Panel(
    logo_and_info,
    title="Welcome To",
    style="bold red",
    fit=true,
)


function render_welcome()
    # Print the logo and info
    println(logo_banner)
    println()
end


function show_help()
    help_text = """
**Main Commands:**
- **quiz** - Enter quiz mode for interactive learning
- **learn** - Enter learn mode to study lessons
- **setup-keys** - Configure OpenAI/Anthropic API keys
- **check-keys** - Check API key status
- **clear** - Clear the console
- **help** - Show this help message
- **exit/quit** - Exit the application

**Getting Started:**
1. Set up your API keys with 'setup-keys'
2. Try 'quiz' for interactive questions
3. Try 'learn' for study materials
"""
    
    println(Panel(help_text, title="Help", style="blue", fit=true))
end

function thinking_spinner(task::Function)
    # Unicode squares for rotation
    squares = ["■", "▣", "□", "▢"]
    # ANSI escape for blue
    blue = "\033[34m"
    reset = "\033[0m"
    msg = " thinking..."
    running = Ref(true)
    result = nothing

    spinner_task = @async begin
        i = 1
        while running[]
            print("\r$(blue)$(squares[i])$(reset)$msg")
            flush(stdout)
            sleep(0.15)
            i = i == length(squares) ? 1 : i + 1
        end
        # Clear the line after done
        print("\r" * " " ^ (length(msg) + 4) * "\r")
        flush(stdout)
    end

    try
        result = task()
    finally
        running[] = false
        wait(spinner_task)
    end
    return result
end

# Function to simulate streaming output
function stream_panel_update(title, style, stream_chunks)
    output = ""
    for chunk in stream_chunks
        output *= chunk
        # Move cursor up by the panel height (estimate or track lines)
        print("\033[2J\033[H")  # Clear screen and move cursor to top left
        println(Panel(output, title=title, style=style))
        flush(stdout)
        sleep(0.15)  # Simulate streaming delay
    end
end

function main()
    Term.Consoles.clear()
    render_welcome()
    
    # Check API keys on startup
    check_and_warn_api_keys()
    println()

    # Main command loop
    running = true
    while running
        print("\e[36mGetAJob> \e[0m")
        
        user_input = strip(readline())
        
        if isempty(user_input)
            continue
        elseif lowercase(user_input) in ["exit", "quit"]
            running = false
            continue
        elseif lowercase(user_input) == "help"
            show_help()
            continue
        elseif lowercase(user_input) == "clear"
            Term.Consoles.clear()
            render_welcome()
            continue
        elseif lowercase(user_input) == "setup-keys"
            setup_api_keys()
            continue
        elseif lowercase(user_input) == "check-keys"
            check_api_keys_status()
            continue
        elseif lowercase(user_input) == "quiz"
            quiz_mode()
            continue
        elseif lowercase(user_input) == "learn"
            learn_mode()
            continue
        else
            println("Unknown command. Type 'help' for available commands.")
        end
    end
    
    println(Panel("Thank you for using Get A Job CLI!", 
                 title="Goodbye", 
                 style="blue bold", 
                 fit=true))
end

# Launch UI
#main()

end
