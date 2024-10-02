function gcm
    # from - https://gist.github.com/knyazer/675e6eb945ae5ec64af2f9be4826b07e
    # which is based on: https://gist.github.com/karpathy/1dd0294ef9567971c1e4348a90d69285
    # Check if llm is installed, if not, install it
    if not type -q llm
        echo "'llm' is not installed. Attempting to install it using pip..."
        if pip install llm
            echo "'llm' installed successfully."
        else
            echo "Failed to install 'llm'. Please install it manually and try again."
            return 1
        end
    end

    # Check if an API key is set up for llm
    set llm_keys (llm keys)
    if test "$llm_keys" = "No keys found"
        echo "No API key found for 'llm'. You need to set it up."
        llm keys set openai
        if test $status -ne 0
            echo "Failed to set up the OpenAI key. Please try again manually."
            return 1
        else
            echo "OpenAI key set successfully."
        end
    end

    # Function to generate commit message
    function generate_commit_message
        set -l prompt_text "Here are some examples of good commit messages:
- tests: correct TPU large array indexing tests
- feat: add overloads to eqx.combine
- docs: improve training loop documentation
- refactor: remove deprecated calls to jax.DeviceArray
- docs: explain why we do direct dtype conversion in precompute_freqs
- perf: donate tensors to increase memory utilization
- ci: switch from unittest to pytest
- tests: add double precision test for Adam
- build: allow cargo multithreading
- style: shorter conditions for key handling
- feat: partial weight decay only for weights
- refactor: improve control flow in some_model_function
- wip: debugging the flash attention with float16
- style: fix the type annotations
- tests: add parametrized testing for the collision logic

Below is a diff of all changes coming from ```git diff HEAD```. Do NOT use quotes in your answer. Generate a concise, one-line, single sentence, at most 7 words long, summary commit message for these changes. End it with a new line, not a period. Feel free to provide a few-sentence explanation after a new line, so that it will be included as a commit description, but be as concise as possible! If it is taking more than 20 words, you are doing something wrong.
Prepend your answer with either of feat, fix, refactor, style, ci, docs, build, tests, perf, or wip, following the commitizen convention. The most important part to get right is the type of the commit, so make try as hard as possible to get it right!
Be specific, and make sure to mention only meaningful changes. Do not use generic terms, talk only about things that happened in the code.
\n\n"

        # Check if --retry argument is present and get the index
        set retry_index (contains --index -- '--retry' $argv)

        if set -q $retry_index
            set -l last_message $argv[$retry_index + 1]
            echo "Previous message: $last_message" # For debugging purposes
            set -l prompt_text "$prompt_text

The previous commit message generated was:
\`\`\`
$last_message
\`\`\`
It was not satisfactory. Below is the diff again. Please generate a better commit message.

Your answer must adhere to the commitizen convention."
        end

        git diff HEAD | llm $prompt_text
    end

    # Function to read user input
    function read_input
        set -l prompt $argv[1]
        read -P $prompt reply
        echo $reply
    end

    # Main script
    if contains -- -a $argv
        set files (git diff HEAD --name-only)
    else
        set files (git diff --cached --name-only)
        echo "Generating AI-powered commit message for staged files:"
    end

    echo $files
    set commit_message (generate_commit_message $argv --retry "")

    while true
        echo -e "Proposed commit message:\n"
        echo $commit_message
        echo -e ""

        set choice (read_input "Do you want to (a)ccept or (r)egenerate? ")

        set short_message (string split -m 1 "\n" $commit_message)[1]
        set description (string split -m 1 "\n" $commit_message)[2]

        if test -z "$description"
            set description ""
        end

        switch $choice
            case a A ''
                if git commit $argv -m "$short_message" -m "$description"
                    echo "Changes committed successfully!"
                    return 0
                else
                    echo "Commit failed. Please check your changes and try again."
                    return 1
                end
            case r R
                echo "Regenerating commit message..."
                set commit_message (generate_commit_message $argv --retry $commit_message)
            case c C q Q
                echo "Commit cancelled."
                return 1
            case '*'
                echo "Invalid choice. Please try again."
        end
    end
end
