test:default() {
    snapshot stdout && mdtable < test/test.txt
}

test:regex-whitespace() {
    snapshot stdout && mdtable -r ' ' < test/test.txt
}

test:regex-csv() {
  snapshot stdout && cat <<EOF | mdtable -r '\s*,\s*'
header 1,   header 2
foo  , bar
qux ,   baz
EOF
}

test:json-objects() {
    snapshot stdout && cat <<EOF | mdtable -j
[
  { "a": "this is some", "b": "json input" },
  { "a": "here is another line", "b": "of json input" }
]
EOF
}

test:json-arrays() {
    snapshot stdout && cat <<EOF | mdtable -j
[
  [ "json input", "in an array" ],
  [ "another row", "of json input" ]
]
EOF
}

test:csv-simple() {
    snapshot stdout && cat <<EOF | mdtable -c
some  ,header,columns
a,row   , of data
another row,   of data
EOF
}

test:csv-quoted() {
    snapshot stdout && cat <<EOF | mdtable -c
stuff," and",  things
this is not, the "greatest" song, in the world
this is, just, a tribute
EOF
}

test:plaintext() {
    snapshot stdout && mdtable -p < test/test.txt
}

test:include() {
    snapshot stdout && mdtable -i 1,3 < test/test.txt
}

test:exclude() {
    snapshot stdout && mdtable -e 1,3 < test/test.txt
}

test:align-and-names() {
    snapshot stdout && mdtable -r ' ' -a lrcc -n some,different,column,names < test/test.txt
}

test:truncate() {
    snapshot stdout && mdtable -r ' ' -t 4 < test/test.txt
}