# ─────────────────────────────────────────────────────────────────────────────────────────── \\  ▼  // ─────────────────────────────────────────────────────────────────────────────────────────── #
                                                                                               atlas()
{

# ────────────── execution ────────────────────────────────────────────────────────────────────── ●

    (( executing )) || {
        local executing=1
        echo

        local tracer sig core quiet pkg opt flatpaks orphans updates i last pfx color children ii lastc indent intent
        local -A cmap nilmap
        local bold="\e[1m" dim="\e[2m" red="\e[31m" r="\e[m" hc="\e[?25l" sc="\e[?25h" origin="\e[7G" ops=$*

        atlas ex_scan
        atlas ex_interface
    }

# ────────────── scan ─────────────────────────────────────────────────────────────────────────── ●

    [[ $1 = ex_scan ]] && {
        [[ $ops =~ [^qcfoud\ ] ]] && atlas ex_error
        [[ $ops =~ q ]] && quiet=1
        [[ $ops =~ [cfoud] ]] || ops=cfoud

        atlas ex_tracer

        [[ $ops =~ c ]] && {
            echo -en "$origin${dim}atlas: scanning core$r"
            core=( $(grep -vxf <(pacman -Qqtd) <(pacman -Qqtt)) )
            (( quiet )) || atlas ex_cmap
        }

        [[ $ops =~ f ]] && {
            echo -en "$origin${dim}atlas: scanning flatpaks$r\e[K"
            mapfile -t flatpaks < <(flatpak list --app --columns=name 2>/dev/null)
        }

        [[ $ops =~ [od] ]] && {
            echo -en "$origin${dim}atlas: scanning orphans$r\e[K"
            orphans=( $(pacman -Qqtd) )
        }

        [[ $ops =~ u ]] && {
            echo -en "$origin${dim}atlas: scanning updates$r\e[K"
            updates=( $(flatpak remote-ls --updates --columns=application 2>/dev/null) )
        }

        atlas ex_tracer
    }

# ────────────── error ────────────────────────────────────────────────────────────────────────── ●

    [[ $1 = ex_error ]] && {
        echo "usage:  atlas (q) (c) (f) (o) (d) (u)"
        echo "  q  ➜  quiet mode"
        echo "  c  ➜  view core packages"
        echo "  f  ➜  view flatpak apps"
        echo "  o  ➜  view orphans"
        echo "  d  ➜  delete orphans"
        echo "  u  ➜  update flatpaks"
        kill -2 $$
    }

# ────────────── tracer ───────────────────────────────────────────────────────────────────────── ●

    [[ $1 = ex_tracer ]] && {
        (( tracer )) && {
            eval "${sig:-trap - 2}"
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
        sig=$(trap -p 2)
        trap "atlas ex_tracer; kill -2 $$" 2
    }

# ────────────── cmap ─────────────────────────────────────────────────────────────────────────── ●

    [[ $1 = ex_cmap ]] && {
        while read pkg opt
        do [[ " ${core[*]} " =~ " $opt " ]] && cmap[$pkg]+="$opt "
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

# ────────────── interface ────────────────────────────────────────────────────────────────────── ●

    [[ $1 = ex_interface ]] && {
        [[ $core ]] && {
            echo -e "${bold}core (${#core[*]})$r"
            local -n arr=core
            local -n map=cmap
            atlas ex_render
        }

        [[ $flatpaks ]] && {
            echo -e "${bold}flatpaks (${#flatpaks[*]})$r"
            local -n arr=flatpaks
            local -n map=nilmap
            atlas ex_render
        }

        [[ $orphans ]] && {
            [[ $ops =~ o ]] && {
                echo -e "$bold${red}orphans (${#orphans[*]})$r"
                local -n arr=orphans
                local -n map=nilmap
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

# ────────────── render ───────────────────────────────────────────────────────────────────────── ●

    [[ $1 = ex_render ]] && {
        for i in ${!arr[*]}
        do
            pkg=${arr[i]}

            last=$(( i == ${#arr[*]} - 1 ))

            (( last )) && pfx="│\n└─ " || pfx="│\n├─ "
            (( quiet )) && pfx=

            echo -e "$color$pfx$pkg$r"

            children=( ${map[$pkg]} )

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

# ────────────── termination ──────────────────────────────────────────────────────────────────── ●

}

# ───────────────────────────────────────────────────────────────────────────────────────── << atlas() >> ───────────────────────────────────────────────────────────────────────────────────────── #
