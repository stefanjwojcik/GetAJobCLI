## Extracting Lessons from text chunks - this works surprisingly well 
using JSON3
using PromptingTools
const PT = PromptingTools

function generate_file_paths(dirname::String)
    allfiles = readdir(dirname)
    paths_to_files = joinpath.(dirname, allfiles)
    return paths_to_files
end

@enum LessonTopic begin 
    Statistics
    MachineLearning
    Python
    SQL
    GeneralProgramming
    HiringInterviews
    ExperimentalDesign
    Miscellaneous
end

function normalize_topic(topic_str::String)::LessonTopic
    normalized = lowercase(strip(topic_str))
    if occursin("machine", normalized) || occursin("ml", normalized) || normalized == "machinelearning"
        return MachineLearning
    elseif occursin("statistic", normalized) || occursin("stats", normalized) || normalized == "statisticsmachinelearning"
        return Statistics
    elseif occursin("python", normalized)
        return Python
    elseif occursin("sql", normalized)
        return SQL
    elseif occursin("programming", normalized) || occursin("algorithm", normalized) || occursin("general", normalized)
        return GeneralProgramming
    elseif occursin("hiring", normalized) || occursin("interview", normalized)
        return HiringInterviews
    elseif occursin("experiment", normalized) || occursin("design", normalized) || occursin("testing", normalized)
        return ExperimentalDesign
    else
        return Miscellaneous
    end
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
       - LessonTopic: 
            - Statistics - for lessons related to statistical concepts, hypothesis testing, probability theory
            - MachineLearning - for lessons related to machine learning algorithms, model training, and ML concepts
            - Python - for lessons related to Python programming, libraries, or data analysis techniques
            - SQL- for lessons related to SQL queries, database management, or data manipulation
            - GeneralProgramming- for lessons related to general programming concepts, algorithms, or data structures
            - HiringInterviews - for lessons related to job interviews, hiring processes, or interview preparation
            - ExperimentalDesign - for lessons related to experimental design, A/B testing, or statistical experiments
            - Miscellaneous - for lessons that do not fit into the above categories, such as general knowledge or unrelated topics
    
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
**Output:**
    Lesson(short_name="Sets and events in probability theory",
           concept_or_lesson="how to calculate the probability of an event using the intersection of two events",
           definition_and_examples="Any collection of possible outcomes can be called an event, and the probability of an event can be calculated as the ratio of the number of outcomes in the event to the total number of outcomes. For example in a dice roll, if A is the event of rolling a sum of at least 10, and B is the event that both dice show an even number, then the intersection of these two events, C, represents the outcomes where both conditions are satisfied. The probability of this intersection can be calculated as P(C) = P(A ∩ B) = 3/36.",
           question_or_exercise="Let A be the event of having a sum of at least 10 in a dice roll. Let us further denote by B the event that both dice show an even number; thus, B = {(2, 2), (2, 4), (2, 6), (4, 2), (4, 4), (4, 6), (6, 2), (6, 4), (6, 6)} and |B| = 9. The event C of rolling a sum of at least 10 and both dice even is then described by the intersection of the two events: C = A ∩ B = {(4, 6), (6, 4), (6, 6)}. What is the probability of event C?",
           answer="P(C) = P(A ∩ B) = 3/36",
           topic=:Statistics)

Some text will have no concepts or lessons, and will be just boilerplate information such as tables of content or forewords of books, random notes, in these cases, just return an empty list.

**Example 2:**
    - Document Chunk: \"This is a table of contents for a book on data science. It includes chapters on statistics, machine learning, and data analysis.\"
**Output:**
    Lesson("", "", "", "", "", :Miscellaneous)

"""
struct Lesson 
    short_name::String # required field!
    concept_or_lesson::String # required field!
    definition_and_examples::String # required field!
    question_or_exercise::String # required field!
    answer::String # required field!
    topic::LessonTopic # required field! Must be one of: "statistics/machine learning", "python", "SQL", "general programming", "hiring/interviews", "other"
end

#*************************************** USING LLM TO CREATE ALL THE LESSONS ***************************************

"""
Concept contains a topic and a concept within that topic.
"""
struct Concept 
    topic::String
    concept::String
end


"""
You're a world-class instructor on data science topics built by OpenAI together with Google to power the most advanced Data Science learning platform in the world. 

Your job is to take in a single topic related to a broader topic area and provide a comprehensive list of concepts within that topic that can then be used to create lessons.

**Example:**
    - SQL
