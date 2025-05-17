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
#   - 'dup': find and delete duplicates
#
# Examples:
#   fzf_delete           # Shows files and directories (excluding hidden)
#   fzf_delete d h       # Shows only directories (including hidden)
#   fzf_delete f h       # Shows only files (including hidden)
#   fzf_delete a h       # Shows files and directories (including hidden)
#   fzf_delete dup       # Shows duplicate files and directories for deletion
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
        echo "  - 'dup': find and delete duplicates"
        echo ""
        echo "Examples:"
        echo "  fzf_delete           # Shows files and directories (excluding hidden)"
        echo "  fzf_delete d h       # Shows only directories (including hidden)"
        echo "  fzf_delete f h       # Shows only files (including hidden)"
        echo "  fzf_delete a h       # Shows files and directories (including hidden)"
        echo "  fzf_delete dup       # Shows duplicate files and directories for deletion"
        return 0
    end

    # Si el primer argumento es dup, ejecuta SOLO la lógica de duplicados y termina
    if test (count $argv) -ge 1; and test "$argv[1]" = "dup"
        # Check for required dependencies
        set missing_deps
        if not type -q fzf
            set -a missing_deps fzf
        end
        if not type -q gum
            set -a missing_deps gum
        end

        # Detecta sistema operativo
        set os (uname)
        if test $os = "Darwin"
            if not type -q md5
                set -a missing_deps md5
            end
        else
            if not type -q md5sum
                set -a missing_deps md5sum
            end
        end
        if test (count $missing_deps) -gt 0
            echo "Error: The following dependencies are required but not installed: (string join ', ' $missing_deps)"
            echo "Please install them and try again."
            return 1
        end

        echo "Searching for duplicate files and directories..."

        # ==== ARCHIVOS: Duplicados por nombre base, muestra solo el más reciente ====
        set file_bases
        set file_mtimes
        set file_paths
        set file_counts

        set all_files
        if test $os = "Darwin"
            set all_files (find . -type f -not -path '*/\.*' -exec stat -f "%N|%m" {} \;)
        else
            set all_files (find . -type f -not -path '*/\.*' -printf '%p|%T@\n')
        end

        for file in $all_files
            if test $os = "Darwin"
                set path (string split "|" $file)[1]
                set mtime (string split "|" $file)[2]
                set fname (basename $path)
            else
                set path (string split "|" $file)[1]
                set mtime (string split "|" $file)[2]
                set fname (basename $path)
            end
            set base (string replace -r ' \([0-9]+\)' '' $fname)

            # Buscar si ya existe este base
            set idx -1
            if test (count $file_bases) -gt 0
                for i in (seq (count $file_bases))
                    if test "$file_bases[$i]" = "$base"
                        set idx $i
                        break
                    end
                end
            end

            if test $idx -eq -1
                set -a file_bases $base
                set -a file_mtimes $mtime
                set -a file_paths $path
                set -a file_counts 1
            else
                # Sumar al contador
                set file_counts[$idx] (math $file_counts[$idx] + 1)
                # Si este es más reciente, reemplazar
                if test $mtime -gt $file_mtimes[$idx]
                    set file_mtimes[$idx] $mtime
                    set file_paths[$idx] $path
                end
            end
        end

        set file_dups
        if test (count $file_bases) -gt 0
            for i in (seq (count $file_bases))
                if test $file_counts[$i] -gt 1
                    set -a file_dups $file_paths[$i]
                end
            end
        end

        # ==== DIRECTORIOS: Duplicados por nombre y tamaño ====
        set dir_keys
        set dir_paths
        set dir_counts

        set all_dirs (find . -type d -not -path '*/\.*')
        for dir in $all_dirs
            set dname (basename $dir)
            if test $os = "Darwin"
                set dsize (du -sk $dir | awk '{print $1}')
            else
                set dsize (du -sb $dir | awk '{print $1}')
            end
            set key "$dname|$dsize"

            set idx -1
            if test (count $dir_keys) -gt 0
                for i in (seq (count $dir_keys))
                    if test "$dir_keys[$i]" = "$key"
                        set idx $i
                        break
                    end
                end
            end

            if test $idx -eq -1
                set -a dir_keys $key
                set -a dir_paths $dir
                set -a dir_counts 1
            else
                set dir_counts[$idx] (math $dir_counts[$idx] + 1)
            end
        end

        set dir_dups
        if test (count $dir_keys) -gt 0
            for i in (seq (count $dir_keys))
                if test $dir_counts[$i] -gt 1
                    set -a dir_dups $dir_paths[$i]
                end
            end
        end

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
end


