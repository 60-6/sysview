sysview() {

    # —————————————————————————————————————————————————————————————————————————————————————————— setup

    local system_flag flatpak_flag orphans_flag quiet_flag help_flag invalid_flag

    for arg in "$@"
    do
        case "$arg" in
            -s) system_flag=1 ;;
            -f) flatpak_flag=1 ;;
            -o) orphans_flag=1 ;;
            -q) quiet_flag=1 ;;
            -h) help_flag=1 ;;
             *) invalid_flag=1 ;;
        esac
    done

    local run_all
    [[ $system_flag -eq 0 && $flatpak_flag -eq 0 && $orphans_flag -eq 0 && $help_flag -eq 0 ]] && run_all=1

    local bold="\e[1m" dim="\e[2m" red="\e[31m" reset="\e[m" hide_cur="\e[?25l" show_cur="\e[?25h"

    # —————————————————————————————————————————————————————————————————————————————————————————— loading

    local loading_pid
    
    loading_anim() {
        while true
        do
            for c in '( / )' '( — )' '( \ )' '( | )'
            do
                echo -en "\r${bold}${c}${reset}"
                sleep 0.05
            done
        done &
    }
    
    start_loading() {
        echo -en "$hide_cur"
        loading_anim 2>/dev/null
        loading_pid=$!
    }

    stop_loading() {
        kill "$loading_pid"
        wait "$loading_pid" 2>/dev/null
        echo -en "\r     \r$show_cur"
    }

    # —————————————————————————————————————————————————————————————————————————————————————————— system

    show_system() {
        start_loading

        local Qqtd Qqtt
        mapfile -t Qqtd < <(pacman -Qqtd)
        mapfile -t Qqtt < <(pacman -Qqtt)

        local -A qqtd_set
        for pkg in "${Qqtd[@]}"
        do qqtd_set[$pkg]=1
        done

        local system
        for pkg in "${Qqtt[@]}"
        do [[ -z "${qqtd_set[$pkg]}" ]] && system+=("$pkg")
        done
        
        local -A sys_pkgs_info system_set
        
        [[ $quiet_flag -eq 0 ]] && {
            for pkg in "${system[@]}"
            do system_set[$pkg]=1
            done

            while read -r pkg dep
            do [[ -n "${system_set[$dep]}" ]] && sys_pkgs_info[$pkg]+="$dep "
            done < <(LC_ALL=C pacman -Qi "${system[@]}" 2>/dev/null | awk '
                /^Name/ {
                    match($0, /: (.+)/, a)
                    next
                }
                /^Optional Deps/ {
                    sub(/^Optional Deps *: *|:.*/, "")
                    print a[1], $0
                    found = 1
                    next
                }
                found && /^ / {
                    gsub(/^ +|:.*/, "")
                    print a[1], $0
                    next
                }
                {
                    found = 0
                }
            ')
        }

        stop_loading

        echo -e "${bold}system (${#system[@]})${reset}"
        
        for i in "${!system[@]}"
        do
            local pkg="${system[$i]}"
            
            local is_last
            [[ $i -eq $((${#system[@]} - 1)) ]] && is_last=1

            local pfx
            [[ $quiet_flag -eq 0 ]] && {
                [[ $is_last -eq 1 ]] && pfx=$'│\n└─ ' || pfx=$'│\n├─ '
            }
            
            echo -e "${pfx}${pkg}"

            [[ -n "${sys_pkgs_info[$pkg]}" ]] && {
                local children
                read -a children <<< "${sys_pkgs_info[$pkg]}"

                for j in "${!children[@]}"
                do
                    local child_is_last
                    [[ $j -eq $((${#children[@]} - 1)) ]] && child_is_last=1

                    local indent cpfx
                    [[ $quiet_flag -eq 0 ]] && {
                        [[ $is_last -eq 1 ]] && indent="   "  || indent="│  "
                        [[ $child_is_last -eq 1 ]] && cpfx="└─ "   || cpfx="├─ "
                    }
                    
                    echo -e "${indent}${dim}${cpfx}${children[$j]}${reset}"
                done
            }
        done
        
        echo
    }

    # —————————————————————————————————————————————————————————————————————————————————————————— flatpak

    show_flatpak() {
        command -v flatpak &>/dev/null || return

        start_loading
        
        [[ $quiet_flag -eq 0 ]] && flatpak uninstall --unused -y &>/dev/null

        local flatpak_app_names
        mapfile -t flatpak_app_names < <(flatpak list --app --columns=name 2>/dev/null)
        
        stop_loading

        [[ ${#flatpak_app_names[@]} -eq 0 ]] && return

        echo -e "${bold}flatpak (${#flatpak_app_names[@]})${reset}"
        
        for i in "${!flatpak_app_names[@]}"
        do
            local is_last
            [[ $i -eq $((${#flatpak_app_names[@]} - 1)) ]] && is_last=1

            local pfx
            [[ $quiet_flag -eq 0 ]] && {
                [[ $is_last -eq 1 ]] && pfx=$'│\n└─ ' || pfx=$'│\n├─ '
            }
            
            echo -e "${pfx}${flatpak_app_names[$i]}"
        done
        
        echo
    }

    # —————————————————————————————————————————————————————————————————————————————————————————— orphans

    show_orphans() {
        start_loading
        
        local Qqtd
        mapfile -t Qqtd < <(pacman -Qqtd 2>/dev/null)
        
        stop_loading

        [[ ${#Qqtd[@]} -eq 0 ]] && return

        echo -e "${bold}${red}orphans (${#Qqtd[@]})${reset}"
        
        for i in "${!Qqtd[@]}"
        do
            local is_last
            [[ $i -eq $((${#Qqtd[@]} - 1)) ]] && is_last=1

            local pfx
            [[ $quiet_flag -eq 0 ]] && {
                [[ $is_last -eq 1 ]] && pfx=$'│\n└─ ' || pfx=$'│\n├─ '
            }
            
            echo -e "${red}${pfx}${Qqtd[$i]}${reset}"
        done

        [[ $quiet_flag -eq 0 ]] && {
            echo -en "\nuninstall orphans? (y/${bold}n${reset}) "
            read -r answer
            [[ "${answer,,}" == "y" ]] && sudo pacman -Rns "${Qqtd[@]}"
        }
        
        echo
    }

    # —————————————————————————————————————————————————————————————————————————————————————————— help

    show_help() {
        echo "usage: sysview (-s) (-f) (-o) (-q) (-h)"
        echo "  -s    show system packages"
        echo "  -f    show flatpak apps"
        echo "  -o    show orphan packages"
        echo "  -q    quiet output"
        echo "  -h    show this help message"
        echo
    }

    # —————————————————————————————————————————————————————————————————————————————————————————— execution

    echo

    [[ $invalid_flag -eq 1 ]] && {
        echo "invalid flag"
        show_help
        return
    }

    [[ $run_all -eq 1 ]] && {
        show_system
        show_flatpak
        show_orphans
    } || {
        for arg in "$@"
        do
            case "$arg" in
                -s) show_system ;;
                -f) show_flatpak ;;
                -o) show_orphans ;;
                -h) show_help ;;
            esac
        done
    }
}
