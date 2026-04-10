sysview() {

    (( executing )) && {

        # ──────────────────────────────────────────────────────────────────────────────────────────────── loading

        [[ $1 = ex_loading ]] && {
            (( loading_pid )) && {
                eval "${old_trap:-trap - 2}"
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
                        sleep 0.03
                    done
                done &
            } 2>/dev/null

            loading_pid=$!
            echo -en $hide_cur
            old_trap=$(trap -p 2)
            trap "sysview ex_loading; kill -2 $$" 2
        }

        # ──────────────────────────────────────────────────────────────────────────────────────────────── system

        [[ $1 = ex_system ]] && {
            sysview ex_loading

            mapfile -t system < <(comm -23 <(pacman -Qqtt | sort) <(pacman -Qqtd | sort))

            local -A system_dict

            (( minimal )) || {
                for pkg in ${system[@]}
                do system_dict[$pkg]=
                done

                while read -r pkg dep
                do [[ -v system_dict[$dep] ]] && system_dict[$pkg]+="$dep "
                done < <(LC_ALL=C pacman -Qi ${system[@]} | awk '
                    /^Name/ { pkg = $NF }
                    /^Optional Deps/ {
                        gsub(/^Optional Deps *: *|:.*/, "")
                        print pkg, $0
                        opt_deps = 1
                        next
                    }
                    opt_deps && /^ / {
                        gsub(/^ +|:.*/, "")
                        print pkg, $0
                        next
                    }
                    { opt_deps = 0 }
                ')
            }

            sysview ex_loading

            echo -e "${bold}system (${#system[@]})$reset"

            for i in ${!system[@]}
            do
                pkg=${system[$i]}

                last=$(( i == ${#system[@]} - 1 ))

                (( minimal )) && pfx= || {
                    (( last )) && pfx="│\n└─ " || pfx="│\n├─ "
                }

                echo -e "$pfx$pkg"

                children=(${system_dict[$pkg]})

                for j in ${!children[@]}
                do
                    pkg=${children[$j]}

                    last_child=$(( j == ${#children[@]} - 1 ))

                    (( last )) && indent="   " || indent="│  "
                    (( last_child )) && pfx="└─ " || pfx="├─ "

                    echo -e "$indent$dim$pfx$pkg$reset"
                done
            done

            echo
        }

        # ──────────────────────────────────────────────────────────────────────────────────────────────── flatpaks

        [[ $1 = ex_flatpaks ]] && {
            sysview ex_loading

            (( minimal )) || flatpak remove --unused -y &>/dev/null

            mapfile -t flatpaks < <(flatpak list --app --columns=name 2>/dev/null)

            sysview ex_loading

            (( ${#flatpaks[@]} )) || return

            echo -e "${bold}flatpaks (${#flatpaks[@]})$reset"

            for i in ${!flatpaks[@]}
            do
                pkg=${flatpaks[$i]}

                last=$(( i == ${#flatpaks[@]} - 1 ))

                (( minimal )) && pfx= || {
                    (( last )) && pfx="│\n└─ " || pfx="│\n├─ "
                }

                echo -e "$pfx$pkg"
            done

            echo
        }

        # ──────────────────────────────────────────────────────────────────────────────────────────────── orphans

        [[ $1 = ex_orphans ]] && {
            sysview ex_loading

            mapfile -t orphans < <(pacman -Qqtd)

            sysview ex_loading

            (( ${#orphans[@]} )) || return

            echo -e "$bold${red}orphans (${#orphans[@]})$reset"

            for i in ${!orphans[@]}
            do
                pkg=${orphans[$i]}

                last=$(( i == ${#orphans[@]} - 1 ))

                (( minimal )) && pfx= || {
                    (( last )) && pfx="│\n└─ " || pfx="│\n├─ "
                }

                echo -e "$red$pfx$pkg$reset"
            done

            (( minimal )) || {
                echo -en "\nuninstall orphans? (y/${bold}n$reset) "
                read -r answer
                [[ ${answer,,} = y ]] && sudo pacman -Rns ${orphans[@]}
            }

            echo
        }

        # ──────────────────────────────────────────────────────────────────────────────────────────────── help

        [[ $1 = ex_help ]] && {
            echo "usage:  sysview (s) (f) (o) (m)"
            echo "  s  ➞  show system packages"
            echo "  f  ➞  show flatpak apps"
            echo "  o  ➞  show orphan packages"
            echo "  m  ➞  minimal mode"

            echo
        }

    :;} || {

        local loading_pid old_trap system minimal pkg dep i last pfx j children last_child indent orphans flatpaks answer
        local bold="\e[1m" dim="\e[2m" red="\e[31m" reset="\e[m" hide_cur="\e[?25l" show_cur="\e[?25h"

        local executing=1
        echo

        local arg queue

        for arg
        do
            case $arg in
                s) queue+=(ex_system) ;;
                f) queue+=(ex_flatpaks) ;;
                o) queue+=(ex_orphans) ;;
                m) minimal=1 ;;
                *) sysview ex_help; return ;;
            esac
        done

        (( ${#queue[@]} )) || queue=(ex_system ex_flatpaks ex_orphans)

        for arg in ${queue[@]}
        do sysview $arg
        done

    }

}
