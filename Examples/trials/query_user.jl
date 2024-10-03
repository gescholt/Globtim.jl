using REPL
using REPL.TerminalMenus

function input(prompt::AbstractString="")::String
    print(prompt)
    return chomp(readline())
end

function prompt_yes_no(prompt::AbstractString)::Bool
    menu = REPL.TerminalMenus.RadioMenu(["yes", "no"])
    println(prompt)
    choice = REPL.TerminalMenus.request(menu)
    return choice == 1
end

function check_parameter(value, threshold; prompt=true)
    if value > threshold && prompt
        while true
            if prompt_yes_no("Are you sure you want to proceed? (use arrow keys to select) ")
                return true
            else
                return false
            end
        end
    else
        return true
    end
end

function main_function(value, threshold)
    if !check_parameter(value, threshold)
        println("Operation aborted.")
        return
    end

    # Proceed with the rest of the function
    println("Proceeding with the main function.")
    # Your main function logic here
end

# Example usage
main_function(15, 10)