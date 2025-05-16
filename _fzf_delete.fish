# Function to interactively delete files and directories
#
# Usage: fzf_delete [options]
#   - No parameters: shows all (except hidden)
#   - 'f': only files
#   - 'd': only directories
#   - 'h': include hidden
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
    # Show help if requested
    if contains -- "-h" $argv; or contains -- "--help" $argv
        echo "Usage: fzf_delete [options]"
        echo "  - No parameters: shows all (except hidden)"
        echo "  - 'f': only files"
        echo "  - 'd': only directories"
        echo "  - 'h': include hidden"
        echo ""
        echo "Examples:"
        echo "  fzf_delete           # Shows files and directories (excluding hidden)"
        echo "  fzf_delete d h       # Shows only directories (including hidden)"
        echo "  fzf_delete f h       # Shows only files (including hidden)"
        echo "  fzf_delete a h       # Shows files and directories (including hidden)"
        return 0
    end

    # Set default values and process parameters
    set type "a"          # Default: show all (files and directories)
    set show_hidden false # Default: do not show hidden
    
    # Process first parameter (type)
    if test (count $argv) -ge 1
        switch $argv[1]
            case "f" "F"
                set type "f"
            case "d" "D"
                set type "d"
            case "a" "A"
                set type "a"
            case "*"
                if test $argv[1] != "h" -a $argv[1] != "H"
                    echo "Invalid option: '$argv[1]}'. Use 'f' for files, 'd' for directories, or 'h' to include hidden."
                    return 1
                end
        end
    end
    
    # Process second parameter (show hidden)
    if test (count $argv) -ge 2
        if test $argv[2] = "h" -o $argv[2] = "H"
            set show_hidden true
        end
    end
    
    # If the first parameter is 'h', set to show hidden
    if test (count $argv) -ge 1
        if test $argv[1] = "h" -o $argv[1] = "H"
            set show_hidden true
        end
    end
    
    # Build the ls command with appropriate options
    set ls_cmd "/bin/ls -l"
    
    # Add option to show hidden files if needed
    if test $show_hidden = true
        set ls_cmd "$ls_cmd -a"
    end
    
    # Get the list of items according to parameters
    set item_list
    
    # Filter by type (file, directory, or both)
    if test $type = "d"
        set item_list (eval $ls_cmd | grep "^d" | awk '{for (i=9; i<=NF; i++) printf "%s ", $i; print ""}')
        set item_type "directories"
    else if test $type = "f"
        set item_list (eval $ls_cmd | grep -v "^d" | grep -v "^total" | awk '{for (i=9; i<=NF; i++) printf "%s ", $i; print ""}')
        set item_type "files"
    else  # type 'a' (both)
        set item_list (eval $ls_cmd | grep -v "^total" | awk '{for (i=9; i<=NF; i++) printf "%s ", $i; print ""}')
        set item_type "items"
    end
    
    # Filter out special items . and .. if showing hidden
    if test $show_hidden = true
        set filtered_list
        for item in $item_list
            if test "$item" != "." -a "$item" != ".."
                set -a filtered_list $item
            end
        end
        set item_list $filtered_list
    end
    
    # Check if there are items
    if test (count $item_list) -eq 0
        echo "No $item_type in the current directory match the criteria."
        return 1
    end
    
    # Check for required dependencies
    set missing_deps
    if not type -q fzf
        set -a missing_deps fzf
    end
    if not type -q gum
        set -a missing_deps gum
    end
    if test (count $missing_deps) -gt 0
        echo "Error: The following dependencies are required but not installed: (string join ', ' $missing_deps)"
        echo "Please install them and try again."
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
    # Use gum for confirmation prompt
    if gum confirm "WARNING: This will permanently delete these $item_type and all their contents! Continue?"
        echo "Deleting selected $item_type..."
        
        for item in $selected_items
            echo "Deleting: $item"
            
            # Use the correct command according to type
            if test $type = "d" -o $type = "a"
                # For directories or when 'a' is selected, use -rf for safety
                rm -rf "./$item"
            else
                # For regular files
                rm -f "./$item"
            end
            
            if test $status -eq 0
                echo "  ✓ Successfully deleted: $item"
            else
                echo "  ✗ Error deleting: $item"
            end
        end
        
        echo ""
        echo "Operation completed."
    else
        echo "Operation cancelled. No $item_type were deleted."
    end
end

name = "fzf_delete"
version = "1.0.0"
description = "Interactive delete function for Fish shell using fzf and gum."
author = "Your Name <pookdeveloper@email.com>"
license = "MIT"

