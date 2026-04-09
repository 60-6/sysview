sysview() {

    # ──────────────────────────────────────────────────────────────────────────────────────────────── scoping

    local arg mode quiet_flag invalid_flag bold dim red reset hide_cur show_cur top_pkgs orphans pkg system dep i is_last pfx j children child child_is_last indent cpfx flatpak_apps answer

    # ──────────────────────────────────────────────────────────────────────────────────────────────── setup

    mode= quiet_flag= invalid_flag=

    for arg
    do
        case $arg in
            s|f|o|h) mode=1 ;;
            q) quiet_flag=1 ;;
            *) invalid_flag=1 ;;
        esac
    done

    bold="\e[1m" dim="\e[2m" red="\e[31m" reset="\e[m" hide_cur="\e[?25l" show_cur="\e[?25h"

    # ──────────────────────────────────────────────────────────────────────────────────────────────── loading

    loading_f() {
        (( loading_pid )) && {
            eval "${old_trap:-trap - INT}"
            kill $loading_pid
            wait $loading_pid &>/dev/null
            loading_pid=
            echo -en "\e[K$show_cur"
            return
        }

        {
            while :
            do
                for c in "( / )" "( — )" "( \ )" "( | )"
                do
                    echo -en "$bold$c$reset\r"
                    sleep 0.02
                done
            done &
        } 2>/dev/null

        declare -g loading_pid=$! old_trap=$(trap -p INT)
        echo -en $hide_cur
        trap loading_f INT
    }

    # ──────────────────────────────────────────────────────────────────────────────────────────────── system

    system_f() {
        loading_f

        mapfile -t top_pkgs < <(pacman -Qqtt)
        mapfile -t orphans < <(pacman -Qqtd)

        local -A orphans_set system_set sys_pkgs_info

        for pkg in ${orphans[@]}
        do orphans_set[$pkg]=1
        done

        system=()
        for pkg in ${top_pkgs[@]}
        do (( orphans_set[$pkg] )) || system+=($pkg)
        done

        (( quiet_flag )) || {
            for pkg in ${system[@]}
            do system_set[$pkg]=1
            done

            while read -r pkg dep
            do (( system_set[$dep] )) && sys_pkgs_info[$pkg]+="$dep "
            done < <(LC_ALL=C pacman -Qi ${system[@]} | awk '
                /^Name/ {
                    pkg = $NF
                    next
                }
                /^Optional Deps/ {
                    gsub(/^Optional Deps *: *|:.*/, "")
                    print pkg, $0
                    found = 1
                    next
                }
                found && /^ / {
                    gsub(/^ +|:.*/, "")
                    print pkg, $0
                    next
                }
                {
                    found = 0
                }
            ')
        }

        loading_f

        echo -e "${bold}system (${#system[@]})$reset"

        for i in ${!system[@]}
        do
            pkg=${system[$i]}

            is_last=$(( i == ${#system[@]} - 1 ))

            (( quiet_flag )) && pfx= || {
                (( is_last )) && pfx=$'│\n└─ ' || pfx=$'│\n├─ '
            }

            echo -e "$pfx$pkg"

            read -a children <<< ${sys_pkgs_info[$pkg]}

            for j in ${!children[@]}
            do
                child=${children[$j]}

                child_is_last=$(( j == ${#children[@]} - 1 ))

                (( is_last )) && indent="   " || indent="│  "
                (( child_is_last )) && cpfx="└─ " || cpfx="├─ "

                echo -e "$indent$dim$cpfx$child$reset"
            done
        done

        echo
    }

    # ──────────────────────────────────────────────────────────────────────────────────────────────── flatpaks

    flatpak_f() {
        loading_f

        (( quiet_flag )) || flatpak remove --unused -y &>/dev/null

        mapfile -t flatpak_apps < <(flatpak list --app --columns=name 2>/dev/null)

        loading_f

        (( ${#flatpak_apps[@]} )) || return

        echo -e "${bold}flatpaks (${#flatpak_apps[@]})$reset"

        for i in ${!flatpak_apps[@]}
        do
            pkg=${flatpak_apps[$i]}

            is_last=$(( i == ${#flatpak_apps[@]} - 1 ))

            (( quiet_flag )) && pfx= || {
                (( is_last )) && pfx=$'│\n└─ ' || pfx=$'│\n├─ '
            }

            echo -e "$pfx$pkg"
        done

        echo
    }

    # ──────────────────────────────────────────────────────────────────────────────────────────────── orphans

    orphans_f() {
        loading_f

        mapfile -t orphans < <(pacman -Qqtd)

        loading_f

        (( ${#orphans[@]} )) || return

        echo -e "$bold${red}orphans (${#orphans[@]})$reset"

        for i in ${!orphans[@]}
        do
            pkg=${orphans[$i]}

            is_last=$(( i == ${#orphans[@]} - 1 ))

            (( quiet_flag )) && pfx= || {
                (( is_last )) && pfx=$'│\n└─ ' || pfx=$'│\n├─ '
            }

            echo -e "$red$pfx$pkg$reset"
        done

        (( quiet_flag )) || {
            echo -en "\nuninstall orphans? (y/${bold}n$reset) "
            read -r answer
            [[ ${answer,,} = y ]] && sudo pacman -Rns ${orphans[@]}
        }

        echo
    }

    # ──────────────────────────────────────────────────────────────────────────────────────────────── help

    help_f() {
        echo "usage: sysview (s) (f) (o) (q) (h)"
        echo "  s    show system packages"
        echo "  f    show flatpak apps"
        echo "  o    show orphan packages"
        echo "  q    quiet mode"
        echo "  h    show this message"
        echo
    }

    # ──────────────────────────────────────────────────────────────────────────────────────────────── execution

    echo

    (( invalid_flag )) && {
        echo "invalid flag"
        help_f
        return
    }

    (( mode )) || {
        system_f
        flatpak_f
        orphans_f
        return
    }

    for arg
    do
        case $arg in
            s) system_f ;;
            f) flatpak_f ;;
            o) orphans_f ;;
            h) help_f ;;
        esac
    done

}
