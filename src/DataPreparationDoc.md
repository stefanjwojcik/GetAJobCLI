# Data Preparation 


## Run a bash script to convert all files in a directory to text files
```bash 
./convert_all_files_to_txt.sh resources/Data Science Interview Resources
```

## Now open Julia, and use PromptingTools to classify the files as: 
```julia
import PromptingTools as PT 
# Load all file names 
files = readdir("all_txt")
sysprompt = """
You are a world-class AI tutor for Data Science, Statistics, and Machine Learning. 
"""

context = PT.SystemMessage(sysprompt)

"""
 Possible classifications of each file

Examples 
 input = "pandas_cheat_sheet.txt"
PT.aiclassify(:InputClassifier; resourcetypes, input) 

input = "A new example of Hateful Misinformation is that all trans people are pedophiles and groom children. Key words like 'pedo' and 'grooming' can be used to find examples. "
PT.aiclassify(:InputClassifier; choices, input) 

"""
global const resourcetypes = 
        [ ("TeachingResource", " Teaches core Statistics, Data Science, or Machine Learning concepts - not including a specific programming language."), 
            ("ProgrammingLanguageResource", "teaches a concept or idea but within the scope of a specific programming language, such as Python, SQL, R, or Julia."), 
            ("QuestionSet", "a set of questions around a specific topic, such as a Data Science interview question set."), 
            ("InterviewResource", "a resource that provides insight into tech screens or specific interview instances at specific companies."), 
            ("Other", "any other resource that does not fit into the above categories.")
            ]

"", "", "", "", "Other"
"""
Function to extract the core concept being described by a chunk of text, along with examples.

Example: "Pandas Cheat Sheet: Method Chaining
Most pandas methods return a DataFrame so that
another pandas method can be applied to the result.
This improves readability of code.
df = (pd.melt(df)
.rename(columns={
'variable':'var',
'value':'val'})
.query('val >= 200')
)." 
 -> Concept(name="Method Chaining in Pandas", 
        description="Method chaining is a programming style for Pandas where multiple methods are called on an object in a single expression, allowing for more readable and concise code.", 
        source="PandasCheatSheet"
        code = """
                df = (pd.melt(df)
                    .rename(columns={
                    'variable':'var',
                    'value':'val'})
                    .query('val >= 200')
                    )"""
        )

"""
@kwdef mutable struct Concept 
    name::String 
    description_or_definition::String=""
    source::String=""
    codeexample::String=""
end 

## For each file, classify it and extract the core concept
filenames_to_classify = readdir("all_txt")
for filename in filenames_to_classify
    # Classify the file
    classification = PT.aiclassify(filename; choices=["TeachingResource", "ProgrammingLanguageResource", "QuestionSet", "InterviewResource", "Other"], 
                                    context=context, 
                                    model="gpt-4-1106-preview", 
                                    temperature=0.0, 
                                    max_tokens=100)
    
    # Store the classification
    if classification == "TeachingResource"
        push!(TeachingResource, filename)
    elseif classification == "ProgrammingLanguageResource"
        push!(ProgrammingLanguageResource, filename)
    elseif classification == "QuestionSet"
        push!(QuestionSet, filename)
    elseif classification == "InterviewResource"
        push!(InterviewResource, filename)
    else
        push!(Other, filename)
    end
end

```