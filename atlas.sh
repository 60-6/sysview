# ─────────────────────────────────────────────────────────────────────────────────────────── \\  ▼  // ─────────────────────────────────────────────────────────────────────────────────────────── #
                                                                                               atlas()
{

# ────────────── execute ──────────────────────────────────────────────────────────────────────── ●

    (( executing )) || {
        local executing=1
        echo

        local pulse sig core quiet pkg opt flatpaks orphans updates i last pfx attr children ii lastc indent intent
        local -A clineage null
        local bold="\e[1m" dim="\e[2m" red="\e[31m" r="\e[m" hc="\e[?25l" sc="\e[?25h" origin="\e[7G" ops=$*

        atlas _scan
        atlas _resolve
    }

# ────────────── scan ─────────────────────────────────────────────────────────────────────────── ●

    [[ $1 = _scan ]] && {
        [[ $ops =~ [^qcfoud\ ] ]] && atlas _error
        [[ $ops =~ q ]] && quiet=1
        [[ $ops =~ [cfoud] ]] || ops=cfoud

        {
            atlas _pulse

            [[ $ops =~ c ]] && {
                echo -en "$origin${dim}atlas: scanning core$r"
                core=( $(grep -vxf <(pacman -Qqtd) <(pacman -Qqtt)) )
                (( quiet )) || atlas _extract
            }

            [[ $ops =~ f ]] && {
                echo -en "$origin${dim}atlas: scanning flatpaks$r\e[K"
                mapfile -t flatpaks < <(flatpak list --app --columns=name)
            }

            [[ $ops =~ [od] ]] && {
                echo -en "$origin${dim}atlas: scanning orphans$r\e[K"
                orphans=( $(pacman -Qqtd) )
            }

            [[ $ops =~ u ]] && {
                echo -en "$origin${dim}atlas: scanning updates$r\e[K"
                updates=( $(flatpak remote-ls --updates --columns=application) )
            }

            atlas _pulse
        } 2>/dev/null
    }

# ────────────── error ────────────────────────────────────────────────────────────────────────── ●

    [[ $1 = _error ]] && {
        echo "usage:  atlas (q) (c) (f) (o) (d) (u)"
        echo "  q  ➜  quiet mode"
        echo "  c  ➜  view core packages"
        echo "  f  ➜  view flatpak apps"
        echo "  o  ➜  view orphans"
        echo "  d  ➜  delete orphans"
        echo "  u  ➜  update flatpaks"
        kill -2 $$
    }

# ────────────── pulse ────────────────────────────────────────────────────────────────────────── ●

    [[ $1 = _pulse ]] && {
        (( pulse )) && {
            eval "${sig:-trap - 2}"
            kill $pulse
            wait $pulse
            pulse=
            echo -en "\r\e[K$sc"
            stty echo </dev/tty
            return
        }

        while :
        do
            for c in '/' '—' '\' '|'
            do
                echo -en "\r$bold( $c )$r"
                sleep 0.05
            done
        done &

        pulse=$!
        echo -en "$hc"
        stty -echo
        sig=$(trap -p 2)
        trap '
            atlas _pulse
            atlas _resolve
            echo -e "${red}scanning terminated$r"
            kill -2 $$
        ' 2
    }

# ────────────── extract ──────────────────────────────────────────────────────────────────────── ●

    [[ $1 = _extract ]] && {
        while read pkg opt
        do [[ " ${core[*]} " =~ " $opt " ]] && clineage[$pkg]+="$opt "
        done < <(LC_ALL=C pacman -Qi ${core[*]} | awk '
            proceed {
                if (/^ /) {
                    gsub(/^ +|:.*/, "")
                    print pkg, $0
                    next
                }
                proceed = 0
                next
            }
            /^Name/ {
                pkg = $NF
                next
            }
            /^Optional Deps/ {
                gsub(/^Optional Deps *: *|:.*/, "")
                print pkg, $0
                proceed = 1
            }
        ')
    }

# ────────────── resolve ──────────────────────────────────────────────────────────────────────── ●

    [[ $1 = _resolve ]] && {
        [[ $core ]] && {
            echo -e "${bold}core (${#core[*]})$r"
            local -n arr=core
            local -n lineage=clineage
            atlas _render
            local -n lineage=null
        }

        [[ $flatpaks ]] && {
            echo -e "${bold}flatpaks (${#flatpaks[*]})$r"
            local -n arr=flatpaks
            atlas _render
        }

        [[ $orphans ]] && {
            [[ $ops =~ o ]] && {
                echo -e "$bold${red}orphans (${#orphans[*]})$r"
                local -n arr=orphans
                attr=$red
                atlas _render
                attr=
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

# ────────────── render ───────────────────────────────────────────────────────────────────────── ●

    [[ $1 = _render ]] && {
        for i in ${!arr[*]}
        do
            pkg=${arr[i]}

            last=$(( i == ${#arr[*]} - 1 ))

            (( last )) && pfx="│\n└─ " || pfx="│\n├─ "
            (( quiet )) && pfx=

            echo -e "$attr$pfx$pkg$r"

            children=( ${lineage[$pkg]} )

            for ii in ${!children[*]}
            do
                pkg=${children[ii]}

                lastc=$(( ii == ${#children[*]} - 1 ))

                (( last )) && indent="   " || indent="│  "
                (( lastc )) && pfx="└─ " || pfx="├─ "

                echo -e "$attr$indent$dim$pfx$pkg$r"
            done
        done

        echo
    }
}

# ───────────────────────────────────────────────────────────────────────────────────────── << atlas() >> ───────────────────────────────────────────────────────────────────────────────────────── #
