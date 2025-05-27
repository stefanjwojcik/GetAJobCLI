#module GetAJobCLI

using Term
using ReplMaker
import PromptingTools as PT


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
    Available commands:
    
    - try again: Try the last command again
    - clear: Clear the console
    - help: Show this help message
    - exit/quit: Exit the application
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
    Term.Consoles.clear()  # <-- Use the correct clear function
    # Banner
    render_welcome()

    # initiate context 
    #modcontext = ModerationContext()
    # Set up an initial system message 
    system_message = PT.SystemMessage("You are a helpful assistant that helps users to get a job in Data Science. 
    
    You are a friendly assistant that helps users to get a job in Data Science.

    You know Python, R, SQL, Julia, and other programming languages.

    You primarily do two things: provide study briefs and quiz exercises.

    ")
    push!(modcontext.conversation_context, system_message)


    # Prompt
    running = true
    while running
        print("\e[36mOstreaCultura> \e[0m")
        
        user_input = readline()
        
        if isempty(user_input)
            continue
        elseif lowercase(user_input) in ["exit", "quit"]
            running = false
            continue
        elseif lowercase(user_input) == "help"
            push!(modcontext.conversation_context, PT.AIMessage("User asked for help"))
            show_help()
            continue
        elseif lowercase(user_input) == "example"
            example_policy_raw = example_policy_input()
            println(Panel("$example_policy_raw", title="Here is an example policy:", style="bold red"))
            user_input = "My policy is: $example_policy_raw"
        elseif lowercase(user_input) == "clear"
            Term.Consoles.clear()
            render_welcome()
            continue
        end

        # Render result in a debug‐friendly box
        println()
        ai_result = thinking_spinner() do
            # Simulate AI call (replace with actual AI call)
            #sleep(2)  # <-- Remove this and call your AI here
            handle_input!(modcontext, user_input)
            #push!(modcontext.conversation_context, PT.UserMessage(user_input))
            msg = PT.aigenerate(modcontext.conversation_context)
            return "$(msg.content)"
        end
        println(Panel("$ai_result", title="AI Response", style="bold blue"))
        println()

    end
    
    println(Panel("Thank you for using OSTREA CULTURA!", 
                 title="Goodbye", 
                 style="blue bold", 
                 fit=true))

    # Send through AI
    #ai_result = ai"$user_input"
end

# Launch UI
#main()

#end
