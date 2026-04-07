sysview() {

    # ==========================================================================
    # setup
    # ==========================================================================

    local system_flag=0 flatpak_flag=0 orphans_flag=0 quiet_flag=0 help_flag=0 invalid_flag=0

    for arg in "$@"; do
        case "$arg" in
            -s) system_flag=1 ;;
            -f) flatpak_flag=1 ;;
            -o) orphans_flag=1 ;;
            -q) quiet_flag=1 ;;
            -h) help_flag=1 ;;
            *)  invalid_flag=1 ;;
        esac
    done

    local run_all=0
    [[ $system_flag == 0 && $flatpak_flag == 0 && $orphans_flag == 0 && $help_flag == 0 ]] && run_all=1

    local bold="\e[1m" dim="\e[2m" red="\e[31m" reset="\e[0m" hide_cur="\e[?25l" show_cur="\e[?25h"

    # ==========================================================================
    # loading function
    # ==========================================================================

    loading_anim() {
        printf "$hide_cur"
        for c in '( / )' '( — )' '( \ )' '( | )' '( / )' '( — )' '( \ )' '( | )'; do
            printf "\r${bold}%s${reset}" "$c"
            sleep 0.05
        done
        printf "\r     \r"
        printf "$show_cur"
    }

    # ==========================================================================
    # system function
    # ==========================================================================

    show_system() {
        local Qqtd
        mapfile -t Qqtd < <(pacman -Qqtd 2>/dev/null)

        local Qqtt
        mapfile -t Qqtt < <(pacman -Qqtt)

        local -A qqtd_set
        for pkg in "${Qqtd[@]}"; do
            qqtd_set[$pkg]=1
        done

        local system=()
        for pkg in "${Qqtt[@]}"; do
            [[ -z "${qqtd_set[$pkg]}" ]] && system+=("$pkg")
        done

        local -A sys_pkgs_info
        if [[ $quiet_flag == 0 ]]; then
            local -A system_set
            for pkg in "${system[@]}"; do
                system_set[$pkg]=1
            done

            while IFS=$'\t' read -r pkg dep; do
                dep="${dep%%:*}"
                dep="${dep//[[:space:]]/}"
                [[ -n "${system_set[$dep]}" ]] && sys_pkgs_info[$pkg]+="$dep "
            done < <(LC_ALL=C pacman -Qi "${system[@]}" 2>/dev/null | awk '
                /^Name[[:space:]]+:/          { match($0, /: (.+)/, a); cur = a[1]; found = 0; next }
                /^Optional Deps[[:space:]]+:/ {
                    sub(/^Optional Deps[[:space:]]+:[[:space:]]*/, "")
                    if ($0 != "None" && $0 != "") print cur "\t" $0
                    found = 1; next
                }
                found && /^[[:space:]]/ { gsub(/^[[:space:]]+/, ""); print cur "\t" $0; next }
                found                  { found = 0 }
            ')
        fi

        echo -e "${bold}system (${#system[@]})${reset}"
        for i in "${!system[@]}"; do
            local pkg="${system[$i]}"
            local is_last=0; [[ $i == $((${#system[@]} - 1)) ]] && is_last=1
            [[ $is_last == 1 ]] && echo -e "$([[ $quiet_flag == 0 ]] && echo '│\n└─ ')$pkg" || echo -e "$([[ $quiet_flag == 0 ]] && echo '│\n├─ ')$pkg"

            if [[ -n "${sys_pkgs_info[$pkg]}" ]]; then
                local children
                read -ra children <<< "${sys_pkgs_info[$pkg]}"

                for j in "${!children[@]}"; do
                    local child_is_last=0; [[ $j == $((${#children[@]} - 1)) ]] && child_is_last=1
                    if [[ $is_last == 1 ]]; then
                        [[ $child_is_last == 1 ]] && echo -e "${dim}   └─ ${children[$j]}${reset}" || echo -e "${dim}   ├─ ${children[$j]}${reset}"
                    else
                        [[ $child_is_last == 1 ]] && echo -e "│${dim}  └─ ${children[$j]}${reset}" || echo -e "│${dim}  ├─ ${children[$j]}${reset}"
                    fi
                done
            fi
        done
        echo
    }

    # ==========================================================================
    # flatpak function
    # ==========================================================================

    show_flatpak() {
        command -v flatpak &>/dev/null || return

        flatpak uninstall --unused -y &>/dev/null

        local flatpak_app_names
        mapfile -t flatpak_app_names < <(flatpak list --app --columns=name 2>/dev/null)

        [[ ${#flatpak_app_names[@]} == 0 ]] && return

        echo -e "${bold}flatpak (${#flatpak_app_names[@]})${reset}"
        for i in "${!flatpak_app_names[@]}"; do
            local is_last=0; [[ $i == $((${#flatpak_app_names[@]} - 1)) ]] && is_last=1
            [[ $is_last == 1 ]] && echo -e "$([[ $quiet_flag == 0 ]] && echo '│\n└─ ')${flatpak_app_names[$i]}" || echo -e "$([[ $quiet_flag == 0 ]] && echo '│\n├─ ')${flatpak_app_names[$i]}"
        done
        echo
    }

    # ==========================================================================
    # orphans function
    # ==========================================================================

    show_orphans() {
        local Qqtd
        mapfile -t Qqtd < <(pacman -Qqtd 2>/dev/null)

        [[ ${#Qqtd[@]} == 0 ]] && return

        echo -e "${red}orphans (${#Qqtd[@]})${reset}"
        for i in "${!Qqtd[@]}"; do
            local is_last=0; [[ $i == $((${#Qqtd[@]} - 1)) ]] && is_last=1
            [[ $is_last == 1 ]] && echo -e "${red}$([[ $quiet_flag == 0 ]] && echo '│\n└─ ')${Qqtd[$i]}${reset}" || echo -e "${red}$([[ $quiet_flag == 0 ]] && echo '│\n├─ ')${Qqtd[$i]}${reset}"
        done

        read -rp "$(echo -e "\nuninstall orphans? (y/${bold}n${reset}) ")" confirm
        [[ "${confirm,,}" == "y" ]] && sudo pacman -Rns "${Qqtd[@]}"
        echo
    }

    # ==========================================================================
    # help function
    # ==========================================================================

    show_help() {
        echo "usage: sysview (-s) (-f) (-o) (-q) (-h)"
        echo "  -s    show system packages"
        echo "  -f    show flatpak apps"
        echo "  -o    show orphan packages"
        echo "  -q    quiet output"
        echo "  -h    show this help message"
        echo
    }

    # ==========================================================================
    # execution
    # ==========================================================================

    echo

    if [[ $invalid_flag == 1 ]]; then
        echo "invalid flag"
        show_help
        return 1
    fi

    if [[ $run_all == 1 ]]; then
        [[ $quiet_flag == 0 ]] && loading_anim
        show_system
        show_flatpak
        show_orphans
    else
        for arg in "$@"; do
            case "$arg" in
                -s) show_system ;;
                -f) show_flatpak ;;
                -o) show_orphans ;;
                -h) show_help ;;
            esac
        done
    fi
}