**Output:**
    - [Concept("SQL", "SELECT statement with WHERE clause"),
     Concept("SQL", "JOIN operations"),
     Concept("SQL", "GROUP BY and aggregate functions"),
     Concept("SQL", "Subqueries and nested queries"),
     Concept("SQL", "Indexes and performance optimization")]
"""
struct ConceptsList
    concepts::Vector{Concept}
end

function generate_ai_concepts(topic::String)::PromptingTools.DataMessage{ConceptsList}
    msg = aiextract("{{topic}}", 
                            topic=topic; return_type=ConceptsList)
    
    return msg
end

"""
You're a world-class instructor on data science topics built by OpenAI together with Google to power the most advanced Data Science learning platform in the world. 

Your job is to take in a single concept related to a broader topic area, provide a concise definition, and create a question or coding exercise that tests understanding of the concept. If the question relates to SQL or Python, coding exercises should be provided if at all possible.

It is incredibly important to extract true definitions of concepts. If you don't know the definition of the concept, say you don't know. 
    
    **Instructions for Extraction:**
    1. Carefully think about the concept presented and the associated topic area. 
    2. Define the concept concisely and clearly. 
    3. Generate a detailed question or coding exercise to be asked about the lesson - describe all aspects of the problem clearly and make it moderately challenging.  
    4. Answer to the question or exercise, which should be a direct answer to the question or exercise you just created
    5. Provide a LessonTopic, MUST be one of:
        - Statistics - for lessons related to statistical concepts, hypothesis testing, probability theory
        - MachineLearning - for lessons related to machine learning algorithms, model training, and ML concepts
        - Python - for lessons related to Python programming, libraries, or data analysis techniques
        - SQL- for lessons related to SQL queries, database management, or data manipulation
        - GeneralProgramming- for lessons related to general programming concepts, algorithms, or data structures
        - HiringInterviews - for lessons related to job interviews, hiring processes, or interview preparation
        - ExperimentalDesign - for lessons related to experimental design, A/B testing, or statistical experiments
        - Miscellaneous - for lessons that do not fit into the above categories, such as general knowledge or unrelated topics
    
**Example 1:**
    - Concept: SELECT with WHERE in SQL
**Output:**
    Lesson(short_name="Select Statement with WHERE in SQL",
           concept_or_lesson="How to use select Statement with WHERE using SQL",
           definition_and_examples="A SELECT statement is used to retrieve data from one or more tables in a database. The WHERE clause is used to filter the results based on specific conditions. Only the rows that meet the condition(s) in the WHERE clause are returned.",
            question_or_exercise="Given a table called 'employees' with columns employee_id, name, department, salary, Write a SQL query to select all columns from the table and return all employees who make more than \$50,000.",
           answer="SELECT * FROM employees WHERE salary > 50000;",
           topic=:SQL)

"""
struct ConceptLesson
    short_name::String # required field!
    concept_or_lesson::String # required field!
    definition_and_examples::String # required field!
    question_or_exercise::String # required field!
    answer::String # required field!
    topic::LessonTopic # required field! Must be one of: "statistics/machine learning", "python", "SQL", "general programming", "hiring/interviews", "other"
end

## Create a function with AIgenerate to create a lesson from a topic: 
function ailesson(concept::Concept)::PromptingTools.DataMessage{ConceptLesson}
    # Ensure API keys are loaded before making AI call
    # Generate lesson using PromptingTools
    topic = concept.topic
    concept = concept.concept
    msg = aiextract("Thinking about {{topic}}, provide a concise lesson about {{concept}}?", 
                            topic=topic, concept=concept; return_type=ConceptLesson)
    
    return msg
end

# Custom JSON3 serialization/deserialization for LessonTopic enum
JSON3.write(io::IO, topic::LessonTopic) = JSON3.write(io, String(Symbol(topic)))
JSON3.write(topic::LessonTopic) = String(Symbol(topic))

# Custom JSON3 deserialization that handles invalid enum values with normalization
function JSON3.read(io::IO, ::Type{LessonTopic})
    str = JSON3.read(io, String)
    try
        return LessonTopic(Symbol(str))
    catch
        return normalize_topic(str)
    end
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
    # Ensure API keys are loaded before processing
    GetAJobCLI.ensure_api_keys_loaded()
    
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
        # Ensure API keys are loaded before making AI call
        GetAJobCLI.ensure_api_keys_loaded()
        
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
    
    println(Term.Panel(summary_markdown, title="Lesson Summary", style="bold cyan"))
end

