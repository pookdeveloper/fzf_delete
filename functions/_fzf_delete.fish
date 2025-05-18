# Function to interactively delete files and directories

# name = "fzf_delete"
# version = "1.0.0"
# description = "Interactive delete function for Fish shell using fzf."
# author = "Your Name <pookdeveloper@email.com>"
# license = "MIT"

# Usage: fzf_delete [options]
#   - No parameters: shows all (except hidden)
#   'f': only files
#   'd': only directories
#   'h': include hidden

#
# Examples:
#   fzf_delete           # Shows files and directories (excluding hidden)
#   fzf_delete d h       # Shows only directories (including hidden)
#   fzf_delete f h       # Shows only files (including hidden)
#   fzf_delete a h       # Shows files and directories (including hidden)

#
# This function shows a numbered list of items in the current directory
# according to the specified criteria, allows selecting multiple items interactively
# and deletes them after confirmation.
function fzf_delete --description "Interactively delete files and directories"
    # Define acceptable arguments for argparse
    set -l type "a" # Default to 'a' (all)
    set -l duplicate false
    set -l show_hidden false
    set -l pattern ""
    set -l exclude ""
    set -l older_than ""
    set -l help false

    set -l idx 1
    while test $idx -le (count $argv)
        set -l arg $argv[$idx]
        switch $arg
        case -h --help
            set help true
        case a
            set type "a"
        case d
            set type "d"
        case --hidden
            set show_hidden true
        case --pattern
            set pattern $argv[(math $idx + 1)]
            set idx (math $idx + 1)
        case --exclude
            set exclude $argv[(math $idx + 1)]
            set idx (math $idx + 1)
        case --older-than
            set older_than $argv[(math $idx + 1)]
            set idx (math $idx + 1)
        case '*'
            echo "Unknown argument: $arg"
            return 0
        end
        set idx (math $idx + 1)
    end

    # print parsed arguments for debugging
#     echo "Parsed arguments:"
#     echo "  - Hidden: $show_hidden"
#     echo "  - Type: $type"
#     echo "  - Pattern: $pattern"
#     echo "  - Exclude: $exclude"
#     echo "  - Older than: $older_than"
    # Check for required dependencies

    # Show help if requested or no arguments provided
    if $help
        echo "Usage: fzf_delete [options]"
        echo "  - No parameters: shows all (except hidden)"
        echo "  - -f: only files"
        echo "  - -d: only directories"
        echo "  - -a: all files and directories (default)"
        echo "  - -h: include hidden files and directories"
        echo "  - --pattern <regex>: filter items by regex pattern (applied to full path)"
        echo "  - --exclude <regex>: exclude items matching regex pattern (applied to full path)"
        echo "  - --older-than <duration>: filter items older than duration (e.g., 7d, 3w, 1y)"
        echo ""
        echo "Examples:"
        echo "  fzf_delete           # Shows files and directories (excluding hidden)"
        echo "  fzf_delete -d -h     # Shows only directories (including hidden)"
        echo "  fzf_delete -f --pattern '.*\\.log\$' # Shows only files ending in .log"
        echo "  fzf_delete --older-than 30d --exclude 'backup' # Shows items older than 30 days, excluding paths containing 'backup'"
        return 0
    end

    # Execute the standard deletion logic with parsed options
    _fzf_delete_items $type $show_hidden $pattern $exclude $older_than
    return $status
end

# Helper function to build the find command based on criteria
# Arguments: 1: type, 2: show_hidden (bool), 3: pattern (regex), 4: exclude (regex), 5: older_than (duration string)
function build_find_cmd --description "Builds a find command string"
    set -l type $argv[1]
    set -l show_hidden $argv[2]
    set -l pattern $argv[3]
    set -l exclude $argv[4]
    set -l older_than $argv[5]

    set find_cmd "find ." # Start in the current directory

    # Handle hidden files/dirs - test the boolean variable directly
    if not $show_hidden
        set find_cmd "$find_cmd -not -path '*/\.*'"
    end

    # Handle type filtering
    switch "$type"
        case "f"
            set find_cmd "$find_cmd -type f"
        case "d"
            set find_cmd "$find_cmd -type d"
        case "a"
            # No specific type filter needed for 'a'
    end

    # Handle older-than filter
    if test -n "$older_than"
        # Parse duration: expect format like 7d, 3w, 1y
        set duration_value (echo "$older_than" | sed 's/[a-zA-Z]*//g')
        set duration_unit (echo "$older_than" | sed 's/[0-9]*//g')

        # Basic validation
        if not string match -q --regex '^[0-9]+$' "$duration_value"
             echo "Error: Invalid number in duration format for --older-than: '$older_than'." >&2
             return 1
        end

        set time_arg ""
        switch "$duration_unit"
            case "d"
                 # -mtime +N means modification time > N*24 hours ago
                 set find_cmd "$find_cmd -mtime +$duration_value"
            case "w"
                 set find_cmd "$find_cmd -mtime +(math $duration_value * 7)"
            case "m"
                 # Approximate month as 30 days
                 set find_cmd "$find_cmd -mtime +(math $duration_value * 30)"
            case "y"
                 # Approximate year as 365 days
                 set find_cmd "$find_cmd -mtime +(math $duration_value * 365)"
            case "*"
                echo "Error: Invalid duration unit in format for --older-than: '$older_than'. Use d, w, m, or y." >&2
                return 1
        end
    end

    # Pattern and exclude are handled after find, so they are not added to the find command here.

    # Add option to print the full path relative to '.'
    set find_cmd "$find_cmd -print"

    # Return the constructed command string
    echo "$find_cmd"
