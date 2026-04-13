# ─────────────────────────────────────────────────────────────────────────────────────────── \\  ▼  // ─────────────────────────────────────────────────────────────────────────────────────────── #
                                                                                               atlas()
{
    (( executing )) && {

# ────────────── error ────────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_error ]] && {
            echo "usage:  atlas (q) (c) (f) (o) (d) (u)"
            echo "  q  ➜  quiet mode"
            echo "  c  ➜  view core packages"
            echo "  f  ➜  view flatpak apps"
            echo "  o  ➜  view orphans"
            echo "  d  ➜  delete orphans"
            echo "  u  ➜  update flatpaks"
            echo
            kill -2 $$
        }

# ────────────── tracer ───────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_tracer ]] && {
            (( tracer )) && {
                eval "${osig:-trap - 2}"
                kill $tracer
                wait $tracer 2>/dev/null
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
            osig=$(trap -p 2)
            trap "atlas ex_tracer; kill -2 $$" 2
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

# ────────────── orphans ──────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_orphans ]] && {
            orphans=( $(pacman -Qqtd) )
        }

# ────────────── updates ──────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_updates ]] && {
            updates=( $(flatpak remote-ls --updates --columns=application 2>/dev/null) )
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

# ────────────── scan ─────────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_scan ]] && {
            [[ $ops =~ [^qcfoud\ ] ]] && atlas ex_error
            [[ $ops =~ q ]] && quiet=1
            [[ $ops =~ [cfoud] ]] || ops=cfoud

            atlas ex_tracer

            [[ $ops =~ c ]] && {
                echo -en "$origin${dim}atlas: scanning core$r"
                atlas ex_core
            }

            [[ $ops =~ f ]] && {
                echo -en "$origin${dim}atlas: scanning flatpaks$r\e[K"
                atlas ex_flatpaks
            }

            [[ $ops =~ [od] ]] && {
                echo -en "$origin${dim}atlas: scanning orphans$r\e[K"
                atlas ex_orphans
            }

            [[ $ops =~ u ]] && {
                echo -en "$origin${dim}atlas: scanning updates$r\e[K"
                atlas ex_updates
            }

            atlas ex_tracer
        }

# ────────────── interface ────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_interface ]] && {
            [[ $core ]] && {
                echo -e "${bold}core (${#core[*]})$r"
                local -n carr=core
                local -n cmap=sysmap
                atlas ex_render
            }

            [[ $flatpaks ]] && {
                echo -e "${bold}flatpaks (${#flatpaks[*]})$r"
                local -n carr=flatpaks
                local -n cmap=nilmap
                atlas ex_render
            }

            [[ $orphans ]] && {
                [[ $ops =~ o ]] && {
                    echo -e "$bold${red}orphans (${#orphans[*]})$r"
                    local -n carr=orphans
                    local -n cmap=nilmap
                    color=$red
                    atlas ex_render
                    color=
                }

                [[ $ops =~ d ]] && {
                    echo -en "delete orphans? (y/${bold}n$r) "
                    read intent
                    [[ ${intent,,} = y ]] && sudo pacman -Rns ${orphans[*]}
                    echo
                }
            }

            [[ $updates ]] && {
                echo -en "upgrade flatpaks? (y/${bold}n$r) "
                read intent
                [[ ${intent,,} = y ]] && {
                    flatpak update ${updates[*]}
                    flatpak remove --unused -y
                }
                echo
            }
        }

# ────────────── execution ────────────────────────────────────────────────────────────────────── ●

    :;} || {
        local tracer osig core quiet pkg dep flatpaks orphans updates i last pfx color children ii lastc indent intent
        local -A sysmap nilmap
        local bold="\e[1m" dim="\e[2m" red="\e[31m" r="\e[m" hc="\e[?25l" sc="\e[?25h" origin="\e[7G" ops=$*

        local executing=1
        echo

        atlas ex_scan
        atlas ex_interface
    }
}

# ───────────────────────────────────────────────────────────────────────────────────────── << atlas() >> ───────────────────────────────────────────────────────────────────────────────────────── #
