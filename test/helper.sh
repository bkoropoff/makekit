skip_test()
{
    echo "$@" > .skip
    exit 1
}