## Extracting Lessons from text chunks - this works surprisingly well 

function generate_file_paths(dirname::String)
    allfiles = readdir(dirname)
    paths_to_files = joinpath.(dirname, allfiles)
    return paths_to_files
end

"""
You're a world-class data extraction engine built by OpenAI together with Google and to extract filter metadata to power the most advanced Data Science learning platform in the world. 

Extract concepts or lessons, definitions and examples, questions or exercises, and answers from the provided text. The extracted items should be relevant to Statistics, Machine Learning, or analyzing data with Python, SQL, or R.

It is incredibly important to extract useful concepts and lessons from the provided text - if something lacks context, or is not related to Statistics, Machine Learning, or analyzing data with Python, SQL, or R, it should not be extracted. You can fill in missing context with your own knowledge, but it must be relevant to the text provided and you must be absolutely certain in the accuracy of the information you provide.
    
    **Instructions for Extraction:**
    1. Carefully read through the provided Text
    2. Identify and extract:
       - One or two individual concepts or lessons contained in this text, such as how to calculate root mean squared error, the elements of xgboost learning, linear regression assumptions, or programming topics such as SQL windowing, etc.
       - Define the main concept or takeaway from the lesson and incorporate clear examples. Keep the definition concise and focused on the key points. Again, you can fill in missing context if the provided text is missing some details, but *only* if you are absolutely certain in the accuracy of the information you provide.
       - Identify a question or coding exercise that could be asked about the lesson - ensuring the anser is containd in the concept definition you just created
       - Answer to the question or exercise, which should be a direct answer to the question or exercise you just created
       - Give the lesson a short name
       - Topic MUST be one of: statistics/machine learning, python, SQL, general programming, hiring/interviews, or other
    
    **Example 1:**
    - Document Chunk: \"Any collection of possible outcomes X ⊆  is called an event; the previous
definition assigns a probability of P(X ) = |X |/|| to such an event. Events are sets
and we can apply the usual operations on them: Let A be as above the event of having
a sum of at least 10. Let us further denote by B the event that both dice show an
even number; thus, B = {(2, 2), (2, 4), (2, 6), (4, 2), (4, 4), (4, 6), (6, 2), (6, 4), (6, 6)}
and |B| = 9. The event C of rolling a sum of at least 10 and both dice even is then
described by the intersection of the two events:
 C = A ∩ B = {(4, 6), (6, 4), (6, 6)},
and has probability
 3
 P(C) = P(A ∩ B) = .
 36\"
    - Extracted items:
      - Short Name: Sets and events in probability theory
      - Concept or Lesson: how to calculate the probability of an event using the intersection of two events
      - Definition and Examples: Any collection of possible outcomes can be called an event, and the probability of an event can be calculated as the ratio of the number of outcomes in the event to the total number of outcomes. For example in a dice roll, if A is the event of rolling a sum of at least 10, and B is the event that both dice show an even number, then the intersection of these two events, C, represents the outcomes where both conditions are satisfied. The probability of this intersection can be calculated as P(C) = P(A ∩ B) = 3/36.
      - Question or Exercise: Let A be the event of having
    a sum of at least 10 in a dice roll. Let us further denote by B the event that both dice show an even number; thus, B = {(2, 2), (2, 4), (2, 6), (4, 2), (4, 4), (4, 6), (6, 2), (6, 4), (6, 6)} and |B| = 9. The event C of rolling a sum of at least 10 and both dice even is then
    described by the intersection of the two events:
    C = A ∩ B = {(4, 6), (6, 4), (6, 6)}. What is the probability of event C?
      - Answer: P(C) = P(A ∩ B) = 3/36
      - Topic: statistics/machine learning

Some text will have no concepts or lessons, and will be just boilerplate information such as tables of content or forewords of books, random notes, in these cases, just return an empty list.

"""
struct Lesson 
    short_name::String # required field!
    concept_or_lesson::String # required field!
    definition_and_examples::String # required field!
    question_or_exercise::String # required field!
    answer::String # required field!
    topic::String # required field! Must be one of: "statistics/machine learning", "python", "SQL", "general programming", "hiring/interviews", "other"
