# ─────────────────────────────────────────────────────────────────────────────────────────── \\  ▼  // ─────────────────────────────────────────────────────────────────────────────────────────── #
                                                                                               atlas()
{
    (( executing )) && {

# ────────────── help ─────────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_help ]] && {
            echo "usage:  atlas (q) (s) (f) (o) (u) (d)"
            echo "  q  ➜  quiet mode"
            echo "  s  ➜  list system packages"
            echo "  f  ➜  list flatpak apps"
            echo "  o  ➜  list orphans"
            echo "  u  ➜  update flatpaks"
            echo "  d  ➜  delete orphans"
            echo
        }

# ────────────── loading ──────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_loading ]] && {
            (( lpid )) && {
                eval "${ptrap:-trap - 2}"
                kill $lpid
                wait $lpid &>/dev/null
                lpid=
                echo -en "\r\e[K$scur"
                return
            }

            {
                while :
                do
                    for c in "( / )" "( — )" "( \ )" "( | )"
                    do
                        echo -en "\r$bold$c$reset"
                        sleep 0.05
                    done
                done &
            } 2>/dev/null

            lpid=$!
            echo -en "$hcur"
            ptrap=$(trap -p 2)
            trap "atlas ex_loading; kill -2 $$" 2
        }

# ────────────── system ───────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_system ]] && {
            mapfile -t system < <(comm -23 <(pacman -Qqtt) <(pacman -Qqtd))

            (( quiet )) || {
                for pkg in ${system[*]}
                do sysmap[$pkg]=
                done

                while read pkg dep
                do [[ -v sysmap[$dep] ]] && sysmap[$pkg]+="$dep "
                done < <(LC_ALL=C pacman -Qi ${system[*]} | awk '
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
            mapfile -t orphans < <(pacman -Qqtd)
        }

# ────────────── upgrade ──────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_upgrade ]] && {
            mapfile -t updates < <(flatpak remote-ls --updates --columns=application 2>/dev/null)
        }

# ────────────── delete ───────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_delete ]] && {
            mapfile -t orphans < <(pacman -Qqtd)
        }

# ────────────── view ─────────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_view ]] && {
            for a in $args
            do
                [[ $a = s ]] && {
                    [[ ${system[0]} ]] && {
                        echo -e "${bold}system (${#system[*]})$reset"
                        local -n carr=system
                        local -n cmap=sysmap
                        atlas ex_render
                    }
                }

                [[ $a = f ]] && {
                    [[ ${flatpaks[0]} ]] && {
                        echo -e "${bold}flatpaks (${#flatpaks[*]})$reset"
                        local -n carr=flatpaks
                        local -n cmap=nilmap
                        atlas ex_render
                    }
                }

                [[ $a = o ]] && {
                    [[ ${orphans[0]} ]] && {
                        echo -e "$bold${red}orphans (${#orphans[*]})$reset"
                        local -n carr=orphans
                        local -n cmap=nilmap
                        atlas ex_render
                    }
                }

                [[ $a = u ]] && {
                    [[ ${updates[0]} ]] && {
                        echo -en "upgrade flatpaks? (y/${bold}n$reset) "
                        read ans
                        [[ ${ans,,} = y ]] && {
                            flatpak update ${updates[*]}
                            flatpak remove --unused -y &>/dev/null
                        }
                        echo
                    }
                }

                [[ $a = d ]] && {
                    [[ ${orphans[0]} ]] && {
                        echo -en "delete orphans? (y/${bold}n$reset) "
                        read ans
                        [[ ${ans,,} = y ]] && sudo pacman -Rns ${orphans[*]}
                        echo
                    }
                }
            done
        }

# ────────────── render ───────────────────────────────────────────────────────────────────────── ●

        [[ $1 = ex_render ]] && {
            for i in ${!carr[*]}
            do
                pkg=${carr[i]}

                last=$(( i == ${#carr[*]} - 1 ))

                (( last )) && pfx="│\n└─ " || pfx="│\n├─ "
                (( quiet )) && pfx=

                echo -e "$pfx$pkg"

                children=(${cmap[$pkg]})

                for ii in ${!children[*]}
                do
                    pkg=${children[ii]}

                    lastc=$(( ii == ${#children[*]} - 1 ))

                    (( last )) && indent="   " || indent="│  "
                    (( lastc )) && pfx="└─ " || pfx="├─ "

                    echo -e "$indent$dim$pfx$pkg$reset"
                done
            done

            echo
        }

# ────────────── execution ────────────────────────────────────────────────────────────────────── ●

    :;} || {
        local a ans args carr cmap children dep flatpaks i ii indent last lastc lpid orphans pfx pkg ptrap quiet system updates
        local -A sysmap nilmap
        local bold="\e[1m" dim="\e[2m" red="\e[31m" reset="\e[m" hcur="\e[?25l" scur="\e[?25h" loffset="\e[7G"

        local executing=1
        echo

        for a
        do
            [[ $a = [sfoudq] ]] || {
                atlas ex_help
                return
            }
        done

        [[ $* = *q* ]] && quiet=1
        [[ $* = *[sfoud]* ]] || set s f o u d

        atlas ex_loading

        [[ $* = *s* ]] && {
            echo -en "$loffset${dim}atlas: executing system$reset"
            atlas ex_system
        }

        [[ $* = *f* ]] && {
            echo -en "$loffset${dim}atlas: executing flatpaks$reset\e[K"
            atlas ex_flatpaks
        }

        [[ $* = *o* ]] && {
            echo -en "$loffset${dim}atlas: executing orphans$reset\e[K"
            atlas ex_orphans
        }

        [[ $* = *u* ]] && {
            echo -en "$loffset${dim}atlas: executing upgrade$reset\e[K"
            atlas ex_upgrade
        }

        [[ $* = *d* ]] && {
            echo -en "$loffset${dim}atlas: executing delete$reset\e[K"
            atlas ex_delete
        }

        atlas ex_loading

        args=$*
        atlas ex_view
    }
}

# ───────────────────────────────────────────────────────────────────────────────────────── << atlas() >> ───────────────────────────────────────────────────────────────────────────────────────── #
