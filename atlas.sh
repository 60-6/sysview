# ─────────────────────────────────────────────────────────────────────────────────────────── \\  ▼  // ─────────────────────────────────────────────────────────────────────────────────────────── #
                                                                                               atlas()
{

#  ┌──────────── execute ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐ 0

    (( executing )) || {
        local executing=1
        echo

        local attr children core flatpaks i ii indent intent last lastc opt orphans pfx pkg pulse quiet scanc scano scanf sig
        local -A clineage nullaa
        local bold="\e[1m" dim="\e[2m" red="\e[31m" r="\e[m" hc="\e[?25l" sc="\e[?25h" origin="\e[7G" ops=$*

        atlas _interpret
        atlas _resolve
    }

#  ┌──────────── interpret ─────────────────────────────────────────────────────────────────────────────────────────────────────────┐ 1

    [[ $1 = _interpret ]] && {
        [[ $ops =~ [^qcofsudr\ ] ]] && atlas _error
        [[ $ops =~ [cofsudr] ]] || ops+=cofsudr
    }

#  ┌──────────── error ───────────────────────────────────────────────────────────────────────────────────────────┐ 2

    [[ $1 = _error ]] && {
        echo "usage:  atlas ${dim}commands$r"
        echo "  q  ➜  quiet"
        echo "  c  ➜  core"
        echo "  o  ➜  orphans"
        echo "  f  ➜  flatpaks"
        echo "  s  ➜  save"
        echo "  u  ➜  upgrade"
        echo "  d  ➜  delta"
        echo "  r  ➜  remove"
        kill -2 $$
    }

#  ┌──────────── resolve ───────────────────────────────────────────────────────────────────────────────────────────────────────────┐ 1

    [[ $1 = _resolve ]] && {
        [[ $ops =~ c ]] && scanc=1
        [[ $ops =~ [or] ]] && scano=1
        [[ $ops =~ f ]] && scanf=1
        [[ $ops =~ q ]] && quiet=1

        atlas _scan
        atlas _visualize

        [[ $ops =~ s ]] && atlas _save
        [[ $ops =~ u ]] && atlas _upgrade
        [[ $ops =~ d ]] && atlas _delta
        [[ $ops =~ r && $orphans ]] && atlas _remove
    }

#  ┌──────────── scan ────────────────────────────────────────────────────────────────────────────────────────────┐ 2

    [[ $1 = _scan ]] && {
        {
            atlas _pulse

            (( scanc || scano )) && {
                echo -en "$origin${dim}atlas: scanning orphans$r"
                orphans=( $(pacman -Qqtd) )
            }

            (( scanc )) && {
                echo -en "$origin${dim}atlas: scanning core$r\e[K"
                core=( $(grep -vxf <(printf "%s\n" ${orphans[*]}) <(pacman -Qqtt)) )
                (( quiet )) || atlas _extractcl
            }

            (( scanf )) && {
                echo -en "$origin${dim}atlas: scanning flatpaks$r\e[K"
                mapfile -t flatpaks < <(flatpak list --app --columns=name)
            }

            atlas _pulse
        } 2>/dev/null
    }

#  ┌──────────── pulse ─────────────────────────────────────────────────────────────────────────┐ 3

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
            echo -e "${red}scanning terminated$r"
            kill -2 $$
        ' 2
    }

#  ┌──────────── extractcl ─────────────────────────────────────────────────────────────────────┐ 3

    [[ $1 = _extractcl ]] && {
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

#  ┌──────────── visualize ──────────────────────────────────────────────────────────────────────────────────────┐ 2

    [[ $1 = _visualize ]] && {
        [[ $ops =~ c ]] && {
            echo -e "${bold}core (${#core[*]})$r"
            local -n arr=core
            local -n lineage=clineage
            atlas _render
        }

        [[ $ops =~ o && $orphans ]] && {
            echo -e "$bold${red}orphans (${#orphans[*]})$r"
            local -n arr=orphans
            local -n lineage=nullaa
            attr=$red
            atlas _render
            attr=
        }

        [[ $ops =~ f && $flatpaks ]] && {
            echo -e "${bold}flatpaks (${#flatpaks[*]})$r"
            local -n arr=flatpaks
            local -n lineage=nullaa
            atlas _render
        }
    }

#  ┌──────────── render ────────────────────────────────────────────────────────────────────────┐ 3

    [[ $1 = _render ]] && {
        for i in ${!arr[*]}
        do
            pkg=${arr[i]}

            last=$(( i == ${#arr[*]} - 1 ))

            (( quiet )) || {
                (( last )) && pfx="│\n└─ " || pfx="│\n├─ "
            }

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

#  ┌──────────── save ────────────────────────────────────────────────────────────────────────────────────────────┐ 2

    [[ $1 = _save ]] && {
        echo -n #wip
    }

#  ┌──────────── upgrade ─────────────────────────────────────────────────────────────────────────────────────────┐ 2

    [[ $1 = _upgrade ]] && {
        echo -en "upgrade system? (y/${bold}n$r) "
        read intent
        [[ ${intent,,} = y ]] && {
            flatpak update
            flatpak remove --unused -y
            echo -n #wip
        }
        echo
    }

#  ┌──────────── delta ───────────────────────────────────────────────────────────────────────────────────────────┐ 2

    [[ $1 = _delta ]] && {
        echo -n #wip
    }

#  ┌──────────── remove ──────────────────────────────────────────────────────────────────────────────────────────┐ 2

    [[ $1 = _remove ]] && {
        echo -en "remove orphans? (y/${bold}n$r) "
        read intent
        [[ ${intent,,} = y ]] && sudo pacman -Rns ${orphans[*]}
        echo
    }

}

# ───────────────────────────────────────────────────────────────────────────────────────── << atlas() >> ───────────────────────────────────────────────────────────────────────────────────────── #
