#!/bin/bash

cd "$(dirname "$0")"
for f in cli time-series-chart; do
    echo '#!/usr/bin/env node' > "../bin/$f.js"
    chmod +x "../bin/$f.js"
    coffee -bp "$f.coffee" >> "../bin/$f.js"
done

coffee -bp build.coffee > ../bin/build.js