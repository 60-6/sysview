# ──────────────────────────────────────────────────────────────────────────────────────────── \\ ▼ // ──────────────────────────────────────────────────────────────────────────────────────────── #
                                                                                               atlas()
{

    (( executing )) && {

# ────────────── help ─────────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_help ]] && {
            echo "usage:  atlas (s) (f) (o) (q)"
            echo "  s  ➜  system packages"
            echo "  f  ➜  flatpak apps"
            echo "  o  ➜  orphan packages"
            echo "  q  ➜  quiet mode"

            echo
        }

# ────────────── loading ──────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_loading ]] && {
            (( lpid )) && {
                eval "${ptrap:-trap - 2}"
                kill $lpid
                wait $lpid &>/dev/null
                lpid=
                echo -en "\e[K$show_cur"
                return
            }

            {
                while :
                do
                    for c in "( / )" "( — )" "( \ )" "( | )"
                    do
                        echo -en "$bold$c$reset $lmsg\r"
                        sleep 0.05
                    done
                done &
            } 2>/dev/null

            lpid=$!
            echo -en "$hide_cur"
            ptrap=$(trap -p 2)
            trap "atlas ex_loading; kill -2 $$" 2
        }

# ────────────── system ───────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_system ]] && {
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
                    (( clast )) && pfx="└─ " || pfx="├─ "

                    echo -e "$indent$dim$pfx$pkg$reset"
                done
            done

            echo
        }

# ────────────── flatpaks ─────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_flatpaks ]] && {
            mapfile -t flatpaks < <(flatpak list --app --columns=name)

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

            queue+=(ex_flatpaks_prompt)

            echo
        }

# ────────────── orphans ──────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_orphans ]] && {
            mapfile -t orphans < <(pacman -Qqtd)

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

            queue+=(ex_orphans_prompt)

            echo
        }

# ────────────── extra ────────────────────────────────────────────────────────────────────────── ●

        (( quiet )) || {

            [[ $1 = ex_intro ]] && {
                lmsg="${dim}atlas: executing$reset"
                atlas ex_loading
                sleep 1
                atlas ex_loading
            }

            [[ $1 = ex_flatpaks_prompt ]] && {
                lmsg="${dim}checking updates$reset"
                atlas ex_loading
                mapfile -t updates < <(flatpak remote-ls --updates --columns=application)
                atlas ex_loading

                (( ${#updates[@]} )) || return

                echo -en "upgrade flatpaks? (y/${bold}n$reset) "
                read ans
                [[ ${ans,,} = y ]] && {
                    flatpak update ${updates[@]}
                    flatpak remove --unused -y &>/dev/null
                }

                echo
            }

            [[ $1 = ex_orphans_prompt ]] && {
                echo -en "uninstall orphans? (y/${bold}n$reset) "
                read ans
                [[ ${ans,,} = y ]] && sudo pacman -Rns ${orphans[@]}

                echo
            }

        }

# ────────────── execution ────────────────────────────────────────────────────────────────────── ●

    :;} || {

        local quiet lpid ptrap lmsg system pkg dep i last pfx j children clast indent flatpaks orphans updates ans
        local bold="\e[1m" dim="\e[2m" red="\e[31m" reset="\e[m" hide_cur="\e[?25l" show_cur="\e[?25h"

        local executing=1
        echo

        local arg queue index

        for arg
        do
            case $arg in
                s) [[ ${queue[@]} = ex_system ]] || queue+=(ex_system) ;;
                f) [[ ${queue[@]} = ex_flatpaks ]] || queue+=(ex_flatpaks) ;;
                o) [[ ${queue[@]} = ex_orphans ]] || queue+=(ex_orphans) ;;
                q) quiet=1 ;;
                *) atlas ex_help; return ;;
            esac
        done

        (( ${#queue[@]} )) || queue=(ex_intro ex_system ex_flatpaks ex_orphans)

        while (( index < ${#queue[@]} ))
        do
            atlas ${queue[$index]}
            (( index++ ))
        done

    }

}

# ───────────────────────────────────────────────────────────────────────────────────────── << atlas() >> ───────────────────────────────────────────────────────────────────────────────────────── #
