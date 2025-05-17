# Function to interactively delete files and directories

# name = "fzf_delete"
# version = "1.0.0"
# description = "Interactive delete function for Fish shell using fzf and gum."
# author = "Your Name <pookdeveloper@email.com>"
# license = "MIT"

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
    set type "a"
    set show_hidden false
    set do_dup false

    # Primer argumento: tipo
    if test (count $argv) -ge 1
        switch $argv[1]
            case "f" "F"
                set type "f"
            case "d" "D"
                set type "d"
            case "a" "A"
                set type "a"
            case "dup"
                set do_dup true
            case "-h" "--help"
                # ya gestionado arriba
            case "*"
                echo "Opción inválida: '$argv[1]'. Usa 'f' para archivos, 'd' para directorios, 'h' para ocultos, o 'dup' para duplicados."
                return 1
        end
    end

    # Segundo argumento: show_hidden o dup
    if test (count $argv) -ge 2
        switch $argv[2]
            case "h" "H"
                set show_hidden true
            case "dup"
                set do_dup true
            case "*"
                echo "Opción inválida: '$argv[2]'. Usa 'h' para ocultos o 'dup' para duplicados."
                return 1
        end
    end

    # Si hay un tercer argumento, solo puede ser dup
    if test (count $argv) -ge 3
        if test $argv[3] = "dup"
            set do_dup true
        else
            echo "Opción inválida: '$argv[3]'. Solo se permite 'dup' como tercer argumento."
            return 1
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

    # Add option for duplicate removal
    if test $do_dup = true
        # Check for required dependencies
        set missing_deps
        if not type -q fzf
            set -a missing_deps fzf
        end
        if not type -q gum
            set -a missing_deps gum
        end
        if not type -q md5
            set -a missing_deps md5
        end
        if not type -q md5sum
            set -a missing_deps md5sum
        end
        if test (count $missing_deps) -gt 0
            echo "Error: The following dependencies are required but not installed: (string join ', ' $missing_deps)"
            echo "Please install them and try again."
            return 1
        end

        # Find duplicate files (same name and size)
        set file_dups (find . -type f -not -path '*/\.*' -printf '%f|%s|%p\n' | sort | uniq -d -f 1 | awk -F'|' '{print $3}')
        # Find duplicate folders (same name, size, and content hash)
        set dir_dups
        for dir in (find . -type d -not -path '*/\.*')
            set dname (basename $dir)
            set dsize (du -sb $dir | awk '{print $1}')
            set dhash (find $dir -type f -exec md5sum {} + | sort | md5sum | awk '{print $1}')
            set dirinfo "$dname|$dsize|$dhash|$dir"
            set -a dir_dups $dirinfo
        end
        set dir_dups (printf "%s\n" $dir_dups | sort | uniq -d -f 1 | awk -F'|' '{print $4}')

        set all_dups $file_dups $dir_dups
        if test (count $all_dups) -eq 0
            echo "No duplicate files or directories found."
            return 0
        end

        set selected_dups (printf "%s\n" $all_dups | fzf --multi --prompt="Select duplicates to delete: " --header="Use TAB to select, ENTER to confirm")
        if test -z "$selected_dups"
            echo "No duplicates selected. Operation cancelled."
            return 0
        end
        echo ""
        echo "You have selected the following duplicates to delete:"
        for item in $selected_dups
            echo "  • $item"
        end
        echo ""
        if gum confirm "WARNING: This will permanently delete these duplicates and all their contents! Continue?"
            echo "Deleting selected duplicates..."
            for item in $selected_dups
                echo "Deleting: $item"
                if test -d "$item"
                    rm -rf "$item"
                else
                    rm -f "$item"
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
            echo "Operation cancelled. No duplicates were deleted."
        end
        return 0
    end
end