end

# Helper function to handle standard file/directory deletion
# Arguments: 1: type, 2: show_hidden (bool), 3: pattern (regex), 4: exclude (regex), 5: older_than (duration string)
function _fzf_delete_items --description "Interactively delete files or directories based on criteria"
    set -l type $argv[1]
    set -l show_hidden $argv[2]
    set -l pattern $argv[3]
    set -l exclude $argv[4]
    set -l older_than $argv[5]

    # Check for required dependencies
    set missing_deps
    if not type -q fzf; set -a missing_deps fzf; end
    if test (count $missing_deps) -gt 0
        echo "Error: The following dependencies are required but not installed: (string join ', ' $missing_deps)" >&2
        echo "Please install them and try again." >&2
        return 1
    end

    # Build the base find command
    set find_cmd (build_find_cmd $type $show_hidden $pattern $exclude $older_than)
    if test $status -ne 0; return 1; end # Exit if build_find_cmd failed (e.g., invalid duration)

    # Get the list of items using find
    set item_list (eval $find_cmd)

    # Apply pattern and exclude filters using grep
    if test -n "$pattern"
         # Use grep -E for extended regex
         set item_list (printf "%s\n" $item_list | grep -E "$pattern")
    end

    if test -n "$exclude"
        # Use grep -E for extended regex and -v to invert match (exclude)
        set item_list (printf "%s\n" $item_list | grep -E -v "$exclude")
    end

    # Filter out the current directory '.' if it's still in the list and not explicitly requested
    set filtered_list
    for item in $item_list
        if test "$item" != "."
            set -a filtered_list $item
        end
    end
    set item_list $filtered_list

    set item_type "items"
    switch "$type"
        case "f"; set item_type "files";
        case "d"; set item_type "directories";
    end
    if $show_hidden; set item_type "$item_type (including hidden)"; end # Test boolean directly
    if test -n "$pattern"; set item_type "$item_type matching '$pattern'"; end
    if test -n "$exclude"; set item_type "$item_type excluding '$exclude'"; end
    if test -n "$older_than"; set item_type "$item_type older than '$older_than'"; end

    # Check if there are items after filtering
    if test (count $item_list) -eq 0
        echo "No $item_type in the current directory match the criteria." >&2
        return 1
    end

    # Show available items and allow selection with fzf
    set selected_items (printf "%s\n" $item_list | fzf --multi --prompt="Select $item_type to delete: " --header="Use TAB to select, ENTER to confirm")

    # Validate selection
    if test -z "$selected_items"
        echo "No $item_type selected. Operation cancelled."
        return 0
    end

    # Show selected items and confirm
    echo ""
    echo "You have selected the following $item_type to delete:"
    for item in $selected_items
        echo "  • $item"
    end

    echo ""
    # Use read for confirmation prompt
    set -l confirm
    echo "WARNING: This will permanently delete these $item_type and all their contents!"
    read -l -P "Continue? (y/N): " confirm
    if string match -iq "y" -- $confirm
        echo "Deleting selected $item_type..."

        for item in $selected_items
            echo "Deleting: $item"

            # Use the correct command according to whether the item is a directory
            if test -d "$item"
                 # Use -rf for directories for safety (recursive and force)
                 rm -rf "$item"
            else
                # Use -f for regular files (force, but not recursive)
                rm -f "$item"
            end

            if test $status -eq 0
                echo "  ✓ Successfully deleted: $item"
            else
                echo "  ✗ Error deleting: $item" >&2 # Output errors to stderr
            end
        end

        echo ""
        echo "Operation completed."
    else
        echo "Operation cancelled. No $item_type were deleted."
    end
end

