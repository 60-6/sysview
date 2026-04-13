# ─────────────────────────────────────────────────────────────────────────────────────────── \\  ▼  // ─────────────────────────────────────────────────────────────────────────────────────────── #
                                                                                               atlas()
{
    (( executing )) && {

# ────────────── help ─────────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_invalid ]] && {
            echo "usage:  atlas (q) (c) (f) (w) (u) (d)"
            echo "  q  ➜  quiet mode"
            echo "  c  ➜  list core packages"
            echo "  f  ➜  list flatpak apps"
            echo "  w  ➜  list waste"
            echo "  u  ➜  update flatpaks"
            echo "  d  ➜  delete waste"
            echo
        }

# ────────────── loading ──────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_loading ]] && {
            (( tracer )) && {
                eval "${psig:-trap - 2}"
                kill $tracer
                wait $tracer &>/dev/null
                tracer=
                echo -en "\r\e[K$sc"
                return
            }

            {
                while :
                do
                    for f in "( / )" "( — )" "( \ )" "( | )"
                    do
                        echo -en "\r$bold$f$r"
                        sleep 0.05
                    done
                done &
            } 2>/dev/null

            tracer=$!
            echo -en "$hc"
            psig=$(trap -p 2)
            trap "atlas ex_loading; kill -2 $$" 2
        }

# ────────────── core ─────────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_core ]] && {
            core=( $(grep -vxf <(pacman -Qqtd) <(pacman -Qqtt)) )

            (( quiet )) || {
                while read pkg dep
                do [[ " ${core[*]} " =~ " $dep " ]] && sysmap[$pkg]+="$dep "
                done < <(LC_ALL=C pacman -Qi ${core[*]} | awk '
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
        }

# ────────────── flatpaks ─────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_flatpaks ]] && {
            mapfile -t flatpaks < <(flatpak list --app --columns=name 2>/dev/null)
        }

# ────────────── waste ────────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_waste ]] && {
            waste=( $(pacman -Qqtd) )
        }

# ────────────── upgrade ──────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_upgrade ]] && {
            delta=( $(flatpak remote-ls --updates --columns=application 2>/dev/null) )
        }

# ────────────── delete ───────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_delete ]] && {
            waste=( $(pacman -Qqtd) )
        }

# ────────────── view ─────────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_view ]] && {
            [[ $ops =~ c ]] && {
                echo -e "${bold}core (${#core[*]})$r"
                local -n carr=core
                local -n cmap=sysmap
                atlas ex_render
            }

            [[ $ops =~ f ]] && {
                [[ $flatpaks ]] && {
                    echo -e "${bold}flatpaks (${#flatpaks[*]})$r"
                    local -n carr=flatpaks
                    local -n cmap=nilmap
                    atlas ex_render
                }
            }

            [[ $ops =~ w ]] && {
                [[ $waste ]] && {
                    echo -e "$bold${red}waste (${#waste[*]})$r"
                    local -n carr=waste
                    local -n cmap=nilmap
                    color=$red
                    atlas ex_render
                    color=
                }
            }

            [[ $ops =~ u ]] && {
                [[ $delta ]] && {
                    echo -en "upgrade flatpaks? (y/${bold}n$r) "
                    read intent
                    [[ ${intent,,} = y ]] && {
                        flatpak update ${delta[*]}
                        flatpak remove --unused -y &>/dev/null
                    }
                    echo
                }
            }

            [[ $ops =~ d ]] && {
                [[ $waste ]] && {
                    echo -en "delete waste? (y/${bold}n$r) "
                    read intent
                    [[ ${intent,,} = y ]] && sudo pacman -Rns ${waste[*]}
                    echo
                }
            }
        }

# ────────────── render ───────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_render ]] && {
            for i in ${!carr[*]}
            do
                pkg=${carr[i]}

                last=$(( i == ${#carr[*]} - 1 ))

                (( last )) && pfx="│\n└─ " || pfx="│\n├─ "
                (( quiet )) && pfx=

                echo -e "$color$pfx$pkg$r"

                children=( ${cmap[$pkg]} )

                for ii in ${!children[*]}
                do
                    pkg=${children[ii]}

                    lastc=$(( ii == ${#children[*]} - 1 ))

                    (( last )) && indent="   " || indent="│  "
                    (( lastc )) && pfx="└─ " || pfx="├─ "

                    echo -e "$color$indent$dim$pfx$pkg$r"
                done
            done

            echo
        }

# ────────────── execution ────────────────────────────────────────────────────────────────────── ●

    :;} || {
        local quiet tracer psig core pkg dep flatpaks waste delta ops color intent i last pfx children ii lastc indent
        local -A sysmap nilmap
        local bold="\e[1m" dim="\e[2m" red="\e[31m" r="\e[m" hc="\e[?25l" sc="\e[?25h" origin="\e[7G"

        local executing=1
        echo

        [[ $* =~ [^cfwudq\ ] ]] && {
            atlas ex_invalid
            return
        }

        [[ $* =~ q ]] && quiet=1
        [[ $* =~ [cfwud] ]] || set c f w u d

        atlas ex_loading

        [[ $* =~ c ]] && {
            echo -en "$origin${dim}atlas: executing core$r"
            atlas ex_core
        }

        [[ $* =~ f ]] && {
            echo -en "$origin${dim}atlas: executing flatpaks$r\e[K"
            atlas ex_flatpaks
        }

        [[ $* =~ w ]] && {
            echo -en "$origin${dim}atlas: executing waste$r\e[K"
            atlas ex_waste
        }

        [[ $* =~ u ]] && {
            echo -en "$origin${dim}atlas: executing upgrade$r\e[K"
            atlas ex_upgrade
        }

        [[ $* =~ d ]] && {
            echo -en "$origin${dim}atlas: executing delete$r\e[K"
            atlas ex_delete
        }

        atlas ex_loading

        ops=$*
        atlas ex_view
    }
}

# ───────────────────────────────────────────────────────────────────────────────────────── << atlas() >> ───────────────────────────────────────────────────────────────────────────────────────── #
