# ────────────────────────────────────────────────────────────────────────────────────────── << atlas >> ────────────────────────────────────────────────────────────────────────────────────────── #

atlas() {

    (( executing )) && {

# ────────────── system ──────────────────────────────────────────────────────────────────────── ▼

        [[ $1 = ex_system ]] && {
            atlas ex_loading

            mapfile -t system < <(comm -23 <(pacman -Qqtt | sort) <(pacman -Qqtd | sort))

            local -A system_dict

            (( quiet )) || {
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

            atlas ex_loading

            echo -e "${bold}system (${#system[@]})$reset"

            for i in ${!system[@]}
            do
                pkg=${system[$i]}

                last=$(( i == ${#system[@]} - 1 ))

                (( quiet )) && pfx= || {
                    (( last )) && pfx="│\n└─ " || pfx="│\n├─ "
                }

                echo -e "$pfx$pkg"

                children=(${system_dict[$pkg]})

                for j in ${!children[@]}
                do
                    pkg=${children[$j]}

                    clast=$(( j == ${#children[@]} - 1 ))

                    (( last )) && indent="   " || indent="│  "
                    (( clast)) && pfx="└─ " || pfx="├─ "

                    echo -e "$indent$dim$pfx$pkg$reset"
                done
            done

            echo
        }

# ────────────── flatpaks ────────────────────────────────────────────────────────────────────── ▼

        [[ $1 = ex_flatpaks ]] && {
            atlas ex_loading

            mapfile -t flatpaks < <(flatpak list --app --columns=name)

            atlas ex_loading

            (( ${#flatpaks[@]} )) || return

            echo -e "${bold}flatpaks (${#flatpaks[@]})$reset"

            for i in ${!flatpaks[@]}
            do
                pkg=${flatpaks[$i]}

                last=$(( i == ${#flatpaks[@]} - 1 ))

                (( quiet )) && pfx= || {
                    (( last )) && pfx="│\n└─ " || pfx="│\n├─ "
                }

                echo -e "$pfx$pkg"
            done

            (( quiet )) || queue+=(ex_flatpaks_prompt)

            echo
        }

# ────────────── orphans ─────────────────────────────────────────────────────────────────────── ▼

        [[ $1 = ex_orphans ]] && {
            atlas ex_loading

            mapfile -t orphans < <(pacman -Qqtd)

            atlas ex_loading

            (( ${#orphans[@]} )) || return

            echo -e "$bold${red}orphans (${#orphans[@]})$reset"

            for i in ${!orphans[@]}
            do
                pkg=${orphans[$i]}

                last=$(( i == ${#orphans[@]} - 1 ))

                (( quiet )) && pfx= || {
                    (( last )) && pfx="│\n└─ " || pfx="│\n├─ "
                }

                echo -e "$red$pfx$pkg$reset"
            done

            (( quiet )) || queue+=(ex_orphans_prompt)

            echo
        }

# ────────────── prompts ─────────────────────────────────────────────────────────────────────── ▼

        [[ $1 = ex_flatpaks_prompt ]] && {
            echo -n "checking updates "
            atlas ex_loading

            mapfile -t update_ids < <(flatpak remote-ls --updates --columns=application)

            atlas ex_loading

            (( ${#update_ids[@]} )) || return

            echo -en "upgrade flatpaks? (y/${bold}n$reset) "
            read -r answer
            [[ ${answer,,} = y ]] && {
                flatpak update ${update_ids[@]}
                flatpak remove --unused -y &>/dev/null
            }

            echo
        }

        [[ $1 = ex_orphans_prompt ]] && {
            echo -en "uninstall orphans? (y/${bold}n$reset) "
            read -r answer
            [[ ${answer,,} = y ]] && sudo pacman -Rns ${orphans[@]}

            echo
        }

# ────────────── help ────────────────────────────────────────────────────────────────────────── ▼

        [[ $1 = ex_help ]] && {
            echo "usage:  atlas (s) (f) (o) (q)"
            echo "  s  ➞  show system packages"
            echo "  f  ➞  show flatpak apps"
            echo "  o  ➞  show orphan packages"
            echo "  q  ➞  quiet mode"

            echo
        }

# ────────────── loading ─────────────────────────────────────────────────────────────────────── ▼

        [[ $1 = ex_loading ]] && {
            (( loading_pid )) && {
                eval "${old_trap:-trap - 2}"
                kill $loading_pid
                wait $loading_pid &>/dev/null
                loading_pid=
                echo -en "\r\e[K$show_cur"
                return
            }

            {
                while :
                do
                    for c in "( / )" "( — )" "( \ )" "( | )"
                    do
                        echo -en "\e[s$bold$c$reset\e[u"
                        sleep 0.03
                    done
                done &
            } 2>/dev/null

            loading_pid=$!
            echo -en $hide_cur
            old_trap=$(trap -p 2)
            trap "atlas ex_loading; kill -2 $$" 2
        }

    :;} || {

# ────────────── scoping ─────────────────────────────────────────────────────────────────────── ▼

        local answer children clast dep flatpaks i indent j last loading_pid old_trap orphans pfx pkg quiet system update_ids
        local bold="\e[1m" dim="\e[2m" red="\e[31m" reset="\e[m" hide_cur="\e[?25l" show_cur="\e[?25h"

# ────────────── execution ───────────────────────────────────────────────────────────────────── ▼

        local executing=1
        echo

        local arg queue index

        for arg
        do
            case $arg in
                s) queue+=(ex_system) ;;
                f) queue+=(ex_flatpaks) ;;
                o) queue+=(ex_orphans) ;;
                q) quiet=1 ;;
                *) atlas ex_help; return ;;
            esac
        done

        (( ${#queue[@]} )) || queue=(ex_system ex_flatpaks ex_orphans)

        while (( index < ${#queue[@]} ))
        do
            atlas ${queue[$index]}
            (( index++ ))
        done

    }

}

# ────────────────────────────────────────────────────────────────────────────────────────── >> atlas << ────────────────────────────────────────────────────────────────────────────────────────── #
