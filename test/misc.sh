test:dhms() {
    assert_equal "$(dhms 3)" 3s
    assert_equal "$(dhms 63)" '1m 3s'
    assert_equal "$(dhms 4233)" '1h 10m 33s'
    assert_equal "$(dhms 86999)" '1d 9m 59s' # note: no hours, it's 0
}

test:commify() {
    snapshot stdout
    unset n
    for i in $(seq 1 9); do n="$n$i" && commify "$n"; done
    n="$n."
    for i in $(seq 1 9); do n="$n$i" && commify "$n"; done
}
