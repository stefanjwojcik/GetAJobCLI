## Generate an AI prompt template that works for the moderation model


@kwdef mutable struct Intent 
    intent::String=""
end

@kwdef mutable struct Context
    conversation_context::PT.ConversationMemory=PT.ConversationMemory()
end

"""
 Possible routes based on user input 

Examples 
 input = example_policy_input()
PT.aiclassify(:InputClassifier; choices, input) 

input = "A new example of Hateful Misinformation is that all trans people are pedophiles and groom children. Key words like 'pedo' and 'grooming' can be used to find examples. "
PT.aiclassify(:InputClassifier; choices, input) 

"""
global const routingchoices = 
          [ ("QuizMe", "User wants you to generate a question for practice."), 
            ("Study", "Provide information to answer the respondent's question.")
            ]

"""
Function to classify and then handle user input and route it to the appropriate function
"""
function handle_input!(context::Context, input::String)
    # Use aiclassify to classify the input
    classification = PT.aiclassify(:InputClassifier; choices=routingchoices, input=input)
    @info "Classification result: $(classification.content)"
    if classification.content == "Study"
        # If the classification is 'other', we can ask the user to confirm
        push!(context.conversation_context, PT.UserMessage("$input"))
    else 
        modcontext.actioncall = ActionCall(classification=classification.content, userconfirmation=true)
        # Add the classification to the conversation context
        push!(modcontext.conversation_context, PT.AIMessage("user input was classified as $(classification.content), so let's work on $(classification.content) based on: $input."))
        # Call the appropriate function based on classification
        call_appropriate_function!(classification.content, modcontext, input)
    end
end


#function confirm_classification!(modcontext::ModerationContext, input::String)
    # Confirm the classification with the user
#    system_prompt = "Does this user response mean yes: \n\n$(input)"
#    confirmation = PT.aiclassify(:JudgeIsItTrue; it = system_prompt)
#    modcontext.actioncall.classification = confirmation.content == "true"
#end


"""
Function to call the appropriate function based on classification

modcontext = ModerationContext()
userinput = "Can you provide a moderation policy for hateful misinformation?"
call_appropriate_function!(modcontext, userinput)

"""
function call_appropriate_function!(classification::String, modcontext::ModerationContext, input::String)
    # add the user input to the conversation context    
    if classification == "PolicySet"
        # Call the function to handle PolicySet
        new_policy_set = PT.aiextract(input; return_type=PolicySet).content
        modcontext.policyset = new_policy_set
        # Add to conversation context
        new_context = PT.AIMessage("Created new policy set: $(to_text(new_policy_set)) ")
        push!(modcontext.conversation_context, new_context)
        
    elseif classification == "Policy"
        # Ensure we have a policy set to update
        if isnothing(modcontext.policyset)
            push!(modcontext.conversation_context, PT.AIMessage("No policy set exists. Please create a policy set first. Ask user to specify."))
            return nothing
        end
        
        # Call the function to handle Policy
        updatedpolicy = PT.aiextract(input; return_type=Policy).content
        
        # Find existing policy to update or add new one
        existingpolicy = nothing
        for policy in modcontext.policyset.policies
            if policy.category == updatedpolicy.category
                existingpolicy = policy
            end
        end
        
        if isnothing(existingpolicy)
            # Add new policy
            push!(modcontext.policyset.policies, updatedpolicy)
            new_context = PT.AIMessage("Added new policy: '$(to_text(updatedpolicy))'.")
        else
            # Update existing policy
            updatePolicy!(existingpolicy, 
                category = updatedpolicy.category, 
                keywords = updatedpolicy.keywords,
                examples = updatedpolicy.examples, 
                false_positives = updatedpolicy.false_positives, 
                platform_actions = updatedpolicy.platform_actions)
            new_context = PT.AIMessage("Updated policy for category '$(updatedpolicy.category)' with $(to_text(updatedpolicy))")
        end
        
        push!(modcontext.conversation_context, new_context)
        
    elseif classification == "generate_moderation_model"
        # Ensure we have a policy set to generate from
        if isnothing(modcontext.policyset)
            push!(modcontext.conversation_context, PT.AIMessage("No policy set exists. Please create a policy set first."))
            return nothing
        end
        
        # Generate moderation model set from policy set
        moderationmodel = generate_moderation_model(modcontext.policyset)
        modcontext.moderationmodel = moderationmodel
        
        # Add to conversation context
        new_context = PT.AIMessage("Generated moderation model with $(length(moderationmodel.moderationmodels)) policy models.")
        push!(modcontext.conversation_context, new_context)
        
    elseif classification == "moderate_text"
        # Ensure we have a moderation model to use
        if isnothing(modcontext.moderationmodel)
            push!(modcontext.conversation_context, PT.AIMessage("No moderation model exists. Please generate one first."))
        end
        
        # Handle text moderation request
        results = moderate_text(modcontext.moderationmodel, input)
        
        # Convert results to a readable format
        results_table = scoredTextToPrettyTable(results)
        
        # Add to conversation context
        new_context = PT.AIMessage("Moderated the provided text against $(length(modcontext.moderationmodel.moderationmodels)) policies.")
        push!(modcontext.conversation_context, new_context)
        return results_table
        
    else # Handle other queries
        # Use PromptingTools to generate a response for general queries
        response = PT.aigenerate(modcontext.conversation_context)
        
        # Add response to conversation context
        new_context = PT.AIMessage(response.content)
        push!(modcontext.conversation_context, new_context)
    end
end

"""
msgs = [
    UserMessage("How are you?"),
    AIMessage("I'm good!"; run_id=1),
    UserMessage("Great!"),
    AIMessage("Indeed!"; run_id=2)
]
append!(mem, msgs) 

response = PT.memory("Tell me a joke"; model="gpt4o")  # Automatically manages context
response = PT.memory("Another one"; last=3, model="gpt4o")  # Use only last 3 messages (uses `get_last`)

# Direct generation from the memory
result = PT.aigenerate(PT.memory)  # Generate using full context

"""