# Commands for managing nested wave groups

set group_list {}
set prefix_list {}

# Starts a group: pass the name of the group and the path prefix
proc push_group {name prefix} {
    global group_list
    global prefix_list
    lappend group_list $name
    lappend prefix_list $prefix
}

# Exit a group, must be paired with push_group
proc pop_group {} {
    global group_list
    global prefix_list
    lremove group_list end
    lremove prefix_list end
}

# Automatically wraps push_group and pop_group around a set of actions
proc with_group {name prefix actions} {
    push_group $name $prefix
    eval $actions
    pop_group
}

# Adds a waveform group with the specified group name and (optional) prefix
proc add_wave {name {prefix ""}} {
    global group_list
    global prefix_list

    # Assemble group prefix list
    set group_args {}
    foreach group $group_list {
        lappend group_args -group
        lappend group_args $group
    }

    # Assemble path
    set path ""
    foreach entry $prefix_list {
        append path /$entry
    }

    add wave {*}$group_args -group $name $path/$prefix/*
}