end

"""
## Select some resources to index in a RAG system 
    filespaths = generate_file_paths("clean_txt")
chunks = get_chunks(RT.FileChunker(), filespaths[1:2]; 
    sources = filespaths[1:2], 
    verbose = true, 
    separators = ["\n\n", ". ", "\n", " "], 
    max_length = 1000)
lessons = lessonfromchunks(chunks; limit=1)

"""
function lessonfromchunks(chunks::Tuple{Vector{SubString{String}}, Vector{String}}; limit=5)::Vector{Lesson}
    lessons = Lesson[]
    counter = 0
    @showprogress for text in chunks[1]
        msg = aiextract(text; return_type=Lesson)
        if !isnothing(msg.content)
            push!(lessons, msg.content)
        end
        counter += 1
        if limit != -1 && counter >= limit
            break
        end
    end
    return lessons
end

"""
Interactive function that displays a lesson question and checks user's answer using PT.aiclassify classification.
Returns true if answer is correct, false otherwise.
"""
function interactive_lesson_quiz(lesson::Lesson)::Bool
    lesson_markdown = """
# 📚 $(lesson.short_name)

## 📖 Concept
$(lesson.concept_or_lesson)

## 📝 Definition & Examples
$(lesson.definition_and_examples)

## ❓ Question
$(lesson.question_or_exercise)
"""
    
    println(Term.Panel(lesson_markdown, title="Lesson Quiz", style="bold blue"))
    println()
    
    print("Your answer: ")
    user_answer = readline()
    
    if isempty(strip(user_answer))
        error_markdown = """
❌ **Wow, you didn't provide an answer, let's try harder next time.**

💡 **Correct Answer:** $(lesson.answer)
"""
        println(Term.Panel(Term.parse_md(error_markdown), title="Result", style="bold red"))
        return false
    end
    
    choices = [("correct", "The user's answer demonstrates understanding of the core concepts and is substantially correct"), 
               ("incorrect", "The user's answer is wrong or shows lack of understanding of the key concepts")]
    
    classification_input = """
Question: $(lesson.question_or_exercise)

Expected Answer: $(lesson.answer)

User's Answer: $(user_answer)

Evaluate if the user's answer demonstrates understanding of the core concepts, even if not perfectly worded.
"""
    
    try
        result = PT.aiclassify(:InputClassifier; choices=choices, input=classification_input)
        is_correct = result.content == "correct"
        
        if is_correct
            result_markdown = """
✅ **CORRECT!** Well done!

Your understanding of the concept is on track.
"""
            println(Term.Panel(result_markdown, title="Result", style="bold green"))
        else
            result_markdown = """
❌ **Hmm, Not Quite.**

💡 **Correct Answer:** $(lesson.answer)

Keep studying - you'll get it next time!
"""
            println(Term.Panel(Term.parse_md(result_markdown), title="Result", style="bold red"))
        end
        
        return is_correct
    catch e
        error_markdown = """
⚠️ **Error classifying answer:** $e

💡 **Correct Answer:** $(lesson.answer)
"""
        println(Term.Panel(error_markdown, title="Error", style="bold yellow"))
        return false
    end
end

"""
Display a lesson object in attractive markdown format for quick concept review.
"""
function display_lesson_summary(lesson::Lesson)
    summary_markdown = """
# 🎯 $(lesson.short_name)

## Key Concept
$(lesson.concept_or_lesson)

## Definition & Examples
$(lesson.definition_and_examples)

## Practice Question
*$(lesson.question_or_exercise)*

## Answer
**$(lesson.answer)**
"""
    
    println(Term.Panel(Term.parse_md(summary_markdown), title="Lesson Summary", style="bold cyan"))
end

