BEGIN {
    output = 1
}

/\/\*.*\*\// {
    sub ("/\\*.*\\*/", "")
}

/\/\*.*$/ {
    sub ("/\\*.*", "")
    output = 0
}

/\*\// {
    if (output == 0) {
        sub (".*\\*/", "")
        output = 1
    }
}

{
    if (output) print $0
}
